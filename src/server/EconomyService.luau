-- Cash, purchases and income are computed exclusively on the server.
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("BrainrotTraits")).Format
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local EconomyService = {}
EconomyService.__index = EconomyService

function EconomyService.new(bases, network)
	local self = setmetatable({ Bases = bases, Network = network, Profiles = {}, IncomeMultiplier = 1,
		Activities = Instance.new("BindableEvent"), Events = {} }, EconomyService)
	bases.Economy = self
	network.RequestSnapshot.OnServerInvoke = function(player) return self:Snapshot(player) end
	task.spawn(function()
		while true do
			task.wait(Config.IncomeInterval)
			for player, profile in pairs(self.Profiles) do
				local income, pops = self:Income(player, true)
				if not profile.Demo then profile.Cash = math.min(Config.MaxCash, profile.Cash + income) end
				if income > 0 then network.CashPop:FireClient(player, pops) end
				self:Send(player)
			end
		end
	end)
	return self
end

function EconomyService:AddPlayer(player)
	self.Profiles[player] = { Cash = Config.StartingCash, Rebirths = 0, Multiplier = 1,
		Upgrades = {}, IndexMilestone = 0 }
	self:Send(player)
end

function EconomyService:Income(player, showPops)
	local state = self.Bases.Players[player]
	local profile = self.Profiles[player]
	if not state or not profile or state.Loading then return 0 end
	local income = 0
	local pops = showPops and {} or nil
	local boost = 1 + (profile.Upgrades.IncomeBoost or 0) * Config.Upgrades.IncomeBoost.Step
	local multiplier = profile.Multiplier * self.IncomeMultiplier * boost
	for _, pedestal in ipairs(state.Bay.Slots) do
		local occupant = pedestal.Occupant
		if occupant then
			local previous = math.floor(income * multiplier)
			income += Catalog.Income(occupant.Record)
			if pops then
				local position = occupant.Model:GetPivot().Position
				table.insert(pops, { Position = position + Vector3.new(1.5, 2.4, 0),
					Amount = math.floor(income * multiplier) - previous })
			end
		end
	end
	return math.floor(income * multiplier), pops
end

function EconomyService:Purchase(player, record, position)
	local profile = self.Profiles[player]
	if not profile or not self.Bases:Near(player, position) then return false end
	if not self.Bases:CanCarry(player) then
		self.Network.Notice:FireClient(player, "Dock your cargo first, and keep an empty pedestal.")
		return false
	end
	local price = Catalog.Price(record)
	if profile.Cash < price then
		self.Network.Notice:FireClient(player, "Not enough cash for this cargo. Start with a Common!")
		return false
	end
	if not self.Bases:Carry(player, record) then return false end
	profile.Cash -= price
	self.Network.Notice:FireClient(player, "BOUGHT " .. Catalog.DisplayName(record) .. " · DOCK AT HOME")
	self:Activity(player, "Buy", record)
	self:Send(player)
	return true
end

function EconomyService:ClaimIndexMilestones(player)
	local profile = self.Profiles[player]
	local state = self.Bases.Players[player]
	if not profile or profile.Demo or not state or state.Loading then return end
	local found = 0
	for _, known in pairs(state.Found) do if known then found += 1 end end
	for index = profile.IndexMilestone + 1, #Config.IndexMilestones do
		local milestone = Config.IndexMilestones[index]
		if found < milestone.Goal then break end
		profile.IndexMilestone = index
		profile.Cash = math.min(Config.MaxCash, profile.Cash + milestone.Reward)
		self.Network.Notice:FireClient(player, "INDEX " .. milestone.Goal .. " FOUND · +" .. Format.Money(milestone.Reward))
	end
end

function EconomyService:Activity(player, kind, record)
	self.Activities:Fire(player, kind, record)
end

function EconomyService:PublishEvent(event)
	self.Events[event.Name] = event
	self.Network.Event:FireAllClients(event)
end

function EconomyService:Snapshot(player)
	local profile = self.Profiles[player]
	local state = self.Bases.Players[player]
	if not profile or not state or state.Loading then return { Ready = false } end
	local inventory = {}
	for _, pedestal in ipairs(state.Bay.Slots) do
		if pedestal.Occupant then table.insert(inventory, pedestal.Occupant.Record) end
	end
	return { Ready = true, Cash = profile.Cash, Income = self:Income(player),
		Rebirths = profile.Rebirths, Multiplier = profile.Multiplier, Upgrades = profile.Upgrades,
		SaveStatus = profile.SaveStatus or "SESSION ONLY",
		BayIndex = state.Bay.Index, BayPosition = state.Bay.SpawnFrame.Position,
		Slots = #state.Bay.Slots, Inventory = inventory, Found = state.Found,
		IndexMilestone = profile.IndexMilestone,
		LockUntil = state.LockUntil or 0, LockReadyAt = state.LockReadyAt or 0,
		ZapReadyAt = state.ZapReadyAt or 0,
		Carrying = state.Carry and { Name = Catalog.DisplayName(state.Carry.Record),
			Id = state.Carry.Record.Id, Mutation = state.Carry.Record.Mutation } or false,
		Catalog = Catalog.Public(), Events = self.Events,
		NextMeteorAt = not profile.Demo and self.NextMeteorAt or nil,
		Contracts = self.Contracts and self.Contracts:View(player) or {} }
end

function EconomyService:Send(player)
	if player.Parent then self.Network.Snapshot:FireClient(player, self:Snapshot(player)) end
end

return EconomyService
