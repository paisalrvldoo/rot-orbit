-- ROT ORBIT server bootstrap. Services share this one runtime world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local Players = game:GetService("Players")

local network = Remotes.Get()
local world = WorldBuilder.Build()
local bases = BaseService.new(world, network)
bases:SeedRivals()
local economy = EconomyService.new(bases, network)

local function joined(player)
	if bases:Assign(player) then economy:AddPlayer(player) end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	bases:Release(player)
	economy.Profiles[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do joined(player) end

print("ROT ORBIT station ready:", world.Root:GetFullName(), network.Snapshot.Name)
