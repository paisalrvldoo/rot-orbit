local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local SolarFlareEvent = {}
SolarFlareEvent.__index = SolarFlareEvent

function SolarFlareEvent.new(world, economy)
	local self = setmetatable({ World = world, Economy = economy, Active = false }, SolarFlareEvent)
	task.spawn(function()
		while true do
			task.wait(Config.SolarFlare.Interval)
			task.spawn(function() self:Start() end)
		end
	end)
	return self
end

function SolarFlareEvent:Start()
	if self.Active or self.World.Root:GetAttribute("ScreenshotFrozen") then return end
	self.Active = true
	self.Economy.IncomeMultiplier = Config.SolarFlare.Multiplier
	self.World.Root:SetAttribute("SolarFlareActive", true)
	self.Economy:PublishEvent({ Name = "SolarFlare", Text = "SOLAR FLARE! ALL BAYS PAY x2",
		EndsAt = workspace:GetServerTimeNow() + Config.SolarFlare.Duration,
		Priority = 1, Color = Config.Palette.Sun })
	for player in pairs(self.Economy.Profiles) do self.Economy:Send(player) end
	task.wait(Config.SolarFlare.Duration)
	self.Economy.IncomeMultiplier = 1
	self.World.Root:SetAttribute("SolarFlareActive", false)
	self.Active = false
	for player in pairs(self.Economy.Profiles) do self.Economy:Send(player) end
end

return SolarFlareEvent
