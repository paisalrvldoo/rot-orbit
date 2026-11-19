-- Failed loads never overwrite saves. A renewable lease prevents concurrent servers saving the same profile.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Mutation = Traits.Mutation
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local DataService = {}
DataService.__index = DataService

local function integer(value, fallback, low, high)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), low, high)
end

function DataService.new(bases, economy)
	local self = setmetatable({ Bases = bases, Economy = economy, Sessions = {},
		Token = game.JobId .. HttpService:GenerateGUID(false) }, DataService)
	local ok, store = pcall(function() return DataStoreService:GetDataStore(Config.Data.StoreName) end)
	if ok then self.Store = store end
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for player in pairs(self.Sessions) do task.spawn(function() self:Save(player, false) end) end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(self.Sessions) do
			pending += 1
			task.spawn(function() self:Save(player, true); pending -= 1 end)
		end
		local deadline = os.clock() + 25
		while os.clock() < deadline do
			local busy = pending > 0
			for _, session in pairs(self.Sessions) do if session.Saving then busy = true end end
			if not busy then break end
			task.wait(0.1)
		end
	end)
	return self
end

function DataService:Load(player)
	local state = self.Bases.Players[player]
	local profile = self.Economy.Profiles[player]
	if not state or not profile then return end
	state.Loading = true
	local session = { Key = "player_" .. player.UserId, Profile = profile, CanSave = false }
	self.Sessions[player] = session
	local reason
	local offlineHaul = 0
	local ok, saved = pcall(function()
		if not self.Store then error("Progress store unavailable") end
		return self.Store:UpdateAsync(session.Key, function(previous)
			offlineHaul = 0
			previous = type(previous) == "table" and previous or { Version = Config.Data.Version }
			if type(previous.Version) == "number" and previous.Version > Config.Data.Version then
				reason = "Your progress needs a newer server. Please rejoin."
				return nil
			end
			local lease = previous.Session
			if type(lease) == "table" and lease.Token ~= self.Token
				and type(lease.ExpiresAt) == "number" and lease.ExpiresAt > os.time() then
				reason = "Your dock is still open in another server. Close it and rejoin shortly."
				return nil
			end
			local now = os.time()
			-- Consume the saved departure time and credit the haul in the same write.
			local lastSeen = integer(previous.LastSeen, now, 0, now)
			local away = math.min(now - lastSeen, Config.Data.OfflineMaxSeconds)
			if away >= Config.Data.OfflineMinSeconds then
				local rate = integer(previous.DockRate, 0, 0, Config.MaxCash)
				local cash = integer(previous.Cash, Config.StartingCash, 0, Config.MaxCash)
				offlineHaul = math.min(Config.MaxCash - cash, math.floor(rate * away * Config.Data.OfflineShare))
				previous.Cash = cash + offlineHaul
			end
			previous.LastSeen = nil
			previous.Session = { Token = self.Token, ExpiresAt = now + Config.Data.LeaseSeconds }
			return previous
		end)
	end)
	if self.Bases.Players[player] ~= state or not player.Parent then
		if ok and type(saved) == "table" then
			pcall(function()
				self.Store:UpdateAsync(session.Key, function(previous)
					if type(previous) == "table" and type(previous.Session) == "table"
						and previous.Session.Token == self.Token then previous.Session = nil; return previous end
					return nil
				end)
			end)
		end
		return
	end
	if ok and not saved and reason then player:Kick(reason); return end
	if ok and type(saved) == "table" then
		session.CanSave = true
		profile.Cash = integer(saved.Cash, Config.StartingCash, 0, Config.MaxCash)
		profile.OfflineHaul = offlineHaul > 0 and offlineHaul or nil
		profile.Rebirths = integer(saved.Rebirths, 0, 0, Config.Rebirth.MaxLevel)
		profile.Multiplier = Config.Rebirth.Multiplier(profile.Rebirths)
		profile.IndexMilestone = integer(saved.IndexMilestone, 0, 0, #Config.IndexMilestones)
		for name, config in pairs(Config.Upgrades) do
			profile.Upgrades[name] = integer(type(saved.Upgrades) == "table" and saved.Upgrades[name], 0, 0, config.MaxLevel)
		end
		for _ = 1, profile.Upgrades.BaySlots * Config.World.SlotsPerUpgrade do self.Bases:AddSlot(player) end
		for _, entry in ipairs(Catalog.Entries) do
			if type(saved.Found) == "table" and saved.Found[tostring(entry.Id)] == true then state.Found[tostring(entry.Id)] = true end
		end
		local guids = {}
		local inventory = type(saved.Inventory) == "table" and saved.Inventory or {}
		for index = 1, math.min(#inventory, Config.World.MaxSlots) do
			local record = inventory[index]
			if type(record) == "table" and Catalog.Get(record.Id) then
				local guid = type(record.Guid) == "string" and #record.Guid <= 64
					and record.Guid or HttpService:GenerateGUID(false)
				if not guids[guid] then
					guids[guid] = true
					self.Bases:Restore(player, { Id = record.Id, Guid = guid,
						Mutation = Mutation.Get(record.Mutation) and record.Mutation or nil },
						integer(record.Slot, 0, 0, Config.World.MaxSlots))
				end
			end
		end
		for index, progress in ipairs(profile.Contracts) do
			local loaded = type(saved.Contracts) == "table" and saved.Contracts[index]
			if type(loaded) == "table" then
				progress.Stage = integer(loaded.Stage, 1, 1, #Config.Contracts.Tracks[index])
				progress.Progress = integer(loaded.Progress, 0, 0, Config.Contracts.Tracks[index][progress.Stage].Goal - 1)
				progress.Completed = integer(loaded.Completed, progress.Stage - 1,
					progress.Stage - 1, #Config.Contracts.Tracks[index])
			end
		end
		profile.SaveStatus = "SAVED"
	else
		profile.SaveStatus = "SESSION ONLY"
		warn("ROT ORBIT saving unavailable; keeping this session playable without overwriting progress.")
	end
	state.Loading = false
	self.Bases:SetSpeed(player)
	self.Economy:ClaimIndexMilestones(player)
	self.Economy:Send(player)
end

function DataService:Serialize(player)
	local state = self.Bases.Players[player]
	local profile = self.Economy.Profiles[player]
	if not state or not profile or state.Loading then return nil end
	local inventory = {}
	local function add(record, slot)
		table.insert(inventory, { Id = record.Id, Mutation = record.Mutation, Guid = record.Guid, Slot = slot })
	end
	for _, pedestal in ipairs(state.Bay.Slots) do
		if pedestal.Occupant then add(pedestal.Occupant.Record, pedestal.Index) end
	end
	-- Cargo already purchased/stolen is owned; reconnecting safely docks it in a free slot.
	if state.Carry then add(state.Carry.Record, 0) end
	return { Version = Config.Data.Version, Cash = profile.Cash, Rebirths = profile.Rebirths,
		LastSeen = os.time(), DockRate = self.Economy:Income(player, false, true),
		Upgrades = table.clone(profile.Upgrades), Found = table.clone(state.Found), Inventory = inventory,
		IndexMilestone = profile.IndexMilestone,
		Contracts = { table.clone(profile.Contracts[1]), table.clone(profile.Contracts[2]), table.clone(profile.Contracts[3]) } }
end

function DataService:Write(session, payload, release)
	session.Saving = true
	local lostLease = false
	local ok = pcall(function()
		self.Store:UpdateAsync(session.Key, function(previous)
			if type(previous) ~= "table" or type(previous.Session) ~= "table"
				or previous.Session.Token ~= self.Token then lostLease = true; return nil end
			payload.Session = not release and { Token = self.Token, ExpiresAt = os.time() + Config.Data.LeaseSeconds } or nil
			return payload
		end)
	end)
	if lostLease then session.CanSave = false end
	session.Profile.SaveStatus = ok and not lostLease and "SAVED" or "SAVE RETRY"
	session.Saving = false
	if session.FinalPayload and not release then
		local final = session.FinalPayload
		session.FinalPayload = nil
		self:Write(session, final, true)
	end
end

function DataService:Save(player, release)
	local session = self.Sessions[player]
	if not session or not session.CanSave or session.Profile.Demo then return end
	local payload = self:Serialize(player)
	if not payload then return end
	if session.Saving then
		if release then session.FinalPayload = payload end
		return
	end
	self:Write(session, payload, release)
end

function DataService:Close(player)
	self:Save(player, true)
	self.Sessions[player] = nil
end

return DataService
