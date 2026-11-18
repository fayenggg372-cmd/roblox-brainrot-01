-- DailyRewards.client.luau -- Daily Heist Bonus panel.
-- Shows the 7-day reward ladder, the player's current streak, and a claim
-- button. The panel never decides anything: it only renders the state the
-- server sends on "DailyRewardState" and asks for a claim by firing
-- "DailyRewardClaim". The server validates and pays; the client just asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardsData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewardsData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild("DailyRewardState")
local claimRemote = remotes:WaitForChild("DailyRewardClaim")

local PANEL_SIZE = UDim2.new(0, 380, 0, 330)
local SLOT_COLOR_UPCOMING = Color3.fromRGB(45, 48, 70)
local SLOT_COLOR_TODAY = Color3.fromRGB(255, 190, 60)
local SLOT_COLOR_CLAIMED = Color3.fromRGB(60, 160, 90)
local TEXT_DARK = Color3.fromRGB(20, 20, 30)
local TEXT_LIGHT = Color3.fromRGB(240, 240, 245)

local function makeLabel(parent, text, size, position, textSize, color)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or TEXT_LIGHT
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size, position, color)
	local button = Instance.new("TextButton")
	button.Text = text
	button.Size = size
	button.Position = position
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = TEXT_DARK
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

-- ScreenGui + panel -------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "DailyRewardsGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = PANEL_SIZE
panel.Position = UDim2.new(0.5, -190, 0.5, -165)
panel.BackgroundColor3 = Color3.fromRGB(28, 30, 48)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

makeLabel(panel, "🎁 DAILY HEIST BONUS", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 8), 20, Color3.fromRGB(255, 210, 90))

local streakLabel = makeLabel(panel, "Streak: 0 days", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 44), 16, TEXT_LIGHT)
local nextLabel = makeLabel(panel, "Log in daily to climb the ladder!", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 70), 14, Color3.fromRGB(180, 180, 200))

local closeButton = makeButton(panel, "X", UDim2.new(0, 30, 0, 30), UDim2.new(1, -38, 0, 8), Color3.fromRGB(220, 80, 80))
closeButton.TextColor3 = TEXT_LIGHT

-- Seven day slots in a row, one per cycle day ------------------------------
local slotsFrame = Instance.new("Frame")
slotsFrame.Name = "Slots"
slotsFrame.Size = UDim2.new(1, -24, 0, 110)
slotsFrame.Position = UDim2.new(0, 12, 0, 100)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 46, 0, 104)
grid.CellPadding = UDim2.new(0, 6, 0, 0)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = slotsFrame

local slotFrames = {}
for day = 1, DailyRewardsData.CYCLE_LENGTH do
	local reward = DailyRewardsData.rewardForDay(day)
	local slot = Instance.new("Frame")
	slot.Name = "Day" .. day
	slot.BackgroundColor3 = SLOT_COLOR_UPCOMING
	slot.BorderSizePixel = 0
	slot.LayoutOrder = day
	slot.Parent = slotsFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot
	makeLabel(slot, "DAY " .. day, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 6), 12, TEXT_LIGHT)
	makeLabel(slot, DailyRewardsData.formatCash(reward.cash), UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 30), 13, Color3.fromRGB(255, 220, 120))
	local status = makeLabel(slot, "•", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 56), 14, TEXT_LIGHT)
	status.Name = "Status"
	makeLabel(slot, reward.label, UDim2.new(1, -4, 0, 30), UDim2.new(0, 2, 0, 74), 10, Color3.fromRGB(200, 200, 215))
	slotFrames[day] = slot
end

-- Claim button + feedback -------------------------------------------------
local claimButton = makeButton(panel, "CLAIM TODAY'S BONUS", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 224), Color3.fromRGB(255, 190, 60))
local feedbackLabel = makeLabel(panel, "Claim your bonus once a day!", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 0, 276), 14, Color3.fromRGB(180, 180, 200))

-- Small floating button that opens the panel ------------------------------
local openButton = makeButton(gui, "🎁 DAILY", UDim2.new(0, 96, 0, 36), UDim2.new(1, -112, 0, 16), Color3.fromRGB(255, 190, 60))

-- State rendering ---------------------------------------------------------
local latestState = nil

local function render(state)
	latestState = state
	streakLabel.Text = "🔥 Streak: " .. state.streak .. " day" .. (state.streak == 1 and "" or "s")
	if state.claimedToday then
		local reward = DailyRewardsData.rewardForDay(state.rewardDay)
		nextLabel.Text = "Claimed " .. DailyRewardsData.formatCash(reward.cash) .. " today -- see you tomorrow!"
		claimButton.Text = "CLAIMED ✓"
		claimButton.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		feedbackLabel.Text = "Come back tomorrow to keep the streak alive!"
	else
		local reward = DailyRewardsData.rewardForDay(state.rewardDay)
		nextLabel.Text = "Today is Day " .. state.rewardDay .. ": " .. reward.label .. " -- " .. DailyRewardsData.formatCash(reward.cash)
		claimButton.Text = "CLAIM " .. DailyRewardsData.formatCash(reward.cash)
		claimButton.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
		feedbackLabel.Text = "Tap CLAIM to collect today's bonus!"
	end
	for day = 1, DailyRewardsData.CYCLE_LENGTH do
		local slot = slotFrames[day]
		local status = slot:FindFirstChild("Status")
		if state.claimedToday and day <= state.rewardDay then
			slot.BackgroundColor3 = SLOT_COLOR_CLAIMED
			if status then status.Text = "✓" end
		elseif not state.claimedToday and day == state.rewardDay then
			slot.BackgroundColor3 = SLOT_COLOR_TODAY
			if status then status.Text = "TODAY" end
		elseif day < state.rewardDay then
			slot.BackgroundColor3 = SLOT_COLOR_CLAIMED
			if status then status.Text = "✓" end
		else
			slot.BackgroundColor3 = SLOT_COLOR_UPCOMING
			if status then status.Text = "•" end
		end
	end
end

-- Events ------------------------------------------------------------------
stateRemote.OnClientEvent:Connect(render)

claimButton.MouseButton1Click:Connect(function()
	if latestState and not latestState.canClaim then
		feedbackLabel.Text = "Already claimed today -- come back tomorrow!"
		return
	end
	feedbackLabel.Text = "Claiming..."
	claimRemote:FireServer()
end)

openButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)
