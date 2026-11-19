local shared = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Config = require(shared:WaitForChild("Config"))
local Rarity = require(shared:WaitForChild("BrainrotTraits")).Rarity
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
				local zeroG = carry.Record.Mutation == "Zero-G"
				carry.Model:PivotTo(root.CFrame * CFrame.new(0, Config.CarryHeight + (zeroG and 0.8 or 0), 0)
					* CFrame.Angles(0, zeroG and workspace:GetServerTimeNow() * 0.6 or 0, 0))
			end
		end
	end)
	return self
end

function BaseService:Near(player, position, distance)
	local state = self.Players[player]
	if state and state.Closing then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0
		and (root.Position - position).Magnitude <= (distance or Config.InteractionDistance)
end

function BaseService:IsBayReady(bay)
	if not bay.Owner then return true end
	local state = self.Players[bay.Owner]
	return state ~= nil and not state.Loading and not state.Closing
end

function BaseService:SetSpeed(player)
	local state = self.Players[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local profile = self.Economy and self.Economy.Profiles[player]
		local upgrades = profile and profile.Upgrades or {}
		local speed = state and state.Carry
			and (Config.BaseCarrySpeed + (upgrades.CarrySpeed or 0) * Config.Upgrades.CarrySpeed.Step)
			or (Config.BaseWalkSpeed + (upgrades.WalkSpeed or 0) * Config.Upgrades.WalkSpeed.Step)
		if state and state.SprintUntil and state.SprintUntil > workspace:GetServerTimeNow() then
			speed *= state.Carry and Config.Skills.Sprint.CarrySpeed or Config.Skills.Sprint.Speed
		end
		local stunned = state and state.StunnedUntil and state.StunnedUntil > workspace:GetServerTimeNow()
		if stunned then speed = 0 end
		humanoid.WalkSpeed = speed
		humanoid.UseJumpPower = true
		humanoid.JumpPower = stunned and 0 or Config.JumpPower
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
	local state = { Bay = bay, Carry = nil, Found = {}, Variants = {} }
	self.Players[player] = state
	for _, pedestal in ipairs(bay.Slots) do
		self:AttachPlacePrompt(bay, pedestal)
	end
	local function characterAdded(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not root or not humanoid or self.Players[player] ~= state then return end
		state.SprintUntil = nil
		state.StunnedUntil = nil
		local destination = state.HasSpawned and state.Bay.SpawnFrame
			or self.World.Spawn.CFrame * CFrame.new(0, 4, 0)
		state.HasSpawned = true
		character:PivotTo(destination)
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
	prompt:SetAttribute("OwnerUserId", bay.Owner.UserId)
	prompt:SetAttribute("SocketOpen", pedestal.Occupant == nil)
	CollectionService:AddTag(prompt, "OrbitDockPrompt")
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

function BaseService:HighestDockRank(player)
	local state = self.Players[player]
	local highest = 0
	if state then
		for _, pedestal in ipairs(state.Bay.Slots) do
			if pedestal.Occupant then
				local entry = Catalog.Get(pedestal.Occupant.Record.Id)
				highest = math.max(highest, Rarity.ByName[entry.Rarity].Rank)
			end
		end
	end
	return highest
end

function BaseService:BestDocked(player)
	local state = self.Players[player]
	local best, income = nil, -1
	if state then
		for _, pedestal in ipairs(state.Bay.Slots) do
			local record = pedestal.Occupant and pedestal.Occupant.Record
			if record and Catalog.Income(record) > income then
				best, income = record, Catalog.Income(record)
			end
		end
	end
	-- Keep the stable identity and mutation without retaining the destroyed model.
	return best and table.clone(best) or nil
end

function BaseService:CanCarry(player)
	local state = self.Players[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return state and not state.Loading and not state.Carry and root and self:Near(player, root.Position)
		and self:FreeSlot(player) ~= nil
end

function BaseService:RefreshPedestal(pedestal)
	local occupant = pedestal.Occupant
	local rarity = occupant and Rarity.ByName[Catalog.Get(occupant.Record.Id).Rarity]
	pedestal.Label.Visible = occupant == nil
	if pedestal.PlacePrompt then pedestal.PlacePrompt:SetAttribute("SocketOpen", occupant == nil) end
	WorldBuilder.ColorSocket(pedestal.Socket, rarity and rarity.Color or pedestal.EmptyColor)
end

function BaseService:ClearPedestal(pedestal)
	pedestal.Occupant.Model:Destroy()
	pedestal.Occupant = nil
	self:RefreshPedestal(pedestal)
end

function BaseService:AttachRetirePrompt(player, pedestal)
	local occupant = pedestal.Occupant
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RetireCargo"
	prompt.ActionText = "Retire · frees slot"
	prompt.ObjectText = Catalog.DisplayName(occupant.Record)
	prompt.KeyboardKeyCode = Enum.KeyCode.H
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.HoldDuration = Config.RetireHoldDuration
	prompt.MaxActivationDistance = Config.InteractionDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(prompt, "OrbitRetirePrompt")
	prompt.Parent = occupant.Model.PrimaryPart
	prompt.Triggered:Connect(function(visitor)
		local state = self.Players[visitor]
		if visitor ~= player or not state or state.Loading or state.Bay.Owner ~= visitor
			or state.Bay.Slots[pedestal.Index] ~= pedestal or pedestal.Occupant ~= occupant
			or not self:Near(visitor, pedestal.Pad.Position) then return end
		self:ClearPedestal(pedestal)
		self.Network.Notice:FireClient(visitor, "RETIRED " .. Catalog.DisplayName(occupant.Record) .. " · SLOT OPEN")
		self.Economy:Send(visitor)
	end)
end

function BaseService:Carry(player, record, stolen)
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
	state.Carry = { Record = record, Model = model, Stolen = stolen == true }
	self:SetSpeed(player)
	if self.Economy then self.Economy:Send(player) end
	return true
end

function BaseService:Discover(state, record)
	local id = tostring(record.Id)
	local discovered = not state.Found[id]
	state.Found[id] = true
	if record.Mutation then
		local variants = state.Variants[record.Mutation] or {}
		state.Variants[record.Mutation] = variants
		local newVariant = not variants[id]
		variants[id] = true
		return discovered, newVariant
	end
	return discovered, false
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
	pedestal.Occupant.Model:SetAttribute("DockedAt", workspace:GetServerTimeNow())
	self:RefreshPedestal(pedestal)
	self:AttachRetirePrompt(player, pedestal)
	local discovered, newVariant = self:Discover(state, record)
	if self.OnPlaced then self.OnPlaced(state.Bay, pedestal) end
	self:SetSpeed(player)
	self.Network.Notice:FireClient(player, Catalog.DisplayName(record) .. " docked! Earning every second.")
	if discovered then self.Network.Notice:FireClient(player, "INDEX DISCOVERY · " .. Catalog.Get(record.Id).Name) end
	if newVariant then self.Network.Notice:FireClient(player, "MUTATION DISCOVERY · " .. Catalog.DisplayName(record)) end
	if self.Economy then
		if discovered or newVariant then self.Economy:ClaimIndexMilestones(player) end
		self.Economy:Activity(player, "Dock", record)
		self.Economy:Send(player)
	end
	return true
end

function BaseService:Drop(player)
	local state = self.Players[player]
	if not state or state.Closing or not state.Carry then return end
	local carry = state.Carry
	state.Carry = nil
	local position = carry.Model:GetPivot().Position
	carry.Model:Destroy()
	self:SetSpeed(player)
	local dropped = self:SpawnDrop(carry.Record, position)
	if self.Economy then self.Economy:Send(player) end
	return dropped
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
		if not self.World.Root:GetAttribute("ScreenshotFrozen") then
			Debris:AddItem(dropped, Config.DropLifetime)
		end
		return dropped
	end
end

function BaseService:Reset(player)
	local state = self.Players[player]
	if not state then return end
	if state.Carry then state.Carry.Model:Destroy(); state.Carry = nil end
	for index = #state.Bay.Slots, 1, -1 do
		local pedestal = state.Bay.Slots[index]
		if pedestal.Occupant then self:ClearPedestal(pedestal) end
		if index > Config.World.InitialSlots then
			pedestal.Pad:Destroy()
			pedestal.Socket:Destroy()
			state.Bay.Slots[index] = nil
		end
	end
	state.LockUntil = 0
	state.LockReadyAt = 0
	state.Bay.Model:SetAttribute("LockedUntil", 0)
	for _, shield in ipairs(state.Bay.Model:GetChildren()) do
		if shield.Name == "BayLockShield" or shield.Name == "SkillBayBubble" then shield:Destroy() end
	end
	self:SetSpeed(player)
end

function BaseService:Restore(player, record, slotIndex)
	local state = self.Players[player]
	if not state then return false end
	local pedestal = state.Bay.Slots[slotIndex]
	if not pedestal or pedestal.Occupant then pedestal = self:FreeSlot(player) end
	if not pedestal then return false end
	pedestal.Occupant = { Record = record,
		Model = BrainrotModel.Create(record, pedestal.Frame, state.Bay.Model) }
	self:RefreshPedestal(pedestal)
	self:AttachRetirePrompt(player, pedestal)
	self:Discover(state, record)
	if self.OnPlaced then self.OnPlaced(state.Bay, pedestal) end
	return true
end

function BaseService:Release(player)
	local state = self.Players[player]
	if not state then return end
	self:Reset(player)
	state.CharacterConnection:Disconnect()
	for _, pedestal in ipairs(state.Bay.Slots) do
		pedestal.PlacePrompt:Destroy()
		pedestal.PlacePrompt = nil
	end
	state.Bay.Owner = nil
	state.Bay.Model:SetAttribute("LockedUntil", 0)
	for _, shield in ipairs(state.Bay.Model:GetChildren()) do
		if shield.Name == "BayLockShield" or shield.Name == "SkillBayBubble" then shield:Destroy() end
	end
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
					Guid = HttpService:GenerateGUID(false) }
				if crewIndex == 2 and index == 8 then record.Mutation = "Gold" end
				if crewIndex == 3 and index == 6 then record.Mutation = "Diamond" end
				pedestal.Occupant = { Record = record,
					Model = BrainrotModel.Create(record, pedestal.Frame, bay.Model) }
				self:RefreshPedestal(pedestal)
			end
		end
	end
end

return BaseService
