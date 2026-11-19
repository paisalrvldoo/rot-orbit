local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ScreenshotMode = require(game:GetService("ReplicatedStorage"):WaitForChild("ScreenshotMode"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local ScreenshotService = {}
ScreenshotService.__index = ScreenshotService
local valid = { Cover = true, Index = true, Raid = true, Upgrades = true }

function ScreenshotService.new(context)
	local self = setmetatable(context, ScreenshotService)
	ScreenshotMode.Configure(function(shot, playerId)
		local player = type(playerId) == "number" and Players:GetPlayerByUserId(playerId) or nil
		return self:Prepare(player or Players:GetPlayers()[1], shot)
	end)
	return self
end

function ScreenshotService:Prepare(player, shot)
	if not RunService:IsStudio() or not player or not valid[shot] then return false end
	local state = self.Bases.Players[player]
	local profile = self.Economy.Profiles[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not state or state.Loading or not profile or not root then return false end
	if not profile.Demo then
		self.Data:Save(player, true)
		local session = self.Data.Sessions[player]
		if session then session.CanSave = false end
		profile.Demo = true
	end
	local world = self.Bases.World
	world.Root:SetAttribute("ScreenshotFrozen", true)
	self.Meteors.Active = false
	self.Meteors.Effects:ClearAllChildren()
	for _, gremlin in pairs(self.Gremlins.Gremlins) do self.Gremlins:Remove(gremlin, false) end
	self.Economy.Events = {}
	self.Economy.IncomeMultiplier = 1
	profile.Upgrades = { WalkSpeed = 2, CarrySpeed = 3, LockDuration = 2, BaySlots = 1 }
	self.Bases:Reset(player)
	self.Bases:AddSlot(player)
	self.Bases:AddSlot(player)
	profile.Cash = 12345678
	profile.Rebirths = 3
	profile.Multiplier = 3
	profile.SaveStatus = "STUDIO PREVIEW"
	profile.Contracts = { { Stage = 2, Progress = 3 }, { Stage = 2, Progress = 4 }, { Stage = 3, Progress = 0 } }
	local lineup = { 18, 23, 27, 30, 11, 22, 28, 29, 13 }
	local mutations = { "Gold", "Diamond", "Neon", "Supernova", "Diamond", "Gold", "Zero-G", "Neon", "Gold" }
	for index, id in ipairs(lineup) do
		self.Bases:Restore(player, { Id = id, Mutation = mutations[index], Guid = HttpService:GenerateGUID(false) }, index)
		local pedestal = state.Bay.Slots[index]
		local frame = pedestal.Frame * CFrame.Angles(0, math.pi, 0)
		pedestal.Occupant.Model:SetAttribute("RestFrame", frame)
		pedestal.Occupant.Model:PivotTo(frame)
		pedestal.Occupant.Model.PrimaryPart:FindFirstChild("BrainrotBillboard").Enabled = index <= 4 or index == 6
	end
	state.Found = {}
	for id = 1, 16 do state.Found[tostring(id)] = true end
	for _, id in ipairs({ 18, 22, 23, 27, 28, 29, 30 }) do state.Found[tostring(id)] = true end
	root.Anchored = true
	root.CFrame = state.Bay.Frame * CFrame.new(9, 3.8, -6) * CFrame.Angles(0, math.pi, 0)
	self.Bases:Carry(player, { Id = 11, Mutation = "Diamond", Guid = HttpService:GenerateGUID(false) })
	for capsule in pairs(self.Conveyor.Capsules) do self.Conveyor.Capsules[capsule] = nil; capsule:Destroy() end
	for index, id in ipairs({ 7, 11, 13, 18, 23, 27 }) do
		self.Conveyor:Spawn({ Id = id, Mutation = index % 2 == 0 and "Gold" or nil }, index * math.pi / 3)
	end
	if shot == "Cover" then
		self.Economy:PublishEvent({ Name = "Meteor", Text = "METEOR SHOWER! GET UNDER THE SHIELD DOME",
			EndsAt = workspace:GetServerTimeNow() + 60, FrozenSeconds = 18, Priority = 3 })
		WorldBuilder.Ring("PreviewWarning", 9, 0.32, 0.15, state.Bay.Frame * CFrame.new(19, 0.15, -18),
			Color3.fromRGB(255, 192, 79), Enum.Material.Neon, self.Meteors.Effects, 28, false)
		WorldBuilder.Part("PreviewMeteor", Vector3.one * 3.5, state.Bay.Frame * CFrame.new(20, 27, -26),
			Color3.fromRGB(255, 126, 54), Enum.Material.Neon, self.Meteors.Effects, Enum.PartType.Ball, false)
	elseif shot == "Raid" then
		self.Economy:PublishEvent({ Name = "Gremlin", Text = "GREMLIN RAID! LOCK [L] OR ZAP [F]",
			EndsAt = workspace:GetServerTimeNow() + 60, FrozenSeconds = 27, Priority = 2,
			Color = Color3.fromRGB(155, 255, 105) })
		for _, offset in ipairs({ Vector3.new(-7, 1, 5), Vector3.new(5, 1, 11) }) do
			self.Gremlins:Grab(self.Gremlins:Spawn(state.Bay, (state.Bay.Frame * CFrame.new(offset)).Position))
		end
	end
	self.Economy:Send(player)
	local cameraPosition = (state.Bay.Frame * CFrame.new(12, 18, 38)).Position
	local target = (state.Bay.Frame * CFrame.new(0, 6, 2)).Position
	self.Economy.Network.Screenshot:FireClient(player, { Shot = shot,
		Camera = CFrame.lookAt(cameraPosition, target), FieldOfView = 64 })
	return true
end

return ScreenshotService
