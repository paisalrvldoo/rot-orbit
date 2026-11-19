-- Capsules complete one orbit; each purchase is checked and claimed on the server.
local shared = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("Format"))
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
				local record = spawnCount % 3 == 0 and { Id = self.Random:NextInteger(1, 4) }
					or Catalog.Roll(self.Random)
				self:Spawn(record, -math.pi / 2)
			end
		end
	end)
	return self
end

function ConveyorService:Frame(angle)
	local position = Vector3.new(math.cos(angle) * Config.World.RailRadius,
		Config.Conveyor.Height, math.sin(angle) * Config.World.RailRadius)
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
	local pad = WorldBuilder.Part("HoverSled", Vector3.new(0.45, 5.4, 5.4),
		CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Config.Palette.Ink,
		Enum.Material.SmoothPlastic, capsule, Enum.PartType.Cylinder, false)
	WorldBuilder.Ring("CapsuleHalo", 2.65, 0.16, 0.12, CFrame.identity,
		Config.Palette.Mint, Enum.Material.Neon, capsule, 20, false)
	local brainrot = BrainrotModel.Create(record, CFrame.identity, capsule)
	brainrot:SetAttribute("VisualState", "Cargo")
	capsule:PivotTo(frame)
	capsule.Parent = self.World.Cargo
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
