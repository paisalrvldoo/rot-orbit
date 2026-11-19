local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Debris = game:GetService("Debris")
local UpgradeRebirthService = {}
UpgradeRebirthService.__index = UpgradeRebirthService

function UpgradeRebirthService.new(bases, economy)
	return setmetatable({ Bases = bases, Economy = economy }, UpgradeRebirthService)
end

function UpgradeRebirthService:Celebrate(player)
	local state = self.Bases.Players[player]
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 7, 0)
	attachment.Parent = state.Bay.Floor
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Config.Palette.Sun, Config.Palette.Mint)
	sparks.Rate = 0
	sparks.Lifetime, sparks.Speed = NumberRange.new(1, 1.6), NumberRange.new(14, 22)
	sparks.Acceleration = Vector3.new(0, -14, 0)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Size = NumberSequence.new(0.45, 0)
	sparks.Parent = attachment
	sparks:Emit(48)
	Debris:AddItem(attachment, 3)
	self.Economy:PublishEvent({ Name = "Rebirth", Text = string.upper(player.DisplayName) .. " REBIRTHED!",
		EndsAt = workspace:GetServerTimeNow() + 5, Priority = 1.25, Color = Config.Palette.Sun, HideCountdown = true })
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
	local state = self.Bases.Players[player]
	if not profile or profile.Demo or not state or state.Loading or state.Closing
		or profile.Rebirths >= Config.Rebirth.MaxLevel then return end
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
	local kept = self.Bases:BestDocked(player)
	profile.Rebirths += 1
	profile.Multiplier = Config.Rebirth.Multiplier(profile.Rebirths)
	profile.Cash = Config.StartingCash
	profile.Upgrades = {}
	self.Bases:Reset(player)
	for _ = 1, Config.Rebirth.BonusSlots(profile.Rebirths) do self.Bases:AddSlot(player) end
	if kept then self.Bases:Restore(player, kept, 1) end
	self.Bases:ApplyRebirthLook(player)
	self:Celebrate(player)
	self.Economy.Network.Notice:FireClient(player, "REBIRTH! x" .. profile.Multiplier
		.. " income · best brainrot kept and earning · index kept.")
	self.Economy:Activity(player, "Rebirth")
	self.Economy:Send(player)
end

return UpgradeRebirthService
