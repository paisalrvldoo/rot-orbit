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
		Locks = locks, Gremlins = {}, Random = Random.new(), Active = false, Wave = 0,
		NextRaidAt = workspace:GetServerTimeNow() + Config.Gremlin.FirstRaid }, GremlinRaid)
	RunService.Heartbeat:Connect(function(dt) self:Step(math.min(dt, 0.1)) end)
	task.spawn(function()
		while true do
			task.wait(1)
			if workspace:GetServerTimeNow() >= self.NextRaidAt then
				self.NextRaidAt = workspace:GetServerTimeNow() + Config.Gremlin.Interval
				self:Start()
			end
		end
	end)
	return self
end

function GremlinRaid:Spawn(bay, position, boss, health)
	local model = Instance.new("Model")
	model.Name = boss and "CaptainGremlin" or "SpaceGremlin"
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
		part("Eye", Vector3.new(0.38, 0.35, 0.1), Vector3.new(side * 0.4, 2.25, -0.56), Config.Palette.Sun)
		part("Pupil", Vector3.new(0.16, 0.24, 0.08), Vector3.new(side * 0.4, 2.2, -0.63), Config.Palette.Ink)
	end
	part("Tooth", Vector3.new(0.35, 0.22, 0.1), Vector3.new(0, 1.93, -0.61), Config.Palette.White)
	if boss then
		part("CaptainCrown", Vector3.new(1.8, 0.6, 1.1), Vector3.new(0, 3, 0), Config.Palette.Sun)
		model:ScaleTo(2)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = self.World.Root
	local label = WorldBuilder.Billboard(root, "SPACE GREMLIN · ZAP [F]", green,
		Vector3.new(0, boss and 8 or 4, 0), boss and 310 or 250, 34)
	local maxHealth = health or Config.Gremlin.Health
	local hp = WorldBuilder.Billboard(root, "", Config.Palette.White,
		Vector3.new(0, boss and 7 or 3.5, 0), 180, 24)
	hp.Parent.Name = "EnemyHealth"
	hp.BackgroundColor3 = Config.Palette.Ink
	hp.BackgroundTransparency = 0.15
	local bar = Instance.new("Frame")
	bar.Name = "HealthFill"
	bar.BackgroundColor3 = boss and Config.Palette.Sun or green
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(1, 0.16)
	bar.Position = UDim2.fromScale(0, 0.84)
	bar.Parent = hp
	local state = { Model = model, Bay = bay, Position = position, Start = position,
		Destination = (bay.Frame * CFrame.new(0, 1, 3)).Position,
		Mode = "Approach", StunnedUntil = 0, Label = label, Boss = boss, Health = maxHealth,
		MaxHealth = maxHealth, HealthLabel = hp, HealthBar = bar,
		ExpiresAt = workspace:GetServerTimeNow() + Config.Gremlin.Duration }
	self.Gremlins[model] = state
	self:HealthView(state)
	return state
end

function GremlinRaid:HealthView(state)
	state.HealthLabel.Text = (state.Boss and "CAPTAIN " or "") .. state.Health .. "/" .. state.MaxHealth .. " HP"
	state.HealthBar.Size = UDim2.fromScale(math.max(0, state.Health / state.MaxHealth), 0.16)
end

function GremlinRaid:Damage(state, player, amount)
	if not self.Gremlins[state.Model] or state.Health <= 0 then return false end
	state.Health = math.max(0, state.Health - amount)
	self:HealthView(state)
	if state.Health > 0 then self:Stun(state, workspace:GetServerTimeNow()); return false end
	local profile = self.Economy.Profiles[player]
	if profile and not profile.Demo then
		local reward = state.Boss and Config.Gremlin.BossReward or Config.Gremlin.KillReward
		profile.Cash = math.min(Config.MaxCash, profile.Cash + reward)
		self.Economy.Network.Notice:FireClient(player, (state.Boss and "CAPTAIN DOWN! +$" or "GREMLIN DOWN! +$") .. reward)
	end
	if state.Wave == self.Wave then self.Defeated = (self.Defeated or 0) + 1 end
	self:Remove(state, true)
	if self.Active and self.Defeated == self.WaveCount then self:Finish() end
	return true
end

