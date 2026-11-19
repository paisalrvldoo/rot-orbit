-- ROT ORBIT server bootstrap. Services share this one runtime world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local StealService = require(script.Parent:WaitForChild("StealService"))
local MeteorEvent = require(script.Parent:WaitForChild("MeteorEvent"))
local LockService = require(script.Parent:WaitForChild("LockService"))
local GremlinRaid = require(script.Parent:WaitForChild("GremlinRaid"))
local SolarFlareEvent = require(script.Parent:WaitForChild("SolarFlareEvent"))
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
local RebirthService = require(script.Parent:WaitForChild("RebirthService"))
local ContractService = require(script.Parent:WaitForChild("ContractService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Players = game:GetService("Players")

local network = Remotes.Get()
local world = WorldBuilder.Build()
local bases = BaseService.new(world, network)
bases:SeedRivals()
local economy = EconomyService.new(bases, network)
local conveyor = ConveyorService.new(world, economy)
local stealing = StealService.new(bases, economy, network)
local meteors = MeteorEvent.new(world, bases, economy)
local locks = LockService.new(bases, economy)
local gremlins = GremlinRaid.new(world, bases, economy, locks)
local solarFlare = SolarFlareEvent.new(world, economy)
local upgrades = UpgradeService.new(bases, economy)
local rebirth = RebirthService.new(bases, economy)
local contracts = ContractService.new(economy)
local data = DataService.new(bases, economy)
local actions = { Lock = function(player) locks:Activate(player) end,
	Zap = function(player) gremlins:Zap(player) end,
	Upgrade = function(player, name) upgrades:Buy(player, name) end,
	Rebirth = function(player) rebirth:Perform(player) end }
local lastAction = {}
network.Action.OnServerEvent:Connect(function(player, action, argument)
	if type(action) ~= "string" or not actions[action] then return end
	if not bases.Players[player] or bases.Players[player].Loading then return end
	local now = workspace:GetServerTimeNow()
	if now - (lastAction[player] or 0) < Config.ActionCooldown then return end
	lastAction[player] = now
	actions[action](player, argument)
end)

local function joined(player)
	local state = bases:Assign(player)
	if state then
		state.Loading = true
		economy:AddPlayer(player)
		contracts:AddPlayer(player)
		data:Load(player)
	end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	data:Close(player)
	bases:Release(player)
	economy.Profiles[player] = nil
	lastAction[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(joined, player) end

print("ROT ORBIT station ready:", world.Root:GetFullName(), network.Snapshot.Name)
