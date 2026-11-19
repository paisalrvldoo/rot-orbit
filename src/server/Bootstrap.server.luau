-- ROT ORBIT server bootstrap. Services share this one runtime world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local StealService = require(script.Parent:WaitForChild("StealService"))
local MeteorSolarEvents = require(script.Parent:WaitForChild("MeteorSolarEvents"))
local LockService = require(script.Parent:WaitForChild("LockService"))
local GremlinRaid = require(script.Parent:WaitForChild("GremlinRaid"))
local CrewService = require(script.Parent:WaitForChild("CrewService"))
local UpgradeRebirthService = require(script.Parent:WaitForChild("UpgradeRebirthService"))
local ContractService = require(script.Parent:WaitForChild("ContractService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ScreenshotService = require(script.Parent:WaitForChild("ScreenshotService"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Players = game:GetService("Players")

local network = Remotes.Get()
local world = WorldBuilder.Build()
local bases = BaseService.new(world, network)
bases:SeedRivals()
local economy = EconomyService.new(bases, network)
local conveyor = ConveyorService.new(world, economy)
local stealing = StealService.new(bases, economy, network)
local meteors = MeteorSolarEvents.new(world, bases, economy)
local locks = LockService.new(bases, economy)
local gremlins = GremlinRaid.new(world, bases, economy, locks)
local crews = CrewService.new(world, bases, economy, gremlins)
local upgrades = UpgradeRebirthService.new(bases, economy)
local contracts = ContractService.new(economy)
local data = DataService.new(bases, economy)
local screenshots = ScreenshotService.new({ Bases = bases, Economy = economy, Data = data,
	Meteors = meteors, Gremlins = gremlins, Conveyor = conveyor })
local actions = { Lock = function(player) locks:Activate(player) end,
	Zap = function(player) gremlins:Zap(player) end,
	Skill = function(player, name) gremlins:Skill(player, name) end,
	Crew = function(player, id) crews:Join(player, id) end,
	Upgrade = function(player, name) upgrades:Buy(player, name) end,
	Rebirth = function(player) upgrades:Perform(player) end,
	Screenshot = function(player, shot) screenshots:Prepare(player, shot) end }
local lastAction = {}
network.Action.OnServerEvent:Connect(function(player, action, argument)
	if type(action) ~= "string" or not actions[action] then return end
	if not bases.Players[player] or bases.Players[player].Loading or bases.Players[player].Closing then return end
	local profile = economy.Profiles[player]
	if action ~= "Screenshot" and ((profile and profile.Demo)
		or world.Root:GetAttribute("ScreenshotFrozen")) then return end
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
		if bases.Players[player] == state and not state.Loading then
			gremlins.NextRaidAt = math.min(gremlins.NextRaidAt, workspace:GetServerTimeNow() + Config.Gremlin.FirstRaid)
		end
	end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	data:Close(player)
	crews:Remove(player)
	bases:Release(player)
	economy.Profiles[player] = nil
	lastAction[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(joined, player) end

print("ROT ORBIT station ready:", world.Root:GetFullName(), network.Snapshot.Name)