function GremlinRaid:Finish()
	if not self.Active then return end
	self.Active = false
	if self.Defeated == self.WaveCount and self.WaveCount > 0 then
		for player, state in pairs(self.Bases.Players) do
			local profile = self.Economy.Profiles[player]
			if profile and not profile.Demo and not state.Loading and not state.Closing then
				state.RaidsDefended = (state.RaidsDefended or 0) + 1
				profile.Cash = math.min(Config.MaxCash, profile.Cash + Config.Gremlin.DefendReward)
				self.Economy.Network.Notice:FireClient(player, "RAID DEFENDED! +$" .. Config.Gremlin.DefendReward)
				self.Economy:Send(player)
			end
		end
	end
	self.Active = false
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
	if not bay.Owner or not self.Bases:IsBayReady(bay) or self.Locks:IsLocked(bay) then
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
	local count, recovered, nearest, distance = 0, 0, nil, Config.Gremlin.ZapRadius
	for _, gremlin in pairs(self.Gremlins) do
		local gap = (gremlin.Position - root.Position).Magnitude
		if gap <= distance then nearest, distance = gremlin, gap end
	end
	if nearest then
		count = 1
		if self:Stun(nearest, now) then recovered = 1 end
		self:Damage(nearest, player, Config.Gremlin.ZapDamage)
		local from, to = root.Position, nearest.Position + Vector3.new(0, 2, 0)
		local beam = WorldBuilder.Part("ZapBlasterBeam", Vector3.new(0.25, 0.25, (to - from).Magnitude),
			CFrame.lookAt((from + to) / 2, to), Config.Palette.Mint, Enum.Material.Neon, self.World.Root, nil, false)
		beam.CanQuery = false
		Debris:AddItem(beam, 0.18)
	end
	self:Pulse(root.Position, 3, Config.Palette.Mint, "ZapMuzzle")
	local message = count > 0 and ("ZAPPED · " .. count .. " HITS · KEEP FIRING TO DEFEAT") or "ZAP MISSED · MOVE CLOSER"
	if recovered > 0 then message ..= " · E TO RECOVER " .. recovered end
	self.Economy.Network.Notice:FireClient(player, message)
	self.Economy:Send(player)
	if count > 0 then self.Economy:Activity(player, "Zap") end
end

