-- Screen edges carry the controls; the centre stays clear for the 3D station.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Format = Traits.Format
local Remotes = require(shared:WaitForChild("Remotes"))
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

local function startEventBanner(gui, network)
	local banner = Instance.new("TextLabel")
	banner.Name = "EventBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 100)
	banner.Size = UDim2.fromOffset(1136, 49)
	banner.BackgroundColor3 = Config.Palette.Ink
	banner.BackgroundTransparency = 0.08
	banner.BorderSizePixel = 0
	banner.TextColor3 = Config.Palette.Sun
	banner.TextScaled = true
	banner.Font = Enum.Font.GothamBlack
	banner.Visible = false
	banner.Parent = gui
	Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 9)
	local textLimit = Instance.new("UITextSizeConstraint", banner)
	textLimit.MinTextSize = 18
	textLimit.MaxTextSize = 40
	local active = {}
	local nextMeteorAt
	network.Event.OnClientEvent:Connect(function(event)
		if type(event) == "table" and type(event.Name) == "string" then
			active[event.Name] = event
		end
	end)
	network.Snapshot.OnClientEvent:Connect(function(snapshot)
		active = snapshot.Events or active
		if snapshot.Ready then nextMeteorAt = snapshot.NextMeteorAt end
	end)
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local selected
		for name, event in pairs(active) do
			if event.EndsAt <= now and not event.FrozenSeconds then active[name] = nil
			elseif not selected or (event.Priority or 0) > (selected.Priority or 0) then selected = event end
		end
		banner.Visible = selected ~= nil or nextMeteorAt ~= nil
		if selected then
			banner.Text = selected.Text .. "  ·  " .. (selected.FrozenSeconds or math.ceil(selected.EndsAt - now)) .. "s"
			banner.TextColor3 = selected.Color or Config.Palette.Sun
		elseif nextMeteorAt then
			local seconds = math.max(0, math.ceil(nextMeteorAt - now))
			banner.Text = string.format("NEXT METEOR SHOWER  %d:%02d", math.floor(seconds / 60), seconds % 60)
			banner.TextColor3 = Config.Palette.Muted
		end
	end)
	return banner
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
	local cash = HudController.Text(gui, "Cash", "$400", UDim2.new(0.5, 0, 0, 4), UDim2.fromOffset(580, 65), 60, Config.Palette.Mint)
	cash.Font = Enum.Font.GothamBlack
	local detail = HudController.Text(gui, "Income", "ARRIVING AT YOUR DOCK...", UDim2.new(0.5, 0, 0, 67), UDim2.fromOffset(720, 28), 21)
	local logo = HudController.Text(gui, "Logo", "ROT\nORBIT", UDim2.new(1, -85, 0, 28), UDim2.fromOffset(140, 60), 23, Config.Palette.Mint)
	logo.Font = Enum.Font.GothamBlack
	local save = HudController.Text(gui, "SaveStatus", "", UDim2.new(1, -98, 0, 89),
		UDim2.fromOffset(176, 18), 11, Config.Palette.Muted)
	local carrying = HudController.Text(gui, "Carrying", "", UDim2.new(0.5, 0, 1, -91), UDim2.fromOffset(940, 33), 21, Config.Palette.Mint)
	carrying.BackgroundColor3 = Config.Palette.Ink
	carrying.BackgroundTransparency = 0.12
	carrying.Visible = false
	Instance.new("UICorner", carrying).CornerRadius = UDim.new(0, 9)
	HudController.Text(gui, "Counts", Config.CatalogCount .. " BRAINROTS · " .. Config.RarityCount
		.. " RARITIES · " .. Config.MutationCount .. " MUTATIONS · STEAL · LOCK · REBIRTH",
		UDim2.new(0.5, 0, 1, -120), UDim2.fromOffset(930, 24), 17, Config.Palette.Mint)
	local hint = HudController.Text(gui, "Hint", "WASD MOVE  ·  E BUY CARGO  ·  E DOCK ON AN EMPTY PEDESTAL",
		UDim2.new(0.5, 0, 1, -91), UDim2.fromOffset(940, 33), 17)
	local feed = {}
	local feedLabels = {}
	local feedGeneration = 0
	for index = 1, 3 do
		local row = HudController.Text(gui, "Action" .. index, "", UDim2.fromOffset(134, 168 + (index - 1) * 50),
			UDim2.fromOffset(236, 44), 14, index == 1 and Config.Palette.Sun or Config.Palette.White)
		row.BackgroundColor3 = Config.Palette.Ink
		row.BackgroundTransparency = 0.14
		row.TextWrapped = true
		row.Visible = false
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local padding = Instance.new("UIPadding", row)
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		feedLabels[index] = row
	end
	local function renderFeed()
		for index, label in ipairs(feedLabels) do
			label.Text = feed[index] or ""
			label.Visible = feed[index] ~= nil
		end
	end
	startEventBanner(gui, network)
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
		save.Text = snapshot.SaveStatus == "SAVED" and "PROGRESS SAVED" or snapshot.SaveStatus
		detail.Text = Format.Money(snapshot.Income) .. "/s  ·  REBIRTH " .. snapshot.Rebirths
			.. "  ·  x" .. snapshot.Multiplier .. " INCOME  ·  BAY " .. string.format("%02d", snapshot.BayIndex)
		carrying.Visible = snapshot.Carrying ~= false
		hint.Visible = not snapshot.Carrying
		if snapshot.Carrying then carrying.Text = "CARRYING " .. snapshot.Carrying.Name .. " → RUN TO YOUR BAY" end
		marker.Position = snapshot.BayPosition + Vector3.new(0, 11, 0)
	end
	network.Snapshot.OnClientEvent:Connect(update)
	network.Notice.OnClientEvent:Connect(function(message)
		if feed[1] ~= message then table.insert(feed, 1, message) end
		feed[4] = nil
		feedGeneration += 1
		local generation = feedGeneration
		renderFeed()
		task.delay(12, function()
			if generation ~= feedGeneration then return end
			table.clear(feed)
			renderFeed()
		end)
	end)
	local function incomePop(position, amount)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Position = position
		anchor.Parent = workspace
		local pop = Instance.new("BillboardGui")
		pop.Adornee = anchor
		pop.Size = UDim2.fromOffset(106, 29)
		pop.AlwaysOnTop = true
		pop.MaxDistance = 52
		pop.Parent = anchor
		local text = HudController.Text(pop, "IncomePop", "+" .. Format.Money(amount), UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 1), 18, Config.Palette.Mint)
		TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 3, 0) }):Play()
		TweenService:Create(text, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(anchor, 1)
	end
	network.CashPop.OnClientEvent:Connect(function(pops)
		local camera = workspace.CurrentCamera
		if not camera then return end
		for index, pop in ipairs(pops) do
			if (camera.CFrame.Position - pop.Position).Magnitude <= 52 then
				task.delay((index - 1) % 4 * 0.08, incomePop, pop.Position, pop.Amount)
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		resize()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if state and root then
			local distance = math.floor((root.Position - state.BayPosition).Magnitude)
			home.Text = "YOUR BAY " .. string.format("%02d", state.BayIndex) .. " ↓  " .. distance .. "m"
			hint.Text = "E BUY CARGO  ·  E STEAL FROM RIVAL BAYS  ·  E DOCK AT HOME"
		end
	end)
	task.spawn(function()
		local ok, snapshot = pcall(function() return network.RequestSnapshot:InvokeServer() end)
		if ok then update(snapshot) end
	end)
	return { Gui = gui, Network = network, GetState = function() return state end }
end

return HudController
