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
	local radius = Config.World.PlanetRadius
	local position = Config.World.PlanetPosition
	WorldBuilder.Part("TangerinePlanet", Vector3.one * radius * 2, CFrame.new(position),
		palette.Planet, Enum.Material.SmoothPlastic, parent, Enum.PartType.Ball, false)
	for band = -2, 2 do
		local latitude = band * 0.27
		local bandRadius = math.cos(latitude) * (radius + 0.9)
		WorldBuilder.Ring("PlanetCloudBelt", bandRadius, 1.4, 9,
			CFrame.new(position) * CFrame.Angles(0, 0, math.rad(-16)) * CFrame.new(0, math.sin(latitude) * radius, 0),
			band % 2 == 0 and Color3.fromRGB(255, 157, 66) or Color3.fromRGB(223, 91, 32),
			Enum.Material.SmoothPlastic, parent, 56, false)
	end
	WorldBuilder.Ring("PlanetHalo", radius * 1.45, 2, 0.9,
		CFrame.new(position) * CFrame.Angles(math.rad(12), 0, math.rad(-16)),
		Color3.fromRGB(255, 199, 115), Enum.Material.Neon, parent, 94, false)

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
			CFrame.new(side * 18.8, height / 2, -3), palette.Teal, Enum.Material.SmoothPlastic, title)
		WorldBuilder.Part("TitleTrim", Vector3.new(41, 0.27, 1.65),
			CFrame.new(0, height + side * 3.4, -3), side == 1 and palette.Sun or palette.Mint,
			Enum.Material.Neon, title, nil, false)
		WorldBuilder.Part("TitleBeacon", Vector3.one * 1.1,
			CFrame.new(side * 19.5, height + 4.15, -3), palette.Sun,
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
	local socket = WorldBuilder.Ring("SocketGlow_" .. index, 2.85, 0.2, 0.12,
		bay.Frame * CFrame.new(x, 1.53, z), bay.Color, Enum.Material.Neon, bay.Model, 16, false)
	local label = WorldBuilder.Billboard(pad, string.format("%02d · EMPTY", index),
		palette.Muted, Vector3.new(0, 2.4, 0), 130, 28)
	label.TextSize = 13
	label.Parent.MaxDistance = 55
	local pedestal = { Index = index, Pad = pad, Label = label, Socket = socket, EmptyColor = bay.Color,
		Frame = bay.Frame * CFrame.new(x, 1.65, z), Occupant = nil }
	bay.Slots[index] = pedestal
	return pedestal
end

function WorldBuilder.ColorSocket(socket, color)
	for _, segment in ipairs(socket:GetChildren()) do
		segment.Color = color
	end
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
			frame * CFrame.new(0, 0.4, floorZ), rival and Color3.fromRGB(255, 235, 211)
			or Color3.fromRGB(207, 238, 240), Enum.Material.SmoothPlastic, model)
		for _, side in ipairs({ -1, 1 }) do
			WorldBuilder.Part("DockEdge", Vector3.new(0.35, 0.1, depth),
				frame * CFrame.new(side * 17.7, 0.8, floorZ), color, Enum.Material.Neon, model, nil, false)
			WorldBuilder.Part("SignPost", Vector3.new(0.7, 10.4, 0.7),
				frame * CFrame.new(side * 16.3, 5.5, 23), palette.Teal, Enum.Material.SmoothPlastic, model)
		end
		WorldBuilder.Part("LandingMark", Vector3.new(12, 0.12, 6),
			frame * CFrame.new(0, 0.82, -9.5), color, Enum.Material.SmoothPlastic, model, nil, false)
		for step = 1, 4 do
			WorldBuilder.Part("HomeArrow", Vector3.new(3.6, 0.08, 1.3),
				frame * CFrame.new(0, 0.06, -16 - step * 7), color,
				Enum.Material.Neon, world.Geometry, nil, false)
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
	WorldBuilder.Ring("TrackChassis", radius, 11.2, 0.6, plane * CFrame.new(0, -0.42, 0),
		palette.Ink, Enum.Material.Metal, track, Config.World.RailSegments, false)
	for _, side in ipairs({ -1, 1 }) do
		local rail = WorldBuilder.Ring("GuideRail", radius + side * 4.55, 1.02, 0.32,
			plane, side == 1 and palette.Mint or palette.Teal, Enum.Material.Neon,
			track, Config.World.RailSegments, false)
		for index, segment in ipairs(rail:GetChildren()) do
			local sector = (index - 1) * #Rarity.Order / Config.World.RailSegments
			local tier = math.floor(sector)
			local a = Rarity.ByName[Rarity.Order[tier + 1]].Color
			local b = Rarity.ByName[Rarity.Order[(tier + 1) % #Rarity.Order + 1]].Color
			segment.Color = a:Lerp(b, sector - tier):Lerp(palette.Teal, side == 1 and 0.08 or 0.45)
		end
	end
	for index = 1, 14 do
		local angle = (index - 0.5) * math.pi * 2 / 14
		local position = Config.World.RailFrame(angle, radius, -0.62).Position
		local height = position.Y
		local frame = CFrame.new(position.X, height / 2, position.Z) * CFrame.Angles(0, -angle, 0)
		WorldBuilder.Part("MaglevPylon", Vector3.new(3.5, height, 1.9), frame, palette.Ink,
			Enum.Material.Metal, track, nil, false)
		WorldBuilder.Part("PylonPowerCell", Vector3.new(1, height * 0.72, 2), frame, palette.Teal,
			Enum.Material.Neon, track, nil, false)
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

	for index = 1, 7 do
		local phase = (index - 1) * math.pi * 2 / 7
		local frame = Config.World.RailFrame(phase, radius + 4.55, 0.24)
		local color = Rarity.ByName[Rarity.Order[index]].Color
		local tracer = WorldBuilder.Part("RailChaser", Vector3.new(0.84, 0.22, 5.4), frame, color:Lerp(palette.White, 0.55),
			Enum.Material.Neon, track, nil, false)
		tracer.CanQuery = false
		tracer:SetAttribute("OrbitPhase", phase)
		CollectionService:AddTag(tracer, "OrbitRailChaser")
	end
	-- Two open hoops sit across the actual cargo path, away from the arrival
	-- sightline. Non-solid scenery cannot trap a carrier or block a purchase.
	for index, angle in ipairs({ -math.pi / 2, -math.pi / 6 }) do
		local gate = folder("CargoWarpGate_" .. index, track)
		local frame = Config.World.RailFrame(angle, radius, 8.6) * CFrame.Angles(math.pi / 2, 0, 0)
		local color = index == 1 and palette.Mint or palette.Sun
		WorldBuilder.Ring("GateHousing", 10.2, 0.8, 1.1, frame,
			palette.Ink, Enum.Material.Metal, gate, 28, false)
		WorldBuilder.Ring("WarpAperture", 9.6, 0.24, 0.28, frame,
			color, Enum.Material.Neon, gate, 28, false)
		for _, side in ipairs({ -1, 1 }) do
			local cap = WorldBuilder.Part("GateBeacon", Vector3.new(0.8, 0.8, 1.4),
				frame * CFrame.new(side * 10.1, 0, 0), color, Enum.Material.Neon, gate, nil, false)
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
		CFrame.new(0, 0.4, 5) * CFrame.Angles(0, 0, math.pi / 2), palette.Ink,
		Enum.Material.SmoothPlastic, world.Geometry, Enum.PartType.Cylinder)
	local hologram = Instance.new("Model")
	hologram.Name = "HologramCore"
	local core = WorldBuilder.Part("SunnyReactor", Vector3.one * 6.2, CFrame.new(0, 5.3, 5),
		palette.Sun, Enum.Material.Neon, hologram, Enum.PartType.Ball, false)
	core.Transparency = 0.26
	local light = Instance.new("PointLight")
	light.Color = palette.Sun
	light.Brightness = 0.9
	light.Range = 19
	light.Parent = core
	-- Every piece stays inside a 4.5-stud sphere well clear of the title panel.
	WorldBuilder.Ring("HologramEquator", 3.9, 0.18, 0.16,
		core.CFrame * CFrame.Angles(math.rad(24), 0, math.rad(12)),
		palette.Mint, Enum.Material.Neon, hologram, 24, false)
	WorldBuilder.Part("HologramSatellite", Vector3.one * 0.62, core.CFrame * CFrame.new(4.15, 0, 0),
		palette.Mint, Enum.Material.Neon, hologram, Enum.PartType.Ball, false)
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
		palette.Deck, Enum.Material.SmoothPlastic, geometry, Enum.PartType.Cylinder)
	WorldBuilder.Ring("DeckTrim", radius, 2.2, 1.8, CFrame.new(0, -0.8, 0),
		palette.Teal, Enum.Material.SmoothPlastic, geometry, 100, false)
	WorldBuilder.Ring("OrbitEdgeLights", radius - 1, 0.65, 0.15, CFrame.new(0, 0.12, 0),
		palette.Mint, Enum.Material.Neon, geometry, 100, false)
	-- Large recessed-looking wedges make the hub read as a station floor,
	-- with bright spokes pointing to the live cargo and the nine docks.
	for index = 1, 18 do
		local angle = (index - 1) * math.pi * 2 / 18
		local frame = CFrame.Angles(0, -angle, 0)
		WorldBuilder.Part("HubDeckPanel", Vector3.new(15, 0.08, 4.8),
			frame * CFrame.new(25, 0.05, 0), Color3.fromRGB(96, 124, 137),
			Enum.Material.Metal, geometry, nil, false)
		if index % 2 == 1 then
			WorldBuilder.Part("DockGuide", Vector3.new(26, 0.06, 0.28),
				frame * CFrame.new(65, 0.08, 0), palette.Teal,
				Enum.Material.Neon, geometry, nil, false)
		end
	end
	skyAndPlanet(root)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalPad"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.3, 10)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 23), Vector3.new(0, 0.2, 42))
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
