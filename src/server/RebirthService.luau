local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local RebirthService = {}
RebirthService.__index = RebirthService

function RebirthService.Multiplier(level)
	local multipliers = Config.Rebirth.Multipliers
	return multipliers[level + 1] or (multipliers[#multipliers] + (level + 1 - #multipliers) * 2)
end

function RebirthService.new(bases, economy)
	return setmetatable({ Bases = bases, Economy = economy }, RebirthService)
end

function RebirthService:Perform(player)
	local profile = self.Economy.Profiles[player]
	if not profile or profile.Rebirths >= Config.Rebirth.MaxLevel then return end
	local cost = Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ profile.Rebirths
	if profile.Cash < cost then
		self.Economy.Network.Notice:FireClient(player, "You need more cash before rebirthing.")
		return
	end
	profile.Rebirths += 1
	profile.Multiplier = RebirthService.Multiplier(profile.Rebirths)
	profile.Cash = Config.StartingCash
	profile.Upgrades = {}
	self.Bases:Reset(player)
	self.Economy.Network.Notice:FireClient(player, "REBIRTH! Permanent income is now x" .. profile.Multiplier .. ". Your index is kept.")
	self.Economy:Activity(player, "Rebirth")
	self.Economy:Send(player)
end

return RebirthService
