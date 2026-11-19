-- Screen edges carry the controls; the centre stays clear for the 3D station.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("Format"))
local Remotes = require(shared:WaitForChild("Remotes"))
local EventBanner = require(script.Parent:WaitForChild("EventBanner"))
local HudController = {}

function HudController.Text(parent, name, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Config.Palette.White
	label.TextStrokeColor3 = Config.Palette.Ink
	label.TextStrokeTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.Parent = parent
	return label
end

function HudController.Start()
	local player = Players.LocalPlayer
	local network = Remotes.Get()
	local screen = Instance.new("ScreenGui")
	screen.Name = "RotOrbitHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")
	local gui = Instance.new("Frame")
	gui.Name = "Canvas"
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Position = UDim2.fromScale(0.5, 0.5)
	gui.Size = UDim2.fromOffset(1280, 720)
	gui.BackgroundTransparency = 1
	gui.Parent = screen
	local scale = Instance.new("UIScale", gui)
	local function resize()
		local camera = workspace.CurrentCamera
		if camera then scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720), 0.4, 1.4) end
	end
	local cash = HudController.Text(gui, "Cash", "$400", UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(580, 49), 42, Config.Palette.Mint)
	cash.Font = Enum.Font.GothamBlack
	local detail = HudController.Text(gui, "Income", "ARRIVING AT YOUR DOCK...", UDim2.new(0.5, 0, 0, 63), UDim2.fromOffset(660, 26), 18)
	local logo = HudController.Text(gui, "Logo", "ROT\nORBIT", UDim2.new(1, -85, 0, 28), UDim2.fromOffset(140, 60), 23, Config.Palette.Mint)
	logo.Font = Enum.Font.GothamBlack
	local carrying = HudController.Text(gui, "Carrying", "", UDim2.new(0.5, 0, 0, 140), UDim2.fromOffset(940, 34), 19, Config.Palette.Mint)
	carrying.BackgroundColor3 = Config.Palette.Ink
	carrying.BackgroundTransparency = 0.12
	carrying.Visible = false
	Instance.new("UICorner", carrying).CornerRadius = UDim.new(0, 9)
	HudController.Text(gui, "Counts", Config.CatalogCount .. " BRAINROTS · 7 RARITIES · 5 MUTATIONS · STEAL · LOCK · REBIRTH",
		UDim2.new(0.5, 0, 1, -110), UDim2.fromOffset(930, 24), 15, Config.Palette.Mint)
	local hint = HudController.Text(gui, "Hint", "WASD MOVE  ·  E BUY CARGO  ·  E DOCK ON AN EMPTY PEDESTAL",
		UDim2.new(0.5, 0, 1, -76), UDim2.fromOffset(940, 30), 17)
	local notice = HudController.Text(gui, "Notice", "", UDim2.new(0.5, 0, 1, -156), UDim2.fromOffset(920, 30), 19, Config.Palette.Sun)
	EventBanner.Start(gui, network)
	local state
	local marker = Instance.new("Part")
	marker.Name = "YourBayBeacon"
	marker.Size = Vector3.one
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Parent = workspace
	local beacon = Instance.new("BillboardGui")
	beacon.Adornee = marker
	beacon.Size = UDim2.fromOffset(240, 52)
	beacon.AlwaysOnTop = true
	beacon.Parent = marker
	local home = HudController.Text(beacon, "Home", "YOUR BAY ↓", UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 1), 23, Config.Palette.Mint)
	local function update(snapshot)
		if not snapshot.Ready then return end
		state = snapshot
		cash.Text = Format.Money(snapshot.Cash)
		detail.Text = Format.Money(snapshot.Income) .. "/s  ·  REBIRTH " .. snapshot.Rebirths
			.. "  ·  x" .. snapshot.Multiplier .. " INCOME  ·  BAY " .. string.format("%02d", snapshot.BayIndex)
		carrying.Visible = snapshot.Carrying ~= false
		if snapshot.Carrying then carrying.Text = "CARRYING " .. snapshot.Carrying.Name .. " → RUN TO YOUR BAY" end
		marker.Position = snapshot.BayPosition + Vector3.new(0, 11, 0)
	end
	network.Snapshot.OnClientEvent:Connect(update)
	local noticeVersion = 0
	network.Notice.OnClientEvent:Connect(function(message)
		noticeVersion += 1
		local version = noticeVersion
		notice.Text = message
		task.delay(4, function() if version == noticeVersion then notice.Text = "" end end)
	end)
	network.CashPop.OnClientEvent:Connect(function(position, amount)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Position = position
		anchor.Parent = workspace
		local pop = Instance.new("BillboardGui")
		pop.Adornee = anchor
		pop.Size = UDim2.fromOffset(220, 45)
		pop.AlwaysOnTop = true
		pop.MaxDistance = 90
		pop.Parent = anchor
		local text = HudController.Text(pop, "IncomePop", "+" .. Format.Money(amount), UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 1), 24, Config.Palette.Mint)
		TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 3, 0) }):Play()
		TweenService:Create(text, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(anchor, 1)
	end)
	RunService.RenderStepped:Connect(function()
		resize()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if state and root then
			local distance = math.floor((root.Position - state.BayPosition).Magnitude)
			home.Text = "YOUR BAY " .. string.format("%02d", state.BayIndex) .. " ↓  " .. distance .. "m"
			hint.Text = state.Carrying and "FOLLOW YOUR MINT BAY BEACON  ·  E DOCK ON AN EMPTY PEDESTAL"
				or "WASD MOVE  ·  E BUY CARGO  ·  E DOCK ON AN EMPTY PEDESTAL"
		end
	end)
	task.spawn(function()
		local ok, snapshot = pcall(function() return network.RequestSnapshot:InvokeServer() end)
		if ok then update(snapshot) end
	end)
	return { Gui = gui, Network = network, GetState = function() return state end }
end

return HudController
