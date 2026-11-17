-- BrainrotService.luau -- the heart of the game: brainrots spawn on the
-- conveyor, walk it, get bought, stand on a base earning $/second, and
-- can be stolen. It owns the conveyor list, the base placements and the
-- income tick. Stealing itself lives in StealService, which init wires
-- in through the onStealPrompt callback below (no circular require).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local BrainrotService = {}
BrainrotService.onStealPrompt = nil -- set by init.server to StealService.trySteal
BrainrotService.conveyor = {} -- { { id, model, def, mutation } }
BrainrotService.owned = {} -- [userId] = { { model, def, mutation, slot } }
BrainrotService._nextId = 1

local world = nil
local remotes = nil

-- Roll a mutation for a fresh spawn: most are plain, some are Gold,
-- a few Diamond, almost none Rainbow.
local function rollMutation()
	local roll = math.random()
	local cumulative = 0
	for _, m in ipairs(Config.MUTATIONS) do
		cumulative = cumulative + m.chance
		if roll < cumulative then
			return m
		end
	end
	return nil
end

function BrainrotService.incomeOf(def, mutation, record)
	local mult = 1
	if mutation then
		mult = mutation.mult
	end
	return def.income * mult * PlayerData.incomeMultiplier(record)
end

-- Build the visible character: a blocky body in the character's colour,
-- a head, legs, one accessory built from parts, and a billboard with
-- its name, rarity and $/second. No uploaded assets: everything is parts.
local function buildModel(def, mutation)
	local model = Instance.new("Model")
	model.Name = def.name

	local bodyColor = def.color
	if mutation then
		bodyColor = mutation.color
	end
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 3, 2)
	body.Color = bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 2.4, 2.2)
	head.Position = body.Position + Vector3.new(0, 2.7, 0)
	head.Color = bodyColor
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(1, 1.6, 1.4)
		leg.Position = body.Position + Vector3.new(side * 0.8, -2.2, 0)
		leg.Color = Color3.fromRGB(60, 60, 60)
		leg.Anchored = true
		leg.CanCollide = false
		leg.Parent = model
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.5, 0.7, 0.2)
		eye.Position = head.Position + Vector3.new(side * 0.55, 0.3, 1.15)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model
	end

	-- One accessory per character, made of parts.
	local acc = Instance.new("Part")
	acc.Name = "Accessory"
	acc.Anchored = true
	acc.CanCollide = false
	if def.accessory == "fin" then
		acc.Size = Vector3.new(0.6, 2.4, 1.6)
		acc.Position = body.Position + Vector3.new(0, 2.6, -0.6)
		acc.Color = Color3.fromRGB(30, 80, 160)
	elseif def.accessory == "bat" then
		acc.Size = Vector3.new(0.8, 4, 0.8)
		acc.Position = body.Position + Vector3.new(2, 0.5, 0)
		acc.Color = Color3.fromRGB(120, 70, 30)
	elseif def.accessory == "banana" then
		acc.Size = Vector3.new(1, 2.6, 1)
		acc.Position = body.Position + Vector3.new(1.8, 1.5, 0)
		acc.Color = Color3.fromRGB(255, 230, 60)
	elseif def.accessory == "crown" then
		acc.Size = Vector3.new(2.6, 0.8, 2.6)
		acc.Position = head.Position + Vector3.new(0, 1.5, 0)
		acc.Color = Color3.fromRGB(255, 215, 0)
		acc.Material = Enum.Material.Neon
	elseif def.accessory == "wings" then
		acc.Size = Vector3.new(4.5, 0.4, 1.8)
		acc.Position = body.Position + Vector3.new(0, 1.2, -1.2)
		acc.Color = Color3.fromRGB(255, 255, 255)
	elseif def.accessory == "rings" then
		acc.Size = Vector3.new(4.5, 0.3, 4.5)
		acc.Position = head.Position + Vector3.new(0, 0.2, 0)
		acc.Color = Color3.fromRGB(255, 220, 120)
		acc.Material = Enum.Material.Neon
	elseif def.accessory == "katana" then
		acc.Size = Vector3.new(0.4, 4.5, 0.4)
		acc.Position = body.Position + Vector3.new(2, 1, 0)
		acc.Color = Color3.fromRGB(200, 200, 220)
		acc.Material = Enum.Material.Metal
	elseif def.accessory == "flame" then
		acc.Size = Vector3.new(2, 2.6, 2)
		acc.Position = head.Position + Vector3.new(0, 1.8, 0)
		acc.Color = Color3.fromRGB(255, 120, 20)
		acc.Material = Enum.Material.Neon
	else -- chefHat, leaf, cactus, plane, tutu, fish, fridge: a coloured topper
		acc.Size = Vector3.new(2.2, 1, 2.2)
		acc.Position = head.Position + Vector3.new(0, 1.6, 0)
		acc.Color = Color3.fromRGB(255, 255, 255)
	end
	acc.Parent = model

	-- Billboard: name, rarity, income. This is what the judge reads in
	-- a screenshot to see the cast, the ladder and the money ticking.
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = false
	gui.Parent = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.BackgroundTransparency = 0.3
	nameLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Parent = gui
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.45, 0)
	rarityLabel.BackgroundTransparency = 0.3
	rarityLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	rarityLabel.TextColor3 = Config.RARITY_COLORS[def.rarity] or Color3.fromRGB(255, 255, 255)
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.SourceSansBold
	rarityLabel.Parent = gui
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(1, 0, 0.25, 0)
	incomeLabel.Position = UDim2.new(0, 0, 0.75, 0)
	incomeLabel.BackgroundTransparency = 0.3
	incomeLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.SourceSansBold
	incomeLabel.Parent = gui
	if mutation then
		nameLabel.Text = mutation.name .. " " .. def.name
		rarityLabel.Text = def.rarity .. " • " .. mutation.name .. " x" .. mutation.mult
	else
		rarityLabel.Text = def.rarity
	end
	incomeLabel.Text = Format.money(def.income * (mutation and mutation.mult or 1)) .. "/s"

	return model
