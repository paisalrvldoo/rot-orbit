local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local LockService = {}
LockService.__index = LockService

function LockService.new(bases, economy)
	return setmetatable({ Bases = bases, Economy = economy }, LockService)
end

function LockService:IsLocked(bay)
	return (bay.Model:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow()
end

function LockService:Activate(player)
	local state = self.Bases.Players[player]
	local profile = self.Economy.Profiles[player]
	if not state or not profile then return end
	local now = workspace:GetServerTimeNow()
	if now < (state.LockReadyAt or 0) then
		self.Economy.Network.Notice:FireClient(player, "Shield recharging. Check LOCK for the countdown.")
		return
	end
	local duration = Config.Lock.Duration + (profile.Upgrades.LockDuration or 0) * Config.Upgrades.LockDuration.Step
		+ profile.Rebirths * Config.Rebirth.LockSecondsPerLevel
	state.LockUntil = now + duration
	local lockedUntil = state.LockUntil
	state.LockReadyAt = state.LockUntil + Config.Lock.Cooldown
	local bay = state.Bay
	bay.Model:SetAttribute("LockedUntil", state.LockUntil)
	local shield = WorldBuilder.Part("BayLockShield", Vector3.new(68, 56, 68),
		bay.Frame * CFrame.new(0, 0, 12), Config.Palette.Mint, Enum.Material.ForceField,
		bay.Model, Enum.PartType.Ball, false)
	shield.Transparency = 0.78
	shield.CanQuery = false
	self.Economy.Network.Notice:FireClient(player, "BAY LOCKED! Your collection is protected for " .. duration .. "s.")
	self.Economy:Send(player)
	task.delay(duration, function()
		shield:Destroy()
		if bay.Owner == player and bay.Model:GetAttribute("LockedUntil") == lockedUntil then
			bay.Model:SetAttribute("LockedUntil", 0)
		end
	end)
end

return LockService
