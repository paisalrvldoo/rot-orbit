local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local ScreenshotMode = require(shared:WaitForChild("ScreenshotMode"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local ScreenshotService = {}
ScreenshotService.__index = ScreenshotService
local valid = { Cover = true, Index = true, Raid = true, Upgrades = true }
local lineup = { 13, 38, 30, 40, 42, 22, 28, 29, 18 }
local mutations = { "Gold", "Diamond", "Supernova", "Neon", "Aurora", "Gold", "Zero-G", "Neon", "Gold" }

local function pose(pedestal, frame)
	local model = pedestal.Occupant.Model
	model:SetAttribute("RestFrame", frame)
	model:PivotTo(frame)
	return model.PrimaryPart.BrainrotBillboard
end

local function stageCover(state, root, meteors)
	local effects = meteors.Effects
	local platform = CFrame.new(0, 0.3, 12)
	local palette = Config.Palette
	WorldBuilder.Part("ShowcaseDock", Vector3.new(48, 0.6, 12), platform,
		palette.Deck, Enum.Material.SmoothPlastic, effects)
	for _, side in ipairs({ -1, 1 }) do
		WorldBuilder.Part("ShowcaseTrim", Vector3.new(48, 0.12, 0.24),
			platform * CFrame.new(0, 0.32, side * 5.8), palette.Teal, Enum.Material.Neon, effects, nil, false)
	end
	for index = 1, 5 do
		local column = index - 3
		local pedestal = state.Bay.Slots[index]
		local center = platform * CFrame.new(column * 9.7, 0.8, math.abs(column) * 0.85)
		local color = index == 3 and palette.Sun or palette.Mint
		WorldBuilder.Part("ShowcasePedestal", Vector3.new(1, 6.2, 6.2),
			center * CFrame.Angles(0, 0, math.pi / 2), palette.Ink, Enum.Material.SmoothPlastic,
			effects, Enum.PartType.Cylinder)
		WorldBuilder.Ring("ShowcaseSocket", 2.8, 0.2, 0.13, center * CFrame.new(0, 0.56, 0),
			color, Enum.Material.Neon, effects, 18, false)
		local card = pose(pedestal, center * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.pi, 0))
		card.Size = UDim2.fromOffset(174, 90)
		card.StudsOffsetWorldSpace = Vector3.new(0, -0.48, 1)
		card.Enabled = true
	end
	root.CFrame = CFrame.new(3.1, 3.4, 25) * CFrame.Angles(0, math.rad(152), 0)
	for _, offset in ipairs({ Vector3.new(-26, 0.16, 12), Vector3.new(28, 0.16, 10), Vector3.new(23, 0.16, -12) }) do
		WorldBuilder.Ring("PreviewWarning", 7, 0.34, 0.15, CFrame.new(offset),
			palette.Sun, Enum.Material.Neon, effects, 24, false)
	end
	for _, center in ipairs({ Vector3.new(-28, 15, -20), Vector3.new(30, 16, -13),
		Vector3.new(42, 18, -40), Vector3.new(-44, 20, -46) }) do
		meteors:CreateMeteor(center, 2.5, Vector3.new(5, 10, -4))
	end
	return CFrame.lookAt(Vector3.new(0, 15, 45), Vector3.new(0, 7.5, 11)), 54
end

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
	self.Meteors:SetShowerLook(shot == "Cover", true)
	for _, gremlin in pairs(self.Gremlins.Gremlins) do self.Gremlins:Remove(gremlin, false) end
	self.Economy.Events = {}
	self.Economy.IncomeMultiplier = 1
	profile.Upgrades = { WalkSpeed = 2, CarrySpeed = 3, LockDuration = 2, BaySlots = 1 }
	self.Bases:Reset(player)
	state.Found = {}
	self.Bases:AddSlot(player)
	self.Bases:AddSlot(player)
	profile.Cash = 867500000
	profile.Rebirths = 3
	profile.Multiplier = 3
	profile.SaveStatus = "STUDIO PREVIEW"
	profile.Contracts = { { Stage = 2, Progress = 3, Completed = 1 },
		{ Stage = 2, Progress = 4, Completed = 1 }, { Stage = 3, Progress = 0, Completed = 2 } }
	for index, id in ipairs(lineup) do
		self.Bases:Restore(player, { Id = id, Mutation = mutations[index], Guid = HttpService:GenerateGUID(false) }, index)
		local pedestal = state.Bay.Slots[index]
		local card = pose(pedestal, pedestal.Frame * CFrame.Angles(0, math.pi, 0))
		card.Enabled = shot ~= "Cover" and (index <= 4 or index == 6)
	end
	for id = 1, 23 do state.Found[tostring(id)] = true end
	for _, id in ipairs({ 31, 33, 35 }) do state.Found[tostring(id)] = true end
	root.Anchored = true
	root.CFrame = state.Bay.Frame * CFrame.new(9, 3.8, -6) * CFrame.Angles(0, math.pi, 0)
	for capsule in pairs(self.Conveyor.Capsules) do self.Conveyor.Capsules[capsule] = nil; capsule:Destroy() end
	for index, id in ipairs({ 7, 11, 15, 18, 23, 27 }) do
		local angle = shot == "Cover" and (index + 1) * math.pi / 8 + math.pi or index * math.pi / 3
		self.Conveyor:Spawn({ Id = id, Mutation = index % 2 == 0 and "Gold" or nil }, angle)
	end
	local cameraPosition = (state.Bay.Frame * CFrame.new(12, 18, 38)).Position
	local target = (state.Bay.Frame * CFrame.new(0, 6, 2)).Position
	local camera, fieldOfView = CFrame.lookAt(cameraPosition, target), 64
	if shot == "Cover" then
		camera, fieldOfView = stageCover(state, root, self.Meteors)
		self.Economy:PublishEvent({ Name = "Meteor", Text = "METEOR SHOWER! GET UNDER THE SHIELD DOME",
			EndsAt = workspace:GetServerTimeNow() + 60, FrozenSeconds = 18, Priority = 3 })
	elseif shot == "Raid" then
		self.Economy:PublishEvent({ Name = "Gremlin", Text = "GREMLIN RAID! LOCK [L] OR ZAP [F]",
			EndsAt = workspace:GetServerTimeNow() + 60, FrozenSeconds = 27, Priority = 2,
			Color = Color3.fromRGB(155, 255, 105) })
		for _, offset in ipairs({ Vector3.new(-7, 1, 5), Vector3.new(5, 1, 11) }) do
			self.Gremlins:Grab(self.Gremlins:Spawn(state.Bay, (state.Bay.Frame * CFrame.new(offset)).Position))
		end
	end
	if shot == "Cover" then
		self.Bases:Carry(player, { Id = 11, Mutation = "Diamond", Guid = HttpService:GenerateGUID(false) })
		if state.Carry then state.Carry.Model.PrimaryPart.BrainrotBillboard.Enabled = false end
		self.Economy.Network.Notice:FireClient(player, "INDEX · 32/43 DISCOVERED")
		self.Economy.Network.Notice:FireClient(player, "DOCKED Supernova Il Supremo Supernova")
		self.Economy.Network.Notice:FireClient(player, "CARGO IN HAND · HEAD FOR YOUR DOCK")
	end
	self.Economy:Send(player)
	self.Economy.Network.Screenshot:FireClient(player, { Shot = shot, Camera = camera, FieldOfView = fieldOfView })
	return true
end

return ScreenshotService
