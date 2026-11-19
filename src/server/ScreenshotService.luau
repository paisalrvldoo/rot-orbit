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

function ScreenshotService:StageDiscoveries(state)
	state.Found, state.Variants = {}, {}
	for index, id in ipairs(lineup) do
		self.Bases:Discover(state, { Id = id, Mutation = mutations[index] })
	end
	-- The nine displayed heroes include six beyond these first 26 entries.
	for id = 1, 26 do state.Found[tostring(id)] = true end
	for id = 1, 7 do state.Variants.Gold[tostring(id)] = true end
end

local function pose(pedestal, frame)
	local model = pedestal.Occupant.Model
	model:SetAttribute("RestFrame", frame)
	model:PivotTo(frame)
	return model.PrimaryPart.BrainrotBillboard
end

local function stageCover(state, root, meteors)
	local effects = meteors.Effects
	-- The sun is the key; two restrained studio lamps separate the hero silhouettes.
	for _, lamp in ipairs({
		{ "DockFill", Vector3.new(-22, 13, 30), Color3.fromRGB(203, 230, 255), 1.1 },
		{ "DockRim", Vector3.new(14, 15, 1), Color3.fromRGB(255, 221, 163), 1.8 },
	}) do
		local mount = WorldBuilder.Part(lamp[1], Vector3.one, CFrame.new(lamp[2]),
			Config.Palette.White, Enum.Material.SmoothPlastic, effects, nil, false)
		mount.Transparency = 1
		mount.CanQuery = false
		local light = Instance.new("PointLight", mount)
		light.Color, light.Brightness, light.Range = lamp[3], lamp[4], 55
	end
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
		local center = platform * CFrame.new(column * 8.4, 0.8, math.abs(column) * 0.85)
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
	-- Keep the carried Cornetto to the left of the SECRET face and its beam.
	root.CFrame = CFrame.new(-6, 3.4, 25) * CFrame.Angles(0, math.rad(152), 0)
	for _, offset in ipairs({ Vector3.new(-26, 0.16, 12), Vector3.new(28, 0.16, 10), Vector3.new(23, 0.16, -12) }) do
		WorldBuilder.Ring("PreviewWarning", 7, 0.34, 0.15, CFrame.new(offset),
			palette.Sun, Enum.Material.Neon, effects, 24, false)
	end
	for _, center in ipairs({ Vector3.new(-28, 15, -20), Vector3.new(30, 16, -13),
		Vector3.new(42, 18, -40), Vector3.new(-44, 20, -46) }) do
		meteors:CreateMeteor(center, 2.5, Vector3.new(5, 10, -4))
	end
	return CFrame.lookAt(Vector3.new(6, 14, 46), Vector3.new(0, 7, 11)), 58
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
	self.Gremlins.Active = false
	self.Meteors.Active = false
	self.Meteors.SolarActive, self.Meteors.AuroraActive = false, false
	world.Root:SetAttribute("SolarFlareActive", false)
	world.Root:SetAttribute("AuroraSurgeUntil", 0)
	self.Meteors.Effects:ClearAllChildren()
	self.Meteors:SetShowerLook(shot == "Cover", true)
	for _, gremlin in pairs(self.Gremlins.Gremlins) do self.Gremlins:Remove(gremlin, false) end
	self.Economy.Events = {}
	self.Economy.IncomeMultiplier = 1
	profile.Upgrades = { WalkSpeed = 2, CarrySpeed = 3, LockDuration = 2, BaySlots = 1, IncomeBoost = 3 }
	self.Bases:Reset(player)
	state.Found = {}
	state.Variants = {}
	profile.MutationMilestones = { Gold = 1 }
	profile.Cash = 867500000
	profile.Rebirths = 3
	local extraSlots = Config.World.SlotsPerUpgrade + Config.Rebirth.BonusSlots(profile.Rebirths)
	for _ = 1, extraSlots do self.Bases:AddSlot(player) end
	profile.Multiplier = Config.Rebirth.Multiplier(profile.Rebirths)
	profile.IndexMilestone = 3
	profile.SaveStatus = "STUDIO PREVIEW"
	profile.Contracts = { { Stage = 2, Progress = 3, Completed = 1 },
		{ Stage = 2, Progress = 4, Completed = 1 }, { Stage = 3, Progress = 0, Completed = 2 } }
	for index, id in ipairs(lineup) do
		self.Bases:Restore(player, { Id = id, Mutation = mutations[index], Guid = HttpService:GenerateGUID(false) }, index)
		local pedestal = state.Bay.Slots[index]
		local card = pose(pedestal, pedestal.Frame * CFrame.Angles(0, math.pi, 0))
		card.Enabled = shot ~= "Cover" and (index <= 4 or index == 6)
	end
	-- Keep the staged late-game cover and the Index preset honest: 32 of the
	-- 43 catalog entries are discovered, with the remaining silhouettes visible.
	self:StageDiscoveries(state)
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
	local actions
	if shot == "Cover" then
		camera, fieldOfView = stageCover(state, root, self.Meteors)
		self.Economy:PublishEvent({ Name = "Meteor", Text = "METEOR SHOWER! GET UNDER THE SHIELD DOME",
			EndsAt = workspace:GetServerTimeNow() + 60, FrozenSeconds = 18, Priority = 3 })
	elseif shot == "Raid" then
		self.Economy:PublishEvent({ Name = "Gremlin", Text = "GREMLIN RAID! LOCK [L] OR ZAP [F]",
			EndsAt = workspace:GetServerTimeNow() + 60, FrozenSeconds = 27, Priority = 2,
			Color = Color3.fromRGB(155, 255, 105) })
		local frame = state.Bay.Frame
		root.CFrame = frame * CFrame.new(1, 3.8, 15) * CFrame.Angles(0, math.rad(38), 0)
		self.Gremlins.Wave = 3
		local left = self.Gremlins:Spawn(state.Bay, (frame * CFrame.new(-6.5, 0.86, 8)).Position, true, 32)
		left.Health = 18
		self.Gremlins:HealthView(left)
		local right = self.Gremlins:Spawn(state.Bay, (frame * CFrame.new(8, 0.86, 11)).Position)
		for _, gremlin in ipairs({ left, right }) do
			gremlin.Model:PivotTo(CFrame.lookAt(gremlin.Position, gremlin.Position - frame.LookVector))
		end
		self.Gremlins:Grab(left, 4)
		self.Gremlins:Grab(right, 2)
		left.Label.Text = "CAPTAIN ESCAPING · ZAP [F]"
		right.Label.Text = "ZAPPED!"
		right.Label.TextColor3 = Config.Palette.Mint
		local dropped = self.Gremlins:Stun(right, workspace:GetServerTimeNow())
		if dropped then
			local dropFrame = frame * CFrame.new(10, 1, 15) * CFrame.Angles(0, math.pi, 0)
			dropped:SetAttribute("RestFrame", dropFrame)
			dropped:PivotTo(dropFrame)
			dropped.Parent = self.Meteors.Effects
			WorldBuilder.Ring("ZapRecovery", 3.4, 0.2, 0.12, frame * CFrame.new(10, 0.79, 15),
				Config.Palette.Mint, Enum.Material.Neon, self.Meteors.Effects, 22, false)
		end
		actions = { "ZAPPED! · E TO RECOVER THE CARGO", "A GREMLIN IS STILL ESCAPING" }
		camera = CFrame.lookAt((frame * CFrame.new(0.3, 9.2, 31)).Position, (frame * CFrame.new(0.4, 4.3, 9)).Position)
		fieldOfView = 55
	end
	if shot == "Cover" then
		self.Bases:Carry(player, { Id = 11, Mutation = "Diamond", Guid = HttpService:GenerateGUID(false) })
		if state.Carry then state.Carry.Model.PrimaryPart.BrainrotBillboard.Enabled = false end
		actions = { "CARGO IN HAND · HEAD FOR YOUR DOCK",
			"DOCKED Supernova Il Supremo Supernova", "INDEX · 32/43 DISCOVERED" }
	end
	self.Economy:Send(player)
	self.Economy.Network.Screenshot:FireClient(player, {
		Shot = shot, Camera = camera, FieldOfView = fieldOfView, Actions = actions })
	return true
end

return ScreenshotService
