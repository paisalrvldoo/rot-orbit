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
		NextPatrolAt = workspace:GetServerTimeNow() + Config.Gremlin.PatrolFirst,
		NextRaidAt = workspace:GetServerTimeNow() + Config.Gremlin.FirstRaid }, GremlinRaid)
	economy.Raids = self
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
		local eye = part("Eye", Vector3.new(0.38, 0.35, 0.1), Vector3.new(side * 0.4, 2.25, -0.56), Config.Palette.Sun)
		eye.Material = Enum.Material.Neon
		part("Pupil", Vector3.new(0.16, 0.24, 0.08), Vector3.new(side * 0.4, 2.2, -0.63), Config.Palette.Ink)
	end
	part("Tooth", Vector3.new(0.35, 0.22, 0.1), Vector3.new(0, 1.93, -0.61), Config.Palette.White)
	if boss then
		part("CaptainCrown", Vector3.new(1.8, 0.6, 1.1), Vector3.new(0, 3, 0), Config.Palette.Sun)
		model:ScaleTo(2)
	end
	model:PivotTo(CFrame.new(position))
	model.Parent = self.World.Root
	local label = WorldBuilder.Billboard(root, boss and "CAPTAIN GREMLIN · FIGHT TOGETHER!" or "SPACE GREMLIN · ZAP [F]", green,
		Vector3.new(0, boss and 8 or 4, 0), boss and 420 or 250, 34)
	local maxHealth = health or Config.Gremlin.Health
	local hp = WorldBuilder.Billboard(root, "", Config.Palette.White,
		Vector3.new(0, boss and 7 or 3.5, 0), boss and 360 or 180, boss and 30 or 24)
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
	if self.Crews and profile and not profile.Demo then self.Crews:OnDefeat(player, state) end
	if state.Wave == self.Wave then self.Defeated = (self.Defeated or 0) + 1 end
	self:Remove(state, true)
	if self.Active and self.Defeated == self.WaveCount then self:Finish() end
	return true
end

function GremlinRaid:Finish()
	if not self.Active then return end
	self.Active = false
	if self.Defeated == self.WaveCount and self.WaveCount > 0 then
		local defended = {}
		for player, state in pairs(self.Bases.Players) do
			local profile = self.Economy.Profiles[player]
			if profile and not profile.Demo and not state.Loading and not state.Closing
				and (not self.Participants or self.Participants[player])
				and self.Bases:Near(player, state.Bay.Frame.Position, Config.Crews.RewardRadius) then
				table.insert(defended, player)
				state.RaidsDefended = (state.RaidsDefended or 0) + 1
				profile.Cash = math.min(Config.MaxCash, profile.Cash + Config.Gremlin.DefendReward)
				self.Economy.Network.Notice:FireClient(player, (state.CrewId and "CREW DEFENDED! +$" or "RAID DEFENDED! +$") .. Config.Gremlin.DefendReward)
				self.Economy:Send(player)
			end
		end
		if self.Crews then self.Crews:Defended(defended) end
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
		state.Model:GetPivot() * (state.Boss and CFrame.new(3.4, 4, 0) or CFrame.new(0, 3.4, 0)), state.Model)
	state.LootModel:SetAttribute("VisualState", "Raided")
	state.Label.Text = "STOLEN CARGO! ZAP [F]"
	self.Economy.Network.Notice:FireClient(bay.Owner,
		"A GREMLIN TOOK " .. Catalog.DisplayName(state.Loot) .. "! Chase it and ZAP [F]!")
	self.Economy:Send(bay.Owner)
end

function GremlinRaid:Step(dt)
	if self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	local now = workspace:GetServerTimeNow()
	if now >= self.NextPatrolAt then
		self.NextPatrolAt = now + Config.Gremlin.PatrolInterval
		self:Patrol()
	end
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

function GremlinRaid:BossView()
	for _, enemy in pairs(self.Gremlins) do
		if enemy.Boss and enemy.Health > 0 then
			return { Health = enemy.Health, MaxHealth = enemy.MaxHealth, Wave = self.Wave }
		end
	end
	return nil
end

