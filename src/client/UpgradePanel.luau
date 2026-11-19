local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("Format"))
local Style = require(script.Parent:WaitForChild("PanelStyle"))
local UpgradePanel = {}

function UpgradePanel.Start(hud, input)
	local panel = Style.Create(hud, "UpgradePanel", "UPGRADES · BUILD YOUR ORBIT", 560, 430, 0.28)
	local rows = {}
	local definitions = {
		{ "WalkSpeed", "WALK SPEED", "+3 speed when empty-handed" },
		{ "CarrySpeed", "CARRY SPEED", "+2 speed while carrying cargo" },
		{ "LockDuration", "LOCK DURATION", "+8 seconds of bay protection" },
		{ "BaySlots", "BAY SLOTS", "+2 earning pedestals" },
	}
	for index, definition in ipairs(definitions) do
		local name = definition[1]
		local y = 58 + (index - 1) * 65
		local title = Style.Text(panel, definition[2], 22, y, 310, 25, 18)
		Style.Text(panel, definition[3], 22, y + 26, 310, 23, 14, Config.Palette.Muted)
		local button = Style.Button(panel, "BUY", 354, y + 4, 184, 40,
			function() hud.Network.Action:FireServer("Upgrade", name) end)
		rows[name] = { Title = title, Button = button, Name = definition[2] }
	end
	input:Register("Upgrades", "UPGRADES [U]", Enum.KeyCode.U, function() panel.Visible = not panel.Visible end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		local state = hud.GetState()
		if not state then return end
		for name, row in pairs(rows) do
			local config = Config.Upgrades[name]
			local level = state.Upgrades[name] or 0
			row.Title.Text = row.Name .. "  " .. level .. "/" .. config.MaxLevel
			local cost = math.floor(config.BaseCost * config.CostGrowth ^ level)
			row.Button.Text = level >= config.MaxLevel and "MAXED" or ("BUY · " .. Format.Money(cost))
			row.Button.BackgroundColor3 = level < config.MaxLevel and state.Cash >= cost
				and Config.Palette.Teal or Color3.fromRGB(43, 67, 83)
		end
	end)
	return panel
end

return UpgradePanel
