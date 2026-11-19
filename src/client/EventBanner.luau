local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local EventBanner = {}

function EventBanner.Start(gui, network)
	local banner = Instance.new("TextLabel")
	banner.Name = "EventBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 100)
	banner.Size = UDim2.fromOffset(960, 32)
	banner.BackgroundColor3 = Config.Palette.Ink
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.TextColor3 = Config.Palette.Sun
	banner.TextSize = 19
	banner.Font = Enum.Font.GothamBold
	banner.Visible = false
	banner.Parent = gui
	Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 9)
	local active = {}
	network.Event.OnClientEvent:Connect(function(event)
		if type(event) == "table" and type(event.Name) == "string" then
			active[event.Name] = event
		end
	end)
	network.Snapshot.OnClientEvent:Connect(function(snapshot)
		active = snapshot.Events or active
	end)
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local selected
		for name, event in pairs(active) do
			if event.EndsAt <= now and not event.FrozenSeconds then active[name] = nil
			elseif not selected or (event.Priority or 0) > (selected.Priority or 0) then selected = event end
		end
		banner.Visible = selected ~= nil
		if selected then
			banner.Text = selected.Text .. "  ·  " .. (selected.FrozenSeconds or math.ceil(selected.EndsAt - now)) .. "s"
			banner.TextColor3 = selected.Color or Config.Palette.Sun
		end
	end)
	return banner
end

return EventBanner
