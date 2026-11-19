local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("Format"))
local Style = require(script.Parent:WaitForChild("PanelStyle"))
local ContractPanel = {}

function ContractPanel.Start(hud, upgrades)
	local panel = Style.Create(hud, "ContractPanel", "CONTRACTS · 3 LIVE MISSIONS", 500, 430, 0.74)
	local rows = {}
	local detailHeader = panel:FindFirstChildOfClass("TextLabel")
	local quest = Instance.new("Frame")
	quest.Name = "QuestCard"
	quest.Position = UDim2.fromOffset(1024, 168)
	quest.Size = UDim2.fromOffset(240, 226)
	quest.BackgroundColor3 = Config.Palette.Ink
	quest.BackgroundTransparency = 0.12
	quest.BorderSizePixel = 0
	quest.Visible = false
	quest.Parent = hud.Gui
	Instance.new("UICorner", quest).CornerRadius = UDim.new(0, 9)
	local questHeader = Style.Text(quest, "CONTRACTS", 12, 5, 216, 28, 17, Config.Palette.Mint)
	questHeader.ZIndex = 2
	local compactRows = {}
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

		local compactY = 36 + (index - 1) * 60
		local compactTitle = Style.Text(quest, "", 12, compactY, 216, 32, 14)
		compactTitle.ZIndex = 2
		compactTitle.TextWrapped = true
		local compactProgress = Style.Text(quest, "", 12, compactY + 30, 216, 18, 12, Config.Palette.Sun)
		compactProgress.ZIndex = 2
		local compactBar = bar:Clone()
		compactBar:ClearAllChildren()
		compactBar.Position = UDim2.fromOffset(12, compactY + 50)
		compactBar.Size = UDim2.fromOffset(216, 4)
		compactBar.ZIndex = 2
		compactBar.Parent = quest
		local compactFill = fill:Clone()
		compactFill.ZIndex = 3
		compactFill.Parent = compactBar
		compactRows[index] = { Title = compactTitle, Progress = compactProgress, Fill = compactFill }
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
		local indexPanel = hud.Gui:FindFirstChild("IndexPanel")
		quest.Visible = not panel.Visible and not (indexPanel and indexPanel.Visible)
		local completed, available = 0, 0
		for index, contract in ipairs(state.Contracts or {}) do
			completed += contract.Completed
			available += contract.Available
			for _, row in ipairs({ rows[index], compactRows[index] }) do
				row.Title.Text = contract.Title
				row.Progress.Text = contract.Progress .. "/" .. contract.Goal .. "  ·  +" .. Format.Money(contract.Reward)
				row.Fill.Size = UDim2.new(math.clamp(contract.Progress / contract.Goal, 0, 1), 0, 1, 0)
			end
		end
		local title = "CONTRACTS · " .. completed .. "/" .. available .. " DONE"
		detailHeader.Text, questHeader.Text = title, title
	end)
	return panel
end

return ContractPanel
