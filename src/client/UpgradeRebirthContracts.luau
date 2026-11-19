local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Format = Traits.Format
local Style = {}
local Progression = { Style = Style }

function Style.Text(parent, text, x, y, width, height, size, color)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(width, height)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Config.Palette.White
	label.Text = text
	label.TextSize = size or 18
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 11
	label.Parent = parent
	return label
end

function Style.Button(parent, text, x, y, width, height, callback)
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(x, y)
	button.Size = UDim2.fromOffset(width, height)
	button.Text = text
	button.TextColor3 = Config.Palette.White
	button.BackgroundColor3 = Config.Palette.Teal
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.ZIndex = 12
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	button.Activated:Connect(callback)
	return button
end

function Style.Create(hud, name, title, width, height, x)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(x or 0.5, 0, 0, 185)
	panel.Size = UDim2.fromOffset(width, height)
	panel.BackgroundColor3 = Config.Palette.Ink
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.ZIndex = 10
	panel.Visible = false
	panel.Parent = hud.Gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", panel)
	stroke.Color = Config.Palette.Teal
	stroke.Thickness = 2
	Style.Text(panel, title, 22, 13, width - 70, 36, 26, Config.Palette.Mint)
	Style.Button(panel, "×", width - 48, 14, 32, 32, function() panel.Visible = false end)
	return panel
end

function Progression.StartUpgrades(hud, input)
	local panel = Style.Create(hud, "UpgradePanel", "UPGRADES · BUILD YOUR ORBIT", 560, 430, 0.28)
	local rows = {}
	local definitions = {
		{ "WalkSpeed", "WALK SPEED", "+3 speed when empty-handed" },
		{ "CarrySpeed", "CARRY SPEED", "+2 speed while carrying cargo" },
		{ "LockDuration", "LOCK DURATION", "+8 seconds of bay protection" },
		{ "BaySlots", "BAY SLOTS", "+2 earning pedestals" },
		{ "IncomeBoost", "INCOME BOOST", "+8% pedestal income per level" },
	}
	for index, definition in ipairs(definitions) do
		local name = definition[1]
		local y = 58 + (index - 1) * 51
		local title = Style.Text(panel, definition[2], 22, y, 310, 25, 18)
		Style.Text(panel, definition[3], 22, y + 24, 310, 23, 14, Config.Palette.Muted)
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

function Progression.AddRebirth(hud, input, panel)
	Style.Text(panel, "REBIRTH · PERMANENT INCOME", 22, 320, 510, 24, 18, Config.Palette.Sun)
	local detail = Style.Text(panel, "", 22, 350, 304, 34, 16)
	Style.Text(panel, "Reset cash, upgrades and bay. Keep your discoveries.", 22, 393, 516, 20, 13, Config.Palette.Muted)
	local confirmUntil = 0
	local button = Style.Button(panel, "REBIRTH", 336, 350, 202, 36, function()
		local state = hud.GetState()
		if not state or state.Rebirths >= Config.Rebirth.MaxLevel then return end
		if state.Cash < Config.Rebirth.Cost(state.Rebirths) then return end
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
		local maxed = state.Rebirths >= Config.Rebirth.MaxLevel
		local nextMultiplier = Config.Rebirth.Multiplier(state.Rebirths + 1)
		detail.Text = maxed and ("LEVEL " .. state.Rebirths .. " · x" .. state.Multiplier)
			or ("LEVEL " .. state.Rebirths .. "  ·  x" .. state.Multiplier .. " → x" .. nextMultiplier)
		local cost = Config.Rebirth.Cost(state.Rebirths)
		button.Text = maxed and "MAX REBIRTH"
			or (os.clock() < confirmUntil and "RESET BAY? CONFIRM"
				or ("REBIRTH · " .. Format.Money(cost)))
		button.BackgroundColor3 = not maxed and state.Cash >= cost and Config.Palette.Teal or Color3.fromRGB(43, 67, 83)
	end)
end

function Progression.StartContracts(hud, upgrades)
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

return Progression
