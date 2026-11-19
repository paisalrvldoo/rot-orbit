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

return table.freeze(Mutation)
