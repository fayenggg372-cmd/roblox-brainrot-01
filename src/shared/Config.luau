-- Config.luau -- one place for every tuning number of Brainrot Heist.
-- Server and client both read this module, so a balance change here
-- changes the whole game at once. Nothing here is a secret: the client
-- reads the same numbers the server enforces, and the server re-checks
-- every action instead of trusting the client's copy.

local Config = {}

Config.GAME_NAME = "Brainrot Heist"
Config.START_CASH = 100
Config.MAX_BASE_SLOTS = 6
Config.CONVEYOR_LENGTH = 170
Config.CONVEYOR_Z = -62
Config.CONVEYOR_Y = 2.5
Config.BRAINROT_WALK_SPEED = 7
Config.BRAINROT_SPAWN_INTERVAL = 4
Config.CONVEYOR_MAX = 8 -- most brainrots on the belt at once
Config.INCOME_TICK_SECONDS = 1
Config.AUTOSAVE_SECONDS = 60
Config.SELL_REFUND_FRACTION = 0.5 -- selling returns half the buy cost

-- Stealing: how long a lock lasts, how long before it can be used again.
Config.LOCK_DURATION = 45
Config.LOCK_COOLDOWN = 90
Config.LOCK_BASE_COST = 1000 -- +1000 per rebirth (see StealService.lockBase)
-- A stolen brainrot is carried; the carrier walks slower while carrying.
Config.CARRY_SPEED_MULTIPLIER = 0.75

-- Rebirth: cash needed is REBIRTH_BASE_COST * 2 ^ rebirths.
Config.REBIRTH_BASE_COST = 50000
Config.REBIRTH_MULTIPLIER_PER = 0.5

-- Upgrades: name -> { baseCost, costMult, maxLevel, description }.
Config.UPGRADES = {
	Speed = { baseCost = 500, costMult = 2.2, maxLevel = 5, description = "+4 WalkSpeed per level" },
	Slots = { baseCost = 2000, costMult = 3, maxLevel = 3, description = "+2 base slots per level" },
	Income = { baseCost = 1500, costMult = 2.5, maxLevel = 5, description = "+25% income per level" },
}

-- Tsunami event: warning, then the wave sweeps the map.
Config.EVENT_INTERVAL = 120
Config.EVENT_WARNING_SECONDS = 10
Config.EVENT_WAVE_SPEED = 28

-- Rarity colours, used by the HUD, the billboards and the shop list.
Config.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 70, 120),
	["Brainrot God"] = Color3.fromRGB(255, 230, 60),
	Secret = Color3.fromRGB(120, 255, 220),
}

-- Mutation multipliers and spawn chances (rolled per brainrot).
Config.MUTATIONS = {
	{ name = "Gold", mult = 2, chance = 0.15, color = Color3.fromRGB(255, 215, 0) },
	{ name = "Diamond", mult = 5, chance = 0.05, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Rainbow", mult = 10, chance = 0.015, color = Color3.fromRGB(255, 120, 220) },
}

-- The four base plots, in join order. Each plot is a coloured pad with
-- pedestals; a player's brainrots live on their plot and earn money.
Config.BASES = {
	{ name = "Base 1", center = Vector3.new(-62, 0, 48), color = Color3.fromRGB(255, 90, 90) },
	{ name = "Base 2", center = Vector3.new(62, 0, 48), color = Color3.fromRGB(90, 140, 255) },
	{ name = "Base 3", center = Vector3.new(-62, 0, -8), color = Color3.fromRGB(90, 255, 140) },
	{ name = "Base 4", center = Vector3.new(62, 0, -8), color = Color3.fromRGB(255, 220, 90) },
}

return Config
