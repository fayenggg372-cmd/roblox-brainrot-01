-- Fusion.client.luau
-- "Fusion" panel: pick exactly 3 of your base slots, then fuse those 3
-- brainrots into 1 brainrot of the next rarity up.
--
-- Own ScreenGui ("FusionGui"), own toggle button in the top-right corner
-- (left of the Contracts button). Slot count comes from StatsUpdate, so the
-- panel always matches the player's current max slots. The result of a
-- fusion shows up through the existing Notify messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local fuseEvent = Remotes:WaitForChild("FuseBrainrots")
local statsEvent = Remotes:WaitForChild("StatsUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------------------
-- UI setup
-- ---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "FusionGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Toggle button, top-right corner, left of the Contracts button.
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "FusionButton"
toggleButton.Size = UDim2.new(0, 110, 0, 36)
toggleButton.Position = UDim2.new(1, -238, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(70, 45, 90)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "Fusion"
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 16
toggleButton.Parent = gui

-- Panel with the slot picker. Hidden until the player opens it.
local panel = Instance.new("Frame")
panel.Name = "FusionPanel"
panel.Size = UDim2.new(0, 300, 0, 300)
panel.Position = UDim2.new(1, -310, 0, 54)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 36)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(200, 160, 255)
titleLabel.Text = "Brainrot Fusion"
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 20
titleLabel.Parent = panel

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -20, 0, 36)
hintLabel.Position = UDim2.new(0, 10, 0, 36)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextYAlignment = Enum.TextYAlignment.Top
hintLabel.Font = Enum.Font.SourceSans
hintLabel.TextSize = 13
hintLabel.TextWrapped = true
hintLabel.Text = "Pick 3 slots with the same rarity to fuse them into 1 stronger brainrot."
hintLabel.Parent = panel

local slotsFrame = Instance.new("Frame")
slotsFrame.Name = "SlotsFrame"
slotsFrame.Size = UDim2.new(1, -20, 0, 150)
slotsFrame.Position = UDim2.new(0, 10, 0, 80)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 52, 0, 40)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.Parent = slotsFrame

local fuseButton = Instance.new("TextButton")
fuseButton.Name = "FuseButton"
fuseButton.Size = UDim2.new(1, -20, 0, 40)
fuseButton.Position = UDim2.new(0, 10, 0, 244)
fuseButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
fuseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
fuseButton.Font = Enum.Font.SourceSansBold
fuseButton.TextSize = 16
fuseButton.Text = "Fuse (0/3)"
fuseButton.Parent = panel

toggleButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

-- ---------------------------------------------------------------------------
-- Slot selection
-- ---------------------------------------------------------------------------

local selected = {} -- slot number -> true
local slotsMax = 6 -- replaced by StatsUpdate as soon as it arrives

local function selectedCount()
	local count = 0
	for _ in pairs(selected) do
		count += 1
	end
	return count
end

local function selectedList()
	local list = {}
	for slot in pairs(selected) do
		table.insert(list, slot)
	end
	table.sort(list)
	return list
end

local function refreshFuseButton()
	local count = selectedCount()
	if slotsMax < 3 then
		fuseButton.Text = "Need at least 3 slots"
		fuseButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		return
	end
	fuseButton.Text = "Fuse (" .. count .. "/3)"
	if count == 3 then
		fuseButton.BackgroundColor3 = Color3.fromRGB(140, 70, 200)
	else
		fuseButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	end
end

local function rebuildSlots()
	for _, child in ipairs(slotsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for slot = 1, slotsMax do
		local button = Instance.new("TextButton")
		button.Name = "Slot" .. slot
		button.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Font = Enum.Font.SourceSansBold
		button.TextSize = 16
		button.Text = tostring(slot)
		button.Parent = slotsFrame

		button.MouseButton1Click:Connect(function()
			if selected[slot] then
				selected[slot] = nil
				button.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
			elseif selectedCount() < 3 then
				selected[slot] = true
				button.BackgroundColor3 = Color3.fromRGB(140, 70, 200)
			end
			refreshFuseButton()
		end)
	end
	-- A smaller max-slots value can orphan selections past the new cap.
	for slot in pairs(selected) do
		if slot > slotsMax then
			selected[slot] = nil
		end
	end
	refreshFuseButton()
end

fuseButton.MouseButton1Click:Connect(function()
	local picked = selectedList()
	if #picked ~= 3 then
		return
	end
	fuseEvent:FireServer(picked[1], picked[2], picked[3])
	selected = {}
	rebuildSlots()
end)

-- StatsUpdate carries slotsMax; rebuild the picker whenever it changes.
statsEvent.OnClientEvent:Connect(function(stats)
	if stats.slotsMax and stats.slotsMax ~= slotsMax then
		slotsMax = stats.slotsMax
		rebuildSlots()
	end
end)

rebuildSlots()
