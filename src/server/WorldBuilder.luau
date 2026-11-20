-- Every world instance is authored here at runtime; the Rojo place holds code only.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Rarity = require(shared:WaitForChild("BrainrotTraits")).Rarity
local WorldBuilder = {}
local built
local palette = Config.Palette

local function folder(name, parent)
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

function WorldBuilder.Part(name, size, frame, color, material, parent, shape, solid)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = solid ~= false
	part.CanTouch = solid ~= false
	part.CastShadow = solid ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function WorldBuilder.Ring(name, radius, width, height, frame, color, material, parent, segments, solid)
	local container = folder(name, parent)
	local count = segments or 64
	local length = 2 * radius * math.sin(math.pi / count) + 0.08
	for index = 1, count do
		local angle = (index - 1) * math.pi * 2 / count
		local segmentFrame = frame * CFrame.Angles(0, -angle, 0) * CFrame.new(radius, 0, 0)
		WorldBuilder.Part("Arc", Vector3.new(width, height, length), segmentFrame, color,
			material, container, nil, solid)
	end
	return container
end

function WorldBuilder.Billboard(part, text, color, offset, width, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(width or 240, height or 44)
	gui.StudsOffsetWorldSpace = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 160
	gui.AlwaysOnTop = false
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = palette.Ink
	label.TextStrokeTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Parent = gui
	return label
end

local function lighting()
	Lighting.Brightness = 3.2
	Lighting.ClockTime = 10.5
	Lighting.GeographicLatitude = 18
	Lighting.Ambient = Color3.fromRGB(104, 133, 155)
	Lighting.OutdoorAmbient = Color3.fromRGB(147, 173, 192)
	Lighting.ExposureCompensation = 0.18
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.7
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "OrbitalDepth"
	atmosphere.Density = 0.08
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(199, 222, 237)
	atmosphere.Decay = Color3.fromRGB(255, 212, 167)
	atmosphere.Haze = 0.35
	atmosphere.Glare = 0.1
	atmosphere.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.Name = "OrbitSky"
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SoftNeon"
	bloom.Intensity = 0.39
	bloom.Size = 24
	bloom.Threshold = 1.24
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "SunnyOrbit"
	grade.Brightness = 0.02
	grade.Saturation = 0.13
	grade.TintColor = Color3.fromRGB(255, 249, 237)
	grade.Parent = Lighting
end

local function skyAndPlanet(parent)
	local backdrop = folder("Starfield", parent)
	local navy = Color3.fromRGB(8, 20, 43)
	for _, direction in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis,
		-Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local center = direction * 900
		local up = math.abs(direction.Y) > 0.5 and Vector3.zAxis or Vector3.yAxis
		local wall = WorldBuilder.Part("SpaceBackdrop", Vector3.new(1900, 1900, 2),
			CFrame.lookAt(center, Vector3.zero, up), navy, Enum.Material.SmoothPlastic, backdrop, nil, false)
		wall.CanQuery = false
	end
	local random = Random.new(73126)
	local starColors = { palette.White, Color3.fromRGB(156, 209, 255), Color3.fromRGB(255, 216, 163) }
	local function star(position, size, color, transparency)
		local point = WorldBuilder.Part("Star", Vector3.one * size, CFrame.new(position),
			color, Enum.Material.Neon, backdrop, Enum.PartType.Ball, false)
		point.CanQuery = false
		point.Transparency = transparency
		return point
	end
	for index = 1, Config.World.StarCount do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(480, 800)
		local elevation = random:NextNumber(-0.62, 0.92)
		local horizontal = distance * math.sqrt(1 - elevation ^ 2)
		local position = Vector3.new(math.cos(angle) * horizontal, elevation * distance, math.sin(angle) * horizontal)
		local bright = index % 14 == 0
		local color = starColors[index % 7 == 0 and 2 or index % 5 == 0 and 3 or 1]
		local point = star(position, random:NextNumber(0.62, bright and 3.2 or 1.65), color, bright and 0.15 or 0.32)
		if bright then
			point:SetAttribute("TwinklePhase", angle)
			CollectionService:AddTag(point, "OrbitSkyStar")
		end
	end
	-- A sloped dust band makes the skyline recognizable from the arrival
	-- camera. Small opaque points avoid a stack of transparent nebula planes.
	local lilac, cyan = Color3.fromRGB(161, 107, 208), Color3.fromRGB(81, 179, 220)
	for index = 1, Config.World.StarBandCount do
		local x = random:NextNumber(-590, 580)
		local scatter = random:NextNumber(-1, 1) + random:NextNumber(-1, 1)
		local y = 42 + x * 0.27 + scatter * 42
		local color = lilac:Lerp(cyan, random:NextNumber())
		if index % 4 == 0 then color = color:Lerp(palette.White, 0.72) end
		star(Vector3.new(x, y, random:NextNumber(-790, -690)), random:NextNumber(1.0, 2.7), color,
			0.25 + math.abs(scatter) * 0.18)
	end
	-- Deep-space hero limb: a blue Earth-like planet replaces the old orange
	-- backdrop. Cloud belts and a thin cyan atmosphere keep the curve readable
	-- behind the elevated orbit without competing with the title or HUD.
	local radius = Config.World.PlanetRadius
	local position = Config.World.PlanetPosition
	WorldBuilder.Part("AzureHeroPlanet", Vector3.one * radius * 2, CFrame.new(position),
		Color3.fromRGB(34, 92, 164), Enum.Material.SmoothPlastic, backdrop, Enum.PartType.Ball, false)
	for band = -2, 2 do
		local latitude = band * 0.25
		local bandRadius = math.cos(latitude) * (radius + 0.9)
		WorldBuilder.Ring("AzureCloudBelt", bandRadius, 1.55, 10,
			CFrame.new(position) * CFrame.Angles(0, 0, math.rad(-18)) * CFrame.new(0, math.sin(latitude) * radius, 0),
			band % 2 == 0 and Color3.fromRGB(164, 218, 239) or Color3.fromRGB(70, 145, 211),
			Enum.Material.SmoothPlastic, backdrop, 56, false)
	end
	WorldBuilder.Ring("AzureAtmosphereHalo", radius * 1.04, 2.2, 1.1,
		CFrame.new(position) * CFrame.Angles(math.rad(12), 0, math.rad(-18)),
		Color3.fromRGB(91, 220, 255), Enum.Material.Neon, backdrop, 94, false)

	-- A Saturn-like ringed planet and a small red planet make the skyline
	-- unmistakably space themed from the phone arrival view.
	local saturn = Vector3.new(275, 142, -560)
	WorldBuilder.Part("RingedSaturn", Vector3.one * 82, CFrame.new(saturn),
		Color3.fromRGB(192, 151, 103), Enum.Material.SmoothPlastic, backdrop, Enum.PartType.Ball, false)
	for band = -1, 1 do
		WorldBuilder.Ring("SaturnCloudBand", 40 - math.abs(band) * 5, 1.1, 4.5,
			CFrame.new(saturn) * CFrame.Angles(math.rad(18), math.rad(-12), math.rad(16)) * CFrame.new(0, band * 12, 0),
			band == 0 and Color3.fromRGB(235, 197, 143) or Color3.fromRGB(156, 111, 79),
			Enum.Material.SmoothPlastic, backdrop, 48, false)
	end
	WorldBuilder.Ring("SaturnRings", 62, 2.2, 1.1,
		CFrame.new(saturn) * CFrame.Angles(math.rad(22), math.rad(-12), math.rad(16)),
		Color3.fromRGB(255, 206, 125), Enum.Material.Neon, backdrop, 72, false)
	local redPlanet = WorldBuilder.Part("RedPlanet", Vector3.one * 52, CFrame.new(-380, 116, -620),
		Color3.fromRGB(173, 63, 72), Enum.Material.SmoothPlastic, backdrop, Enum.PartType.Ball, false)
	redPlanet.CanQuery = false
	WorldBuilder.Ring("RedPlanetGlow", 27, 0.8, 0.7, CFrame.new(-380, 116, -620) * CFrame.Angles(math.rad(20), 0, math.rad(-18)),
		Color3.fromRGB(255, 119, 101), Enum.Material.Neon, backdrop, 48, false)

	-- Soft nebula ribbons sit behind the stars as broad, low-cost colour fields.
	for index, data in ipairs({
		{ Vector3.new(-80, 210, -790), Color3.fromRGB(135, 62, 190), math.rad(-15) },
		{ Vector3.new(170, 72, -785), Color3.fromRGB(47, 151, 201), math.rad(12) },
		{ Vector3.new(-250, -12, -780), Color3.fromRGB(208, 74, 151), math.rad(-8) },
	}) do
		local nebula = WorldBuilder.Part("MilkyWayRibbon" .. index, Vector3.new(520, 74, 1),
			CFrame.new(data[1]) * CFrame.Angles(0, 0, data[3]), data[2], Enum.Material.Neon, backdrop, nil, false)
		nebula.Transparency = 0.84
		nebula.CanQuery = false
	end

	-- A second planetary limb sits well behind the station on the opposite
	-- edge. Nested spheres give the horizon a narrow blue atmospheric rim.
	local bluePosition = Vector3.new(389, -236, -468)
	local rim = WorldBuilder.Part("AzureAtmosphere", Vector3.one * 453, CFrame.new(bluePosition),
		cyan, Enum.Material.Neon, backdrop, Enum.PartType.Ball, false)
	rim.Transparency = 0.64
	rim.CanQuery = false
	local planet = WorldBuilder.Part("AzurePlanet", Vector3.one * 444, CFrame.new(bluePosition),
		Color3.fromRGB(41, 105, 178), Enum.Material.SmoothPlastic, backdrop, Enum.PartType.Ball, false)
	planet.CanQuery = false
	for _, latitude in ipairs({ -0.21, 0.03, 0.24 }) do
		WorldBuilder.Ring("AzureClouds", math.cos(latitude) * 223.5, 1.3, 7,
			CFrame.new(bluePosition) * CFrame.Angles(0, 0, math.rad(23))
				* CFrame.new(0, math.sin(latitude) * 222, 0),
			Color3.fromRGB(119, 183, 217), Enum.Material.SmoothPlastic, backdrop, 54, false)
	end
	local moonPosition = Vector3.new(157, 10, -408)
	local moon = WorldBuilder.Part("PearlMoon", Vector3.one * 46, CFrame.new(moonPosition),
		Color3.fromRGB(173, 177, 204), Enum.Material.SmoothPlastic, backdrop, Enum.PartType.Ball, false)
	moon.CanQuery = false
	for _, crater in ipairs({
		Vector3.new(-9, 7, 9), Vector3.new(7, 4, 16), Vector3.new(-4, -8, 17),
		Vector3.new(5, 13, 6), Vector3.new(-13, -3, 8),
	}) do
		local normal = crater.Unit
		local face = CFrame.lookAt(moonPosition + normal * 22.6, moonPosition) * CFrame.Angles(0, math.pi / 2, 0)
		local width = random:NextNumber(5.4, 10)
		local mark = WorldBuilder.Part("MoonCrater", Vector3.new(1.55, width, width), face,
			Color3.fromRGB(127, 136, 167), Enum.Material.SmoothPlastic, backdrop, Enum.PartType.Ball, false)
		mark.CanQuery = false
	end
end

local function signFace(board, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DockSign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.LightInfluence = 0
	gui.Parent = board
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Size = UDim2.fromScale(0.96, 0.9)
	caption.Position = UDim2.fromScale(0.02, 0.05)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBlack
	caption.TextScaled = true
	caption.TextColor3 = color
	caption.Text = text
	caption.Parent = gui
	return caption
end

local function buildTitle(parent)
	local title = folder("StationTitle", parent)
	local height = 14.5
	local board = WorldBuilder.Part("TitlePanel", Vector3.new(40, 6.6, 1.2),
		CFrame.new(0, height, -3), palette.Ink, Enum.Material.SmoothPlastic, title, nil, false)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local caption = signFace(board, face, Config.Title, palette.White)
		caption.TextStrokeColor3 = palette.Teal
		caption.TextStrokeTransparency = 0.45
	end
	for _, side in ipairs({ -1, 1 }) do
		WorldBuilder.Part("TitleSupport", Vector3.new(1.05, height, 1.05),
			CFrame.new(side * 21.2, height / 2, -3), palette.Teal, Enum.Material.SmoothPlastic, title)
		WorldBuilder.Part("TitleTrim", Vector3.new(41, 0.27, 1.65),
			CFrame.new(0, height + side * 3.55, -3), side == 1 and palette.Sun or palette.Mint,
			Enum.Material.Neon, title, nil, false)
		WorldBuilder.Part("TitleBeacon", Vector3.one * 1.1,
			CFrame.new(side * 22.2, height + 4.3, -3), palette.Sun,
			Enum.Material.Neon, title, Enum.PartType.Ball, false)
	end
end

function WorldBuilder.CreatePedestal(bay, index)
	local column = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local x = -12 + column * 8
	local z = 1 + row * 8
	local center = bay.Frame * CFrame.new(x, 1.1, z)
	local pad = WorldBuilder.Part("Pedestal_" .. index, Vector3.new(0.8, 6.1, 6.1),
		center * CFrame.Angles(0, 0, math.pi / 2), palette.Ink,
		Enum.Material.SmoothPlastic, bay.Model, Enum.PartType.Cylinder)
	pad:SetAttribute("BayIndex", bay.Index)
	pad:SetAttribute("SlotIndex", index)
	local socket = WorldBuilder.Ring("SocketGlow_" .. index, 2.85, 0.32, 0.12,
		bay.Frame * CFrame.new(x, 1.53, z), bay.Color, Enum.Material.Neon, bay.Model, 16, false)
	socket:SetAttribute("SocketFrame", bay.Frame * CFrame.new(x, 1.53, z))
	WorldBuilder.Part("SocketUnderglow", Vector3.new(0.16, 6.3, 6.3),
		center * CFrame.new(0, -0.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		bay.Color, Enum.Material.Neon, socket, Enum.PartType.Cylinder, false).Transparency = 0.38
	local label = WorldBuilder.Billboard(pad, string.format("%02d · EMPTY", index),
		palette.Muted, Vector3.new(0, 2.4, 0), 130, 28)
	label.TextSize = 13
	label.Parent.MaxDistance = 55
	local pedestal = { Index = index, Pad = pad, Label = label, Socket = socket, EmptyColor = bay.Color,
		Frame = bay.Frame * CFrame.new(x, 1.65, z), Occupant = nil }
	bay.Slots[index] = pedestal
	return pedestal
end

function WorldBuilder.ColorSocket(socket, color, rank)
	for _, segment in ipairs(socket:GetChildren()) do
		if segment:IsA("BasePart") then segment.Color = color end
	end
	local accent = socket:FindFirstChild("SocketAccent")
	if not rank or rank == 0 then
		if accent then accent:Destroy() end
		return
	end
	local frame = socket:GetAttribute("SocketFrame")
	if not frame then return end
	if not accent then
		accent = Instance.new("Model")
		accent.Name = "SocketAccent"
		-- Gaps in the outer ring make its slow rotation visible without textures.
		for index = 1, 8 do
			local angle = (index - 1) * math.pi / 4
			local arc = WorldBuilder.Part("OrbitFacet", Vector3.new(0.12, 0.1, 1.2),
				frame * CFrame.Angles(0, angle, 0) * CFrame.new(3.22, 0.07, 0),
				color, Enum.Material.Neon, accent, nil, false)
			arc.CanQuery = false
		end
		local mount = WorldBuilder.Part("AuraMount", Vector3.one * 0.1, frame,
			color, Enum.Material.SmoothPlastic, accent, nil, false)
		mount.Transparency, mount.CanQuery = 1, false
		accent.PrimaryPart = mount
		local foot = Instance.new("Attachment", mount)
		local tip = Instance.new("Attachment", mount)
		tip.Position = Vector3.new(0, 1.8, 0)
		local aura = Instance.new("Beam", mount)
		aura.Name = "SocketAura"
		aura.Attachment0, aura.Attachment1 = foot, tip
		aura.Width0, aura.Width1 = 4.5, 0.25
		aura.FaceCamera, aura.LightEmission = true, 0.8
		aura.Transparency = NumberSequence.new(0.88, 1)
		local sparks = Instance.new("ParticleEmitter", foot)
		sparks.Name = "SocketSparkles"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Rate, sparks.LightEmission = 1.5, 0.8
		sparks.Lifetime, sparks.Speed = NumberRange.new(0.6, 1), NumberRange.new(0.5, 1.2)
		sparks.SpreadAngle = Vector2.new(45, 45)
		sparks.Size = NumberSequence.new(0.13, 0)
		sparks.Transparency = NumberSequence.new(0.35, 1)
		accent.Parent = socket
	end
	accent:SetAttribute("SocketFrame", frame)
	accent:SetAttribute("SocketRank", rank)
	accent:SetAttribute("SocketColor", color)
	for _, item in ipairs(accent:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Color = color
			if item.Name == "OrbitFacet" then item.Transparency = 0.22 end
		elseif item:IsA("Beam") then
			item.Color, item.Enabled = ColorSequence.new(color), rank >= 3
		elseif item:IsA("ParticleEmitter") then
			item.Color, item.Enabled = ColorSequence.new(color), false
		end
	end
	CollectionService:AddTag(accent, "OrbitSocketAccent")
end

local function buildBays(world)
	local parent = folder("DockingBays", world.Root)
	local crews = { "PASTA PIRATES", "MOON MUNCHERS", "COSMIC NONNAS" }
	local total = Config.World.PlayerBays + Config.World.RivalBays
	local playerIndex, rivalIndex = 0, 0
	for orbitIndex = 1, total do
		local rival = orbitIndex % 3 == 0
		if rival then rivalIndex += 1 else playerIndex += 1 end
		local index = rival and rivalIndex or playerIndex
		local angle = math.pi / 2 + (orbitIndex - 1) * math.pi * 2 / total
		local position = Vector3.new(math.cos(angle) * Config.World.BayRadius, 0,
			math.sin(angle) * Config.World.BayRadius)
		local frame = CFrame.lookAt(position, Vector3.zero)
		local model = Instance.new("Model")
		model.Name = (rival and "RivalBay_" or "PlayerBay_") .. index
		model:SetAttribute("OwnerUserId", 0)
		model:SetAttribute("Rival", rival)
		model.Parent = parent
		local color = rival and Color3.fromRGB(255, 162, 83) or palette.Teal
		local depth = rival and 43 or 51
		local floorZ = depth / 2 - 14
		local floor = WorldBuilder.Part("DockFloor", Vector3.new(36, 0.7, depth),
			frame * CFrame.new(0, 0.4, floorZ), rival and Color3.fromRGB(43, 37, 47)
			or Config.Rebirth.FloorColors[0], Enum.Material.Metal, model)
		floor.Reflectance = 0.035
		-- Large dark panels stay quiet; narrow lit borders define each bay.
		for seam = 0, 2 do
			WorldBuilder.Part("DockPanelSeam", Vector3.new(34.6, 0.025, 0.1),
				frame * CFrame.new(0, 0.766, -3 + seam * 12), palette.Ink,
				Enum.Material.Metal, model, nil, false)
		end
		WorldBuilder.Part("DockThreshold", Vector3.new(34.8, 0.06, 0.18),
			frame * CFrame.new(0, 0.8, -13.4), color, Enum.Material.Neon, model, nil, false)
		for _, side in ipairs({ -1, 1 }) do
			WorldBuilder.Part("DockLane", Vector3.new(0.25, 0.06, 26),
				frame * CFrame.new(side * 5.6, 0.06, -27), color, Enum.Material.Neon, model, nil, false)
			WorldBuilder.Part("DockEdge", Vector3.new(0.35, 0.1, depth),
				frame * CFrame.new(side * 17.7, 0.8, floorZ), color, Enum.Material.Neon, model, nil, false)
			WorldBuilder.Part("SignPost", Vector3.new(0.7, 10.4, 0.7),
				frame * CFrame.new(side * 16.3, 5.5, 23), palette.Teal, Enum.Material.SmoothPlastic, model)
		end
		WorldBuilder.Part("LandingMark", Vector3.new(12, 0.06, 6),
			frame * CFrame.new(0, 0.8, -9.5), palette.Ink, Enum.Material.Metal, model, nil, false)
		for step = 1, 4 do
			for _, side in ipairs({ -1, 1 }) do
				WorldBuilder.Part("HomeArrow", Vector3.new(2.35, 0.05, 0.27),
					frame * CFrame.new(side * 1.02, 0.06, -16 - step * 7) * CFrame.Angles(0, side * 0.52, 0),
					color, Enum.Material.Neon, model, nil, false)
			end
		end
		local name = rival and crews[index] or string.format("BAY %02d · OPEN DOCK", index)
		local board = WorldBuilder.Part("CrewSign", Vector3.new(29, 3.2, 0.35),
			frame * CFrame.new(0, 10.2, 23), palette.Ink, Enum.Material.SmoothPlastic, model, nil, false)
		local caption = signFace(board, Enum.NormalId.Front, name, palette.White)
		if not rival then
			caption.Size = UDim2.fromScale(0.7, 0.86)
			local badge = caption:Clone()
			badge.Name = "ShieldStatus"
			badge.Position = UDim2.fromScale(0.73, 0.15)
			badge.Size = UDim2.fromScale(0.25, 0.68)
			badge.Parent = caption.Parent
			local function updateStatus()
				local seconds = math.max(0, math.ceil((model:GetAttribute("LockedUntil") or 0) - Workspace:GetServerTimeNow()))
				local locked = seconds > 0
				badge.Text = locked and string.format("LOCKED\n%d:%02d", math.floor(seconds / 60), seconds % 60) or "OPEN"
				badge.TextColor3 = locked and palette.Sun or palette.Mint
			end
			model:GetAttributeChangedSignal("LockedUntil"):Connect(updateStatus)
			updateStatus()
			task.spawn(function()
				while model.Parent do
					task.wait(1)
					if model.Parent then updateStatus() end
				end
			end)
		end
		local bay = { Index = index, Model = model, Frame = frame, Floor = floor,
			Label = caption, Color = color, Slots = {}, Rival = rival, CrewName = name,
			SpawnFrame = frame * CFrame.new(0, 4.5, -9.5), Owner = nil }
		for slot = 1, Config.World.InitialSlots do
			WorldBuilder.CreatePedestal(bay, slot)
		end
		table.insert(rival and world.RivalBays or world.PlayerBays, bay)
	end
end

local function buildCargoRing(world)
	local radius = Config.World.RailRadius
	local plane = Config.World.RailPlane()
	local track = folder("CargoTrack", world.Geometry)
	-- These are sky-scale energy orbits, separate from the walkable cargo
	-- track. Their lowest points stay above the portals and station title.
	for index, spec in ipairs({
		{ Radius = 94, Tilt = 28, Pitch = -12, Color = palette.Teal, Speed = 0.035 },
		{ Radius = 108, Tilt = -34, Pitch = 16, Color = Color3.fromRGB(169, 109, 255), Speed = -0.027 },
		{ Radius = 120, Tilt = 19, Pitch = -22, Color = palette.Sun, Speed = 0.019 },
	}) do
		local halo = Instance.new("Model")
		halo.Name = "CelestialHalo_" .. index
		local frame = CFrame.new(0, 116, -26)
			* CFrame.Angles(math.rad(spec.Pitch), 0, math.rad(spec.Tilt))
		halo.WorldPivot = frame
		halo:SetAttribute("HaloFrame", frame)
		halo:SetAttribute("HaloSpeed", spec.Speed)
		for segment = 0, 63 do
			-- Small deliberate gaps and gold nodes make slow counterrotation read.
			if segment % 16 < 14 then
				local angle = segment * math.pi * 2 / 64
				local arc = WorldBuilder.Part("CelestialEnergyArc", Vector3.new(0.7, 0.65, spec.Radius * 0.099),
					frame * CFrame.Angles(0, -angle, 0) * CFrame.new(spec.Radius, 0, 0),
					segment % 16 == 0 and palette.White or spec.Color, Enum.Material.Neon, halo, nil, false)
				arc.Transparency, arc.CanQuery = 0.16, false
			end
		end
		halo.Parent = track
		CollectionService:AddTag(halo, "OrbitCelestialHalo")
	end
	WorldBuilder.Ring("TrackChassis", radius, 11.2, 0.6, plane * CFrame.new(0, -0.42, 0),
		palette.Ink, Enum.Material.Metal, track, Config.World.RailSegments, true)
	-- Raising the real conveyor must not strand its purchase prompts in the
	-- sky. Two broad, solid ramps connect the deck to the annular shopping walk.
	-- They sit to either side of arrival, leaving the title sightline open.
	for _, angle in ipairs({ math.pi / 4, math.pi * 3 / 4 }) do
		local top = Config.World.RailFrame(angle, radius, -0.48).Position
		local foot = Vector3.new(math.cos(angle) * 86, -0.42, math.sin(angle) * 86)
		local frame = CFrame.lookAt((top + foot) / 2, top)
		local length = (top - foot).Magnitude + 2
		WorldBuilder.Part("CargoAccessRamp", Vector3.new(9, 0.8, length), frame,
			palette.Ink, Enum.Material.Metal, track)
		for _, side in ipairs({ -1, 1 }) do
			WorldBuilder.Part("RampGuide", Vector3.new(0.24, 0.12, length),
				frame * CFrame.new(side * 4.2, 0.46, 0), palette.Mint,
				Enum.Material.Neon, track, nil, false)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		-- Wrap the glowing edges around the chassis so they read from the hub below.
		local rail = WorldBuilder.Ring("GuideRail", radius + side * Config.World.RailEdgeOffset, 1.02, 1.28,
			plane * CFrame.new(0, -0.42, 0), side == 1 and palette.Mint or palette.Teal, Enum.Material.Neon,
			track, Config.World.RailSegments, false)
		for index, segment in ipairs(rail:GetChildren()) do
			local sector = (index - 1) * #Rarity.Order / Config.World.RailSegments
			local tier = math.floor(sector)
			local a = Rarity.ByName[Rarity.Order[tier + 1]].Color
			local b = Rarity.ByName[Rarity.Order[(tier + 1) % #Rarity.Order + 1]].Color
			segment.Color = a:Lerp(b, sector - tier):Lerp(palette.Teal, side == 1 and 0.08 or 0.45)
		end
	end
	-- Split the near span between two supports to leave a clear view of the
	-- title from arrival. A support at pi/2 stands directly in front of it.
	for index = 1, 12 do
		local angle = (index - 0.5) * math.pi * 2 / 12
		local position = Config.World.RailFrame(angle, radius, -0.62).Position
		local height = position.Y
		local frame = CFrame.new(position.X, height / 2, position.Z) * CFrame.Angles(0, -angle, 0)
		WorldBuilder.Part("MaglevPylon", Vector3.new(3.5, height, 1.9), frame, palette.Ink,
			Enum.Material.Metal, track, nil, false)
		local cell = WorldBuilder.Part("PylonPowerCell", Vector3.new(1, height * 0.72, 2), frame, palette.Mint,
			Enum.Material.Neon, track, nil, false)
		cell.Transparency = 0.44
		cell.CanQuery = false
		cell:SetAttribute("OrbitPhase", angle)
		CollectionService:AddTag(cell, "OrbitRailPowerCell")
	end
	for index = 1, 28 do
		local angle = (index - 1) * math.pi * 2 / 28
		local frame = Config.World.RailFrame(angle, radius, -0.17)
		WorldBuilder.Part("TrackSleeper", Vector3.new(10.8, 0.2, 0.67), frame, palette.Teal,
			Enum.Material.Metal, track, nil, false)
	end
	-- Wide clamps and center lane marks keep the ring recognizable from above.
	for index, name in ipairs(Rarity.Order) do
		local angle = (index - 1) * math.pi * 2 / #Rarity.Order
		local frame = Config.World.RailFrame(angle, radius, -0.06)
		local color = Rarity.ByName[name].Color
		for _, side in ipairs({ -1, 1 }) do
			WorldBuilder.Part("GuideClamp", Vector3.new(1.8, 0.58, 2.5),
				frame * CFrame.new(side * 5.45, -0.2, 0), palette.White, Enum.Material.Metal, track, nil, false)
		end
		for tick = -1, 1 do
			WorldBuilder.Part("LaneMark", Vector3.new(1.9, 0.06, 0.28),
				frame * CFrame.new(0, -0.02, tick * 0.55), color, Enum.Material.Neon, track, nil, false)
		end
	end

	for _, side in ipairs({ 1, -1 }) do
		local count = side == 1 and 7 or 4
		for index = 1, count do
			local phase = (index - 1) * math.pi * 2 / count + (side == 1 and 0 or 0.4)
			local frame = Config.World.RailFrame(phase, radius + side * Config.World.RailEdgeOffset,
				Config.World.RailChaserHeight)
			local color = side == 1 and Rarity.ByName[Rarity.Order[index]].Color or palette.Teal
			local tracer = WorldBuilder.Part("RailChaser", Vector3.new(0.76, 0.26, side == 1 and 5.4 or 3.8),
				frame, color:Lerp(palette.White, 0.55), Enum.Material.Neon, track, nil, false)
			tracer.CanQuery = false
			tracer:SetAttribute("OrbitPhase", phase)
			tracer:SetAttribute("RailSide", side)
			CollectionService:AddTag(tracer, "OrbitRailChaser")
		end
	end
	-- Two open hoops sit across the actual cargo path, away from the arrival
	-- sightline. Non-solid scenery cannot trap a carrier or block a purchase.
	for index, angle in ipairs({ Config.World.CargoEntryAngle, math.pi * 1.88 }) do
		local gate = folder("CargoWarpGate_" .. index, track)
		-- The 2x SECRET crown reaches ~22 studs above the rail, including
		-- hover. Keep the aperture above it instead of cutting through its head.
		local frame = Config.World.RailFrame(angle, radius, 12.4) * CFrame.Angles(math.pi / 2, 0, 0)
		local color = index == 1 and palette.Mint or palette.Sun
		WorldBuilder.Ring("GateHousing", 12.6, 0.8, 1.1, frame,
			palette.Ink, Enum.Material.Metal, gate, 28, false)
		WorldBuilder.Ring("WarpAperture", 12, 0.24, 0.28, frame,
			color, Enum.Material.Neon, gate, 28, false)
		-- Three separated rims give the warp mouth real depth in silhouette.
		for _, depth in ipairs({ -1.8, 1.8 }) do
			WorldBuilder.Ring("WarpOuterCrown", 13.1, 0.28, 0.24, frame * CFrame.new(0, depth, 0),
				depth < 0 and palette.Sun or color, Enum.Material.Neon, gate, 28, false)
		end
		local rotor = Instance.new("Model")
		rotor.Name = "WarpRotor"
		rotor.WorldPivot = frame
		rotor:SetAttribute("GateFrame", frame)
		rotor:SetAttribute("GateColor", color)
		rotor:SetAttribute("GatePhase", index * 0.9)
		rotor.Parent = gate
		local motes = {}
		for arc = 0, 2 do
			for segment = 0, 2 do
				local spin = (arc * 2 * math.pi / 3) + segment * 0.13
				local shard = WorldBuilder.Part("WarpArc", Vector3.new(0.38, 0.46, 1.34),
					frame * CFrame.Angles(0, -spin, 0) * CFrame.new(11.46, 0, 0),
					color, Enum.Material.Neon, rotor, nil, false)
				shard.CanQuery = false
				if segment == 0 then
					local sparks = Instance.new("ParticleEmitter", shard)
					sparks.Name = "WarpMotes"
					sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					sparks.Color = ColorSequence.new(color, palette.White)
					sparks.LightEmission = 0.8
					sparks.Rate = 3
					sparks.Lifetime = NumberRange.new(0.35, 0.65)
					sparks.Speed = NumberRange.new(0.5, 1.7)
					sparks.EmissionDirection = Enum.NormalId.Right
					sparks.SpreadAngle = Vector2.new(18, 18)
					sparks.Size = NumberSequence.new(0.48, 0)
					sparks.Transparency = NumberSequence.new(0.25, 1)
					table.insert(motes, sparks)
				end
			end
		end
		world.Root:GetAttributeChangedSignal("ScreenshotFrozen"):Connect(function()
			local frozen = world.Root:GetAttribute("ScreenshotFrozen") == true
			for _, sparks in ipairs(motes) do
				sparks.Enabled = not frozen
				if frozen then sparks:Clear() end
			end
		end)
		CollectionService:AddTag(rotor, "OrbitWarpRotor")
		if index == 1 then world.CargoEntry = rotor end
		for _, side in ipairs({ -1, 1 }) do
			local cap = WorldBuilder.Part("GateBeacon", Vector3.new(0.8, 0.8, 1.4),
				frame * CFrame.new(side * 12.5, 0, 0), color, Enum.Material.Neon, gate, nil, false)
			local lamp = Instance.new("PointLight", cap)
			lamp.Color, lamp.Brightness, lamp.Range = color, 0.65, 17
		end
	end
	for index = 1, 3 do
		local angle = (index - 1) * math.pi * 2 / 3 + 0.36
		local frame = CFrame.Angles(0, -angle, 0) * CFrame.new(radius - 8.4, 3.4, 0)
		local drone = Instance.new("Model")
		drone.Name = "CargoRelay"
		local core = WorldBuilder.Part("RelayCore", Vector3.new(1.25, 1.1, 1.35), frame,
			palette.White, Enum.Material.SmoothPlastic, drone, nil, false)
		for _, side in ipairs({ -1, 1 }) do
			WorldBuilder.Part("SolarWing", Vector3.new(0.9, 0.18, 1.42), frame * CFrame.new(side * 1.04, 0, 0),
				palette.Teal, Enum.Material.Metal, drone, nil, false)
		end
		WorldBuilder.Part("RelayLens", Vector3.new(0.46, 0.46, 0.33), frame * CFrame.new(0, 0, 0.69),
			palette.Mint, Enum.Material.Neon, drone, Enum.PartType.Ball, false)
		drone.PrimaryPart = core
		drone:SetAttribute("RelayFrame", frame)
		drone:SetAttribute("RelayPhase", angle)
		drone.Parent = track
		CollectionService:AddTag(drone, "OrbitCargoRelay")
	end
	WorldBuilder.Ring("HubTrim", 13, 1.5, 0.25, CFrame.new(0, 0.17, 0),
		palette.Teal, Enum.Material.SmoothPlastic, world.Geometry, 48, false)
	WorldBuilder.Part("ReactorBase", Vector3.new(0.65, 11, 11),
		CFrame.new(0, 0.4, -16) * CFrame.Angles(0, 0, math.pi / 2), palette.Ink,
		Enum.Material.SmoothPlastic, world.Geometry, Enum.PartType.Cylinder)
	WorldBuilder.Part("HologramProjector", Vector3.new(0.16, 5.2, 5.2),
		CFrame.new(0, 0.75, -16) * CFrame.Angles(0, 0, math.pi / 2), palette.Teal,
		Enum.Material.Neon, world.Geometry, Enum.PartType.Cylinder, false)
	local hologram = Instance.new("Model")
	hologram.Name = "HologramCore"
	local core = WorldBuilder.Part("HologramGlobe", Vector3.one * 9.2, CFrame.new(0, 27, -16),
		palette.Teal, Enum.Material.Neon, hologram, Enum.PartType.Ball, false)
	core.Transparency = 0.78
	local light = Instance.new("PointLight")
	light.Color = palette.Mint
	light.Brightness = 0.6
	light.Range = 14
	light.Parent = core
	-- The projection rises behind the sign; the sign face remains unobstructed.
	local axis = core.CFrame * CFrame.Angles(math.rad(24), 0, math.rad(12))
	for _, latitude in ipairs({ -0.54, 0, 0.54 }) do
		WorldBuilder.Ring("HologramLatitude", 4.7 * math.cos(latitude), 0.16, 0.16,
			axis * CFrame.new(0, 4.7 * math.sin(latitude), 0), palette.Teal,
			Enum.Material.Neon, hologram, 16, false)
	end
	for index = 1, 3 do
		local orbit = axis * CFrame.Angles(index * 0.37, 0, index * 0.3)
		WorldBuilder.Ring("HologramOrbit", 5.2 + index * 0.8, 0.2, 0.18, orbit,
			index == 2 and palette.Sun or palette.Mint, Enum.Material.Neon, hologram, 24, false)
		WorldBuilder.Part("HologramSatellite", Vector3.new(0.6, 1.65, 0.6),
			orbit * CFrame.new(5.2 + index * 0.8, 0, 0) * CFrame.Angles(0, 0, 0.6),
			palette.Mint, Enum.Material.Neon, hologram, nil, false)
	end
	local beamFoot = Instance.new("Attachment", core)
	beamFoot.Position = Vector3.new(0, -26, 0)
	local beamTip = Instance.new("Attachment", core)
	beamTip.Position = Vector3.new(0, 9, 0)
	local projection = Instance.new("Beam", core)
	projection.Name = "HologramProjection"
	projection.Attachment0, projection.Attachment1 = beamFoot, beamTip
	projection.Width0, projection.Width1 = 4.8, 0.5
	projection.Color = ColorSequence.new(palette.Teal, palette.Mint)
	projection.Transparency = NumberSequence.new(0.88, 0.97)
	projection.LightEmission, projection.FaceCamera = 0.7, true
	hologram.PrimaryPart = core
	hologram:SetAttribute("CoreFrame", core.CFrame)
	hologram.Parent = world.Geometry
	CollectionService:AddTag(hologram, "OrbitHologramCore")
	buildTitle(world.Geometry)
	WorldBuilder.Ring("SafetyRail", Config.World.DeckRadius - 0.5, 0.75, 2.1,
		CFrame.new(0, 1.2, 0), palette.Teal, Enum.Material.SmoothPlastic, world.Geometry, 90, true)
end

local function buildDomes(world)
	local parent = folder("ShieldDomes", world.Root)
	for index = 1, 4 do
		local angle = (index - 1) * math.pi / 2
		local center = Vector3.new(math.cos(angle) * Config.World.DomeOrbit, 0.05,
			math.sin(angle) * Config.World.DomeOrbit)
		local dome = WorldBuilder.Part("ShieldDome_" .. index, Vector3.one * Config.World.DomeRadius * 2,
			CFrame.new(center), palette.Mint, Enum.Material.Glass, parent, Enum.PartType.Ball, false)
		dome.Transparency = 0.84
		dome.CanQuery = false
		WorldBuilder.Ring("DomeRim", Config.World.DomeRadius, 0.35, 0.12,
			CFrame.new(center + Vector3.new(0, 0.07, 0)), palette.Mint, Enum.Material.Neon, parent, 48, false)
		local label = WorldBuilder.Billboard(dome, "SAFE ZONE", palette.Mint,
			Vector3.new(0, Config.World.DomeRadius + 1.5, 0), 120, 28)
		label.TextSize = 15
		label.Parent.MaxDistance = 20
		table.insert(world.Domes, { Part = dome, Label = label.Parent, Center = center, Radius = Config.World.DomeRadius })
	end
end

function WorldBuilder.Build()
	if built then
		return built
	end
	-- Optional ambience must never prevent the playable station from spawning.
	local lit, reason = pcall(lighting)
	if not lit then warn("ROT ORBIT lighting fallback:", reason) end
	local gravitySet, gravityReason = pcall(function() Workspace.Gravity = Config.Gravity end)
	if not gravitySet then warn("ROT ORBIT default gravity:", gravityReason) end
	-- Restricted Workspace properties belong in default.project.json, never here.
	local root = folder("ROT_ORBIT", Workspace)
	local geometry = folder("Station", root)
	local radius = Config.World.DeckRadius
	WorldBuilder.Part("SunlitDeck", Vector3.new(Config.World.DeckThickness, radius * 2, radius * 2),
		CFrame.new(0, -Config.World.DeckThickness / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		palette.Deck, Enum.Material.Metal, geometry, Enum.PartType.Cylinder).Reflectance = 0.025
	WorldBuilder.Ring("DeckTrim", radius, 2.2, 1.8, CFrame.new(0, -0.8, 0),
		palette.Teal, Enum.Material.SmoothPlastic, geometry, 100, false)
	WorldBuilder.Ring("OrbitEdgeLights", radius - 1, 0.65, 0.15, CFrame.new(0, 0.12, 0),
		palette.Mint, Enum.Material.Neon, geometry, 100, false)
	-- Low-contrast panels and recessed paths make the deck readable at a glance.
	for index = 1, 18 do
		local angle = (index - 1) * math.pi * 2 / 18
		local frame = CFrame.Angles(0, -angle, 0)
		local tint = palette.Deck:Lerp(palette.White, index % 2 == 0 and 0.08 or 0.035)
		WorldBuilder.Part("HubDeckPanel", Vector3.new(17, 0.04, 5.2),
			frame * CFrame.new(25, 0.025, 0), tint,
			Enum.Material.Metal, geometry, nil, false)
		if index % 2 == 1 then
			for _, side in ipairs({ -1, 1 }) do
				WorldBuilder.Part("HubGuide", Vector3.new(14.6, 0.045, 0.18),
					frame * CFrame.new(25, 0.04, side * 2.45), side == 1 and palette.Teal or Color3.fromRGB(145, 98, 238),
					Enum.Material.Neon, geometry, nil, false)
			end
		end
	end
	skyAndPlanet(root)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalPad"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.3, 10)
	spawn.CFrame = Config.World.SpawnFrame()
	spawn.Transparency = 1
	spawn.Color = palette.Teal
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = geometry
	built = { Root = root, Geometry = geometry, Spawn = spawn,
		PlayerBays = {}, RivalBays = {}, Domes = {}, Cargo = folder("CargoRing", root) }
	buildCargoRing(built)
	buildBays(built)
	buildDomes(built)
	root:SetAttribute("Ready", true)
	return built
end

return WorldBuilder
