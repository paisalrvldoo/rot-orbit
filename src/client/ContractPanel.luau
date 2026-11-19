local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("Format"))
local Style = require(script.Parent:WaitForChild("PanelStyle"))
local ContractPanel = {}

function ContractPanel.Start(hud, upgrades)
	local panel = Style.Create(hud, "ContractPanel", "CONTRACTS · 3 LIVE MISSIONS", 500, 430, 0.74)
	local rows = {}
	for index = 1, 3 do
		local y = 62 + (index - 1) * 108
		local title = Style.Text(panel, "Loading mission...", 22, y, 454, 44, 19)
		title.TextWrapped = true
		local progress = Style.Text(panel, "", 22, y + 46, 454, 24, 16, Config.Palette.Sun)
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(22, y + 77)
		bar.Size = UDim2.fromOffset(454, 7)
		bar.BackgroundColor3 = Color3.fromRGB(43, 67, 83)
		bar.BorderSizePixel = 0
		bar.ZIndex = 11
		bar.Parent = panel
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		local fill = bar:Clone()
		fill.Position = UDim2.fromOffset(0, 0)
		fill.BackgroundColor3 = Config.Palette.Mint
		fill.ZIndex = 12
		fill.Parent = bar
		rows[index] = { Title = title, Progress = progress, Fill = fill }
	end
	Style.Text(panel, "Rewards pay automatically. New missions follow.", 22, 391, 454, 24, 14, Config.Palette.Muted)
	upgrades:GetPropertyChangedSignal("Visible"):Connect(function()
		panel.Visible = upgrades.Visible
		if upgrades.Visible then
			local index = hud.Gui:FindFirstChild("IndexPanel")
			if index then index.Visible = false end
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.3 then return end
		elapsed = 0
		local state = hud.GetState()
		if not state then return end
		for index, contract in ipairs(state.Contracts or {}) do
			local row = rows[index]
			row.Title.Text = contract.Title
			row.Progress.Text = contract.Progress .. "/" .. contract.Goal .. "  ·  REWARD " .. Format.Money(contract.Reward)
			row.Fill.Size = UDim2.new(math.clamp(contract.Progress / contract.Goal, 0, 1), 0, 1, 0)
		end
	end)
	return panel
end

return ContractPanel
