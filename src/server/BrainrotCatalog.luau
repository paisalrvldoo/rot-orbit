-- The complete original cast lives in this one catalog; clients get a read-only public view.
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Rarity = require(shared:WaitForChild("Rarity"))
local Mutation = require(shared:WaitForChild("Mutation"))
local Catalog = {}

local function brainrot(id, name, rarity, price, income, kind, color, accent)
	return table.freeze({ Id = id, Name = name, Rarity = rarity, Price = price,
		Income = income, Kind = kind, Color = color, Accent = accent })
end

local rgb = Color3.fromRGB
Catalog.Entries = {
	brainrot(1, "Toastronaut", "Common", 100, 7, "Toast", rgb(255, 220, 145), rgb(174, 100, 45)),
	brainrot(2, "Moonbean Mumbler", "Common", 180, 11, "Bean", rgb(154, 218, 166), rgb(65, 137, 123)),
	brainrot(3, "Lunar Lattuga", "Common", 260, 16, "Leaf", rgb(126, 211, 88), rgb(218, 251, 135)),
	brainrot(4, "Rocketto Raviolo", "Common", 340, 22, "Raviolo", rgb(255, 201, 129), rgb(231, 80, 67)),
	brainrot(5, "Meteorino Mozzarella", "Common", 500, 29, "Cheese", rgb(255, 245, 194), rgb(242, 190, 71)),
	brainrot(6, "Orbitello Olivino", "Common", 700, 38, "Olive", rgb(155, 185, 76), rgb(250, 127, 74)),
	brainrot(7, "Cometto Cannolini", "Rare", 1200, 58, "Cannoli", rgb(232, 175, 100), rgb(253, 247, 220)),
	brainrot(8, "Satellina Ciabatta", "Rare", 1800, 79, "Satellite", rgb(220, 179, 124), rgb(102, 199, 251)),
	brainrot(9, "Astro Pinguino Turbo", "Rare", 2500, 108, "Penguin", rgb(47, 63, 94), rgb(255, 163, 64)),
	brainrot(10, "Nebuloso Nachito", "Rare", 3600, 145, "Nacho", rgb(255, 193, 65), rgb(225, 113, 62)),
	brainrot(11, "Cosmo Cornetto", "Rare", 5200, 200, "Cornetto", rgb(250, 183, 85), rgb(146, 92, 62)),
	brainrot(12, "Zero-G Zucchinetta", "Rare", 7500, 270, "Zucchini", rgb(84, 184, 121), rgb(185, 243, 103)),
	brainrot(13, "Gravitone Gelato", "Epic", 14000, 450, "Gelato", rgb(255, 176, 209), rgb(164, 224, 251)),
	brainrot(14, "Orbita Pastafrolla", "Epic", 22000, 650, "Pastry", rgb(255, 218, 140), rgb(222, 123, 176)),
	brainrot(15, "Saturnino Salsiccia", "Epic", 34000, 910, "Sausage", rgb(207, 110, 91), rgb(255, 221, 100)),
	brainrot(16, "Plutone Panettone", "Epic", 51000, 1250, "Panettone", rgb(184, 127, 70), rgb(102, 163, 242)),
	brainrot(17, "Spaghettino Spaziale", "Epic", 77000, 1730, "Spaghetti", rgb(255, 211, 108), rgb(233, 111, 87)),
	brainrot(18, "Quasar Quokkino", "Legendary", 160000, 3300, "Quokka", rgb(209, 169, 231), rgb(252, 197, 218)),
	brainrot(19, "Galattico Gnocco", "Legendary", 250000, 4800, "Gnocco", rgb(233, 241, 174), rgb(151, 205, 177)),
	brainrot(20, "Blackhole Bruschetta", "Legendary", 390000, 6900, "Bruschetta", rgb(203, 145, 98), rgb(117, 94, 193)),
	brainrot(21, "Rockettino Risottone", "Legendary", 610000, 9900, "Risotto", rgb(249, 237, 198), rgb(250, 104, 83)),
	brainrot(22, "Cappuccino Comandante", "Legendary", 950000, 14000, "Cappuccino", rgb(240, 218, 193), rgb(105, 179, 204)),
	brainrot(23, "Nebulina Tiramisu", "Mythic", 2400000, 29500, "Tiramisu", rgb(164, 100, 67), rgb(255, 171, 214)),
	brainrot(24, "Astrale Arancino", "Mythic", 4100000, 43000, "Arancino", rgb(251, 167, 52), rgb(253, 234, 129)),
	brainrot(25, "Martiano Maccherone", "Mythic", 7200000, 63000, "Maccherone", rgb(137, 228, 144), rgb(252, 195, 87)),
	brainrot(26, "Superluna Stracciatella", "Mythic", 12500000, 92000, "Stracciatella", rgb(235, 243, 255), rgb(128, 93, 150)),
	brainrot(27, "Quasarino Quesadillo", "Cosmic", 35000000, 210000, "Quesadilla", rgb(255, 212, 90), rgb(142, 251, 223)),
	brainrot(28, "Pulsar Pistacchione", "Cosmic", 68000000, 340000, "Pistachio", rgb(163, 237, 176), rgb(177, 161, 255)),
	brainrot(29, "Galassia Gorgonzola", "Cosmic", 130000000, 550000, "Gorgonzola", rgb(155, 214, 249), rgb(106, 210, 173)),
	brainrot(30, "Il Supremo Supernova", "SECRET", 600000000, 2400000, "Supernova", rgb(255, 246, 214), rgb(255, 126, 65)),
	-- Append stable IDs so saved collections from the original cast keep their meaning.
	brainrot(31, "Asteroide Biscottino", "Common", 220, 14, "Biscotto",
		rgb(227, 182, 119), rgb(107, 70, 54)),
	brainrot(32, "Carotina Cosmonauta", "Common", 600, 33, "Carrot",
		rgb(255, 145, 62), rgb(100, 208, 119)),
	brainrot(33, "Razzo Pretzellino", "Rare", 2100, 93, "Pretzel",
		rgb(206, 138, 69), rgb(255, 237, 168)),
	brainrot(34, "Lunotto Dumplino", "Rare", 6200, 235, "Dumpling",
		rgb(244, 225, 177), rgb(150, 220, 210)),
	brainrot(35, "Peperone Parabolico", "Epic", 28000, 790, "Pepper",
		rgb(242, 93, 86), rgb(135, 225, 114)),
	brainrot(36, "Tagliatella Teleportina", "Epic", 62000, 1480, "Tagliatelle",
		rgb(255, 219, 110), rgb(121, 192, 255)),
	brainrot(37, "Espressino Eclipse", "Legendary", 470000, 8100, "Espresso",
		rgb(109, 75, 70), rgb(255, 188, 101)),
	brainrot(38, "Draconico Fruttone", "Legendary", 780000, 12100, "Dragonfruit",
		rgb(245, 106, 192), rgb(121, 238, 157)),
	brainrot(39, "Basilico Bellatrix", "Mythic", 5600000, 54000, "Basil",
		rgb(101, 207, 129), rgb(250, 210, 95)),
	brainrot(40, "Meringa Magnetica", "Mythic", 9600000, 79000, "Meringue",
		rgb(249, 224, 255), rgb(162, 159, 255)),
	brainrot(41, "Andromeda Anellino", "Cosmic", 95000000, 440000, "Ringlet",
		rgb(255, 181, 105), rgb(117, 255, 229)),
	brainrot(42, "Nebulone Nocciolone", "Cosmic", 185000000, 740000, "Hazelnut",
		rgb(182, 134, 91), rgb(188, 152, 255)),
	brainrot(43, "Imperatore Infinito", "SECRET", 950000000, 3800000, "Emperor",
		rgb(222, 241, 255), rgb(255, 210, 92)),
}
assert(#Catalog.Entries == Config.CatalogCount, "Update Config and the cast together")

Catalog.ById = {}
Catalog.ByRarity = {}
for _, name in ipairs(Rarity.Order) do Catalog.ByRarity[name] = {} end
for _, entry in ipairs(Catalog.Entries) do
	assert(not Catalog.ById[entry.Id], "Duplicate brainrot ID")
	assert(Rarity.ByName[entry.Rarity], "Unknown rarity")
	Catalog.ById[entry.Id] = entry
	table.insert(Catalog.ByRarity[entry.Rarity], entry)
end

function Catalog.Get(id)
	return Catalog.ById[id]
end

function Catalog.Price(record)
	return math.floor(Catalog.ById[record.Id].Price * Mutation.Multiplier(record.Mutation))
end

function Catalog.Income(record)
	return math.floor(Catalog.ById[record.Id].Income * Mutation.Multiplier(record.Mutation))
end

function Catalog.DisplayName(record)
	local name = Catalog.ById[record.Id].Name
	return record.Mutation and (record.Mutation .. " " .. name) or name
end

function Catalog.Roll(random)
	local choices = Catalog.ByRarity[Rarity.Roll(random)]
	return { Id = choices[random:NextInteger(1, #choices)].Id, Mutation = Mutation.Roll(random) }
end

function Catalog.Public()
	local view = {}
	for _, entry in ipairs(Catalog.Entries) do
		table.insert(view, { Id = entry.Id, Name = entry.Name, Rarity = entry.Rarity,
			Price = entry.Price, Income = entry.Income })
	end
	table.sort(view, function(a, b)
		local rankA, rankB = Rarity.ByName[a.Rarity].Rank, Rarity.ByName[b.Rarity].Rank
		return rankA == rankB and a.Id < b.Id or rankA < rankB
	end)
	return view
end

return table.freeze(Catalog)
