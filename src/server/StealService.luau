-- StealService.luau -- stealing, the tension of the genre. A player
-- grabs a brainrot off someone else's open base, carries it home, and
-- it becomes theirs when they reach their own plot. Locked bases cannot
-- be stolen from; the carrier walks slower; dying, resetting or getting
-- caught by the tsunami drops the catch back to its owner.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Format"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local StealService = {}
StealService.carried = {} -- [userId] = { entry, fromPlayer, model }

local brainrotService = nil
local remotes = nil
local world = nil

local function baseBounds(base)
	return base.center.X - 15, base.center.X + 15, base.center.Z - 11, base.center.Z + 11
end

local function insideBase(player, baseIndex)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local base = world.bases[baseIndex]
	if not base then return false end
	local minX, maxX, minZ, maxZ = baseBounds(base)
	local p = root.Position
	return p.X >= minX and p.X <= maxX and p.Z >= minZ and p.Z <= maxZ
end

function StealService.trySteal(thief, owner, entry)
	local thiefRecord = PlayerData.get(thief)
	local ownerRecord = PlayerData.get(owner)
	if not thiefRecord or not ownerRecord then return end
	if thief == owner then return end
	if StealService.carried[thief.UserId] then
		remotes.Notify:FireClient(thief, "You are already carrying a brainrot!")
		return
	end
	-- Already being carried by someone else: its prompt rides along.
	for _, carry in pairs(StealService.carried) do
		if carry.entry == entry then
			return
		end
	end
	if PlayerData.isLocked(ownerRecord) then
		remotes.Notify:FireClient(thief, owner.DisplayName .. "'s base is LOCKED!")
		return
	end
	-- Take it off the victim's base (model stays, ownership moves to the carry).
	local ownedList = brainrotService.owned[owner.UserId]
	if ownedList then
		for i, e in ipairs(ownedList) do
			if e == entry then
				table.remove(ownedList, i)
				break
			end
		end
	end
	for i, e in ipairs(ownerRecord.owned) do
		if e.defId == entry.def.id then
			table.remove(ownerRecord.owned, i)
			break
		end
	end
	StealService.carried[thief.UserId] = { entry = entry, fromPlayer = owner, model = entry.model }
	remotes.Notify:FireClient(thief, "You stole " .. entry.def.name .. "! Run it home!")
	remotes.Notify:FireClient(owner, thief.DisplayName .. " stole your " .. entry.def.name .. "! Chase them!")
	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerData.walkSpeed(thiefRecord) * Config.CARRY_SPEED_MULTIPLIER
	end
end

-- Drop the catch: it walks back to its owner's base as if bought again.
function StealService.dropCarried(player, announce)
	local carry = StealService.carried[player.UserId]
	if not carry then return end
	StealService.carried[player.UserId] = nil
	local record = PlayerData.get(player)
	if record then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = PlayerData.walkSpeed(record)
		end
	end
	local owner = carry.fromPlayer
	if owner and owner.Parent then
		brainrotService.placeOnBase(owner, carry.entry.def, carry.entry.mutation)
		if announce then
			remotes.Notify:FireClient(player, "You dropped " .. carry.entry.def.name .. " — it ran home!")
		end
	end
	if carry.model and carry.model.Parent then
		carry.model:Destroy()
	end
end

function StealService.lockBase(player)
	local record = PlayerData.get(player)
	if not record then return false, "No player data" end
	local now = os.time()
	if now < record.lockCooldownUntil then
		return false, "Lock recharging: " .. tostring(record.lockCooldownUntil - now) .. "s left"
	end
	local cost = Config.LOCK_BASE_COST * (record.rebirths + 1)
	if record.cash < cost then
		return false, "Lock costs " .. Format.money(cost)
	end
	record.cash = record.cash - cost
	record.lockedUntil = now + Config.LOCK_DURATION
	record.lockCooldownUntil = now + Config.LOCK_COOLDOWN
	local base = world.bases[record.baseIndex]
	if base and base.gate then
		base.gate.Color = Color3.fromRGB(255, 60, 60)
		task.delay(Config.LOCK_DURATION, function()
			if base.gate then
				base.gate.Color = Color3.fromRGB(255, 255, 255)
			end
		end)
	end
	return true, "Base locked for " .. Config.LOCK_DURATION .. "s!"
end

function StealService.init(worldRef, remotesRef, brainrotServiceRef)
	world = worldRef
	remotes = remotesRef
	brainrotService = brainrotServiceRef

	remotes.LockBase.OnServerEvent:Connect(function(player)
		local ok, msg = StealService.lockBase(player)
		remotes.Notify:FireClient(player, msg)
	end)

	-- Carried brainrots hover behind their thief; reaching their own
	-- base converts the steal into ownership.
	RunService.Heartbeat:Connect(function()
		for userId, carry in pairs(StealService.carried) do
			local player = Players:GetPlayerByUserId(userId)
			if not player or not player.Character then
				if player then
					StealService.dropCarried(player, false)
				end
			else
				local root = player.Character:FindFirstChild("HumanoidRootPart")
				if root and carry.model and carry.model.Parent then
					local behind = root.CFrame * CFrame.new(0, 4, 3)
					carry.model:SetPrimaryPartCFrame(behind)
				end
				local record = PlayerData.get(player)
				if record and insideBase(player, record.baseIndex) then
					local placed = brainrotService.placeOnBase(player, carry.entry.def, carry.entry.mutation)
					if placed then
						StealService.carried[userId] = nil
						local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid.WalkSpeed = PlayerData.walkSpeed(record)
						end
						if carry.model and carry.model.Parent then
							carry.model:Destroy()
						end
						remotes.Notify:FireClient(player, "STOLEN! " .. carry.entry.def.name .. " is yours now!")
						PlayerData.save(player)
					end
				end
			end
		end
	end)

	-- Dying or resetting drops the catch.
	Players.PlayerRemoving:Connect(function(player)
		StealService.dropCarried(player, false)
	end)
end

return StealService
