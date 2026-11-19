local shared = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Config = require(shared:WaitForChild("Config"))
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local BrainrotModel = require(script.Parent:WaitForChild("BrainrotModel"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseService = {}
BaseService.__index = BaseService

function BaseService.new(world, network)
	local self = setmetatable({ World = world, Network = network, Players = {} }, BaseService)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then return end
		elapsed = 0
		for player, state in pairs(self.Players) do
			local carry = state.Carry
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if carry and root then
				carry.Model:PivotTo(root.CFrame * CFrame.new(0, Config.CarryHeight, 0))
			end
		end
	end)
	return self
end

function BaseService:Near(player, position, distance)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0
		and (root.Position - position).Magnitude <= (distance or Config.InteractionDistance)
end

function BaseService:SetSpeed(player)
	local state = self.Players[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local profile = self.Economy and self.Economy.Profiles[player]
		local upgrades = profile and profile.Upgrades or {}
		humanoid.WalkSpeed = state and state.Carry
			and (Config.BaseCarrySpeed + (upgrades.CarrySpeed or 0) * Config.Upgrades.CarrySpeed.Step)
			or (Config.BaseWalkSpeed + (upgrades.WalkSpeed or 0) * Config.Upgrades.WalkSpeed.Step)
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.JumpPower
	end
end

function BaseService:Assign(player)
	if self.Players[player] then return self.Players[player] end
	local bay
	for _, candidate in ipairs(self.World.PlayerBays) do
		if not candidate.Owner then bay = candidate; break end
	end
	if not bay then
		self.Network.Notice:FireClient(player, "All six docks are occupied. Join a quieter server.")
		return nil
	end
	bay.Owner = player
	bay.Model:SetAttribute("OwnerUserId", player.UserId)
	bay.Label.Text = string.upper(player.DisplayName) .. " · BAY " .. string.format("%02d", bay.Index)
	local state = { Bay = bay, Carry = nil, Found = {} }
	self.Players[player] = state
	for _, pedestal in ipairs(bay.Slots) do
		self:AttachPlacePrompt(bay, pedestal)
	end
	local function characterAdded(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not root or not humanoid or self.Players[player] ~= state then return end
		character:PivotTo(bay.SpawnFrame)
		self:SetSpeed(player)
		humanoid.Died:Connect(function() self:Drop(player) end)
	end
	state.CharacterConnection = player.CharacterAdded:Connect(characterAdded)
	if player.Character then task.spawn(characterAdded, player.Character) end
	return state
end

function BaseService:AttachPlacePrompt(bay, pedestal)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlaceBrainrot"
	prompt.ActionText = "Dock brainrot"
	prompt.ObjectText = "Your empty pedestal"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = Config.InteractionDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = pedestal.Occupant == nil
	prompt.Parent = pedestal.Pad
	pedestal.PlacePrompt = prompt
	prompt.Triggered:Connect(function(visitor)
		if visitor == bay.Owner then self:Place(visitor, pedestal) end
	end)
end

function BaseService:AddSlot(player)
	local state = self.Players[player]
	if not state or #state.Bay.Slots >= Config.World.MaxSlots then return false end
	local pedestal = WorldBuilder.CreatePedestal(state.Bay, #state.Bay.Slots + 1)
	self:AttachPlacePrompt(state.Bay, pedestal)
	return true
end

function BaseService:FreeSlot(player)
	local state = self.Players[player]
	if state then
		for _, pedestal in ipairs(state.Bay.Slots) do
			if not pedestal.Occupant then return pedestal end
		end
	end
	return nil
end

function BaseService:CanCarry(player)
	local state = self.Players[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return state and not state.Carry and root and self:Near(player, root.Position)
		and self:FreeSlot(player) ~= nil
end

function BaseService:Carry(player, record)
	if not self:CanCarry(player) then return false end
	local state = self.Players[player]
	local root = player.Character.HumanoidRootPart
	record.Guid = record.Guid or HttpService:GenerateGUID(false)
	local model = BrainrotModel.Create(record, root.CFrame * CFrame.new(0, Config.CarryHeight, 0), self.World.Cargo)
	model:SetAttribute("VisualState", "Carrying")
	local first = Instance.new("Attachment")
	first.Position = Vector3.new(-0.7, 0.3, 0)
	first.Parent = model.PrimaryPart
	local second = Instance.new("Attachment")
	second.Position = Vector3.new(0.7, 0.3, 0)
	second.Parent = model.PrimaryPart
	local trail = Instance.new("Trail")
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Color = ColorSequence.new(Config.Palette.Mint)
	trail.Lifetime = Config.CarryTrailLifetime
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = model.PrimaryPart
	state.Carry = { Record = record, Model = model }
	self:SetSpeed(player)
	if self.Economy then self.Economy:Send(player) end
	return true
end

function BaseService:Place(player, pedestal)
	local state = self.Players[player]
	if not state or not state.Carry or pedestal.Occupant
		or state.Bay.Slots[pedestal.Index] ~= pedestal
		or not self:Near(player, pedestal.Pad.Position) then return false end
	local record = state.Carry.Record
	state.Carry.Model:Destroy()
	state.Carry = nil
	pedestal.Occupant = { Record = record, Model = BrainrotModel.Create(record, pedestal.Frame, state.Bay.Model) }
	pedestal.Label.Visible = false
	pedestal.PlacePrompt.Enabled = false
	state.Found[tostring(record.Id)] = true
	if self.OnPlaced then self.OnPlaced(state.Bay, pedestal) end
	self:SetSpeed(player)
	self.Network.Notice:FireClient(player, Catalog.DisplayName(record) .. " docked! Earning every second.")
	if self.Economy then self.Economy:Activity(player, "Dock", record) end
	if self.Economy then self.Economy:Send(player) end
	return true
end

function BaseService:Drop(player)
	local state = self.Players[player]
	if not state or not state.Carry then return end
	local carry = state.Carry
	state.Carry = nil
	local position = carry.Model:GetPivot().Position
	carry.Model:Destroy()
	self:SetSpeed(player)
	self:SpawnDrop(carry.Record, position)
	if self.Economy then self.Economy:Send(player) end
end

function BaseService:SpawnDrop(record, position)
	if position.Y > -10 then
		local dropped = BrainrotModel.Create(record, CFrame.new(position.X, 1, position.Z), self.World.Cargo)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Recover cargo"
		prompt.ObjectText = Catalog.DisplayName(record)
		prompt.MaxActivationDistance = Config.InteractionDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = dropped.PrimaryPart
		prompt.Triggered:Connect(function(visitor)
			if dropped.Parent and self:Near(visitor, dropped.PrimaryPart.Position)
				and self:Carry(visitor, record) then dropped:Destroy() end
		end)
		Debris:AddItem(dropped, Config.DropLifetime)
		return dropped
	end
end

function BaseService:Reset(player)
	local state = self.Players[player]
	if not state then return end
	if state.Carry then state.Carry.Model:Destroy(); state.Carry = nil end
	for index = #state.Bay.Slots, 1, -1 do
		local pedestal = state.Bay.Slots[index]
		if pedestal.Occupant then pedestal.Occupant.Model:Destroy() end
		pedestal.Occupant = nil
		if index > Config.World.InitialSlots then
			pedestal.Pad:Destroy()
			local ring = state.Bay.Model:FindFirstChild("SocketGlow_" .. index)
			if ring then ring:Destroy() end
			state.Bay.Slots[index] = nil
		else
			pedestal.Label.Visible = true
			pedestal.PlacePrompt.Enabled = true
		end
	end
	state.LockUntil = 0
	state.LockReadyAt = 0
	state.Bay.Model:SetAttribute("LockedUntil", 0)
	local shield = state.Bay.Model:FindFirstChild("BayLockShield")
	if shield then shield:Destroy() end
	self:SetSpeed(player)
end

function BaseService:Release(player)
	local state = self.Players[player]
	if not state then return end
	if state.Carry then state.Carry.Model:Destroy() end
	state.CharacterConnection:Disconnect()
	for _, pedestal in ipairs(state.Bay.Slots) do
		if pedestal.Occupant then pedestal.Occupant.Model:Destroy() end
		pedestal.Occupant = nil
		pedestal.Label.Visible = true
		pedestal.PlacePrompt:Destroy()
		pedestal.PlacePrompt = nil
	end
	state.Bay.Owner = nil
	state.Bay.Model:SetAttribute("LockedUntil", 0)
	local shield = state.Bay.Model:FindFirstChild("BayLockShield")
	if shield then shield:Destroy() end
	state.Bay.Model:SetAttribute("OwnerUserId", 0)
	state.Bay.Label.Text = state.Bay.CrewName
	self.Players[player] = nil
end

function BaseService:SeedRivals()
	local lineup = { 1, 4, 7, 8, 11, 13, 15, 18 }
	for crewIndex, bay in ipairs(self.World.RivalBays) do
		for index, pedestal in ipairs(bay.Slots) do
			if not pedestal.Occupant then
				local record = { Id = lineup[index] + crewIndex - 1,
					Guid = "rival_" .. crewIndex .. "_" .. index }
				if crewIndex == 2 and index == 8 then record.Mutation = "Gold" end
				if crewIndex == 3 and index == 6 then record.Mutation = "Diamond" end
				pedestal.Occupant = { Record = record,
					Model = BrainrotModel.Create(record, pedestal.Frame, bay.Model) }
				pedestal.Label.Visible = false
			end
		end
	end
end

return BaseService
