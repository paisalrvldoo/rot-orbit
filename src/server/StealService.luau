-- Rival crews restock; player bays can also be raided until they raise a lock shield.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local StealService = {}
StealService.__index = StealService

function StealService.new(bases, economy, network)
	local self = setmetatable({ Bases = bases, Economy = economy, Network = network }, StealService)
	bases.OnPlaced = function(bay, pedestal) self:Attach(bay, pedestal) end
	self:RefreshRivals()
	task.spawn(function()
		while true do
			task.wait(Config.Steal.RefillSeconds)
			bases:SeedRivals()
			self:RefreshRivals()
		end
	end)
	return self
end

function StealService:RefreshRivals()
	for _, bay in ipairs(self.Bases.World.RivalBays) do
		for _, pedestal in ipairs(bay.Slots) do self:Attach(bay, pedestal) end
	end
end

function StealService:Attach(bay, pedestal)
	local occupant = pedestal.Occupant
	if not occupant or occupant.Model.PrimaryPart:FindFirstChild("StealCargo") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealCargo"
	prompt.ActionText = "Steal brainrot"
	prompt.ObjectText = Catalog.DisplayName(occupant.Record)
	prompt.HoldDuration = Config.Steal.HoldDuration
	prompt.MaxActivationDistance = Config.InteractionDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = occupant.Model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if bay.Owner == player or pedestal.Occupant ~= occupant then return end
		if not self.Bases:Near(player, pedestal.Pad.Position) then return end
		if (bay.Model:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow() then
			self.Network.Notice:FireClient(player, "This bay is shield locked. Find another target!")
			return
		end
		if not self.Bases:Carry(player, occupant.Record) then
			self.Network.Notice:FireClient(player, "You need empty hands and a free home pedestal.")
			return
		end
		occupant.Model:Destroy()
		pedestal.Occupant = nil
		pedestal.Label.Visible = true
		if pedestal.PlacePrompt then pedestal.PlacePrompt.Enabled = true end
		self.Network.Notice:FireClient(player, "STOLEN " .. Catalog.DisplayName(occupant.Record) .. "! Run to your bay.")
		if bay.Owner then
			self.Network.Notice:FireClient(bay.Owner, player.DisplayName .. " stole from your bay! Lock [L] to protect it.")
			self.Economy:Send(bay.Owner)
		end
		self.Economy:Activity(player, "Steal", occupant.Record)
		self.Economy:Send(player)
	end)
end

return StealService