-- Skill decisions stay on the server: clients send only the skill name.
function GremlinRaid:Pulse(position, radius, color, name)
	local pulse = WorldBuilder.Part(name, Vector3.one, CFrame.new(position), color,
		Enum.Material.Neon, self.World.Root, Enum.PartType.Ball, false)
	pulse.CanQuery = false
	pulse.Transparency = 0.5
	TweenService:Create(pulse, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	local sound = Instance.new("Sound")
	sound.Name = "SkillPing"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.3
	sound.RollOffMaxDistance = 65
	sound.PlaybackSpeed = name == "GravitySlam" and 0.65 or 1.3
	sound.Parent = pulse
	sound:Play()
	Debris:AddItem(pulse, 1)
end

function GremlinRaid:Skill(player, name)
	if type(name) ~= "string" or not table.find(Config.Skills.Order, name) then return end
	local state, profile = self.Bases.Players[player], self.Economy.Profiles[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not state or state.Loading or state.Closing or not profile or profile.Demo or not root
		or not self.Bases:Near(player, root.Position) then return end
	local skill = Config.Skills[name]
	if not Config.Skills.Unlocked(name, profile) then
		self.Economy.Network.Notice:FireClient(player, skill.Name .. " · NEED " .. skill.Unlock)
		return
	end
	local now = workspace:GetServerTimeNow()
	state.SkillReadyAt = state.SkillReadyAt or {}
	if now < (state.SkillReadyAt[name] or 0) then return end
	if name == "Bubble" and (root.Position - state.Bay.Frame.Position).Magnitude > skill.Radius then
		self.Economy.Network.Notice:FireClient(player, "BAY BUBBLE · GET CLOSER TO YOUR BAY")
		return
	end
	state.SkillReadyAt[name] = now + skill.Cooldown
	if name == "Dash" then
		local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if direction.Magnitude > 0.01 then
			direction = direction.Unit * skill.Distance
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { player.Character }
			params.RespectCanCollide = true
			local hit = workspace:Raycast(root.Position, direction, params)
			if hit then direction = direction.Unit * math.max(0, hit.Distance - 3) end
			local target = root.Position + direction
			if Vector3.new(target.X, 0, target.Z).Magnitude < Config.World.DeckRadius - 4 then
				self:Pulse(root.Position, 3, Config.Palette.Mint, "DashDeparture")
				root.CFrame += direction
				self:Pulse(target, 4, Config.Palette.Mint, "JetDash")
			end
		end
	elseif name == "Slam" then
		local hits = 0
		for _, enemy in pairs(self.Gremlins) do
			if (enemy.Position - root.Position).Magnitude <= skill.Radius then
				hits += 1
				self:Damage(enemy, player, skill.Damage)
				if self.Gremlins[enemy.Model] then
					local away = (enemy.Position - root.Position) * Vector3.new(1, 0, 1)
					if away.Magnitude > 0.1 then enemy.Position += away.Unit * (enemy.Boss and 3 or 8) end
				end
			end
		end
		self:Pulse(root.Position, skill.Radius, Config.Palette.Sun, "GravitySlam")
		self.Economy.Network.Notice:FireClient(player, "GRAVITY SLAM · " .. hits .. " ENEMIES HIT")
	else
		local bay = state.Bay
		local untilTime = math.max(bay.Model:GetAttribute("LockedUntil") or 0, now + skill.Duration)
		state.LockUntil = untilTime
		bay.Model:SetAttribute("LockedUntil", untilTime)
		local shield = WorldBuilder.Part("SkillBayBubble", Vector3.new(68, 56, 68),
			bay.Frame * CFrame.new(0, 0, 12), Config.Palette.Sun, Enum.Material.ForceField,
			bay.Model, Enum.PartType.Ball, false)
		shield.Transparency = 0.8
		shield.CanQuery = false
		self:Pulse(root.Position, 6, Config.Palette.Sun, "BubbleActivate")
		task.delay(skill.Duration, function()
			shield:Destroy()
			if bay.Owner == player and bay.Model:GetAttribute("LockedUntil") == untilTime
				and workspace:GetServerTimeNow() >= untilTime then bay.Model:SetAttribute("LockedUntil", 0) end
		end)
		self.Economy.Network.Notice:FireClient(player, "BAY BUBBLE · 12s EMERGENCY SHIELD")
	end
	self.Economy:Send(player)
end

function GremlinRaid:Start()
	if self.Active or self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	local bays = {}
	for _, state in pairs(self.Bases.Players) do
		if self.Bases:IsBayReady(state.Bay) then table.insert(bays, state.Bay) end
	end
	if #bays == 0 then return end
	self.Active = true
	self.Wave += 1
	self.Defeated = 0
	self.WaveCount = Config.Gremlin.Count + math.min(4, #bays - 1)
	local boss = self.Wave % Config.Gremlin.BossEvery == 0
	local endsAt = workspace:GetServerTimeNow() + Config.Gremlin.Duration + Config.Gremlin.Telegraph
	self.Economy:PublishEvent({ Name = "Gremlin", Text = boss and "CAPTAIN RAID! FIGHT THE BOSS · ZAP [F]"
		or "GREMLIN RAID! INCOMING · LOCK [L] OR ZAP [F]", EndsAt = endsAt, Priority = 4,
		Color = Color3.fromRGB(255, 109, 91) })
	local portal = WorldBuilder.Part("GremlinArrivalPortal", Vector3.new(12, 14, 1), CFrame.new(0, 7, -60),
		Color3.fromRGB(151, 255, 81), Enum.Material.Neon, self.World.Root, Enum.PartType.Ball, false)
	portal.Transparency = 0.3
	WorldBuilder.Billboard(portal, boss and "CAPTAIN INCOMING!" or "GREMLIN RAID INCOMING!",
		Config.Palette.Sun, Vector3.new(0, 9, 0), 420, 44)
	Debris:AddItem(portal, Config.Gremlin.Duration + Config.Gremlin.Telegraph)
	task.delay(Config.Gremlin.Telegraph, function()
		if self.World.Root:GetAttribute("ScreenshotFrozen") then self.Active = false; return end
		for index = 1, self.WaveCount do
			local bay = bays[(index - 1) % #bays + 1]
			local profile = self.Economy.Profiles[bay.Owner]
			local rebirths = profile and profile.Rebirths or 0
			local captain = boss and index == 1
			local health = captain and (Config.Gremlin.BossHealth + #bays * 4 + math.min(rebirths, 6) * 2)
				or (Config.Gremlin.Health + math.min(rebirths, 6))
			local enemy = self:Spawn(bay, Vector3.new((index - (self.WaveCount + 1) / 2) * 4, 0.9, -58), captain, health)
			enemy.Wave = self.Wave
		end
	end)
	task.delay(Config.Gremlin.Duration + Config.Gremlin.Telegraph, function() self:Finish() end)
end

return GremlinRaid
