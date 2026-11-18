-- DailyRewardsService.luau -- Daily Heist Bonus: login streak rewards.
-- Every UTC day a player logs in and claims, their streak grows by one and
-- they are paid the cash for that day of a 7-day cycle. Day 7 pays a big
-- jackpot, then the cycle wraps to day 1 while the streak keeps counting.
-- Missing a day resets the streak to 1; claiming twice in one day is
-- impossible, because the server -- never the client -- owns the decision.
--
-- State lives in two places: an in-memory table for this session, and a
-- DataStore so streaks survive server restarts. Every DataStore call is
-- wrapped in pcall: when the store is down or throttled, the game keeps
-- running on memory alone instead of erroring mid-claim.
--
-- Two RemoteEvents are created here (not in init.server.luau):
--   "DailyRewardState" (server -> client): streak, reward day, claim status.
--   "DailyRewardClaim" (client -> server): the claim button's request.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardsData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewardsData"))

local DailyRewardsService = {}

local STORE_NAME = "BrainrotHeistDailyRewardsV1"
local STORE_KEY_PREFIX = "dailyRewards_"

-- [userId] = { streak: number, lastClaimDate: string ("YYYY-MM-DD" UTC) }
local states = {}
local dataStore = nil
local dataStoreOk = false
local remotesRef = nil
local playerDataRef = nil

-- Today's date as a UTC string, e.g. "2026-11-18". The "!" prefix forces
-- UTC so the day boundary is the same for every player on Earth.
local function todayDateString()
	return os.date("!%Y-%m-%d", os.time())
end

-- Days since 1970-01-01 for a civil date (Howard Hinnant's algorithm).
-- Pure arithmetic on the calendar, so no local timezone ever leaks in.
local function daysFromCivil(year, month, day)
	local y = year
	if month <= 2 then
		y = y - 1
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (month + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + day - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

-- "2026-11-18" -> 20773 (days since epoch), or nil when the string is bad.
local function dayNumber(dateString)
	if type(dateString) ~= "string" then
		return nil
	end
	local year, month, day = string.match(dateString, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not year then
		return nil
	end
	return daysFromCivil(tonumber(year), tonumber(month), tonumber(day))
end

local function newState()
	return { streak = 0, lastClaimDate = "" }
end

-- Which day of the cycle the player's streak is standing on. A fresh
-- streak (0) is about to claim day 1.
local function currentRewardDay(state)
	if state.streak <= 0 then
		return 1
	end
	return ((state.streak - 1) % DailyRewardsData.CYCLE_LENGTH) + 1
end

-- Load a player's streak from the DataStore, falling back to a fresh
-- streak when the store is down or has never seen this player.
local function loadState(player)
	local state = newState()
	if dataStoreOk then
		local ok, saved = pcall(function()
			return dataStore:GetAsync(STORE_KEY_PREFIX .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			if type(saved.streak) == "number" and saved.streak >= 0 then
				state.streak = math.floor(saved.streak)
			end
			if type(saved.lastClaimDate) == "string" and dayNumber(saved.lastClaimDate) ~= nil then
				state.lastClaimDate = saved.lastClaimDate
			end
		elseif not ok then
			warn("[DailyRewards] Load failed for " .. player.Name .. "; starting fresh in memory.")
		end
	end
	states[player.UserId] = state
	return state
end

-- Persist a player's streak. A failed save only warns: the in-memory
-- state is still correct for the rest of this session.
local function saveState(player)
	if not dataStoreOk then
		return
	end
	local state = states[player.UserId]
	if not state then
		return
	end
	local ok, err = pcall(function()
		dataStore:SetAsync(STORE_KEY_PREFIX .. player.UserId, {
			streak = state.streak,
			lastClaimDate = state.lastClaimDate,
		})
	end)
	if not ok then
		warn("[DailyRewards] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- The payload the client panel renders. claimedToday is derived live from
-- the stored date, so a stale flag can never grant a second claim.
local function buildPayload(player)
	local state = states[player.UserId] or newState()
	local today = todayDateString()
	local claimedToday = state.lastClaimDate == today
	return {
		streak = state.streak,
		rewardDay = currentRewardDay(state),
		claimedToday = claimedToday,
		canClaim = not claimedToday,
		lastClaimDate = state.lastClaimDate,
		today = today,
	}
end

local function sendState(player)
	if remotesRef and remotesRef.DailyRewardState then
		remotesRef.DailyRewardState:FireClient(player, buildPayload(player))
	end
end

local function notify(player, message)
	if remotesRef and remotesRef.Notify then
		remotesRef.Notify:FireClient(player, message)
	end
end

-- The one and only place a daily reward is granted. Validates everything:
-- the player must have a record, and the stored claim date must not be
-- today. A missed day resets the streak; a consecutive day grows it.
local function claimReward(player)
	local record = playerDataRef and playerDataRef.get(player)
	if not record then
		return
	end
	local state = states[player.UserId]
	if not state then
		state = loadState(player)
	end

	local today = todayDateString()
	if state.lastClaimDate == today then
		sendState(player)
		notify(player, "Daily bonus already claimed today -- come back tomorrow!")
		return
	end

	local todayNum = dayNumber(today)
	local lastNum = dayNumber(state.lastClaimDate)
	if lastNum == nil or todayNum == nil or (todayNum - lastNum) > 1 then
		-- First claim ever, a broken save, or a missed day: start over.
		state.streak = 1
	else
		-- Yesterday's claim: the streak survives.
		state.streak = state.streak + 1
	end

	local rewardDay = currentRewardDay(state)
	local reward = DailyRewardsData.rewardForDay(rewardDay)
	state.lastClaimDate = today

	record.cash += reward.cash
	saveState(player)
	if playerDataRef.save then
		playerDataRef.save(player)
	end
	sendState(player)

	if DailyRewardsData.isJackpotDay(rewardDay) then
		notify(player, "🎉 JACKPOT! Day 7 Daily Heist Bonus: "
			.. DailyRewardsData.formatCash(reward.cash)
			.. " (streak " .. state.streak .. " days)!")
	else
		notify(player, "🎁 Daily Heist Bonus Day " .. rewardDay .. ": "
			.. DailyRewardsData.formatCash(reward.cash)
			.. " (streak " .. state.streak .. " days)!")
	end
	print("[DailyRewards] " .. player.Name .. " claimed day " .. rewardDay
		.. " (" .. DailyRewardsData.formatCash(reward.cash) .. "), streak " .. state.streak)
end

local function onPlayerAdded(player)
	loadState(player)
	sendState(player)
end

local function onPlayerRemoving(player)
	saveState(player)
	states[player.UserId] = nil
end

-- init(world, remotes, PlayerData): creates the two RemoteEvents, wires the
-- claim handler, and hooks join/leave. `world` is accepted for the same
-- shape as the other services; daily rewards do not touch the map.
function DailyRewardsService.init(world, remotes, PlayerData)
	remotesRef = remotes
	playerDataRef = PlayerData

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and store then
		dataStore = store
		dataStoreOk = true
	else
		warn("[DailyRewards] DataStore unavailable; streaks are in-memory only this session.")
	end

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name = "DailyRewardState"
	stateRemote.Parent = remotesFolder
	remotes.DailyRewardState = stateRemote

	local claimRemote = Instance.new("RemoteEvent")
	claimRemote.Name = "DailyRewardClaim"
	claimRemote.Parent = remotesFolder
	remotes.DailyRewardClaim = claimRemote

	claimRemote.OnServerEvent:Connect(claimReward)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	print("[DailyRewards] Service ready. 7-day cycle, jackpot on day 7.")
end

return DailyRewardsService
