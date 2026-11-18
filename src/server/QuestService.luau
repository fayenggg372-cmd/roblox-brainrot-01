-- QuestService.luau
-- "Heist Contracts": session quests for Brainrot Heist.
--
-- Each player gets a fresh set of contracts when they join; progress lives
-- only in memory and is wiped when the player leaves (no DataStore here).
-- Progress is tracked two ways:
--   * event listeners on the existing remotes (BuyBrainrot, SellBrainrot,
--     LockBase, Rebirth, BuyUpgrade), and
--   * a 1-second heartbeat that watches peak cash and accumulates income.
-- Completed contracts are claimed by the player through the ClaimQuest
-- remote; the reward is paid straight into the player's cash.
--
-- Remotes created by this service (inside ReplicatedStorage "Remotes"):
--   QuestUpdate (server -> client): full contract list with progress.
--   ClaimQuest  (client -> server): player claims a finished contract.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local Format = require(Shared:WaitForChild("Format"))

local QuestService = {}

-- ---------------------------------------------------------------------------
-- Contract definitions.
-- id, title, description, goal (number), reward (cash $).
-- ---------------------------------------------------------------------------
local CONTRACTS = {
	{
		id = "first-haul",
		title = "First Haul",
		description = "Buy your first brainrot from the conveyor.",
		goal = 1,
		reward = 500,
	},
	{
		id = "collector",
		title = "Collector",
		description = "Buy 3 brainrots and grow your base.",
		goal = 3,
		reward = 1500,
	},
	{
		id = "big-spender",
		title = "Big Spender",
		description = "Spend $10,000 buying brainrots.",
		goal = 10000,
		reward = 2500,
	},
	{
		id = "spring-cleaning",
		title = "Spring Cleaning",
		description = "Sell 2 brainrots you no longer want.",
		goal = 2,
		reward = 1000,
	},
	{
		id = "lockdown",
		title = "Lockdown",
		description = "Lock your base once to keep thieves out.",
		goal = 1,
		reward = 1500,
	},
	{
		id = "reborn",
		title = "Reborn",
		description = "Complete 1 rebirth and rise stronger.",
		goal = 1,
		reward = 5000,
	},
	{
		id = "upgrader",
		title = "Upgrader",
		description = "Buy 2 upgrades for your empire.",
		goal = 2,
		reward = 2000,
	},
	{
		id = "tycoon",
		title = "Tycoon",
		description = "Hold $25,000 cash at once.",
		goal = 25000,
		reward = 3000,
	},
	{
		id = "moneybags",
		title = "Moneybags",
		description = "Earn $50,000 total income from your brainrots.",
		goal = 50000,
		reward = 5000,
	},
}

-- Fast lookup: contract id -> definition.
local BY_ID = {}
for _, contract in ipairs(CONTRACTS) do
	BY_ID[contract.id] = contract
end

