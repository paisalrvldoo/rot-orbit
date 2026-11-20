-- Tunable gameplay values for ROT ORBIT. Geometry is built in WorldBuilder.
local Config = {
	Title = "ROT ORBIT",
	CatalogCount = 43,
	RarityCount = 7,
	MutationCount = 6,
	StartingCash = 400,
	BaseWalkSpeed = 22,
	BaseCarrySpeed = 15,
	JumpPower = 42,
	Gravity = 115,
	IncomeInterval = 1,
	SnapshotInterval = 1,
	InteractionDistance = 13,
	RetireHoldDuration = 1.3,
	ActionCooldown = 0.2,
	CarryHeight = 4.6,
	CarryTrailLifetime = 0.65,
	SecretDock = { Duration = 0.9, Anticipation = 0.12, Settle = 0.62, StartScale = 0.88, PeakScale = 1.08,
		Drop = 0.3, Tilt = 0.065, Radius = 28 },
	DropLifetime = 35,
	MaxCash = 1e15,
	World = {
		DeckRadius = 132,
		DeckThickness = 6,
		RailRadius = 42,
		RailHeight = 36,
		RailTilt = math.rad(15),
		RailSegments = 84,
		BayRadius = 91,
		PlayerBays = 6,
		RivalBays = 3,
		InitialSlots = 8,
		SlotsPerUpgrade = 2,
		MaxSlots = 20,
		DomeRadius = 14,
		DomeOrbit = 63,
		PlanetPosition = Vector3.new(-110, -190, -330),
		PlanetRadius = 210,
		StarCount = 220,
		StarBandCount = 132,
	},
	Conveyor = {
		SpawnInterval = 4.5,
		Speed = 6.5,
		MaxCapsules = 12,
		HoverHeight = 1.5,
		ModelScale = 2,
		PodScale = 1.65,
		PreviewAffordableCount = 3,
		PreviewDisplayIds = { 8, 13, 18 },
		RareNoticeSeconds = 5,
	},
	Meteor = { Interval = 90, Duration = 20, WarningSeconds = 2.5, ImpactRadius = 9,
		WaveInterval = 2, MeteorsPerWave = 2, FallHeight = 72 },
	Steal = { HoldDuration = 0.7, RefillSeconds = 35 },
	SolarFlare = { Interval = 150, Duration = 20, Multiplier = 2 },
	AuroraSurge = { Interval = 270, Duration = 20 },
	EventLooks = {
		Calm = { Tint = Color3.fromRGB(255, 249, 237), Sky = Color3.fromRGB(199, 222, 237),
			Decay = Color3.fromRGB(255, 212, 167) },
		Meteor = { Tint = Color3.fromRGB(255, 230, 214), Sky = Color3.fromRGB(248, 195, 160),
			Decay = Color3.fromRGB(255, 133, 87) },
		Solar = { Tint = Color3.fromRGB(255, 245, 207), Sky = Color3.fromRGB(255, 229, 158),
			Decay = Color3.fromRGB(255, 180, 83) },
		Aurora = { Tint = Color3.fromRGB(224, 255, 238), Sky = Color3.fromRGB(151, 241, 211),
			Decay = Color3.fromRGB(169, 188, 255) },
	},
	Gremlin = { PatrolFirst = 30, PatrolInterval = 45, PatrolMax = 2, FirstRaid = 75, Interval = 135, Telegraph = 6, Duration = 48, Count = 4, Speed = 9, StunDuration = 3,
		Health = 4, BossHealth = 18, BossEvery = 3, KillReward = 140, BossReward = 1800,
		DefendReward = 600, ZapDamage = 2, ZapRadius = 48, ZapCooldown = 3 },
	Crews = { GlobalRefresh = 60, SwitchCooldown = 15, RewardRadius = 90, KillScore = 10, BossScore = 150, RaidScore = 100,
		KillAssist = 50, BossAssist = 500, Teams = {
			{ Name = "Solar Sporks", Color = Color3.fromRGB(255, 192, 79) },
			{ Name = "Lunar Linguini", Color = Color3.fromRGB(113, 213, 255) },
			{ Name = "Comet Cannoli", Color = Color3.fromRGB(255, 129, 172) },
		} },
	Skills = {
		Order = { "Blink", "Sprint" },
		Blink = { Name = "BLINK", Key = "Q", Cooldown = 9, Distance = 28, CarryDistance = 15 },
		Sprint = { Name = "RUN", Key = "LeftShift", KeyLabel = "SHIFT", Cooldown = 11,
			Duration = 4, Speed = 1.7, CarrySpeed = 1.35 },
		Bomb = { Name = "BOMB", Key = "G", Cooldown = 13, Radius = 13, Damage = 6,
			Distance = 34, Arc = 9, Travel = 0.55, Fuse = 1.5, Arm = 0.65,
			TrapLimit = 2, TrapLifetime = 30, TriggerRadius = 5, Stun = 0.9 },
	},
	Lock = { Duration = 40, Cooldown = 65 },
	Upgrades = {
		WalkSpeed = { BaseCost = 1200, CostGrowth = 2.2, Step = 3, MaxLevel = 5 },
		CarrySpeed = { BaseCost = 1600, CostGrowth = 2.3, Step = 2, MaxLevel = 5 },
		LockDuration = { BaseCost = 2500, CostGrowth = 2.5, Step = 8, MaxLevel = 5 },
		BaySlots = { BaseCost = 4000, CostGrowth = 3, Step = 2, MaxLevel = 4 },
		IncomeBoost = { BaseCost = 10000, CostGrowth = 3, Step = 0.08, MaxLevel = 6 },
	},
	Rebirth = { BaseCost = 100000, CostGrowth = 5, MaxLevel = 15, BonusSlotCap = 4, LockSecondsPerLevel = 3,
		BlinkBonus = 8, CarryBlinkBonus = 4, SupplyEvery = 8,
		FloorColors = { [0] = Color3.fromRGB(207, 238, 240), Color3.fromRGB(204, 241, 218),
			Color3.fromRGB(211, 226, 253), Color3.fromRGB(250, 227, 188), Color3.fromRGB(244, 213, 233) },
		DockRanks = { 2, 3, 3, 4, 4, 5, 5, 6 },
		Multipliers = { 1, 1.5, 2, 3, 4.5, 6, 8, 10 } },
	IndexMilestones = { { Goal = 10, Reward = 5000 }, { Goal = 20, Reward = 50000 },
		{ Goal = 30, Reward = 750000 }, { Goal = 40, Reward = 15000000 } },
	MutationMilestones = { { Goal = 10, Reward = 50000 }, { Goal = 22, Reward = 750000 },
		{ Goal = 33, Reward = 15000000 }, { Goal = 43, Reward = 100000000 } },
	Data = { StoreName = "RotOrbit_v1", AutosaveSeconds = 60, Version = 1, LeaseSeconds = 180,
		OfflineMinSeconds = 60, OfflineMaxSeconds = 7200, OfflineShare = 0.25 },
	Contracts = { Tracks = {
		{ { Kind = "Dock", Goal = 3, Reward = 1200, Title = "Dock 3 brainrots" },
			{ Kind = "Buy", MinRank = 2, Goal = 5, Reward = 8500, Title = "Buy 5 Rare or better" },
			{ Kind = "Buy", MinRank = 3, Goal = 3, Reward = 35000, Title = "Buy 3 Epic or better" },
			{ Kind = "Dock", MinRank = 4, Goal = 3, Reward = 90000, Title = "Dock 3 Legendary or better" },
			{ Kind = "Buy", MinRank = 5, Goal = 3, Reward = 600000, Title = "Buy 3 Mythic or better" } },
		{ { Kind = "Steal", Goal = 2, Reward = 1800, Title = "Steal 2 brainrots" },
			{ Kind = "Steal", Goal = 5, Reward = 6500, Title = "Steal 5 brainrots" },
			{ Kind = "Steal", MinRank = 4, Goal = 2, Reward = 25000, Title = "Steal 2 Legendary or better" },
			{ Kind = "Dock", MinRank = 3, Goal = 6, Reward = 65000, Title = "Dock 6 Epic or better" },
			{ Kind = "Rebirth", Goal = 1, Reward = 9000, Title = "Complete a rebirth" } },
		{ { Kind = "SurviveMeteor", Goal = 1, Reward = 3000, Title = "Survive a shower holding cargo" },
			{ Kind = "Zap", Goal = 3, Reward = 4500, Title = "Zap gremlins 3 times" },
			{ Kind = "SurviveMeteor", MinRank = 5, Goal = 1, Reward = 120000, Title = "Shelter a Mythic through meteors" },
			{ Kind = "Zap", Goal = 5, Reward = 21000, Title = "Zap gremlins 5 times" },
			{ Kind = "SurviveMeteor", MinRank = 4, Goal = 3, Reward = 200000, Title = "Shelter Legendary cargo 3 times" } },
	} },
	Palette = {
	-- Dark station metal lets the teal and gold orbit guides read on phones.
	Deck = Color3.fromRGB(38, 46, 57),
		Teal = Color3.fromRGB(17, 183, 186),
		Mint = Color3.fromRGB(104, 255, 222),
		Ink = Color3.fromRGB(11, 31, 52),
		Muted = Color3.fromRGB(150, 185, 195),
		Sun = Color3.fromRGB(255, 192, 79),
		Planet = Color3.fromRGB(248, 117, 42),
		White = Color3.fromRGB(250, 253, 255),
	},
}

