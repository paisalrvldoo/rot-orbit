-- Chunky food astronauts, assembled from original primitive geometry.
local shared = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Rarity = Traits.Rarity
local Mutation = Traits.Mutation
local Format = Traits.Format
local Config = require(shared:WaitForChild("Config"))
local BrainrotModel = {}
local rounded = { Bean = true, Olive = true, Leaf = true, Raviolo = true, Penguin = true,
	Cornetto = true, Pastry = true, Quokka = true, Gnocco = true, Arancino = true,
	Stracciatella = true, Pistachio = true, Supernova = true, Dumpling = true,
	Pepper = true, Dragonfruit = true, Basil = true, Meringue = true, Hazelnut = true,
	Zucchini = true, Carrot = true }
local flatCylinder = CFrame.Angles(0, math.pi / 2, 0)

local function label(parent, name, text, y, height, size, color)
	local result = Instance.new("TextLabel")
	result.Name = name
	result.Position = UDim2.fromOffset(5, y)
	result.Size = UDim2.new(1, -10, 0, height)
	result.BackgroundTransparency = 1
	result.Text = text
	result.TextColor3 = color
	result.Font = Enum.Font.GothamBold
	result.TextSize = size
	result.Parent = parent
	return result
end

local function billboard(record, root, scale, forSale)
	local entry = Catalog.Get(record.Id)
	local rarity = Rarity.ByName[entry.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotBillboard"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(248, 90)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.3 * scale, 0)
	gui.MaxDistance = 48
	gui.AlwaysOnTop = false
	gui.Parent = root
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Config.Palette.Ink
	card.BackgroundTransparency = 0.13
	card.BorderSizePixel = 0
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 2
	stroke.Parent = card
	if forSale then
		gui.Size = UDim2.fromOffset(148, 40)
		gui.MaxDistance = 34
		gui.Enabled = false -- BillboardFx reveals only cards with clear screen space.
		corner.CornerRadius = UDim.new(0, 7)
		stroke.Thickness = 1
		local name = label(card, "Name", Catalog.DisplayName(record), 1, 20, 14, rarity.Color)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		label(card, "Price", "BUY " .. Format.Money(Catalog.Price(record)), 20, 18, 13, Config.Palette.White)
		local details = label(card, "Details", string.upper(entry.Rarity)
			.. (record.Mutation and (" · ×" .. Mutation.Multiplier(record.Mutation)) or "")
			.. " · " .. Format.Money(Catalog.Income(record)) .. "/s", 39, 24, 13, Config.Palette.Mint)
		details.Visible = false
		return gui
	end
	local name = label(card, "Name", Catalog.DisplayName(record), 4, 34, 19, Config.Palette.White)
	name.TextScaled = true
	name.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 12
	limit.MaxTextSize = 20
	limit.Parent = name
	label(card, "Rarity", string.upper(entry.Rarity) .. (record.Mutation
		and ("  ·  ×" .. Mutation.Multiplier(record.Mutation)) or ""),
		39, 20, 15, rarity.Color)
	label(card, "Value", Format.Money(Catalog.Income(record)) .. "/s", 61, 24, 17, Config.Palette.Mint)
	return gui
end

function BrainrotModel.Create(record, frame, parent, forSale)
	local entry = assert(Catalog.Get(record.Id), "Unknown brainrot ID")
	local rarity = Rarity.ByName[entry.Rarity]
	local mutation = Mutation.Get(record.Mutation)
	local scale = rarity.Scale * (forSale and Config.Conveyor.ModelScale or 1)
	local bodyColor = mutation and entry.Color:Lerp(mutation.Color, 0.4) or entry.Color
	local accent = mutation and entry.Accent:Lerp(mutation.Color, 0.5) or entry.Accent
	local glow = mutation and mutation.Color or rarity.Color
	local model = Instance.new("Model")
	model.Name = Catalog.DisplayName(record)
	local function make(name, size, position, color, shape, rotation, className)
		local part = Instance.new(className or "Part")
		part.Name = name
		part.Size = size * scale
		part.CFrame = CFrame.new(position * scale) * (rotation or CFrame.identity)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		if part:IsA("Part") then part.Shape = shape or Enum.PartType.Block end
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	local function pill(name, width, height, depth, position, color)
		return make(name, Vector3.new(width, height, depth), position, color, Enum.PartType.Ball)
	end
	-- A straight-sided slice with soft corners and a curved top.
	local function toastSlice(name, width, height, depth, y, z, color)
		local corner = width * 0.16
		make(name, Vector3.new(width - 2 * corner, height, depth), Vector3.new(0, y, z), color)
		make(name, Vector3.new(width, height - 2 * corner, depth - 0.018), Vector3.new(0, y, z), color)
		for _, side in ipairs({ -1, 1 }) do
			for _, endY in ipairs({ -1, 1 }) do
				make(name, Vector3.new(depth - 0.036, corner * 2, corner * 2),
					Vector3.new(side * (width / 2 - corner), y + endY * (height / 2 - corner), z),
					color, Enum.PartType.Cylinder, flatCylinder)
			end
			pill(name, width * 0.54, height * 0.32, depth, Vector3.new(side * width * 0.21,
				y + height * 0.39, z), color)
		end
	end
	local function orbit(radius, y, color, tilt)
		for index = 1, 14 do
			local angle = index * math.pi * 2 / 14
			local localFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, tilt or 0)
				* CFrame.Angles(0, -angle, 0) * CFrame.new(radius, 0, 0)
			local part = make("OrbitCharm", Vector3.new(0.13, 0.13, radius * 0.46),
				localFrame.Position, color, nil, localFrame.Rotation)
			part.Material = Enum.Material.Neon
			part.CastShadow = false
		end
	end
	local root = make("Root", Vector3.one * 0.4, Vector3.zero, Config.Palette.White)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root
	local kind = entry.Kind
	local isToast = kind == "Toast" or kind == "Bruschetta"
	local bodySize = Vector3.new(2.2, 2.55, 1.7)
	if isToast then bodySize = Vector3.new(2.62, 2.5, 1.36) end
	if kind == "Zucchini" or kind == "Maccherone" then bodySize = Vector3.new(1.95, 2.95, 1.65) end
	if kind == "Carrot" then bodySize = Vector3.new(1.4, 3.0, 1.4) end
	if kind == "Biscotto" then bodySize = Vector3.new(2.1, 2.9, 0.9) end
	if isToast then
		toastSlice("BakedCrust", bodySize.X, bodySize.Y, bodySize.Z, 1.87, 0, accent)
		toastSlice("GoldenCrumb", bodySize.X - 0.36, bodySize.Y - 0.35, 0.19, 1.90, -0.64, bodyColor)
	else
		local ball = rounded[kind]
		local size = ball and bodySize or Vector3.new(bodySize.Y, bodySize.X, bodySize.Z)
		make("Body", size, Vector3.new(0, 1.8, 0), bodyColor,
			ball and Enum.PartType.Ball or Enum.PartType.Cylinder,
			not ball and CFrame.Angles(0, 0, math.pi / 2) or nil)
	end
	for _, side in ipairs({ -1, 1 }) do
		local ankle = Vector3.new(side * 0.7, 0.48, 0.04)
		pill("SuitLeg", 0.49, 0.9, 0.56, ankle + Vector3.new(0, 0.2, 0), accent)
		pill("MoonBoot", 0.88, 0.56, 1.23, ankle + Vector3.new(0, -0.18, -0.18), accent)
		pill("BootToe", 0.69, 0.34, 0.57, ankle + Vector3.new(0, -0.12, -0.54), Config.Palette.White)
		local hand = Vector3.new(side * (isToast and 1.58 or 1.39), side == -1 and 1.57 or 1.76, -0.09)
		pill("SuitSleeve", 0.64, 0.73, 0.7, hand + Vector3.new(-side * 0.14, 0.22, 0.13), accent)
		pill("Mitten", 0.59, 0.62, 0.67, hand, Config.Palette.White)
		pill("GloveThumb", 0.26, 0.37, 0.34, hand + Vector3.new(-side * 0.19, -0.04, -0.23), Config.Palette.White)
	end
	-- Each catalog kind has its own recognizable silhouette or food detail.
	if isToast then
		if kind == "Bruschetta" then
			make("Blackhole", Vector3.new(0.8, 0.8, 0.15), Vector3.new(0, 1.1, -0.65),
				Config.Palette.Ink, Enum.PartType.Ball)
			orbit(2, 1.1, accent, 0.2)
		else
			make("ButterVisorPeak", Vector3.new(1.05, 0.25, 0.68), Vector3.new(-0.38, 3.19, -0.47),
				Config.Palette.Sun, nil, CFrame.Angles(-0.15, -0.22, 0.19))
			pill("JamBadge", 0.54, 0.39, 0.16, Vector3.new(0, 0.99, -0.78), Color3.fromRGB(235, 77, 109))
			local radio = make("ToasterRadio", Vector3.new(1.5, 1.29, 0.73), Vector3.new(0, 1.85, 0.92),
				Color3.fromRGB(98, 127, 149))
			radio.Material = Enum.Material.Metal
			for _, side in ipairs({ -1, 1 }) do
				pill("ToasterCoil", 0.24, 0.8, 0.1, Vector3.new(side * 0.35, 1.93, 1.3),
					Color3.fromRGB(255, 164, 71)).Material = Enum.Material.Neon
			end
		end
	elseif kind == "Leaf" then
		for index = -2, 2 do
			local tilt = CFrame.Angles(0, 0, -index * 0.36)
			local y = 3.17 - math.abs(index) * 0.15
			make("LettuceCrown", Vector3.new(0.81, 1.5, 0.59), Vector3.new(index * 0.51, y, 0.24),
				bodyColor:Lerp(accent, 0.18 + math.abs(index) * 0.39), Enum.PartType.Ball, tilt)
			make("LeafVein", Vector3.new(0.10, 0.86, 0.14), Vector3.new(index * 0.53, y + 0.06, -0.05),
				accent, Enum.PartType.Ball, tilt)
		end
	elseif kind == "Raviolo" or kind == "Gnocco" then
		if kind == "Raviolo" then
			-- A stuffed pasta pillow, with crimped edges outside the eyes.
			pill("RavioliPillow", 2.48, 2.45, 1.49, Vector3.new(0, 1.83, 0.04), bodyColor)
			for _, side in ipairs({ -1, 1 }) do
				for index = -2, 2 do
					pill("PastaCrimp", 0.43, 0.39, 0.7,
						Vector3.new(side * 1.16, 1.8 + index * 0.43, 0), accent)
					pill("PastaCrimp", 0.4, 0.4, 0.7,
						Vector3.new(index * 0.43, 1.8 + side * 1.07, 0), accent)
				end
			end
			pill("SauceMedallion", 0.63, 0.39, 0.15, Vector3.new(0, 1.01, -0.79), accent)
		else
			for index = -2, 2 do
				make("PastaRidge", Vector3.new(0.16, 0.53, 0.17),
					Vector3.new(index * 0.34, 1.0, -0.67), accent, Enum.PartType.Ball,
					CFrame.Angles(0, 0, -0.25))
			end
		end
	elseif kind == "Cheese" or kind == "Gorgonzola" then
		for index = 1, 5 do
			make("CheeseSpot", Vector3.new(0.31, 0.3, 0.13),
				Vector3.new(math.sin(index * 2.1) * 0.85, 0.85 + index * 0.39, -0.9), accent, Enum.PartType.Ball)
		end
	elseif kind == "Cannoli" or kind == "Sausage" or kind == "Maccherone" then
		for _, side in ipairs({ -1, 1 }) do
			make("PastaEnd", Vector3.new(1.45, 0.55, 1.45), Vector3.new(0, 1.8 + side * 1.28, 0),
				accent, Enum.PartType.Ball)
		end
		if kind == "Sausage" then orbit(2.3, 1.4, accent, 0.18) end
		if kind == "Maccherone" then
			make("TubeOpening", Vector3.new(0.8, 0.12, 0.8), Vector3.new(0, 3.27, 0), Config.Palette.Ink)
		end
	elseif kind == "Satellite" then
		for _, side in ipairs({ -1, 1 }) do
			make("PanelStrut", Vector3.new(1.4, 0.22, 0.32), Vector3.new(side * 1.25, 2.2, 0.2), accent)
			make("SolarPanel", Vector3.new(1.7, 1.25, 0.2), Vector3.new(side * 2.2, 2.2, 0.2), Config.Palette.Ink)
			for cell = 1, 3 do
				make("SolarCell", Vector3.new(0.35, 1.0, 0.06), Vector3.new(side * 2.2 + (cell - 2) * 0.5, 2.2, 0.05), accent)
			end
		end
		local dishTilt = CFrame.Angles(-0.48, -0.3, 0.15)
		local dish = make("CiabattaDish", Vector3.new(1.42, 0.27, 1.42),
			Vector3.new(-0.54, 3.26, 0.13), Config.Palette.White, Enum.PartType.Ball, dishTilt)
		dish.Material = Enum.Material.Metal
		pill("DishBowl", 0.94, 0.13, 0.94, Vector3.new(-0.54, 3.4, 0.08), accent)
		make("DishFeed", Vector3.new(0.11, 0.48, 0.11), Vector3.new(-0.54, 3.55, 0.08), accent)
		pill("DishSignal", 0.22, 0.22, 0.22, Vector3.new(-0.54, 3.82, 0.08), glow).Material = Enum.Material.Neon
	elseif kind == "Penguin" then
		make("WhiteBelly", Vector3.new(1.55, 1.9, 0.2), Vector3.new(0, 1.65, -0.79), Config.Palette.White, Enum.PartType.Ball)
		make("TurboBeak", Vector3.new(0.62, 0.25, 0.4), Vector3.new(0, 1.9, -1.04), accent)
		for _, side in ipairs({ -1, 1 }) do
			make("TurboFlipper", Vector3.new(0.65, 1.48, 0.61), Vector3.new(side * 1.4, 1.63, 0.21),
				bodyColor, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.42))
			make("PilotGoggleRim", Vector3.new(0.87, 0.98, 0.17), Vector3.new(side * 0.48, 2.23, -0.89),
				accent, Enum.PartType.Ball).Material = Enum.Material.Metal
			pill("TurboSki", 0.93, 0.24, 1.87, Vector3.new(side * 0.7, 0.08, -0.3), accent)
		end
	elseif kind == "Nacho" or kind == "Quesadilla" then
		make("TriangleCrown", Vector3.new(2.6, 1.2, 1.9), Vector3.new(0, 3.05, 0), accent,
			nil, CFrame.Angles(0, math.pi, 0), "WedgePart")
	elseif kind == "Cornetto" then
		for _, side in ipairs({ -1, 1 }) do
			make("CroissantHorn", Vector3.new(1.0, 1.4, 0.85), Vector3.new(side * 1.15, 2.4, 0),
				bodyColor, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.7))
			make("CroissantTip", Vector3.new(0.83, 0.53, 0.65), Vector3.new(side * 1.64, 2.91, -0.1),
				side == 1 and accent or bodyColor, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.24))
			make("PastryFold", Vector3.new(0.16, 0.61, 0.13), Vector3.new(side * 1.14, 2.58, -0.43),
				accent, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.7))
		end
		for index = -1, 1 do
			make("ToastyStripe", Vector3.new(0.15, 0.51, 0.15), Vector3.new(index * 0.49, 1.02, -0.67),
				accent, Enum.PartType.Ball, CFrame.Angles(0, 0, -0.2))
		end
	elseif kind == "Zucchini" then
		pill("VeggieStem", 0.55, 0.58, 0.55, Vector3.new(0, 3.33, 0), accent)
		for _, side in ipairs({ -1, 1 }) do
			make("SquashStripe", Vector3.new(0.24, 2.54, 0.42), Vector3.new(side * 0.65, 1.81, -0.35),
				accent, Enum.PartType.Ball, CFrame.Angles(0, 0, side * 0.07))
		end
	elseif kind == "Gelato" then
		for index = 1, 3 do
			make("GelatoScoop", Vector3.one * 1.1, Vector3.new((index - 2) * 0.66, 3.05, 0),
				index == 2 and accent or bodyColor, Enum.PartType.Ball)
		end
	elseif kind == "Pastry" or kind == "Panettone" then
		make("BakeryDome", Vector3.new(2.4, 1.1, 1.9), Vector3.new(0, 3, 0), bodyColor, Enum.PartType.Ball)
		for index = 1, 5 do
			make("SugarChip", Vector3.new(0.2, 0.2, 0.13), Vector3.new(math.sin(index * 2) * 0.8,
				1.0 + index * 0.39, -0.88), accent)
		end
	elseif kind == "Spaghetti" then
		for index = 1, 7 do
			make("SpaceNoodle", Vector3.new(0.22, 1.3, 0.3), Vector3.new((index - 4) * 0.27, 3, 0),
				bodyColor, nil, CFrame.Angles(0, 0, math.sin(index) * 0.4))
		end
	elseif kind == "Quokka" then
		for _, side in ipairs({ -1, 1 }) do
			make("QuokkaEar", Vector3.new(0.9, 1.1, 0.55), Vector3.new(side * 0.92, 3.03, 0), bodyColor, Enum.PartType.Ball)
			make("EarCentre", Vector3.new(0.48, 0.7, 0.14), Vector3.new(side * 0.92, 3.06, -0.25), accent, Enum.PartType.Ball)
		end
	elseif kind == "Risotto" then
		make("RocketNose", Vector3.new(1.5, 1.1, 1.4), Vector3.new(0, 3.16, 0), accent, Enum.PartType.Ball)
		for _, side in ipairs({ -1, 1 }) do
			make("RiceFin", Vector3.new(0.7, 1.3, 1.1), Vector3.new(side * 1.22, 0.85, 0.2), accent,
				nil, nil, "WedgePart")
		end
	elseif kind == "Cappuccino" then
		for _, y in ipairs({ 1.3, 2.5 }) do
			make("CupHandle", Vector3.new(1, 0.25, 0.4), Vector3.new(1.4, y, 0), bodyColor)
		end
		make("HandleSide", Vector3.new(0.25, 1.3, 0.4), Vector3.new(1.8, 1.9, 0), bodyColor)
		make("MilkFoam", Vector3.new(2.2, 0.4, 1.7), Vector3.new(0, 3.1, 0), Config.Palette.White, Enum.PartType.Ball)
	elseif kind == "Tiramisu" then
		for index = 1, 3 do
			make("CreamLayer", Vector3.new(2.28, 0.21, 1.78), Vector3.new(0, 0.8 + index * 0.65, 0),
				Color3.fromRGB(255, 231, 191))
		end
	elseif kind == "Arancino" or kind == "Supernova" then
		for index = 1, 8 do
			local angle = index * math.pi / 4
			local ray = make("SolarRay", Vector3.new(0.28, 0.8, 0.25),
				Vector3.new(math.sin(angle) * 1.65, 1.8 + math.cos(angle) * 1.65, 0.3),
				accent, nil, CFrame.Angles(0, 0, -angle))
			if kind == "Supernova" then ray.Material = Enum.Material.Neon end
		end
		if kind == "Supernova" then
			make("SupernovaCape", Vector3.new(2.5, 2.7, 0.2), Vector3.new(0, 1.6, 0.85), accent)
			orbit(2.5, 2, glow, 0.28)
		end
	elseif kind == "Stracciatella" then
		for index = 1, 6 do
			make("ChocolateChip", Vector3.new(0.17, 0.24, 0.13), Vector3.new(math.cos(index * 2.4) * 0.8,
				0.7 + index * 0.39, -0.75), accent, nil, CFrame.Angles(0, 0, index))
		end
	elseif kind == "Pistachio" then
		make("PistachioShell", Vector3.new(2.55, 1.4, 1.9), Vector3.new(0, 2.95, 0.1), accent, Enum.PartType.Ball)
	elseif kind == "Biscotto" then
		for index = 1, 6 do
			make("CookieChip", Vector3.one * 0.22, Vector3.new(math.sin(index * 2) * 0.75,
				0.7 + index * 0.42, -0.51), accent, Enum.PartType.Ball)
		end
	elseif kind == "Carrot" or kind == "Basil" then
		for index = -1, 1 do
			make("LeafThruster", Vector3.new(0.55, 1.4, 0.5), Vector3.new(index * 0.6, 3.5, 0),
				accent, Enum.PartType.Ball, CFrame.Angles(0, 0, -index * 0.5))
		end
		if kind == "Basil" then
			make("LeafWings", Vector3.new(3.6, 1.2, 0.45), Vector3.new(0, 1.7, 0.7), accent, Enum.PartType.Ball)
		end
	elseif kind == "Pretzel" then
		for _, side in ipairs({ -1, 1 }) do
			for index = 1, 10 do
				local angle = index * math.pi / 5
				make("PretzelLoop", Vector3.one * 0.42,
					Vector3.new(side * 0.8 + math.cos(angle) * 0.8, 3.3 + math.sin(angle) * 0.75, 0),
					bodyColor, Enum.PartType.Ball)
			end
		end
	elseif kind == "Dumpling" then
		for index = -2, 2 do
			make("DumplingPleat", Vector3.new(0.25, 0.7, 1.2), Vector3.new(index * 0.43, 3.0, 0), accent)
		end
	elseif kind == "Pepper" then
		make("CurvedStem", Vector3.new(0.45, 0.8, 0.45), Vector3.new(0, 3.4, 0), accent,
			nil, CFrame.Angles(0, 0, 0.4))
		make("PepperVisor", Vector3.new(2.2, 0.18, 0.3), Vector3.new(0, 2.7, -0.9), accent)
	elseif kind == "Tagliatelle" then
		for index = -2, 2 do
			make("RibbonNoodle", Vector3.new(0.42, 2.1, 0.2), Vector3.new(index * 0.48, 3.1, 0.3),
				bodyColor, nil, CFrame.Angles(0, 0, index * 0.16))
		end
	elseif kind == "Espresso" then
		make("Saucer", Vector3.new(3.5, 0.2, 2.6), Vector3.new(0, 0.65, 0), accent, Enum.PartType.Ball)
		make("Crema", Vector3.new(2.2, 0.28, 1.7), Vector3.new(0, 3.1, 0), accent)
		orbit(1.7, 3.6, glow, 0.4)
	elseif kind == "Dragonfruit" then
		for index = 1, 7 do
			local angle = index * math.pi * 2 / 7
			make("DragonScale", Vector3.new(0.6, 1.0, 0.5),
				Vector3.new(math.sin(angle) * 1.2, 2.6, math.cos(angle) * 0.9), accent,
				nil, CFrame.Angles(0, angle, 0.4), "WedgePart")
		end
	elseif kind == "Meringue" then
		for index = 1, 4 do
			make("SugarSwirl", Vector3.new(2.3 - index * 0.4, 0.5, 1.9 - index * 0.3),
				Vector3.new(0, 2.8 + index * 0.35, 0), index % 2 == 0 and accent or bodyColor, Enum.PartType.Ball)
		end
	elseif kind == "Ringlet" then
		orbit(2.2, 2.7, accent, 0.65)
		orbit(2.6, 1.5, bodyColor, -0.65)
	elseif kind == "Hazelnut" then
		make("NutShell", Vector3.new(2.6, 1.6, 2.1), Vector3.new(0, 1.2, 0.2), accent, Enum.PartType.Ball)
		for _, side in ipairs({ -1, 1 }) do
			make("CometHorn", Vector3.new(0.45, 1.6, 0.4), Vector3.new(side * 1.1, 3.4, 0), glow,
				nil, CFrame.Angles(0, 0, -side * 0.35))
		end
	elseif kind == "Emperor" then
		make("ImperialCape", Vector3.new(3.1, 3.0, 0.3), Vector3.new(0, 1.7, 0.85), accent)
		make("SceptreGrip", Vector3.new(0.65, 0.27, 0.35), Vector3.new(1.55, 1.8, 0), accent)
		make("Sceptre", Vector3.new(0.18, 3.8, 0.18), Vector3.new(1.8, 2.1, 0), glow)
		make("SceptreStar", Vector3.one * 0.8, Vector3.new(1.8, 3.94, 0), glow, Enum.PartType.Ball)
	elseif kind == "Bean" or kind == "Olive" then
		if kind == "Bean" then
			pill("BeanCurve", 1.31, 2.48, 1.54, Vector3.new(-0.48, 1.79, 0.15), bodyColor)
			pill("BeanCheek", 0.74, 0.67, 0.48, Vector3.new(0.59, 1.53, -0.67), bodyColor:Lerp(accent, 0.24))
			local dish = make("MoonBeanDish", Vector3.new(0.97, 0.97, 0.22), Vector3.new(-0.77, 3.15, 0.13),
				accent, Enum.PartType.Ball, CFrame.Angles(-0.5, -0.36, 0))
			dish.Material = Enum.Material.Metal
			pill("DishReceiver", 0.17, 0.25, 0.17, Vector3.new(-0.82, 3.28, -0.15), glow).Material = Enum.Material.Neon
		else
			pill("PimentoBuckle", 0.8, 0.72, 0.31, Vector3.new(0, 0.98, -0.64), Color3.fromRGB(251, 108, 73))
		end
	end
	-- Rank silhouettes read before a label: food cadets, jetpack pilots,
	-- utensil navigators, comet captains, then shard-crowned space royalty.
	if rarity.Rank == 1 and not isToast then
		pill("LunchboxBackpack", 1.58, 1.34, 0.84, Vector3.new(0, 1.8, 0.95), accent)
	elseif rarity.Rank == 2 or rarity.Rank == 4 then
		for _, side in ipairs({ -1, 1 }) do
			make("EspressoJetTank", Vector3.new(0.65, 1.85, 0.7), Vector3.new(side * 0.8, 1.75, 0.95), accent,
				Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
			local flame = make("JetFlame", Vector3.new(0.42, 0.95, 0.45), Vector3.new(side * 0.8, 0.6, 0.95),
				glow, Enum.PartType.Ball)
			flame.Material, flame.CastShadow = Enum.Material.Neon, false
		end
		if rarity.Rank == 4 then
			make("CaptainScarf", Vector3.new(3.4, 0.45, 0.35), Vector3.new(0.35, 1.25, 0.85),
				glow, nil, CFrame.Angles(0, -0.2, -0.18))
		end
	elseif rarity.Rank == 3 then
		make("AstroForkHandle", Vector3.new(0.16, 2.7, 0.16), Vector3.new(1.7, 1.8, -0.05), Config.Palette.Sun)
		make("AstroForkHead", Vector3.new(0.85, 0.22, 0.25), Vector3.new(1.7, 3.05, -0.05), Config.Palette.Sun)
		for tooth = -1, 1 do
			make("AstroForkProng", Vector3.new(0.15, 0.65, 0.2), Vector3.new(1.7 + tooth * 0.34, 3.4, -0.05),
				Config.Palette.Sun)
		end
	elseif rarity.Rank >= 5 then
		for _, side in ipairs({ -1, 1 }) do
			local pauldron = make("OrbitalShoulder", Vector3.new(1.05, 0.6, 0.9),
				Vector3.new(side * 1.3, 2.5, 0), rarity.Rank == 7 and Config.Palette.Sun or accent,
				nil, CFrame.Angles(0, 0, side * 0.24))
			pauldron.Material = Enum.Material.Metal
			if rarity.Rank >= 6 then
				local shard = make("FloatingCometShard", Vector3.new(0.6, 1.25, 0.6),
					Vector3.new(side * 2.05, 2.7, 0.4), glow, nil,
					CFrame.Angles(0, side * 0.45, -side * 0.45), "WedgePart")
				shard.Material, shard.CastShadow = Enum.Material.Neon, false
			end
		end
	end
	-- Space suits stay behind the face; rank is visible in the outer silhouette.
	if rarity.Rank <= 2 then
		for _, side in ipairs({ -1, 1 }) do
			local ear = make("RadioEarcup", Vector3.new(0.25, 0.67, 0.67),
				Vector3.new(side * (isToast and 1.35 or 1.12), 2.57, 0.03),
				accent, Enum.PartType.Cylinder)
			ear.Material = Enum.Material.Metal
			pill("EarcupLamp", 0.12, 0.21, 0.21,
				Vector3.new(side * ((isToast and 1.35 or 1.12) + 0.14), 2.57, 0.03), glow).Material = Enum.Material.Neon
		end
	elseif rarity.Rank == 3 then
		for _, side in ipairs({ -1, 1 }) do
			make("NavigatorCape", Vector3.new(1.18, 1.72, 0.22), Vector3.new(side * 0.74, 1.53, 0.99),
				accent, nil, CFrame.Angles(0.13, side * 0.22, -side * 0.21), "WedgePart")
		end
	elseif rarity.Rank >= 5 then
		for _, side in ipairs({ -1, 1 }) do
			local wing = make("CometMantle", Vector3.new(0.78, 1.98, 0.42),
				Vector3.new(side * 1.39, 1.62, 0.98), accent, nil,
				CFrame.Angles(0, side * 0.2, -side * 0.42), "WedgePart")
			wing.Material = Enum.Material.Metal
			local edge = make("MantleLight", Vector3.new(0.15, 1.54, 0.17),
				Vector3.new(side * 1.68, 1.76, 0.71), glow, nil,
				CFrame.Angles(0, 0, -side * 0.42))
			edge.Material, edge.CastShadow = Enum.Material.Neon, false
			if rarity.Rank >= 6 then
				local moon = pill("CompanionMoon", 0.55, 0.55, 0.55,
					Vector3.new(side * 2.16, 3.37, 0.28), accent)
				moon.Material = Enum.Material.Metal
				pill("MoonCrater", 0.21, 0.21, 0.08,
					Vector3.new(side * 2.16, 3.4, 0.01), glow).Material = Enum.Material.Neon
			end
		end
	end
	-- Oversized expressive faces remain different even when mutations tint them.
	local faceZ = -bodySize.Z / 2 - (isToast and 0.16 or 0.06)
	local expression = entry.Id % 5
	for _, side in ipairs({ -1, 1 }) do
		make("EyeWhite", Vector3.new(0.67, expression == 2 and side == -1 and 0.2 or 0.77, 0.24),
			Vector3.new(side * 0.48, 2.22 + (side == -1 and expression == 0 and 0.12 or 0), faceZ - 0.03),
			Config.Palette.White, Enum.PartType.Ball)
		make("Pupil", Vector3.new(0.33, expression == 2 and side == -1 and 0.1 or 0.44, 0.12),
			Vector3.new(side * 0.48 + (expression == 1 and -side * 0.07 or 0.04), 2.19, faceZ - 0.18),
			Config.Palette.Ink, Enum.PartType.Ball)
		make("EyeGlint", Vector3.new(0.1, 0.12, 0.05), Vector3.new(side * 0.48 + 0.08, 2.28, faceZ - 0.26),
			Config.Palette.White, Enum.PartType.Ball)
		make("MemeEyebrow", Vector3.new(0.64, 0.13, 0.13), Vector3.new(side * 0.48, 2.76, faceZ - 0.05),
			accent, nil, CFrame.Angles(0, 0, side * (expression == 3 and -0.28 or 0.16)))
		pill("BlushCheek", 0.28, 0.17, 0.10, Vector3.new(side * 0.81, 1.83, faceZ - 0.05),
			bodyColor:Lerp(Color3.fromRGB(255, 141, 158), 0.63))
	end
	if expression == 0 then
		make("AstonishedMouth", Vector3.new(0.48, 0.55, 0.14), Vector3.new(0, 1.51, faceZ - 0.08),
			Config.Palette.Ink, Enum.PartType.Ball)
	else
		make("Smile", Vector3.new(0.89, 0.36, 0.16), Vector3.new(0, 1.57, faceZ - 0.06),
			Config.Palette.Ink, nil, CFrame.Angles(0, 0, expression == 2 and 0.15 or 0))
		for _, side in ipairs({ -1, 1 }) do
			make("SmileCorner", Vector3.new(0.12, 0.22, 0.1), Vector3.new(side * 0.34, 1.67, faceZ - 0.08), Config.Palette.Ink)
		end
		if expression == 1 or expression == 4 then
			for _, x in ipairs({ -0.15, 0.15 }) do
				make("GoofyTooth", Vector3.new(0.22, x < 0 and 0.25 or 0.21, 0.13),
					Vector3.new(x, 1.61, faceZ - 0.16), Config.Palette.White)
			end
		elseif expression == 3 then
			pill("Tongue", 0.38, 0.24, 0.13, Vector3.new(0.15, 1.42, faceZ - 0.17), Color3.fromRGB(255, 130, 162))
		end
	end
	if entry.Id % 4 == 0 then
		local helmet = make("BubbleHelmet", Vector3.new(2.85, 2.1, 2.5), Vector3.new(0, 2.4, 0),
			Color3.fromRGB(188, 246, 255), Enum.PartType.Ball)
		helmet.Material = Enum.Material.Glass
		helmet.Transparency = 0.72
		helmet.CastShadow = false
	elseif entry.Id % 4 == 2 then
		make("PilotCap", Vector3.new(2.3, 0.22, 1.95), Vector3.new(0, 3.1, -0.08), accent)
	end
	make("Antenna", Vector3.new(0.13, 1.3, 0.13), Vector3.new(0.62, 3.4, 0.14), accent)
	local beacon = make("AntennaBeacon", Vector3.one * 0.35, Vector3.new(0.62, 4.05, 0.14), glow, Enum.PartType.Ball)
	beacon.Material = Enum.Material.Neon
	if rarity.Rank >= 6 or record.Mutation == "Zero-G" then orbit(2.1, 1.3, glow, -0.18) end
	if record.Mutation == "Diamond" then
		for _, side in ipairs({ -1, 1 }) do
			make("DiamondCharm", Vector3.new(0.55, 0.7, 0.55), Vector3.new(side * 1.5, 2.8, 0),
				glow, nil, CFrame.Angles(0, 0, side * 0.5), "WedgePart")
		end
	elseif record.Mutation == "Neon" then
		local belt = make("NeonBelt", Vector3.new(2.3, 0.15, 1.8), Vector3.new(0, 1.17, 0), glow)
		belt.Material = Enum.Material.Neon
	elseif record.Mutation == "Supernova" then
		orbit(2.35, 2.3, glow, 0.4)
	elseif record.Mutation == "Aurora" then
		for index = 1, 3 do
			orbit(1.7 + index * 0.25, 0.65 + index * 0.8,
				index == 2 and Color3.fromRGB(186, 142, 255) or glow, index * 0.17)
		end
	end
	if rarity.Rank == 7 then
		for panel = -1, 1 do
			make("RoyalCometCape", Vector3.new(1.0, 2.75, 0.25),
				Vector3.new(panel * 0.83, 1.67, 1.12), panel == 0 and glow or accent, nil,
				CFrame.Angles(0.10, panel * 0.15, -panel * 0.19), "WedgePart")
		end
		orbit(1.62, 3.62, Config.Palette.Sun, 0)
		make("CrownBand", Vector3.new(2.6, 0.24, 1.9), Vector3.new(0, 3.7, 0), Config.Palette.Sun)
		for index = -2, 2 do
			local jewel = make("CrownPoint", Vector3.new(0.32, 0.65, 0.35),
				Vector3.new(index * 0.48, 4.02, -0.6), glow)
			jewel.Material = Enum.Material.Neon
		end
	end
	if rarity.Rank >= 6 then
		local secret = rarity.Rank == 7
		local foot = Instance.new("Attachment", root)
		local sky = Instance.new("Attachment", root)
		foot.Position = Vector3.new(0, 0.08, 0.9) * scale
		sky.Position = Vector3.new(0, secret and 10.5 or 6.5, 0.9) * scale
		local pillar = Instance.new("Beam", root)
		pillar.Name = secret and "SecretLightPillar" or "CosmicBeacon"
		pillar.Attachment0, pillar.Attachment1 = foot, sky
		pillar.FaceCamera = true
		pillar.Width0 = (secret and 2 or 0.85) * scale
		pillar.Width1 = (secret and 1 or 0.12) * scale
		pillar.LightEmission = 1
		pillar.Color = ColorSequence.new(glow, rarity.Color)
		pillar.Transparency = NumberSequence.new(0.67, 1)
	end
	local halo = Instance.new("Highlight")
	halo.Name = "RarityGlow"
	halo.FillColor = glow
	halo.FillTransparency = 0.94
	halo.OutlineColor = glow
	halo.OutlineTransparency = rarity.Rank == 1 and 0.82 or 0.42
	halo.DepthMode = Enum.HighlightDepthMode.Occluded
	halo.Parent = model
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Brightness = 0.2 + rarity.Rank * 0.08
	light.Range = 6 + rarity.Rank
	light.Parent = beacon
	if mutation or rarity.Rank >= 5 or (forSale and rarity.Rank >= 4) then
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, 1.8 * scale, 0)
		attachment.Parent = root
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "MutationAura"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(glow)
		sparks.LightEmission = 0.9
		sparks.Rate = math.min(16, (mutation and 7 or 1) + rarity.Rank)
		sparks.Lifetime = NumberRange.new(0.5, 1.15)
		sparks.Speed = NumberRange.new(0.4, 1.6)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12 + rarity.Rank * 0.025),
			NumberSequenceKeypoint.new(1, 0) })
		sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		sparks.Parent = attachment
	end
	model:SetAttribute("BrainrotId", record.Id)
	model:SetAttribute("Rarity", entry.Rarity)
	model:SetAttribute("RarityRank", rarity.Rank)
	model:SetAttribute("Mutation", record.Mutation or "")
	model:SetAttribute("VisualState", "Pedestal")
	model:SetAttribute("RestFrame", frame)
	model:SetAttribute("VisualScale", scale)
	billboard(record, root, scale, forSale)
	model:PivotTo(frame)
	model.Parent = parent
	CollectionService:AddTag(model, "OrbitBrainrot")
	return model
end

return BrainrotModel
