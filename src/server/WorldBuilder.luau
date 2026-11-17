-- WorldBuilder.luau -- builds the whole 3D world in code, so the place
-- file stays small and every part of the map is visible in the source.
-- Layout: a conveyor belt across the north edge carries brainrots from
-- west to east; four coloured base plots sit south of it; the spawn is
-- at the south edge; trees and lamps dress the borders.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

local function part(name, size, pos, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.Parent = parent
	return p
end

local function pedestalSlots(center)
	-- 12 slots in a 4 x 3 grid on the plot, facing the conveyor.
	-- Base capacity starts at 6 and the Slots upgrade adds 2 per level
	-- (max 12), so every slot a player can ever own needs a pedestal.
	local slots = {}
	for row = 0, 2 do
		for _, col in ipairs({ -1.5, -0.5, 0.5, 1.5 }) do
			table.insert(slots, center + Vector3.new(col * 8, 0, (row - 1) * 7))
		end
	end
	return slots
end

function WorldBuilder.build()
	local workspace = game:GetService("Workspace")
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	-- Conveyor belt: dark belt, bright rails, chevron stripes.
	local belt = part("ConveyorBelt", Vector3.new(Config.CONVEYOR_LENGTH, 1, 12),
		Vector3.new(0, Config.CONVEYOR_Y - 1, Config.CONVEYOR_Z),
		Color3.fromRGB(45, 45, 55), Enum.Material.Metal, world)
	belt.CanCollide = false
	part("ConveyorRailNorth", Vector3.new(Config.CONVEYOR_LENGTH, 2, 1),
		Vector3.new(0, Config.CONVEYOR_Y, Config.CONVEYOR_Z - 6.5),
		Color3.fromRGB(255, 200, 40), Enum.Material.Neon, world)
	part("ConveyorRailSouth", Vector3.new(Config.CONVEYOR_LENGTH, 2, 1),
		Vector3.new(0, Config.CONVEYOR_Y, Config.CONVEYOR_Z + 6.5),
		Color3.fromRGB(255, 200, 40), Enum.Material.Neon, world)
	for x = -75, 75, 15 do
		part("BeltStripe", Vector3.new(3, 0.2, 10),
			Vector3.new(x, Config.CONVEYOR_Y + 0.6, Config.CONVEYOR_Z),
			Color3.fromRGB(255, 220, 80), Enum.Material.Neon, world).CanCollide = false
	end

	-- Spawn pad (west end) and despawn gate (east end).
	part("SpawnPad", Vector3.new(10, 1, 12),
		Vector3.new(-Config.CONVEYOR_LENGTH / 2 - 4, Config.CONVEYOR_Y, Config.CONVEYOR_Z),
		Color3.fromRGB(90, 255, 140), Enum.Material.Neon, world)
	part("DespawnGate", Vector3.new(2, 12, 12),
		Vector3.new(Config.CONVEYOR_LENGTH / 2 + 4, Config.CONVEYOR_Y + 5, Config.CONVEYOR_Z),
		Color3.fromRGB(255, 80, 80), Enum.Material.Neon, world)

	-- The four base plots.
	local bases = {}
	for i, def in ipairs(Config.BASES) do
		local plot = part(def.name .. "Plot", Vector3.new(30, 1, 22),
			def.center, def.color, Enum.Material.SmoothPlastic, world)
		plot.Transparency = 0.15
		-- A low wall around the plot: the safe zone the tsunami cannot enter.
		local wallColor = def.color
		part(def.name .. "WallN", Vector3.new(30, 3, 1), def.center + Vector3.new(0, 1.5, -11), wallColor, Enum.Material.SmoothPlastic, world)
		part(def.name .. "WallS", Vector3.new(30, 3, 1), def.center + Vector3.new(0, 1.5, 11), wallColor, Enum.Material.SmoothPlastic, world)
		part(def.name .. "WallW", Vector3.new(1, 3, 22), def.center + Vector3.new(-15, 1.5, 0), wallColor, Enum.Material.SmoothPlastic, world)
		part(def.name .. "WallE", Vector3.new(1, 3, 22), def.center + Vector3.new(15, 1.5, 0), wallColor, Enum.Material.SmoothPlastic, world)
		-- A lock gate across the south entrance; EventService/StealService
		-- tint it red while the base is locked.
		local gate = part(def.name .. "Gate", Vector3.new(10, 4, 1),
			def.center + Vector3.new(0, 2, 11), Color3.fromRGB(255, 255, 255),
			Enum.Material.Neon, world)
		gate.Transparency = 0.7
		gate.CanCollide = false
		local slots = pedestalSlots(def.center)
		for s, slotPos in ipairs(slots) do
			part(def.name .. "Pedestal" .. s, Vector3.new(5, 1, 5),
				slotPos + Vector3.new(0, 0.5, 0), Color3.fromRGB(240, 240, 240),
				Enum.Material.Marble, world)
		end
		-- Floating base sign so a player can find their plot at a glance.
		local sign = part(def.name .. "Sign", Vector3.new(14, 4, 0.5),
			def.center + Vector3.new(0, 12, 0), def.color, Enum.Material.Neon, world)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 60)
		gui.AlwaysOnTop = true
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = def.name
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = gui
		table.insert(bases, {
			index = i, name = def.name, center = def.center, color = def.color,
			slots = slots, gate = gate, sign = sign,
		})
	end

	-- Big title arch over the spawn, so screenshots read the game's name.
	local arch = part("TitleArch", Vector3.new(40, 6, 1),
		Vector3.new(0, 14, 78), Color3.fromRGB(255, 180, 40), Enum.Material.Neon, world)
	local archGui = Instance.new("BillboardGui")
	archGui.Size = UDim2.fromOffset(640, 90)
	archGui.AlwaysOnTop = true
	archGui.Parent = arch
	local archLabel = Instance.new("TextLabel")
	archLabel.Size = UDim2.fromScale(1, 1)
	archLabel.BackgroundTransparency = 1
	archLabel.Text = "🧠 BRAINROT HEIST 🧠"
	archLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	archLabel.TextScaled = true
	archLabel.Font = Enum.Font.FredokaOne
	archLabel.Parent = archGui

	-- Trees and lamps around the borders, for a built-world look.
	local treeSpots = { { -100, -100 }, { -60, -100 }, { 60, -100 }, { 100, -100 },
		{ -105, 0 }, { 105, 0 }, { -105, 90 }, { 105, 90 }, { -40, 100 }, { 40, 100 } }
	for _, spot in ipairs(treeSpots) do
		local trunk = part("TreeTrunk", Vector3.new(2, 8, 2),
			Vector3.new(spot[1], 4, spot[2]), Color3.fromRGB(120, 70, 30),
			Enum.Material.Wood, world)
		trunk.CanCollide = false
		local leaves = part("TreeLeaves", Vector3.new(8, 8, 8),
			Vector3.new(spot[1], 11, spot[2]), Color3.fromRGB(40, 160, 60),
			Enum.Material.SmoothPlastic, world)
		leaves.Shape = Enum.PartType.Ball
		leaves.CanCollide = false
	end
	for _, x in ipairs({ -40, 0, 40 }) do
		local pole = part("LampPole", Vector3.new(1, 10, 1),
			Vector3.new(x, 5, 20), Color3.fromRGB(60, 60, 60), Enum.Material.Metal, world)
		pole.CanCollide = false
		part("LampHead", Vector3.new(3, 1, 3),
			Vector3.new(x, 10.5, 20), Color3.fromRGB(255, 240, 150),
			Enum.Material.Neon, world).CanCollide = false
	end

	return { bases = bases, world = world }
end

return WorldBuilder
