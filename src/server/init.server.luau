-- init.server.luau -- Brainrot Heist server bootstrap.
-- Creates the RemoteEvents, builds the world, assigns each joining
-- player a base plot, and wires the services together:
--   WorldBuilder -> BrainrotService -> StealService -> EventService
-- Rebirth and upgrades are handled here, next to the economy they touch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local PlayerData = require(script:WaitForChild("PlayerData"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local BrainrotService = require(script:WaitForChild("BrainrotService"))
local StealService = require(script:WaitForChild("StealService"))
local EventService = require(script:WaitForChild("EventService"))

print("[Brainrot Heist] Server starting...")

-- RemoteEvents: one folder, one job each. The client never trusts its
-- own numbers: every buy, steal, lock, rebirth and upgrade is validated
-- on the server before it changes any state.
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage
local remoteNames = {
	"BuyBrainrot", "SellBrainrot", "LockBase", "Rebirth", "BuyUpgrade",
	"StatsUpdate", "Notify", "ConveyorUpdate",
	"EventWarning", "EventStart", "EventEnd",
}
local remotes = {}
for _, name in ipairs(remoteNames) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	remotes[name] = remote
end

local world = WorldBuilder.build()
BrainrotService.init(world, remotes)
BrainrotService.onStealPrompt = function(thief, owner, entry)
	StealService.trySteal(thief, owner, entry)
end
StealService.init(world, remotes, BrainrotService)
EventService.init(world, remotes, StealService)

-- Rebirth: wipe cash and brainrots, keep a permanent +50% income per rebirth.
remotes.Rebirth.OnServerEvent:Connect(function(player)
	local record = PlayerData.get(player)
	if not record then return end
	local cost = PlayerData.rebirthCost(record)
	if record.cash < cost then
		remotes.Notify:FireClient(player, "Rebirth needs " .. Format.money(cost) .. " cash!")
		return
	end
	for _, entry in ipairs(BrainrotService.owned[player.UserId] or {}) do
		if entry.model then
			entry.model:Destroy()
		end
	end
	BrainrotService.owned[player.UserId] = {}
	record.owned = {}
	record.cash = Config.START_CASH
	record.rebirths = record.rebirths + 1
	remotes.Notify:FireClient(player, "🔄 REBIRTH #" .. record.rebirths .. "! Income x" ..
		string.format("%.1f", PlayerData.incomeMultiplier(record)) .. " forever!")
	PlayerData.save(player)
end)

-- Upgrades: Speed, Slots, Income. Cost grows per level, capped per Config.
remotes.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeName)
	local record = PlayerData.get(player)
	if not record then return end
	local def = Config.UPGRADES[upgradeName]
	if not def then return end
	local level = record.upgrades[upgradeName] or 0
	if level >= def.maxLevel then
		remotes.Notify:FireClient(player, upgradeName .. " is already maxed!")
		return
	end
	local cost = math.floor(def.baseCost * (def.costMult ^ level))
	if record.cash < cost then
		remotes.Notify:FireClient(player, upgradeName .. " Lv" .. (level + 1) .. " costs " .. Format.money(cost))
		return
	end
	record.cash = record.cash - cost
	record.upgrades[upgradeName] = level + 1
	if upgradeName == "Speed" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = PlayerData.walkSpeed(record)
		end
	end
	remotes.Notify:FireClient(player, upgradeName .. " upgraded to Lv" .. (level + 1) .. "! " .. def.description)
	PlayerData.save(player)
end)

-- Pick the least crowded base plot for a joining player.
local function assignBase()
	local counts = { 0, 0, 0, 0 }
	for _, record in pairs(PlayerData._records) do
		if record.baseIndex >= 1 and record.baseIndex <= 4 then
			counts[record.baseIndex] = counts[record.baseIndex] + 1
		end
	end
	local best = 1
	for i = 2, 4 do
		if counts[i] < counts[best] then
			best = i
		end
	end
	return best
end

local function onPlayerAdded(player)
	local baseIndex = assignBase()
	local record = PlayerData.create(player, baseIndex)
	player:SetAttribute("BaseIndex", baseIndex)

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = PlayerData.walkSpeed(record)
	end
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Restore the brainrots they saved last visit, then greet them.
	BrainrotService.restoreOwned(player)
	task.wait(2)
	remotes.Notify:FireClient(player, "Welcome to Brainrot Heist! Buy brainrots off the belt, protect your base, and run from the tsunami! 🌊")
	remotes.Notify:FireClient(player, "Your base is " .. world.bases[baseIndex].name .. " — press H for help.")
	print("[Brainrot Heist] " .. player.Name .. " joined on " .. world.bases[baseIndex].name)
end

local function onPlayerRemoving(player)
	StealService.dropCarried(player, false)
	for _, entry in ipairs(BrainrotService.owned[player.UserId] or {}) do
		if entry.model then
			entry.model:Destroy()
		end
	end
	BrainrotService.owned[player.UserId] = nil
	PlayerData.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Autosave every 60 seconds, so a crash costs at most a minute.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.save(player)
		end
	end
end)

print("[Brainrot Heist] Server ready. Belt running, tsunami armed.")
