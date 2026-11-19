-- ROT ORBIT server bootstrap. Services share this one runtime world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local network = Remotes.Get()
local world = WorldBuilder.Build()
local bases = BaseService.new(world, network)
bases:SeedRivals()

print("ROT ORBIT station ready:", world.Root:GetFullName(), network.Snapshot.Name)