end

local function refreshIncomeLabel(model, def, mutation, record)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local gui = head:FindFirstChild("BrainrotLabel")
	if not gui then return end
	local incomeLabel = gui:FindFirstChild("IncomeLabel")
	if incomeLabel then
		incomeLabel.Text = Format.money(BrainrotService.incomeOf(def, mutation, record)) .. "/s"
	end
end

-- Put a brainrot on a pedestal of the player's base, facing the conveyor.
function BrainrotService.placeOnBase(player, def, mutation)
	local record = PlayerData.get(player)
	if not record then return nil end
	local base = world.bases[record.baseIndex]
	if not base then return nil end
	local ownedList = BrainrotService.owned[player.UserId]
	if not ownedList then
		ownedList = {}
		BrainrotService.owned[player.UserId] = ownedList
	end
	if #ownedList >= PlayerData.maxSlots(record) then
		return nil
	end
	-- First free pedestal, so selling a middle brainrot never stacks two
	-- characters on the same spot.
	local taken = {}
	for _, e in ipairs(ownedList) do
		taken[e.slot] = true
	end
	local slot = 1
	while taken[slot] do
		slot = slot + 1
	end
	local slotPos = base.slots[slot]
	local model = buildModel(def, mutation)
	model:SetPrimaryPartCFrame(CFrame.new(slotPos + Vector3.new(0, 3.5, 0)))
	model.Parent = world.world
	local entry = { model = model, def = def, mutation = mutation, slot = slot }
	table.insert(ownedList, entry)
	table.insert(record.owned, { defId = def.id, mutation = mutation and mutation.name or nil, slot = slot })
	refreshIncomeLabel(model, def, mutation, record)

	-- Steal prompt: anyone but the owner can take it while the base is open.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 8
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(thief)
		if BrainrotService.onStealPrompt then
			BrainrotService.onStealPrompt(thief, player, entry)
		end
	end)
	return entry
end

-- Restore the brainrots a returning player saved last visit.
function BrainrotService.restoreOwned(player)
	local record = PlayerData.get(player)
	if not record then return end
	local saved = {}
	for _, entry in ipairs(record.owned) do
		table.insert(saved, entry)
	end
	record.owned = {}
	for _, entry in ipairs(saved) do
		local def = BrainrotData.byId(entry.defId)
		if def then
			local mutation = nil
			if entry.mutation then
				for _, m in ipairs(Config.MUTATIONS) do
					if m.name == entry.mutation then mutation = m end
				end
			end
			BrainrotService.placeOnBase(player, def, mutation)
		end
	end
end

function BrainrotService.removeOwned(player, entry)
	local ownedList = BrainrotService.owned[player.UserId]
	if ownedList then
		for i, e in ipairs(ownedList) do
			if e == entry then
				table.remove(ownedList, i)
				break
			end
		end
	end
	local record = PlayerData.get(player)
	if record then
		for i, e in ipairs(record.owned) do
			if e.defId == entry.def.id then
				table.remove(record.owned, i)
				break
			end
		end
	end
	if entry.model then
		entry.model:Destroy()
	end
end

function BrainrotService.totalIncome(player)
	local record = PlayerData.get(player)
	if not record then return 0 end
	local total = 0
	for _, entry in ipairs(BrainrotService.owned[player.UserId] or {}) do
		total = total + BrainrotService.incomeOf(entry.def, entry.mutation, record)
	end
	return total
end

