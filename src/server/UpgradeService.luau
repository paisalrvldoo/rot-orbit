local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local UpgradeService = {}
UpgradeService.__index = UpgradeService

function UpgradeService.new(bases, economy)
	return setmetatable({ Bases = bases, Economy = economy }, UpgradeService)
end

function UpgradeService:Buy(player, name)
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

return UpgradeService
