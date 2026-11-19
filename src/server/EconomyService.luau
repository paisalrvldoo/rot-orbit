-- Cash, purchases and income are computed exclusively on the server.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
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
				local income = self:Income(player)
				if not profile.Demo then profile.Cash = math.min(Config.MaxCash, profile.Cash + income) end
				local state = bases.Players[player]
				if income > 0 and state then
					network.CashPop:FireClient(player, state.Bay.Frame.Position + Vector3.new(0, 6, 0), income)
				end
				self:Send(player)
			end
		end
	end)
	return self
end

function EconomyService:AddPlayer(player)
	self.Profiles[player] = { Cash = Config.StartingCash, Rebirths = 0, Multiplier = 1, Upgrades = {} }
	self:Send(player)
end

function EconomyService:Income(player)
	local state = self.Bases.Players[player]
	local profile = self.Profiles[player]
	if not state or not profile or state.Loading then return 0 end
	local income = 0
	for _, pedestal in ipairs(state.Bay.Slots) do
		if pedestal.Occupant then income += Catalog.Income(pedestal.Occupant.Record) end
	end
	return math.floor(income * profile.Multiplier * self.IncomeMultiplier)
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
	self:Activity(player, "Buy", record)
	self:Send(player)
	return true
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
		LockUntil = state.LockUntil or 0, LockReadyAt = state.LockReadyAt or 0,
		ZapReadyAt = state.ZapReadyAt or 0,
		Carrying = state.Carry and { Name = Catalog.DisplayName(state.Carry.Record),
			Id = state.Carry.Record.Id, Mutation = state.Carry.Record.Mutation } or false,
		Catalog = Catalog.Public(), Events = self.Events,
		Contracts = self.Contracts and self.Contracts:View(player) or {} }
end

function EconomyService:Send(player)
	if player.Parent then self.Network.Snapshot:FireClient(player, self:Snapshot(player)) end
end

return EconomyService