function GremlinRaid:Patrol()
	if self.Active then return end
	local patrols = 0
	for _, enemy in pairs(self.Gremlins) do if enemy.Patrol then patrols += 1 end end
	if patrols >= Config.Gremlin.PatrolMax then return end
	local targets = {}
	for player, state in pairs(self.Bases.Players) do
		local profile = self.Economy.Profiles[player]
		if self.Bases:IsBayReady(state.Bay) and profile and not profile.Demo then
			for _, pedestal in ipairs(state.Bay.Slots) do
				if pedestal.Occupant then table.insert(targets, state.Bay); break end
			end
		end
	end
	if #targets == 0 or #self.World.RivalBays == 0 then return end
	local bay = targets[self.Random:NextInteger(1, #targets)]
	local rival = self.World.RivalBays[self.Random:NextInteger(1, #self.World.RivalBays)]
	local enemy = self:Spawn(bay, (rival.Frame * CFrame.new(0, 1, -12)).Position)
	enemy.Patrol = true
	enemy.Model.Name = "RivalCrewThief"
	enemy.Label.Text = "RIVAL THIEF! · ZAP [F]"
	self.Economy.Network.Notice:FireClient(bay.Owner, "THIEF APPROACHING YOUR BAY! ZAP [F] OR LOCK [L]")
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

-- Find where a path enters a shield, using the same shape as its visible part.
local function shieldEntry(origin, move, shield)
	local radii = shield.Size * 0.5 + Vector3.one
	local start = shield.CFrame:PointToObjectSpace(origin) / radii
	if start:Dot(start) < 1 then return nil end -- Players already inside can leave.
	local direction = shield.CFrame:VectorToObjectSpace(move) / radii
	local lengthSquared = direction:Dot(direction)
	if lengthSquared < 1e-6 then return nil end
	local ahead = start:Dot(direction)
	local discriminant = ahead * ahead - lengthSquared * (start:Dot(start) - 1)
	if ahead >= 0 or discriminant < 0 then return nil end
	local entry = (-ahead - math.sqrt(discriminant)) / lengthSquared
	return entry <= 1 and entry or nil
end

function GremlinRaid:BlinkTarget(player, root, distance)
	local origin = root.Position
	local direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.01 then return nil end
	local move = direction.Unit * distance
	local fraction = 1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.RespectCanCollide = true
	local hit = workspace:Spherecast(origin, 1, move, params)
	if hit then fraction = math.min(fraction, (hit.Distance - 1) / distance) end
	local function checkShield(shield)
		local entry = shieldEntry(origin, move, shield)
		if entry then fraction = math.min(fraction, entry - 0.5 / distance) end
	end
	for _, dome in ipairs(self.World.Domes) do checkShield(dome.Part) end
	for _, bay in ipairs(self.World.PlayerBays) do
		if self.Locks:IsLocked(bay) then
			local shield = bay.Model:FindFirstChild("BayLockShield") or bay.Model:FindFirstChild("SkillBayBubble")
			if shield then checkShield(shield) end
		end
	end
	local position = origin + move * fraction
	if fraction * distance < 2 or Vector3.new(position.X, 0, position.Z).Magnitude >= Config.World.DeckRadius - 4 then
		return nil
	end
	return position
end

function GremlinRaid:Sprint(player, state, root, now, skill)
	local ends = now + skill.Duration
	state.SprintUntil = ends
	self.Bases:SetSpeed(player)
	local a, b = Instance.new("Attachment", root), Instance.new("Attachment", root)
	a.Position, b.Position = Vector3.new(-0.8, 0, 0.6), Vector3.new(0.8, 0, 0.6)
	local trail = Instance.new("Trail")
	trail.Name = "SprintIonTrail"
	trail.Attachment0, trail.Attachment1 = a, b
	trail.Color = ColorSequence.new(Config.Palette.Mint, Config.Palette.Teal)
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Lifetime = 0.23
	trail.MinLength = 0.2
	trail.LightEmission = 0.6
	trail.Parent = root
	for _, effect in ipairs({ trail, a, b }) do Debris:AddItem(effect, skill.Duration) end
	task.delay(skill.Duration, function()
		if self.Bases.Players[player] == state and state.SprintUntil == ends then
			state.SprintUntil = nil
			self.Bases:SetSpeed(player)
		end
	end)
end

function GremlinRaid:ShieldBlocks(origin, target)
	local move = target - origin
	local function blocks(shield)
		-- Test both directions so a blast cannot escape a shield either.
		return shieldEntry(origin, move, shield) ~= nil or shieldEntry(target, -move, shield) ~= nil
	end
	for _, dome in ipairs(self.World.Domes) do
		if blocks(dome.Part) then return true end
	end
	for _, bay in ipairs(self.World.PlayerBays) do
		if self.Locks:IsLocked(bay) then
			local shield = bay.Model:FindFirstChild("BayLockShield") or bay.Model:FindFirstChild("SkillBayBubble")
			if shield and blocks(shield) then return true end
		end
	end
	return false
end

function GremlinRaid:TargetableThief(player, other, state)
	return other ~= player and not state.Loading and not state.Closing and state.Carry and state.Carry.Stolen
		and not (self.Crews and self.Crews:Same(player, other))
end

function GremlinRaid:Knockback(player, state, root, away, duration)
	local now = workspace:GetServerTimeNow()
	local untilTime = math.max(state.StunnedUntil or 0, now + duration)
	state.StunnedUntil = untilTime
	self.Bases:Drop(player)
	self.Bases:SetSpeed(player)
	if away.Magnitude > 0.01 then
		local ok = pcall(function() root:SetNetworkOwner(nil) end)
		root.AssemblyLinearVelocity = away.Unit * 65 + Vector3.new(0, 12, 0)
		task.delay(duration, function()
			if ok and root.Parent and state.StunnedUntil == untilTime then
				pcall(function() root:SetNetworkOwnershipAuto() end)
			end
		end)
	end
	task.delay(untilTime - now, function()
		if self.Bases.Players[player] == state and state.StunnedUntil == untilTime then
			state.StunnedUntil = nil
			self.Bases:SetSpeed(player)
		end
	end)
end

function GremlinRaid:BombBlast(player, position, skill)
	local function inRange(at)
		return (at - position).Magnitude <= skill.Radius and not self:ShieldBlocks(position, at)
	end
	for _, enemy in pairs(self.Gremlins) do
		if inRange(enemy.Position) then self:Damage(enemy, player, skill.Damage) end
	end
	for other, state in pairs(self.Bases.Players) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and self:TargetableThief(player, other, state) and self.Bases:Near(other, root.Position) and inRange(root.Position) then
			self:Knockback(other, state, root, (root.Position - position) * Vector3.new(1, 0, 1), skill.Stun)
			self.Economy.Network.Notice:FireClient(other, "BOMB HIT · CARGO DROPPED")
		end
	end
	self:Pulse(position, skill.Radius, Config.Palette.Sun, "CargoBombBurst")
	self.Economy:Send(player)
end

function GremlinRaid:Bomb(player, state, root, trap, skill)
	state.Traps = state.Traps or {}
	local origin = root.Position
	local model = Instance.new("Model")
	model.Name = trap and "CargoTrap" or "CargoBomb"
	local shell = WorldBuilder.Part("BombShell", Vector3.one * 1.8, CFrame.new(origin), Config.Palette.Ink,
		Enum.Material.SmoothPlastic, model, Enum.PartType.Ball, false)
	model.PrimaryPart = shell
	local lamp = WorldBuilder.Part("FuseBeacon", Vector3.one * 0.4, CFrame.new(origin + Vector3.new(0, 0.92, 0)),
		Config.Palette.Sun, Enum.Material.Neon, model, Enum.PartType.Ball, false)
	shell.CanQuery, lamp.CanQuery = false, false
	model.Parent = self.World.Root
	local function live()
		return model.Parent ~= nil and self.Bases.Players[player] == state and not state.Closing
			and not self.World.Root:GetAttribute("ScreenshotFrozen")
	end
	local function finish(explode)
		if explode and live() then self:BombBlast(player, shell.Position, skill) end
		state.Traps[model] = nil
		model:Destroy()
	end
	local function pulseFuse()
		TweenService:Create(lamp, TweenInfo.new(trap and 0.45 or 0.16, Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut, -1, true), { Transparency = 0.78 }):Play()
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, model }
	params.RespectCanCollide = true
	local function floorAt(position)
		local ground = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -22, 0), params)
		return ground and ground.Position + Vector3.new(0, 0.93, 0)
	end
	if trap then
		local landing = floorAt(origin)
		if not landing then finish(false); return false end
		model:PivotTo(CFrame.new(landing))
		state.Traps[model] = true
		pulseFuse()
		task.spawn(function()
			task.wait(skill.Arm)
			local expires = workspace:GetServerTimeNow() + skill.TrapLifetime
			local function near(position)
				return (position - landing).Magnitude <= skill.TriggerRadius and not self:ShieldBlocks(landing, position)
			end
			while live() and workspace:GetServerTimeNow() < expires do
				for _, enemy in pairs(self.Gremlins) do
					if near(enemy.Position) then finish(true); return end
				end
				for other, otherState in pairs(self.Bases.Players) do
					local target = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
					if target and self:TargetableThief(player, other, otherState)
						and self.Bases:Near(other, target.Position) and near(target.Position) then finish(true); return end
				end
				task.wait(0.15)
			end
			finish(false)
		end)
	else
		pulseFuse()
		task.spawn(function()
			local aim = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local move = aim.Magnitude > 0.01 and aim.Unit * skill.Distance or Vector3.zero
			local started = workspace:GetServerTimeNow()
			while live() do
				local t = math.clamp((workspace:GetServerTimeNow() - started) / skill.Travel, 0, 1)
				local nextAt = origin + move * t + Vector3.new(0, 4 * skill.Arc * t * (1 - t), 0)
				local step = nextAt - shell.Position
				if step.Magnitude > 0.01 then
					local wall = workspace:Spherecast(shell.Position, 0.65, step, params)
					if wall or self:ShieldBlocks(shell.Position, nextAt) then break end
					model:PivotTo(CFrame.new(nextAt))
				end
				if t >= 1 then break end
				RunService.Heartbeat:Wait()
			end
			if live() then
				local landing = floorAt(shell.Position)
				if landing and not self:ShieldBlocks(shell.Position, landing) then model:PivotTo(CFrame.new(landing)) end
				task.wait(math.max(0, skill.Fuse - (workspace:GetServerTimeNow() - started)))
			end
			finish(true)
		end)
	end
	return true
end

function GremlinRaid:Skill(player, name, mode)
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
	if (state.StunnedUntil or 0) > now then return end
	state.SkillReadyAt = state.SkillReadyAt or {}
	if now < (state.SkillReadyAt[name] or 0) then return end
	if name == "Bubble" and (root.Position - state.Bay.Frame.Position).Magnitude > skill.Radius then
		self.Economy.Network.Notice:FireClient(player, "BAY BUBBLE · GET CLOSER TO YOUR BAY")
		return
	end
	local blinkTarget
	if name == "Blink" then
		blinkTarget = self:BlinkTarget(player, root, Config.Rebirth.BlinkDistance(profile.Rebirths or 0, state.Carry ~= nil))
		if not blinkTarget then
			self.Economy.Network.Notice:FireClient(player, "BLINK BLOCKED · TURN TOWARD OPEN DECK")
			return
		end
	end
	if name == "Bomb" then
		local trap = mode == "Trap"
		if mode ~= nil and not trap then return end
		if trap then
			local traps = 0
			for model in pairs(state.Traps or {}) do if model.Parent then traps += 1 end end
			if traps >= skill.TrapLimit then
				self.Economy.Network.Notice:FireClient(player, "BOMB · TWO TRAPS ALREADY ACTIVE")
				return
			end
		end
		if not self:Bomb(player, state, root, trap, skill) then return end
		state.SkillReadyAt[name] = now + skill.Cooldown
		self.Economy:Send(player)
		return
	end
	state.SkillReadyAt[name] = now + skill.Cooldown
	if name == "Blink" then
		local violet = Color3.fromRGB(189, 125, 255)
		self:Pulse(root.Position, 2.5, violet, "BlinkDeparture")
		root.CFrame += blinkTarget - root.Position
		self:Pulse(blinkTarget, 3, violet, "BlinkArrival")
	elseif name == "Sprint" then
		self:Sprint(player, state, root, now, skill)
	elseif name == "Dash" then
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
	self.Participants = {}
	for _, bay in ipairs(bays) do self.Participants[bay.Owner] = true end
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
