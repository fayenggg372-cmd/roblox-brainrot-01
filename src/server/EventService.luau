-- EventService.luau -- the tsunami: the hazard that forces the dash home.
-- Every EVENT_INTERVAL seconds the server warns the map, then a giant
-- wave sweeps north to south. Anyone caught outside their own base plot
-- is washed back to spawn and drops whatever they were carrying.
-- The wave crosses the whole map (z -120 to +130) at EVENT_WAVE_SPEED,
-- so the sweep lasts about 9 seconds; the loop waits 10 to be sure the
-- Heartbeat connection is gone before the wave part is destroyed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local EventService = {}

local world = nil
local remotes = nil
local stealService = nil

local function playerOnOwnBase(player, record)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local base = world.bases[record.baseIndex]
	if not base then return false end
	local p = root.Position
	return p.X >= base.center.X - 15 and p.X <= base.center.X + 15
		and p.Z >= base.center.Z - 11 and p.Z <= base.center.Z + 11
end

function EventService.init(worldRef, remotesRef, stealServiceRef)
	world = worldRef
	remotes = remotesRef
	stealService = stealServiceRef

	task.spawn(function()
		while true do
			task.wait(Config.EVENT_INTERVAL)
			-- Warning phase: the HUD counts it down.
			remotes.EventWarning:FireAllClients(Config.EVENT_WARNING_SECONDS)
			task.wait(Config.EVENT_WARNING_SECONDS)

			remotes.EventStart:FireAllClients()
			local wave = Instance.new("Part")
			wave.Name = "TsunamiWave"
			wave.Size = Vector3.new(260, 30, 12)
			wave.Color = Color3.fromRGB(60, 140, 255)
			wave.Material = Enum.Material.Neon
			wave.Transparency = 0.35
			wave.Anchored = true
			wave.CanCollide = false
			wave.Parent = world.world

			local z = -120
			local hit = {}
			local conn
			conn = RunService.Heartbeat:Connect(function(dt)
				z = z + Config.EVENT_WAVE_SPEED * dt
				wave.Position = Vector3.new(0, 12, z)
				for _, player in ipairs(Players:GetPlayers()) do
					if not hit[player.UserId] then
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if root and math.abs(root.Position.Z - z) < 8 then
							local record = PlayerData.get(player)
							if record and not playerOnOwnBase(player, record) then
								hit[player.UserId] = true
								stealService.dropCarried(player, true)
								root.CFrame = CFrame.new(0, 3, 85)
								remotes.Notify:FireClient(player, "🌊 The tsunami washed you back to spawn!")
							end
						end
					end
				end
				if z > 130 then
					conn:Disconnect()
				end
			end)
			task.wait(10)
			if conn and conn.Connected then
				conn:Disconnect()
			end
			wave:Destroy()
			remotes.EventEnd:FireAllClients()
		end
	end)
end

return EventService
