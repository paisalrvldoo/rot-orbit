-- Simple anchored thieves walk across the open deck; zap returns their stolen cargo.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BrainrotModel = require(script.Parent:WaitForChild("BrainrotModel"))
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local GremlinRaid = {}
GremlinRaid.__index = GremlinRaid

function GremlinRaid.new(world, bases, economy, locks)
	local self = setmetatable({ World = world, Bases = bases, Economy = economy,
		Locks = locks, Gremlins = {}, Random = Random.new(), Active = false }, GremlinRaid)
	RunService.Heartbeat:Connect(function(dt) self:Step(math.min(dt, 0.1)) end)
	task.spawn(function()
		while true do
			task.wait(Config.Gremlin.Interval)
			self:Start()
		end
	end)
	return self
end

function GremlinRaid:Spawn(bay, position)
	local model = Instance.new("Model")
	model.Name = "SpaceGremlin"
	local function part(name, size, offset, color, shape)
		return WorldBuilder.Part(name, size, CFrame.new(offset), color,
			Enum.Material.SmoothPlastic, model, shape, false)
	end
	local root = part("Root", Vector3.one * 0.2, Vector3.zero, Config.Palette.Mint)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root
	local green = Color3.fromRGB(111, 219, 72)
	part("BeanBody", Vector3.new(1.45, 1.8, 1.2), Vector3.new(0, 1.2, 0), green, Enum.PartType.Ball)
	part("GremlinHead", Vector3.new(1.65, 1.25, 1.15), Vector3.new(0, 2.2, 0), green, Enum.PartType.Ball)
	part("LootPack", Vector3.new(1.1, 1.35, 0.5), Vector3.new(0, 1.25, 0.65), Config.Palette.Ink)
	for _, side in ipairs({ -1, 1 }) do
		part("PointyEar", Vector3.new(0.55, 0.9, 0.25), Vector3.new(side * 1, 2.45, 0), green)
		part("Boot", Vector3.new(0.48, 0.3, 0.7), Vector3.new(side * 0.4, 0.15, -0.1), Config.Palette.Ink)
		part("Eye", Vector3.new(0.38, 0.35, 0.1), Vector3.new(side * 0.4, 2.25, -0.56), Config.Palette.White)
		part("Pupil", Vector3.new(0.16, 0.24, 0.08), Vector3.new(side * 0.4, 2.2, -0.63), Config.Palette.Ink)
	end
	part("Tooth", Vector3.new(0.35, 0.22, 0.1), Vector3.new(0, 1.93, -0.61), Config.Palette.White)
	model:PivotTo(CFrame.new(position))
	model.Parent = self.World.Root
	local label = WorldBuilder.Billboard(root, "SPACE GREMLIN · ZAP [F]", green,
		Vector3.new(0, 4, 0), 250, 34)
	local state = { Model = model, Bay = bay, Position = position, Start = position,
		Destination = (bay.Frame * CFrame.new(0, 1, 3)).Position,
		Mode = "Approach", StunnedUntil = 0, Label = label,
		ExpiresAt = workspace:GetServerTimeNow() + Config.Gremlin.Duration }
	self.Gremlins[model] = state
	return state
end

function GremlinRaid:Remove(state, recover)
	if recover and state.Loot then self.Bases:SpawnDrop(state.Loot, state.Position) end
	self.Gremlins[state.Model] = nil
	state.Model:Destroy()
end