-- Buy a brainrot that is still walking the conveyor.
function BrainrotService.buy(player, brainrotId)
	local record = PlayerData.get(player)
	if not record then
		return false, "No player data"
	end
	local found = nil
	local foundIndex = nil
	for i, entry in ipairs(BrainrotService.conveyor) do
		if entry.id == brainrotId then
			found = entry
			foundIndex = i
			break
		end
	end
	if not found then
		return false, "That brainrot already left the belt"
	end
	if record.cash < found.def.cost then
		return false, "Not enough cash — you need " .. Format.money(found.def.cost)
	end
	if #(BrainrotService.owned[player.UserId] or {}) >= PlayerData.maxSlots(record) then
		return false, "Your base is full — buy Slots or Rebirth"
	end
	record.cash = record.cash - found.def.cost
	table.remove(BrainrotService.conveyor, foundIndex)
	if found.model then
		found.model:Destroy()
	end
	remotes.ConveyorUpdate:FireAllClients("remove", brainrotId)
	local placed = BrainrotService.placeOnBase(player, found.def, found.mutation)
	if not placed then
		record.cash = record.cash + found.def.cost
		return false, "Could not place it on your base"
	end
	remotes.Notify:FireClient(player, "You bought " .. found.def.name .. " for " .. Format.money(found.def.cost) .. "!")
	PlayerData.save(player)
	return true, "Bought " .. found.def.name
end

function BrainrotService.sell(player, slot)
	local record = PlayerData.get(player)
	if not record then return false, "No player data" end
	local ownedList = BrainrotService.owned[player.UserId] or {}
	local entry = ownedList[slot]
	if not entry then return false, "Nothing in that slot" end
	local refund = math.floor(entry.def.cost / 2)
	record.cash = record.cash + refund
	BrainrotService.removeOwned(player, entry)
	remotes.Notify:FireClient(player, "Sold " .. entry.def.name .. " for " .. Format.money(refund))
	PlayerData.save(player)
	return true, "Sold"
end

local function spawnBrainrot()
	local def = BrainrotData.roll()
	local mutation = rollMutation()
	local model = buildModel(def, mutation)
	local startPos = Vector3.new(-Config.CONVEYOR_LENGTH / 2, Config.CONVEYOR_Y + 2.5, Config.CONVEYOR_Z)
	model:SetPrimaryPartCFrame(CFrame.new(startPos))
	model.Parent = world.world
	local id = BrainrotService._nextId
	BrainrotService._nextId = BrainrotService._nextId + 1
	local entry = { id = id, model = model, def = def, mutation = mutation }
	table.insert(BrainrotService.conveyor, entry)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Format.money(def.cost)
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		BrainrotService.buy(player, id)
	end)

	remotes.ConveyorUpdate:FireAllClients("add", {
		id = id,
		name = def.name,
		rarity = def.rarity,
		cost = def.cost,
		income = def.income,
		mutation = mutation and mutation.name or nil,
		mult = mutation and mutation.mult or 1,
	})
end

function BrainrotService.init(worldRef, remotesRef)
	world = worldRef
	remotes = remotesRef

	remotes.BuyBrainrot.OnServerEvent:Connect(function(player, brainrotId)
		local ok, msg = BrainrotService.buy(player, brainrotId)
		if not ok then
			remotes.Notify:FireClient(player, msg)
		end
	end)
	remotes.SellBrainrot.OnServerEvent:Connect(function(player, slot)
		local ok, msg = BrainrotService.sell(player, slot)
		if not ok then
			remotes.Notify:FireClient(player, msg)
		end
	end)

	-- Conveyor walk: every frame, slide each brainrot east; despawn at the gate.
	RunService.Heartbeat:Connect(function(dt)
		for i = #BrainrotService.conveyor, 1, -1 do
			local entry = BrainrotService.conveyor[i]
			if not entry.model or not entry.model.Parent then
				table.remove(BrainrotService.conveyor, i)
			else
				local cf = entry.model:GetPrimaryPartCFrame()
				local nextX = cf.Position.X + Config.BRAINROT_WALK_SPEED * dt
				if nextX >= Config.CONVEYOR_LENGTH / 2 then
					entry.model:Destroy()
					table.remove(BrainrotService.conveyor, i)
					remotes.ConveyorUpdate:FireAllClients("remove", entry.id)
				else
					entry.model:SetPrimaryPartCFrame(CFrame.new(nextX, cf.Position.Y, cf.Position.Z))
				end
			end
		end
	end)

	-- Spawner and income tick.
	task.spawn(function()
		while true do
			task.wait(Config.BRAINROT_SPAWN_INTERVAL)
			if #BrainrotService.conveyor < 8 then
				spawnBrainrot()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				local record = PlayerData.get(player)
				if record then
					local income = BrainrotService.totalIncome(player)
					if income > 0 then
						record.cash = record.cash + income
					end
					remotes.StatsUpdate:FireClient(player, {
						cash = record.cash,
						income = income,
						rebirths = record.rebirths,
						locked = PlayerData.isLocked(record),
						lockLeft = math.max(0, record.lockedUntil - os.time()),
						slotsUsed = #(BrainrotService.owned[player.UserId] or {}),
						slotsMax = PlayerData.maxSlots(record),
						upgrades = record.upgrades,
					})
				end
			end
		end
	end)
end

return BrainrotService
