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
local actions = { Lock = function(player) locks:Activate(player) end }
local lastAction = {}
network.Action.OnServerEvent:Connect(function(player, action)
	if type(action) ~= "string" or not actions[action] then return end
	local now = workspace:GetServerTimeNow()
	if now - (lastAction[player] or 0) < Config.ActionCooldown then return end
	lastAction[player] = now
	actions[action](player)
end)

local function joined(player)
	if bases:Assign(player) then economy:AddPlayer(player) end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	bases:Release(player)
	economy.Profiles[player] = nil
	lastAction[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do joined(player) end

print("ROT ORBIT station ready:", world.Root:GetFullName(), network.Snapshot.Name)
