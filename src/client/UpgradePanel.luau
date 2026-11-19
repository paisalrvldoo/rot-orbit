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

function UpgradePanel.AddRebirth(hud, input, panel)
	Style.Text(panel, "REBIRTH · PERMANENT INCOME", 22, 320, 510, 24, 18, Config.Palette.Sun)
	local detail = Style.Text(panel, "", 22, 350, 304, 34, 16)
	Style.Text(panel, "Reset cash, upgrades and bay. Keep your discoveries.", 22, 393, 516, 20, 13, Config.Palette.Muted)
	local confirmUntil = 0
	local button = Style.Button(panel, "REBIRTH", 336, 350, 202, 36, function()
		local state = hud.GetState()
		if not state or state.Rebirths >= Config.Rebirth.MaxLevel then return end
		local now = os.clock()
		if now < confirmUntil then
			confirmUntil = 0
			hud.Network.Action:FireServer("Rebirth")
		else confirmUntil = now + 4 end
	end)
	button.TextSize = 14
	input:Register("Rebirth", "REBIRTH [R]", Enum.KeyCode.R, function() panel.Visible = true end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		local state = hud.GetState()
		if not state then return end
		local nextLevel = state.Rebirths + 1
		local multipliers = Config.Rebirth.Multipliers
		local multiplier = multipliers[nextLevel + 1] or (multipliers[#multipliers] + (nextLevel + 1 - #multipliers) * 2)
		detail.Text = "LEVEL " .. state.Rebirths .. " → " .. nextLevel .. " · x" .. multiplier
		button.Text = state.Rebirths >= Config.Rebirth.MaxLevel and "MAX REBIRTH"
			or (os.clock() < confirmUntil and "RESET BAY? CONFIRM"
				or ("REBIRTH · " .. Format.Money(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ state.Rebirths)))
	end)
end

return UpgradePanel
