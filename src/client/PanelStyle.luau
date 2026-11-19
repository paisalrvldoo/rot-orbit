local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local PanelStyle = {}

function PanelStyle.Text(parent, text, x, y, width, height, size, color)
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

function PanelStyle.Button(parent, text, x, y, width, height, callback)
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

function PanelStyle.Create(hud, name, title, width, height, x)
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
	PanelStyle.Text(panel, title, 22, 13, width - 70, 36, 26, Config.Palette.Mint)
	PanelStyle.Button(panel, "×", width - 48, 14, 32, 32, function() panel.Visible = false end)
	return panel
end

return PanelStyle
