-- Quests.client.luau
-- "Contracts" panel: shows the 9 Heist Contracts from QuestService, their
-- live progress, and a Claim button for each finished contract.
--
-- Own ScreenGui ("QuestsGui"), own toggle button in the top-right corner.
-- Listens to QuestUpdate (server -> client) and fires ClaimQuest
-- (client -> server) with the contract id when the player claims a reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local questUpdateEvent = Remotes:WaitForChild("QuestUpdate")
local claimEvent = Remotes:WaitForChild("ClaimQuest")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------------------
-- UI setup
-- ---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "QuestsGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Toggle button, top-right corner.
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ContractsButton"
toggleButton.Size = UDim2.new(0, 110, 0, 36)
toggleButton.Position = UDim2.new(1, -120, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "Contracts"
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 16
toggleButton.Parent = gui

-- Panel holding the contract list. Hidden until the player opens it.
local panel = Instance.new("Frame")
panel.Name = "ContractsPanel"
panel.Size = UDim2.new(0, 380, 0, 460)
panel.Position = UDim2.new(1, -390, 0, 54)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 36)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
titleLabel.Text = "Heist Contracts"
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 20
titleLabel.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Name = "ContractList"
list.Size = UDim2.new(1, -16, 1, -46)
list.Position = UDim2.new(0, 8, 0, 40)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

toggleButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

-- ---------------------------------------------------------------------------
-- Contract rows
-- ---------------------------------------------------------------------------

-- Cash-goal contracts (spending, holding cash, earning income) read better
-- as money; count-goal contracts (buy 3, sell 2, ...) read better as plain
-- numbers. "1 / $1" for First Haul would be confusing.
local MONEY_GOALS = {
	["big-spender"] = true,
	["tycoon"] = true,
	["moneybags"] = true,
}

local function formatProgress(contract)
	if MONEY_GOALS[contract.id] then
		return Format.money(contract.progress) .. " / " .. Format.money(contract.goal)
	end
	return tostring(contract.progress) .. " / " .. tostring(contract.goal)
end

local function makeRow(contract)
	local row = Instance.new("Frame")
	row.Name = "Contract_" .. contract.id
	row.Size = UDim2.new(1, 0, 0, 96)
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
	row.BorderSizePixel = 0
	row.Parent = list

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -76, 0, 22)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 16
	title.Text = contract.title
	title.Parent = row

	local description = Instance.new("TextLabel")
	description.Size = UDim2.new(1, -20, 0, 34)
	description.Position = UDim2.new(0, 10, 0, 28)
	description.BackgroundTransparency = 1
	description.TextColor3 = Color3.fromRGB(200, 200, 210)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Font = Enum.Font.SourceSans
	description.TextSize = 13
	description.TextWrapped = true
	description.Text = contract.description
	description.Parent = row

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressLabel"
	progressLabel.Size = UDim2.new(0, 140, 0, 20)
	progressLabel.Position = UDim2.new(0, 10, 0, 66)
	progressLabel.BackgroundTransparency = 1
	progressLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Font = Enum.Font.SourceSans
	progressLabel.TextSize = 14
	progressLabel.Text = formatProgress(contract)
	progressLabel.Parent = row

	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Size = UDim2.new(0, 120, 0, 20)
	rewardLabel.Position = UDim2.new(1, -196, 0, 66)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.TextColor3 = Color3.fromRGB(120, 230, 130)
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
	rewardLabel.Font = Enum.Font.SourceSansBold
	rewardLabel.TextSize = 14
	rewardLabel.Text = "Reward: " .. Format.money(contract.reward)
	rewardLabel.Parent = row

	local claimButton = Instance.new("TextButton")
	claimButton.Name = "ClaimButton"
	claimButton.Size = UDim2.new(0, 62, 0, 26)
	claimButton.Position = UDim2.new(1, -70, 0, 6)
	claimButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimButton.Font = Enum.Font.SourceSansBold
	claimButton.TextSize = 14
	claimButton.Text = "Claim"
	claimButton.Parent = row

	-- Refresh the row from fresh contract data.
	local function refresh(data)
		progressLabel.Text = formatProgress(data)
		local finished = data.progress >= data.goal
		if data.claimed then
			claimButton.Text = "Claimed"
			claimButton.BackgroundColor3 = Color3.fromRGB(50, 120, 60)
			claimButton.Active = false
		elseif finished then
			claimButton.Text = "Claim"
			claimButton.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
			claimButton.Active = true
		else
			claimButton.Text = "Claim"
			claimButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
			claimButton.Active = false
		end
	end

	claimButton.MouseButton1Click:Connect(function()
		-- The server re-validates everything; this is only a UI guard.
		if claimButton.Active then
			claimEvent:FireServer(contract.id)
		end
	end)

	refresh(contract)
	return row, refresh
end

-- ---------------------------------------------------------------------------
-- Updates from the server
-- ---------------------------------------------------------------------------

-- Row refreshers, keyed by contract id, so updates rebuild cheaply.
local refreshers = {}

questUpdateEvent.OnClientEvent:Connect(function(contracts)
	for _, contract in ipairs(contracts) do
		local refresher = refreshers[contract.id]
		if refresher then
			refresher(contract)
		else
			local _, refresh = makeRow(contract)
			refreshers[contract.id] = refresh
		end
	end
end)
