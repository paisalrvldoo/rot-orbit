local Rarity = {}
Rarity.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "SECRET" }
Rarity.ByName = {
	Common = { Rank = 1, Color = Color3.fromRGB(194, 220, 228), Scale = 0.95, Weight = 52 },
	Rare = { Rank = 2, Color = Color3.fromRGB(65, 170, 255), Scale = 1.05, Weight = 25 },
	Epic = { Rank = 3, Color = Color3.fromRGB(183, 110, 255), Scale = 1.17, Weight = 13 },
	Legendary = { Rank = 4, Color = Color3.fromRGB(255, 204, 65), Scale = 1.3, Weight = 6.5 },
	Mythic = { Rank = 5, Color = Color3.fromRGB(255, 91, 160), Scale = 1.43, Weight = 2.4 },
	Cosmic = { Rank = 6, Color = Color3.fromRGB(69, 255, 226), Scale = 1.6, Weight = 0.9 },
	SECRET = { Rank = 7, Color = Color3.fromRGB(255, 116, 63), Scale = 1.85, Weight = 0.2 },
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

return table.freeze(Rarity)