-- ---------------------------------------------------------------------------
-- Per-player session state (in-memory only, keyed by UserId).
--   progress[userId][contractId] = { progress = number, claimed = boolean }
--   snapshots[userId] = { owned = number, rebirths = number, upgrades = number }
-- Snapshots let us count only purchases/sales that actually happened: the
-- buy/sell remotes fire before we know whether the action succeeded, so we
-- compare the owned-brainrot count before and after the service handled it.
-- (QuestService.init runs after BrainrotService.init, so the brainrot
-- service's own listener processes the event first.)
-- ---------------------------------------------------------------------------
local progress = {}
local snapshots = {}

-- Service references, filled in by init().
local brainrotService = nil
local playerData = nil
local remotes = nil
local notifyEvent = nil
local questUpdateEvent = nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function newProgressTable()
	local state = {}
	for _, contract in ipairs(CONTRACTS) do
		state[contract.id] = { progress = 0, claimed = false }
	end
	return state
end

local function getState(player)
	local state = progress[player.UserId]
	if not state then
		state = newProgressTable()
		progress[player.UserId] = state
	end
	return state
end

-- How many upgrade levels a record has in total (all three upgrade tracks).
local function totalUpgrades(record)
	local total = 0
	if record.upgrades then
		for _, level in pairs(record.upgrades) do
			total += level
		end
	end
	return total
end

local function takeSnapshot(player)
	local record = playerData.get(player)
	if not record then
		return
	end
	snapshots[player.UserId] = {
		owned = #record.owned,
		rebirths = record.rebirths,
		upgrades = totalUpgrades(record),
	}
end

-- Add `amount` to a contract's progress (clamped at the goal) and push an
-- update to the player when the value actually moved.
local function addProgress(player, contractId, amount)
	local state = getState(player)
	local entry = state[contractId]
	local contract = BY_ID[contractId]
	if not entry or not contract then
		return
	end
	local before = entry.progress
	entry.progress = math.min(contract.goal, entry.progress + amount)
	if entry.progress ~= before then
		QuestService.sendUpdate(player)
	end
end

-- Build the contract list the client renders and fire it to one player.
function QuestService.sendUpdate(player)
	local state = getState(player)
	local list = {}
	for _, contract in ipairs(CONTRACTS) do
		local entry = state[contract.id]
		table.insert(list, {
			id = contract.id,
			title = contract.title,
			description = contract.description,
			goal = contract.goal,
			reward = contract.reward,
			progress = entry.progress,
			claimed = entry.claimed,
		})
	end
	questUpdateEvent:FireClient(player, list)
end

-- ---------------------------------------------------------------------------
-- Event handlers (hooked to the remotes the other services already own).
-- ---------------------------------------------------------------------------

local function onBuyBrainrot(player, brainrotId)
	local record = playerData.get(player)
	local snapshot = snapshots[player.UserId]
	if not record then
		return
	end
	if not snapshot then
		-- Record exists but we never snapshotted this player (e.g. they
		-- joined before this service started). Baseline now, count later.
		takeSnapshot(player)
		return
	end
	local ownedNow = #record.owned
	local bought = ownedNow - snapshot.owned
	if bought <= 0 then
		-- The purchase did not go through (not enough cash, base full, ...).
		return
	end
	-- Cost of the brainrot that was just bought.
	local spent = 0
	local def = BrainrotData.byId(brainrotId)
	if def then
		spent = def.cost * bought
	end
	addProgress(player, "first-haul", bought)
	addProgress(player, "collector", bought)
	addProgress(player, "big-spender", spent)
	snapshot.owned = ownedNow
end

local function onSellBrainrot(player, _slot)
	local record = playerData.get(player)
	local snapshot = snapshots[player.UserId]
	if not record or not snapshot then
		return
	end
	local ownedNow = #record.owned
	local sold = snapshot.owned - ownedNow
	if sold > 0 then
		addProgress(player, "spring-cleaning", sold)
	end
	snapshot.owned = ownedNow
end

local function onLockBase(player)
	-- Only count the lock if the base is actually locked now.
	local record = playerData.get(player)
	if record and playerData.isLocked(record) then
		addProgress(player, "lockdown", 1)
	end
end

local function onRebirth(player)
	local record = playerData.get(player)
	local snapshot = snapshots[player.UserId]
	if not record or not snapshot then
		return
	end
	if record.rebirths > snapshot.rebirths then
		addProgress(player, "reborn", record.rebirths - snapshot.rebirths)
	end
	-- Rebirth wipes cash and brainrots: refresh the snapshot so later
	-- buy/sell counts start from the post-rebirth numbers.
	snapshot.owned = #record.owned
	snapshot.rebirths = record.rebirths
end

local function onBuyUpgrade(player, _upgradeName)
	local record = playerData.get(player)
	local snapshot = snapshots[player.UserId]
	if not record or not snapshot then
		return
	end
	local levelsNow = totalUpgrades(record)
	local bought = levelsNow - snapshot.upgrades
	if bought > 0 then
		addProgress(player, "upgrader", bought)
	end
	snapshot.upgrades = levelsNow
end

-- ---------------------------------------------------------------------------
-- Claiming
-- ---------------------------------------------------------------------------

local function onClaimQuest(player, questId)
	if typeof(questId) ~= "string" then
		return
	end
	local contract = BY_ID[questId]
	if not contract then
		return
	end
	local state = getState(player)
	local entry = state[questId]
	if not entry or entry.claimed or entry.progress < contract.goal then
		return
	end
	local record = playerData.get(player)
	if not record then
		return
	end
	entry.claimed = true
	record.cash += contract.reward
	notifyEvent:FireClient(
		player,
		"Contract complete: " .. contract.title .. " — +" .. Format.money(contract.reward) .. "!"
	)
	QuestService.sendUpdate(player)
end

-- ---------------------------------------------------------------------------
-- Heartbeat: peak-cash watch (Tycoon) and income accumulation (Moneybags).
-- Runs once a second for every player currently in the game. It also
-- reconciles the owned/rebirth/upgrade snapshots, so brainrots removed by
-- other systems (a successful steal, a tsunami drop) cannot make a later
-- buy/sell event miscount.
-- ---------------------------------------------------------------------------

local function heartbeat()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local record = playerData.get(player)
			if record then
				local snapshot = snapshots[player.UserId]
				if snapshot then
					snapshot.owned = #record.owned
					snapshot.rebirths = record.rebirths
					snapshot.upgrades = totalUpgrades(record)
				end
				-- Tycoon: remember the most cash ever held this session.
				local state = getState(player)
				local tycoon = state["tycoon"]
				if record.cash > tycoon.progress then
					tycoon.progress = math.min(BY_ID["tycoon"].goal, record.cash)
					QuestService.sendUpdate(player)
				end
				-- Moneybags: income earned this second adds up.
				local income = brainrotService.totalIncome(player)
				if income > 0 then
					addProgress(player, "moneybags", income)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

local function onPlayerAdded(player)
	getState(player)
	takeSnapshot(player)
	-- Give the client a moment to connect its QuestUpdate listener, then
	-- push the fresh (all-zero) contract list.
	task.delay(1, function()
		if player.Parent then
			QuestService.sendUpdate(player)
		end
	end)
end

local function onPlayerRemoving(player)
	progress[player.UserId] = nil
	snapshots[player.UserId] = nil
end

function QuestService.init(worldRef, remotesRef, brainrotServiceRef, playerDataRef)
	brainrotService = brainrotServiceRef
	playerData = playerDataRef
	remotes = remotesRef

	notifyEvent = remotes:WaitForChild("Notify")

	-- Create the two remotes this service owns.
	questUpdateEvent = Instance.new("RemoteEvent")
	questUpdateEvent.Name = "QuestUpdate"
	questUpdateEvent.Parent = remotes

	local claimEvent = Instance.new("RemoteEvent")
	claimEvent.Name = "ClaimQuest"
	claimEvent.Parent = remotes
	claimEvent.OnServerEvent:Connect(onClaimQuest)

	-- Hook the existing remotes to track quest progress. These listeners
	-- only observe; the owning services still handle the actions.
	remotes:WaitForChild("BuyBrainrot").OnServerEvent:Connect(onBuyBrainrot)
	remotes:WaitForChild("SellBrainrot").OnServerEvent:Connect(onSellBrainrot)
	remotes:WaitForChild("LockBase").OnServerEvent:Connect(onLockBase)
	remotes:WaitForChild("Rebirth").OnServerEvent:Connect(onRebirth)
	remotes:WaitForChild("BuyUpgrade").OnServerEvent:Connect(onBuyUpgrade)

	-- Players already in the game (e.g. Studio play-test restarts).
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(heartbeat)
end

return QuestService
