-- Shared rarity and mutation rules, plus display formatting for catalog and HUD.
local Rarity = {}
Rarity.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "SECRET" }
Rarity.ByName = {
	Common = { Rank = 1, Color = Color3.fromRGB(194, 220, 228), Scale = 0.95, Weight = 52 },
	Rare = { Rank = 2, Color = Color3.fromRGB(65, 170, 255), Scale = 1.05, Weight = 25 },
	Epic = { Rank = 3, Color = Color3.fromRGB(183, 110, 255), Scale = 1.17, Weight = 13 },
	Legendary = { Rank = 4, Color = Color3.fromRGB(255, 204, 65), Scale = 1.3, Weight = 6.5 },
	Mythic = { Rank = 5, Color = Color3.fromRGB(255, 91, 160), Scale = 1.43, Weight = 2.4 },
	Cosmic = { Rank = 6, Color = Color3.fromRGB(69, 255, 226), Scale = 1.8, Weight = 0.9 },
	SECRET = { Rank = 7, Color = Color3.fromRGB(255, 116, 63), Scale = 2.35, Weight = 0.2 },
}

function Rarity.Roll(random)
	local roll = random:NextNumber(0, 100)
	local cumulative = 0
	for _, name in ipairs(Rarity.Order) do
		cumulative += Rarity.ByName[name].Weight
		if roll < cumulative then return name end
	end
	return "SECRET"
end

local Mutation = {}
Mutation.Order = { "Gold", "Diamond", "Neon", "Zero-G", "Aurora", "Supernova" }
Mutation.ByName = {
	Gold = { Multiplier = 2, Chance = 6, Color = Color3.fromRGB(255, 209, 68) },
	Diamond = { Multiplier = 3, Chance = 2, Color = Color3.fromRGB(103, 222, 255) },
	Neon = { Multiplier = 4, Chance = 1, Color = Color3.fromRGB(198, 255, 72) },
	["Zero-G"] = { Multiplier = 5, Chance = 0.45, Color = Color3.fromRGB(171, 139, 255) },
	Aurora = { Multiplier = 7, Chance = 0.25, Color = Color3.fromRGB(80, 255, 189) },
	Supernova = { Multiplier = 10, Chance = 0.15, Color = Color3.fromRGB(255, 128, 78) },
}

function Mutation.Get(name)
	return name and Mutation.ByName[name] or nil
end

function Mutation.Multiplier(name)
	local mutation = Mutation.Get(name)
	return mutation and mutation.Multiplier or 1
end

function Mutation.Roll(random)
	local roll = random:NextNumber(0, 100)
	local cumulative = 0
	for _, name in ipairs(Mutation.Order) do
		cumulative += Mutation.ByName[name].Chance
		if roll < cumulative then return name end
	end
	return nil
end

local Format = {}
local units = { { 1e15, "Q" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Format.Number(value)
	for _, unit in ipairs(units) do
		if math.abs(value) >= unit[1] then
			return (string.format("%.1f%s", value / unit[1], unit[2]):gsub("%.0(%a)$", "%1"))
		end
	end
	return tostring(math.floor(value))
end

function Format.Money(value)
	return "$" .. Format.Number(value)
end

return table.freeze({
	Rarity = table.freeze(Rarity),
	Mutation = table.freeze(Mutation),
	Format = table.freeze(Format),
})
