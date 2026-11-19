local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local UpgradeRebirthService = {}
UpgradeRebirthService.__index = UpgradeRebirthService

function UpgradeRebirthService.new(bases, economy)
	return setmetatable({ Bases = bases, Economy = economy }, UpgradeRebirthService)
end

function UpgradeRebirthService:Buy(player, name)
	if type(name) ~= "string" then return end
	local upgrade = Config.Upgrades[name]
	local profile = self.Economy.Profiles[player]
	if not upgrade or not profile then return end
	local level = profile.Upgrades[name] or 0
	if level >= upgrade.MaxLevel then return end
	local cost = math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level)
	if profile.Cash < cost then
		self.Economy.Network.Notice:FireClient(player, "Earn more cash to afford this upgrade.")
		return
	end
	if name == "BaySlots" then
		for _ = 1, Config.World.SlotsPerUpgrade do self.Bases:AddSlot(player) end
	end
	profile.Cash -= cost
	profile.Upgrades[name] = level + 1
	self.Bases:SetSpeed(player)
	self.Economy.Network.Notice:FireClient(player, "UPGRADED! " .. name .. " is now level " .. (level + 1) .. ".")
	self.Economy:Send(player)
end

function UpgradeRebirthService:Perform(player)
	local profile = self.Economy.Profiles[player]
	if not profile or profile.Rebirths >= Config.Rebirth.MaxLevel then return end
	local cost = Config.Rebirth.Cost(profile.Rebirths)
	if profile.Cash < cost then
		self.Economy.Network.Notice:FireClient(player, "You need more cash before rebirthing.")
		return
	end
	local required = Config.Rebirth.RequiredRank(profile.Rebirths)
	if self.Bases:HighestDockRank(player) < required then
		self.Economy.Network.Notice:FireClient(player, "Dock higher rarity cargo to qualify for rebirth.")
		return
	end
	profile.Rebirths += 1
	profile.Multiplier = Config.Rebirth.Multiplier(profile.Rebirths)
	profile.Cash = Config.StartingCash
	profile.Upgrades = {}
	self.Bases:Reset(player)
	for _ = 1, Config.Rebirth.BonusSlots(profile.Rebirths) do self.Bases:AddSlot(player) end
	self.Economy.Network.Notice:FireClient(player, "REBIRTH! Permanent income is now x" .. profile.Multiplier .. ". Your index is kept.")
	self.Economy:Activity(player, "Rebirth")
	self.Economy:Send(player)
end

return UpgradeRebirthService