function GremlinRaid:Grab(state, slotIndex)
	local bay = state.Bay
	state.Mode = "Escape"
	state.Destination = state.Start
	if not bay.Owner or self.Locks:IsLocked(bay) then
		state.Label.Text = "SHIELD BLOCKED ME!"
		return
	end
	local choices = {}
	for _, pedestal in ipairs(bay.Slots) do
		if pedestal.Occupant then table.insert(choices, pedestal) end
	end
	if #choices == 0 then return end
	local pedestal = slotIndex and bay.Slots[slotIndex] or choices[self.Random:NextInteger(1, #choices)]
	if not pedestal or not pedestal.Occupant then return end
	local occupant = pedestal.Occupant
	state.Loot = occupant.Record
	self.Bases:ClearPedestal(pedestal)
	state.LootModel = BrainrotModel.Create(state.Loot,
		state.Model:GetPivot() * CFrame.new(0, 3.4, 0), state.Model)
	state.LootModel:SetAttribute("VisualState", "Raided")
	state.Label.Text = "STOLEN CARGO! ZAP [F]"
	self.Economy.Network.Notice:FireClient(bay.Owner,
		"A GREMLIN TOOK " .. Catalog.DisplayName(state.Loot) .. "! Chase it and ZAP [F]!")
	self.Economy:Send(bay.Owner)
end

function GremlinRaid:Step(dt)
	if self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	local now = workspace:GetServerTimeNow()
	for _, state in pairs(self.Gremlins) do
		if now >= state.ExpiresAt then
			self:Remove(state, true)
		elseif now < state.StunnedUntil then
			state.Label.Text = "ZAPPED! " .. math.ceil(state.StunnedUntil - now) .. "s"
		else
			local destination = Vector3.new(state.Destination.X, state.Position.Y, state.Destination.Z)
			local delta = destination - state.Position
			if delta.Magnitude < 1.8 then
				if state.Mode == "Approach" then self:Grab(state)
				else self:Remove(state, false) end
			else
				state.Position += delta.Unit * math.min(delta.Magnitude, Config.Gremlin.Speed * dt)
				local bob = math.sin(now * 12) * 0.08
				state.Model:PivotTo(CFrame.lookAt(state.Position + Vector3.new(0, bob, 0), destination + Vector3.new(0, bob, 0)))
			end
		end
	end
end

function GremlinRaid:Stun(gremlin, now)
	gremlin.StunnedUntil = now + Config.Gremlin.StunDuration
	gremlin.Mode = "Escape"
	gremlin.Destination = gremlin.Start
	if not gremlin.Loot then return nil end
	local dropped = self.Bases:SpawnDrop(gremlin.Loot, gremlin.Position)
	gremlin.LootModel:Destroy()
	gremlin.LootModel = nil
	gremlin.Loot = nil
	return dropped
end

function GremlinRaid:Zap(player)
	local state = self.Bases.Players[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not state or not root or not self.Bases:Near(player, root.Position) then return end
	local now = workspace:GetServerTimeNow()
	if now < (state.ZapReadyAt or 0) then return end
	state.ZapReadyAt = now + Config.Gremlin.ZapCooldown
	local count = 0
	local recovered = 0
	for _, gremlin in pairs(self.Gremlins) do
		if (gremlin.Position - root.Position).Magnitude <= Config.Gremlin.ZapRadius then
			count += 1
			if self:Stun(gremlin, now) then recovered += 1 end
		end
	end
	local pulse = WorldBuilder.Part("ZapPulse", Vector3.one * 2, root.CFrame,
		Config.Palette.Mint, Enum.Material.Neon, self.World.Root, Enum.PartType.Ball, false)
	pulse.Transparency = 0.75
	TweenService:Create(pulse, TweenInfo.new(0.35),
		{ Size = Vector3.one * Config.Gremlin.ZapRadius * 2, Transparency = 1 }):Play()
	Debris:AddItem(pulse, 0.4)
	local message = count > 0 and ("ZAPPED · " .. count .. " GREMLINS STUNNED") or "ZAP MISSED · MOVE CLOSER"
	if recovered > 0 then message ..= " · E TO RECOVER " .. recovered end
	self.Economy.Network.Notice:FireClient(player, message)
	self.Economy:Send(player)
	if count > 0 then self.Economy:Activity(player, "Zap") end
end

function GremlinRaid:Start()
	if self.Active or self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	local bays = {}
	for _, state in pairs(self.Bases.Players) do table.insert(bays, state.Bay) end
	if #bays == 0 then return end
	self.Active = true
	local endsAt = workspace:GetServerTimeNow() + Config.Gremlin.Duration
	self.Economy:PublishEvent({ Name = "Gremlin", Text = "GREMLIN RAID! LOCK [L] OR ZAP [F]",
		EndsAt = endsAt, Priority = 2, Color = Color3.fromRGB(155, 255, 105) })
	for index = 1, Config.Gremlin.Count do
		local bay = bays[(index - 1) % #bays + 1]
		local angle = self.Random:NextNumber(0, math.pi * 2)
		self:Spawn(bay, Vector3.new(math.cos(angle) * (Config.World.DeckRadius - 8), 0.9,
			math.sin(angle) * (Config.World.DeckRadius - 8)))
	end
	task.delay(Config.Gremlin.Duration, function() self.Active = false end)
end

return GremlinRaid
