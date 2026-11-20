-- Capsules complete one orbit; each purchase is checked and claimed on the server.
local shared = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Format = Traits.Format
local Mutation = Traits.Mutation
local Rarity = Traits.Rarity
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local BrainrotModel = require(script.Parent:WaitForChild("BrainrotModel"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local ConveyorService = {}
ConveyorService.__index = ConveyorService

function ConveyorService.new(world, economy)
	local self = setmetatable({ World = world, Economy = economy, Capsules = {}, Random = Random.new() }, ConveyorService)
	local nearArc = math.pi / 2
	for index = 1, Config.Conveyor.PreviewAffordableCount do
		self:Spawn({ Id = index }, nearArc + (index - 1) * math.pi / 3)
	end
	-- Stock the far half too, so the first title/hub view already shows a
	-- complete cargo orbit. These are ordinary purchasable, expiring cargo.
	for index, id in ipairs(Config.Conveyor.PreviewDisplayIds) do
		self:Spawn({ Id = id }, nearArc + (Config.Conveyor.PreviewAffordableCount + index - 1) * math.pi / 3)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if world.Root:GetAttribute("ScreenshotFrozen") then return end
		elapsed += dt
		if elapsed < 1 / 30 then return end
		local step = elapsed
		elapsed = 0
		for capsule, state in pairs(self.Capsules) do
			state.Travel += Config.Conveyor.Speed * step / Config.World.RailRadius
			if state.Travel >= math.pi * 2 then
				self.Capsules[capsule] = nil
				capsule:Destroy()
			else
				capsule:PivotTo(self:Frame(state.Angle + state.Travel))
			end
		end
	end)
	task.spawn(function()
		local spawnCount = 0
		while true do
			task.wait(Config.Conveyor.SpawnInterval)
			local count = 0
			for _ in pairs(self.Capsules) do count += 1 end
			if count < Config.Conveyor.MaxCapsules and not world.Root:GetAttribute("ScreenshotFrozen") then
				spawnCount += 1
				-- Regular starter cargo prevents a run of unaffordable rolls stranding newcomers.
				local surge = (world.Root:GetAttribute("AuroraSurgeUntil") or 0) > workspace:GetServerTimeNow()
				local record
				if spawnCount % 3 == 0 then
					record = surge and { Id = 1, Mutation = "Gold" } or { Id = self.Random:NextInteger(1, 4) }
				else
					record = spawnCount % Config.Rebirth.SupplyEvery == 1 and self:RebirthSupply() or nil
					record = record or Catalog.Roll(self.Random)
					if surge then record.Mutation = Mutation.Roll(self.Random, true) end
				end
				self:Spawn(record, Config.World.CargoEntryAngle)
				local entry = Catalog.Get(record.Id)
				local rarity = Rarity.ByName[entry.Rarity]
				if rarity.Rank >= 5 and world.CargoEntry then
					world.CargoEntry:SetAttribute("ArrivalColor", rarity.Color)
					world.CargoEntry:SetAttribute("ArrivalTime", workspace:GetServerTimeNow())
				end
				if rarity.Rank >= 4 then
					local notice = entry.Rarity == "SECRET" and "SECRET INCOMING!"
						or (string.upper(entry.Rarity) .. " ON THE RING")
					economy:PublishEvent({
						Name = "RareCargo",
						Text = notice .. " · " .. string.upper(Catalog.DisplayName(record)),
						EndsAt = workspace:GetServerTimeNow() + Config.Conveyor.RareNoticeSeconds,
						Priority = entry.Rarity == "SECRET" and 1.75 or 1.25,
						Color = rarity.Color,
						HideCountdown = true,
					})
				end
			end
		end
	end)
	return self
end

function ConveyorService:RebirthSupply()
	for player, profile in pairs(self.Economy.Profiles) do
		local state = self.Economy.Bases.Players[player]
		if profile.Rebirths >= 3 and not profile.Demo and state and not state.Loading and not state.Closing then
			local choices = Catalog.ByRarity.Mythic
			return { Id = choices[self.Random:NextInteger(1, #choices)].Id, Mutation = Mutation.Roll(self.Random) }
		end
	end
	return nil
end

function ConveyorService:Frame(angle)
	local position = Config.World.RailFrame(angle, Config.World.RailRadius, Config.Conveyor.HoverHeight).Position
		+ Vector3.new(0, math.sin(angle * 7) * 0.12, 0)
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

function ConveyorService:Spawn(record, angle)
	record.Guid = HttpService:GenerateGUID(false)
	local frame = self:Frame(angle)
	local capsule = Instance.new("Model")
	capsule.Name = "CargoCapsule"
	local pivot = WorldBuilder.Part("CapsulePivot", Vector3.one * 0.2, CFrame.identity,
		Config.Palette.White, Enum.Material.SmoothPlastic, capsule, nil, false)
	pivot.Transparency = 1
	pivot.CanQuery = false
	capsule.PrimaryPart = pivot
	local rarity = Rarity.ByName[Catalog.Get(record.Id).Rarity]
	local sledSize = Config.Conveyor.PodScale * (1 + math.max(0, rarity.Rank - 3) * 0.07)
	local pad = WorldBuilder.Part("HoverSled", Vector3.new(0.92, 5.8 * sledSize, 5.8 * sledSize),
		CFrame.new(0, -0.41, 0) * CFrame.Angles(0, 0, math.pi / 2), Config.Palette.Ink,
		Enum.Material.Metal, capsule, Enum.PartType.Cylinder, false)
	WorldBuilder.Part("SledRarityBand", Vector3.new(0.28, 6 * sledSize, 6 * sledSize),
		CFrame.new(0, -0.44, 0) * CFrame.Angles(0, 0, math.pi / 2), rarity.Color,
		Enum.Material.Neon, capsule, Enum.PartType.Cylinder, false)
	for _, side in ipairs({ -1, 1 }) do
		WorldBuilder.Part("SledClamp", Vector3.new(0.64, 0.48, 2.6),
			CFrame.new(side * 2.75 * sledSize, -0.06, 0), Config.Palette.White,
			Enum.Material.SmoothPlastic, capsule, nil, false)
		-- Open glass wings frame the model and leave both shopping sides clear.
		local canopy = WorldBuilder.Part("GlassCanopy", Vector3.new(0.29, 3.15, 3.5) * sledSize,
			CFrame.new(side * 2.46 * sledSize, 0.8 * sledSize, 0) * CFrame.Angles(0, 0, side * 0.29),
			rarity.Color:Lerp(Config.Palette.White, 0.5), Enum.Material.Glass, capsule, Enum.PartType.Ball, false)
		canopy.Transparency = 0.62
		canopy.CanQuery = false
	end
	WorldBuilder.Part("SledUnderglow", Vector3.new(0.14, 4.8 * sledSize, 4.8 * sledSize),
		CFrame.new(0, -0.93, 0) * CFrame.Angles(0, 0, math.pi / 2), rarity.Color,
		Enum.Material.Neon, capsule, Enum.PartType.Cylinder, false)
	local exhaust = Instance.new("ParticleEmitter")
	exhaust.Name = "IonDust"
	exhaust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	exhaust.Color = ColorSequence.new(rarity.Color)
	exhaust.LightEmission = 0.8
	exhaust.Size = NumberSequence.new(0.28, 0)
	exhaust.Transparency = NumberSequence.new(0.28, 1)
	exhaust.Lifetime = NumberRange.new(0.35, 0.65)
	exhaust.Speed = NumberRange.new(0.4, 1.8)
	exhaust.SpreadAngle = Vector2.new(25, 25)
	exhaust.EmissionDirection = Enum.NormalId.Bottom
	exhaust.Rate = rarity.Rank >= 4 and 10 or 4
	exhaust.Enabled = not self.World.Root:GetAttribute("ScreenshotFrozen")
	exhaust.Parent = pivot
	if rarity.Rank >= 4 then
		local source = Instance.new("Attachment", pivot)
		local top = Instance.new("Attachment", pivot)
		top.Position = Vector3.new(0, 8 + (rarity.Rank - 4) * 3, 0)
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = source, top
		beam.Width0, beam.Width1 = rarity.Rank == 7 and 4.2 or 2.6, 0.28
		beam.FaceCamera, beam.LightEmission = true, 0.75
		beam.Color = ColorSequence.new(rarity.Color)
		beam.Transparency = NumberSequence.new(rarity.Rank == 7 and 0.52 or 0.72, 1)
		beam.Parent = pivot
		if rarity.Rank >= 5 and exhaust.Enabled then exhaust:Emit(rarity.Rank == 7 and 24 or 12) end
		for _, side in ipairs({ -1, 1 }) do
			local low = Instance.new("Attachment", pivot)
			low.Position = Vector3.new(side * 2.2 * sledSize, -0.36, 0)
			local high = Instance.new("Attachment", pivot)
			high.Position = low.Position + Vector3.new(0, 0.3, 0)
			local wake = Instance.new("Trail")
			wake.Attachment0, wake.Attachment1 = low, high
			wake.Lifetime, wake.LightEmission, wake.FaceCamera = 0.48, 0.85, true
			wake.Color = ColorSequence.new(rarity.Color)
			wake.Transparency = NumberSequence.new(0.3, 1)
			wake.Parent = pivot
		end
	end
	local brainrot = BrainrotModel.Create(record, CFrame.Angles(0, math.pi, 0), capsule, true)
	brainrot:SetAttribute("VisualState", "Cargo")
	capsule:PivotTo(frame)
	capsule.Parent = self.World.Cargo
	if rarity.Rank >= 4 and not self.World.Root:GetAttribute("ScreenshotFrozen") then
		local sound = Instance.new("Sound")
		sound.Name = "RareCargoArrival"
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.RollOffMaxDistance = 48
		sound.Volume = 0.19
		sound.PlaybackSpeed = 0.85 + rarity.Rank * 0.08
		sound.Parent = pad
		sound:Play()
		Debris:AddItem(sound, 2)
	end
	local state = { Record = record, Angle = angle, Travel = 0, Sold = false }
	self.Capsules[capsule] = state
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyCargo"
	prompt.ActionText = "Buy · " .. Format.Money(Catalog.Price(record))
	prompt.ObjectText = Catalog.DisplayName(record)
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = Config.InteractionDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		if state.Sold or not self.Capsules[capsule] then return end
		if self.Economy:Purchase(player, record, pad.Position) then
			state.Sold = true
			self.Capsules[capsule] = nil
			capsule:Destroy()
		end
	end)
	return capsule
end

return ConveyorService
