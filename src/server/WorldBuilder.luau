-- Every world instance is authored here at runtime; the Rojo place holds code only.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
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
	bloom.Intensity = 0.24
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "SunnyOrbit"
	grade.Brightness = 0.02
	grade.Saturation = 0.08
	grade.TintColor = Color3.fromRGB(255, 249, 237)
	grade.Parent = Lighting
end

local function skyAndPlanet(parent)
	local backdrop = folder("Starfield", parent)
	local navy = Color3.fromRGB(8, 20, 43)
	for _, direction in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis,
		-Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local center = direction * 900
		local wall = WorldBuilder.Part("SpaceBackdrop", Vector3.new(1900, 1900, 2),
			CFrame.lookAt(center, Vector3.zero), navy, Enum.Material.SmoothPlastic, backdrop, nil, false)
		wall.CanQuery = false
	end
	local random = Random.new(73126)
	for index = 1, Config.World.StarCount do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = random:NextNumber(420, 720)
		local size = random:NextNumber(0.8, 2.7)
		local position = Vector3.new(math.cos(angle) * radius, random:NextNumber(25, 410), math.sin(angle) * radius)
		WorldBuilder.Part("Star", Vector3.one * size, CFrame.new(position),
			index % 4 == 0 and palette.Mint or palette.White, Enum.Material.Neon, backdrop, Enum.PartType.Ball, false)
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
			Enum.Material.SmoothPlastic, parent, 84, false)
	end
	WorldBuilder.Ring("PlanetHalo", radius * 1.45, 2, 0.9,
		CFrame.new(position) * CFrame.Angles(math.rad(12), 0, math.rad(-16)),
		Color3.fromRGB(255, 199, 115), Enum.Material.Neon, parent, 120, false)
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
			CFrame.new(0, height + side * 3.4, -3), palette.Mint, Enum.Material.Neon, title, nil, false)
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
	local y = Config.World.RailHeight
	WorldBuilder.Ring("CargoTrack", radius, 6.5, 0.18, CFrame.new(0, 0.14, 0),
		palette.Ink, Enum.Material.SmoothPlastic, world.Geometry, Config.World.RailSegments, false)
	for _, side in ipairs({ -1, 1 }) do
		WorldBuilder.Ring("NeonRail", radius + side * 2.7, 0.4, 0.22, CFrame.new(0, y, 0),
			side == 1 and palette.Mint or palette.Teal, Enum.Material.Neon,
			world.Geometry, Config.World.RailSegments, false)
	end
	WorldBuilder.Ring("HubTrim", 13, 1.5, 0.25, CFrame.new(0, 0.17, 0),
		palette.Teal, Enum.Material.SmoothPlastic, world.Geometry, 48, false)
	WorldBuilder.Part("ReactorBase", Vector3.new(0.65, 11, 11),
		CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), palette.Ink,
		Enum.Material.SmoothPlastic, world.Geometry, Enum.PartType.Cylinder)
	local core = WorldBuilder.Part("SunnyReactor", Vector3.one * 5, CFrame.new(0, 6.5, 0),
		palette.Sun, Enum.Material.Neon, world.Geometry, Enum.PartType.Ball, false)
	local light = Instance.new("PointLight")
	light.Color = palette.Sun
	light.Brightness = 1.6
	light.Range = 25
	light.Parent = core
	for level = 1, 3 do
		WorldBuilder.Ring("ReactorOrbit", 4 + level, 0.2, 0.15,
			CFrame.new(0, 4 + level * 1.8, 0) * CFrame.Angles(math.rad(level * 13), 0, math.rad(15)),
			palette.Mint, Enum.Material.Neon, world.Geometry, 40, false)
	end
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
		local label = WorldBuilder.Billboard(dome, "SHIELD DOME · SAFE", palette.Mint,
			Vector3.new(0, Config.World.DomeRadius + 1.5, 0), 220, 35)
		label.TextSize = 16
		table.insert(world.Domes, { Part = dome, Center = center, Radius = Config.World.DomeRadius })
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
	skyAndPlanet(root)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ArrivalPad"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.3, 10)
	spawn.Position = Vector3.new(0, 0.2, 23)
	spawn.Color = palette.Teal
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = geometry
	WorldBuilder.Billboard(spawn, "WELCOME TO ROT ORBIT", palette.White, Vector3.new(0, 5.5, 0), 300)
	built = { Root = root, Geometry = geometry, Spawn = spawn,
		PlayerBays = {}, RivalBays = {}, Domes = {}, Cargo = folder("CargoRing", root) }
	buildCargoRing(built)
	buildBays(built)
	buildDomes(built)
	root:SetAttribute("Ready", true)
	return built
end

return WorldBuilder
