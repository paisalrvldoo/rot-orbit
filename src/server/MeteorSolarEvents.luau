-- Telegraph every impact; a carrying astronaut can always run for a mint dome.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local MeteorSolarEvents = {}
MeteorSolarEvents.__index = MeteorSolarEvents

function MeteorSolarEvents.new(world, bases, economy)
	local self = setmetatable({ World = world, Bases = bases, Economy = economy,
		Random = Random.new(), Active = false }, MeteorSolarEvents)
	self.Effects = Instance.new("Folder")
	self.Effects.Name = "MeteorEffects"
	self.Effects.Parent = world.Root
	task.spawn(function()
		while true do
			task.wait(Config.Meteor.Interval)
			task.spawn(function() self:Start() end)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.SolarFlare.Interval)
			task.spawn(function() self:StartSolarFlare() end)
		end
	end)
	return self
end

function MeteorSolarEvents:IsProtected(position)
	for _, dome in ipairs(self.World.Domes) do
		if (position - dome.Center).Magnitude <= dome.Radius then return true end
	end
	return false
end

function MeteorSolarEvents:Impact(position)
	local warning = WorldBuilder.Ring("ImpactWarning", Config.Meteor.ImpactRadius, 0.32, 0.15,
		CFrame.new(position), Config.Palette.Sun, Enum.Material.Neon, self.Effects, 28, false)
	local target = WorldBuilder.Part("WarningCore", Vector3.new(0.12, 2.5, 2.5),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), Config.Palette.Planet,
		Enum.Material.Neon, warning, Enum.PartType.Cylinder, false)
	WorldBuilder.Billboard(target, "IMPACT! RUN TO A DOME", Config.Palette.Sun,
		Vector3.new(0, 2.8, 0), 260, 30)
	local meteor = WorldBuilder.Part("FallingMeteor", Vector3.one * 3,
		CFrame.new(position + Vector3.new(12, Config.Meteor.FallHeight, -7)), Config.Palette.Planet,
		Enum.Material.Neon, self.Effects, Enum.PartType.Ball, false)
	local light = Instance.new("PointLight")
	light.Color = Config.Palette.Sun
	light.Brightness = 2
	light.Range = 22
	light.Parent = meteor
	TweenService:Create(meteor, TweenInfo.new(Config.Meteor.WarningSeconds, Enum.EasingStyle.Linear),
		{ Position = position + Vector3.new(0, 1.5, 0) }):Play()
	task.delay(Config.Meteor.WarningSeconds, function()
		warning:Destroy()
		meteor:Destroy()
		if not self.Active then return end
		local burst = WorldBuilder.Part("MeteorBurst", Vector3.one * 2, CFrame.new(position),
			Config.Palette.Sun, Enum.Material.Neon, self.Effects, Enum.PartType.Ball, false)
		burst.Transparency = 0.35
		TweenService:Create(burst, TweenInfo.new(0.6),
			{ Size = Vector3.one * Config.Meteor.ImpactRadius * 2, Transparency = 1 }):Play()
		Debris:AddItem(burst, 0.7)
		for player, state in pairs(self.Bases.Players) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and state.Carry and not self:IsProtected(root.Position) then
				local horizontal = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
				if horizontal.Magnitude <= Config.Meteor.ImpactRadius then
					self.Bases:Drop(player)
					self.Economy.Network.Notice:FireClient(player, "METEOR HIT! Your cargo dropped. Recover it with E!")
				end
			end
		end
	end)
end

function MeteorSolarEvents:Start()
	if self.Active or self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	self.Active = true
	local endsAt = workspace:GetServerTimeNow() + Config.Meteor.Duration
	self.Economy:PublishEvent({ Name = "Meteor", Text = "METEOR SHOWER! GET UNDER THE SHIELD DOME",
		EndsAt = endsAt, Priority = 3, Color = Config.Palette.Sun })
	local holding = {}
	for player, state in pairs(self.Bases.Players) do
		if state.Carry then holding[player] = state.Carry.Record.Guid end
	end
	while self.Active and workspace:GetServerTimeNow() < endsAt - Config.Meteor.WarningSeconds do
		local targets = {}
		for player, state in pairs(self.Bases.Players) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and state.Carry then table.insert(targets, root.Position) end
		end
		for index = 1, Config.Meteor.MeteorsPerWave do
			local target
			if index == 1 and #targets > 0 then
				target = targets[self.Random:NextInteger(1, #targets)]
					+ Vector3.new(self.Random:NextNumber(-5, 5), 0, self.Random:NextNumber(-5, 5))
			else
				local angle = self.Random:NextNumber(0, math.pi * 2)
				local radius = math.sqrt(self.Random:NextNumber()) * (Config.World.DeckRadius - 12)
				target = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			end
			self:Impact(Vector3.new(target.X, 0.15, target.Z))
		end
		task.wait(Config.Meteor.WaveInterval)
	end
	task.wait(math.max(0, endsAt - workspace:GetServerTimeNow()))
	self.Active = false
	for player, guid in pairs(holding) do
		local state = self.Bases.Players[player]
		if state and state.Carry and state.Carry.Record.Guid == guid then
			self.Economy:Activity(player, "SurviveMeteor", state.Carry.Record)
		end
	end
end

function MeteorSolarEvents:StartSolarFlare()
	if self.SolarActive or self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	self.SolarActive = true
	self.Economy.IncomeMultiplier = Config.SolarFlare.Multiplier
	self.World.Root:SetAttribute("SolarFlareActive", true)
	self.Economy:PublishEvent({ Name = "SolarFlare", Text = "SOLAR FLARE! ALL BAYS PAY x2",
		EndsAt = workspace:GetServerTimeNow() + Config.SolarFlare.Duration,
		Priority = 1, Color = Config.Palette.Sun })
	for player in pairs(self.Economy.Profiles) do self.Economy:Send(player) end
	task.wait(Config.SolarFlare.Duration)
	self.Economy.IncomeMultiplier = 1
	self.World.Root:SetAttribute("SolarFlareActive", false)
	self.SolarActive = false
	for player in pairs(self.Economy.Profiles) do self.Economy:Send(player) end
end

return MeteorSolarEvents
