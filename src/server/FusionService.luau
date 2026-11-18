-- FusionService.luau
-- "Brainrot Fusion": combine 3 brainrots you own that share the same rarity
-- into 1 random brainrot of the next rarity up.
--
-- Rarity ladder (bottom to top):
--   Common -> Rare -> Epic -> Legendary -> Mythic -> Brainrot God -> Secret
-- Secret brainrots sit at the top of the ladder, so they cannot be fused.
--
-- The client sends 3 base-slot numbers through the FuseBrainrots remote.
-- The server validates everything (slots exist, all three different, same
-- rarity, not Secret, and room on the base for the result) before it touches
-- any brainrot, then removes the three inputs and places the fused result.
--
-- Remote created by this service (inside ReplicatedStorage "Remotes"):
--   FuseBrainrots (client -> server): three slot numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))

local FusionService = {}

-- Rarity ladder, lowest first. The next rarity is simply the next entry.
local LADDER = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Brainrot God",
	"Secret",
}

-- Returns the rarity one step above `rarity`, or nil at the top of the ladder.
local function nextRarity(rarity)
	for index, name in ipairs(LADDER) do
		if name == rarity then
			return LADDER[index + 1]
		end
	end
	return nil
end

-- Service references, filled in by init().
local brainrotService = nil
local playerData = nil
local remotes = nil
local notifyEvent = nil

-- Find the owned entry sitting in a given base slot, or nil.
local function entryInSlot(player, slot)
	local owned = brainrotService.owned[player.UserId]
	if not owned then
		return nil
	end
	for _, entry in ipairs(owned) do
		if entry.slot == slot then
			return entry
		end
	end
	return nil
end

local function fail(player, message)
	notifyEvent:FireClient(player, "Fusion failed: " .. message)
end

-- ---------------------------------------------------------------------------
-- Fusion request handler.
-- ---------------------------------------------------------------------------

local function onFuse(player, slotA, slotB, slotC)
	-- 1. The payload must be three slot numbers.
	if typeof(slotA) ~= "number" or typeof(slotB) ~= "number" or typeof(slotC) ~= "number" then
		fail(player, "pick 3 brainrot slots to fuse.")
		return
	end

	-- 2. The three slots must be different from each other.
	if slotA == slotB or slotA == slotC or slotB == slotC then
		fail(player, "pick 3 different slots.")
		return
	end

	-- 3. All three slots must hold a brainrot right now.
	local first = entryInSlot(player, slotA)
	local second = entryInSlot(player, slotB)
	local third = entryInSlot(player, slotC)
	if not first or not second or not third then
		fail(player, "one of those slots is empty.")
		return
	end

	-- 4. All three brainrots must share one rarity.
	local rarity = first.def.rarity
	if second.def.rarity ~= rarity or third.def.rarity ~= rarity then
		fail(player, "all 3 brainrots must have the same rarity.")
		return
	end

	-- 5. Secret brainrots cannot be fused any further.
	local higher = nextRarity(rarity)
	if not higher then
		fail(player, "Secret brainrots cannot be fused.")
		return
	end

	-- 6. There must be a brainrot of the higher rarity to roll into.
	local candidates = BrainrotData.byRarity(higher)
	if not candidates or #candidates == 0 then
		fail(player, "no " .. higher .. " brainrot exists to fuse into.")
		return
	end

	-- 7. Room check: fusing frees 3 slots and takes 1, so the base must
	-- still fit the result after the inputs are gone. Without a record
	-- (player mid-leave, data not loaded) we cannot verify anything, so
	-- refuse instead of risking the three inputs.
	local record = playerData.get(player)
	if not record then
		fail(player, "could not load your data, please try again.")
		return
	end
	local owned = brainrotService.owned[player.UserId] or {}
	local afterCount = #owned - 3 + 1
	if afterCount > playerData.maxSlots(record) then
		fail(player, "not enough base slots for the fused brainrot.")
		return
	end

	-- All checks passed: roll the result first, then swap the brainrots.
	local resultDef = candidates[math.random(1, #candidates)]

	brainrotService.removeOwned(player, first)
	brainrotService.removeOwned(player, second)
	brainrotService.removeOwned(player, third)

	local placed = brainrotService.placeOnBase(player, resultDef, nil)
	if not placed then
		-- Should not happen after the room check above, but never silently
		-- eat three brainrots: tell the player loudly if it ever does.
		fail(player, "something went wrong placing the fused brainrot. Please report this!")
		return
	end

	notifyEvent:FireClient(
		player,
		"Fused 3 " .. rarity .. " into " .. resultDef.name .. " (" .. higher .. ")!"
	)
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function FusionService.init(worldRef, remotesRef, brainrotServiceRef, playerDataRef)
	brainrotService = brainrotServiceRef
	playerData = playerDataRef
	remotes = remotesRef

	notifyEvent = remotes:WaitForChild("Notify")

	local fuseEvent = Instance.new("RemoteEvent")
	fuseEvent.Name = "FuseBrainrots"
	fuseEvent.Parent = remotes
	fuseEvent.OnServerEvent:Connect(onFuse)
end

return FusionService
