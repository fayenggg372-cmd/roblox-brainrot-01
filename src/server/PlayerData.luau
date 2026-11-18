-- PlayerData.luau -- one record per player: cash, rebirths, upgrades,
-- the brainrots standing on their base, and which base plot is theirs.
-- Saved to a DataStore when Studio allows it (pcall: in a playtest with
-- API access off, the game keeps playing with in-memory data only).
-- Loaded saves are sanitised: a corrupt or tampered record can never
-- hand a player negative cash, a negative rebirth count, or an upgrade
-- level above the cap in Config.

local DataStoreService = game:GetService("DataStoreService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}
PlayerData._records = {}
PlayerData._store = nil

do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("BrainrotHeistV1")
	end)
	if ok then
		PlayerData._store = store
	end
end

function PlayerData.newRecord()
	return {
		cash = Config.START_CASH,
		rebirths = 0,
		upgrades = { Speed = 0, Slots = 0, Income = 0 },
		owned = {}, -- { { defId, mutation, slot } } brainrots on the base
		baseIndex = 0,
		lockedUntil = 0,
		lockCooldownUntil = 0,
		carrying = nil, -- stolen brainrot currently carried, if any
	}
end

function PlayerData.get(player)
	return PlayerData._records[player.UserId]
end

-- Clamp a loaded save into the ranges the game can actually honour.
local function sanitise(record)
	if type(record.cash) ~= "number" or record.cash < 0 then
		record.cash = Config.START_CASH
	else
		record.cash = math.floor(record.cash)
	end
	if type(record.rebirths) ~= "number" or record.rebirths < 0 then
		record.rebirths = 0
	else
		record.rebirths = math.floor(record.rebirths)
	end
	if type(record.upgrades) ~= "table" then
		record.upgrades = { Speed = 0, Slots = 0, Income = 0 }
	else
		for name, def in pairs(Config.UPGRADES) do
			local level = record.upgrades[name]
			if type(level) ~= "number" or level < 0 then
				record.upgrades[name] = 0
			else
				record.upgrades[name] = math.min(math.floor(level), def.maxLevel)
			end
		end
	end
	if type(record.owned) ~= "table" then
		record.owned = {}
	end
end

function PlayerData.create(player, baseIndex)
	local record = PlayerData.newRecord()
	record.baseIndex = baseIndex
	-- Restore a previous visit when the DataStore answers.
	if PlayerData._store then
		local ok, saved = pcall(function()
			return PlayerData._store:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			if type(saved.cash) == "number" then record.cash = saved.cash end
			if type(saved.rebirths) == "number" then record.rebirths = saved.rebirths end
			if type(saved.upgrades) == "table" then record.upgrades = saved.upgrades end
			if type(saved.owned) == "table" then record.owned = saved.owned end
			sanitise(record)
		end
	end
	PlayerData._records[player.UserId] = record
	return record
end

function PlayerData.save(player)
	local record = PlayerData._records[player.UserId]
	if not record or not PlayerData._store then
		return
	end
	local ownedCopy = {}
	for _, entry in ipairs(record.owned) do
		table.insert(ownedCopy, { defId = entry.defId, mutation = entry.mutation, slot = entry.slot })
	end
	pcall(function()
		PlayerData._store:SetAsync("player_" .. player.UserId, {
			cash = record.cash,
			rebirths = record.rebirths,
			upgrades = record.upgrades,
			owned = ownedCopy,
		})
	end)
end

function PlayerData.remove(player)
	PlayerData.save(player)
	PlayerData._records[player.UserId] = nil
end

-- Rebirth multiplier: +50% income per rebirth, compounding with upgrades.
function PlayerData.incomeMultiplier(record)
	local mult = 1 + Config.REBIRTH_MULTIPLIER_PER * record.rebirths
	mult = mult * (1 + 0.25 * (record.upgrades.Income or 0))
	return mult
end

function PlayerData.rebirthCost(record)
	return Config.REBIRTH_BASE_COST * (2 ^ record.rebirths)
end

function PlayerData.maxSlots(record)
	return Config.MAX_BASE_SLOTS + 2 * (record.upgrades.Slots or 0)
end

function PlayerData.walkSpeed(record)
	return 16 + 4 * (record.upgrades.Speed or 0)
end

function PlayerData.isLocked(record)
	return os.time() < record.lockedUntil
end

return PlayerData