function Config.World.RailPlane()
	return CFrame.new(0, Config.World.RailHeight, 0) * CFrame.Angles(Config.World.RailTilt, 0, 0)
end

function Config.World.RailFrame(angle, radius, height)
	return Config.World.RailPlane() * CFrame.Angles(0, -angle, 0) * CFrame.new(radius, height, 0)
end

-- One arrival view shared by live Play and the Studio phone review. Look up
-- along the ring rather than down across a mostly empty station floor.
function Config.World.SpawnFrame()
	return CFrame.lookAt(Vector3.new(0, 0.2, 54), Vector3.new(0, 0.2, 0))
end

function Config.World.SpawnCamera()
	return CFrame.lookAt(Vector3.new(0, 11, 72), Vector3.new(0, 20, -2))
end

function Config.Rebirth.Cost(level)
	return Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ level
end

function Config.Rebirth.Multiplier(level)
	local multipliers = Config.Rebirth.Multipliers
	return multipliers[level + 1] or (multipliers[#multipliers] + (level + 1 - #multipliers) * 2)
end

function Config.Rebirth.BonusSlots(level)
	return level == 0 and 0 or math.min(level + 1, Config.Rebirth.BonusSlotCap)
end

function Config.Rebirth.NextUnlock(level)
	local rewards = { "2 pods + mint bay", "Blink+ + blue bay", "Mythic supply", "Orbit Ace aura" }
	return rewards[level + 1] or "+3s shield + permanent income"
end

function Config.Rebirth.BlinkDistance(level, carrying)
	local skill = Config.Skills.Blink
	return (carrying and skill.CarryDistance or skill.Distance)
		+ (level >= 2 and (carrying and Config.Rebirth.CarryBlinkBonus or Config.Rebirth.BlinkBonus) or 0)
end

function Config.Rebirth.RequiredRank(level)
	local ranks = Config.Rebirth.DockRanks
	return ranks[math.min(level + 1, #ranks)]
end

return table.freeze(Config)
