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
	for index = 1, Config.Conveyor.PreviewAffordableCount do
		self:Spawn({ Id = index }, (index - 1) * math.pi / 3)
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
				self:Spawn(record, -math.pi / 2)
				local entry = Catalog.Get(record.Id)
				if Rarity.ByName[entry.Rarity].Rank >= 4 then
					economy:PublishEvent({
						Name = "RareCargo",
						Text = string.upper(entry.Rarity) .. " ON THE RING · " .. string.upper(Catalog.DisplayName(record)),
						EndsAt = workspace:GetServerTimeNow() + Config.Conveyor.RareNoticeSeconds,
						Priority = entry.Rarity == "SECRET" and 1.75 or 1.25,
						Color = Rarity.ByName[entry.Rarity].Color,
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
	local position = Vector3.new(math.cos(angle) * Config.World.RailRadius,
		Config.Conveyor.Height + math.sin(angle * 7) * 0.12, math.sin(angle) * Config.World.RailRadius)
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
	local sledSize = 1 + math.max(0, rarity.Rank - 3) * 0.07
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
	end
	WorldBuilder.Part("SledUnderglow", Vector3.new(0.14, 4.8 * sledSize, 4.8 * sledSize),
		CFrame.new(0, -0.93, 0) * CFrame.Angles(0, 0, math.pi / 2), rarity.Color,
		Enum.Material.Neon, capsule, Enum.PartType.Cylinder, false)
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
