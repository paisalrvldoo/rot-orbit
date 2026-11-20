-- Screen edges carry the controls; the centre stays clear for the 3D station.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Format = Traits.Format
local Remotes = require(shared:WaitForChild("Remotes"))
local HudController = {}

function HudController.IsCompact()
	local camera = workspace.CurrentCamera
	return UserInputService.TouchEnabled or (camera ~= nil and camera.ViewportSize.Y <= 540)
end

-- Shared mouse, touch and gamepad feedback, used by both HUD and panel controls.
function HudController.ButtonFeedback(button, callback, pendingSeconds)
	button.AutoButtonColor = false
	local scale = Instance.new("UIScale", button)
	local stroke = button:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", button)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local hovered, focused, pressed = false, false, false
	local tween
	local function refresh()
		local blocked = button:GetAttribute("Unavailable") or button:GetAttribute("Pending")
		button.Active = not blocked
		button.Selectable = not blocked
		button.TextTransparency = blocked and 0.35 or 0
		local selected = button:GetAttribute("Selected")
		stroke.Color = (focused or selected) and Config.Palette.Sun
			or (hovered and not blocked and Config.Palette.Mint or button:GetAttribute("AccentColor") or Config.Palette.Teal)
		stroke.Transparency = blocked and 0.65 or 0.15
		stroke.Thickness = (focused or selected) and 3 or 2
		if tween then tween:Cancel() end
		tween = TweenService:Create(scale, TweenInfo.new(pressed and 0.1 or 0.2,
			pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = pressed and not blocked and 0.96 or 1 })
		tween:Play()
	end
	button.MouseEnter:Connect(function() hovered = true; refresh() end)
	button.MouseLeave:Connect(function() hovered = false; pressed = false; refresh() end)
	button.SelectionGained:Connect(function() focused = true; refresh() end)
	button.SelectionLost:Connect(function() focused = false; pressed = false; refresh() end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed = true; refresh()
		end
	end)
	button.InputEnded:Connect(function() pressed = false; refresh() end)
	for _, attribute in ipairs({ "Unavailable", "Pending", "Selected" }) do
		button:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	local function activate()
		if button:GetAttribute("Unavailable") or button:GetAttribute("Pending") then return end
		pressed = false
		if pendingSeconds then
			button:SetAttribute("Pending", true)
			task.delay(pendingSeconds, function()
				if button.Parent then button:SetAttribute("Pending", false) end
			end)
		end
		callback()
	end
	button.Activated:Connect(activate)
	refresh()
	return activate
end

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

function HudController.EventCopy(event, compact)
	if not compact then return event.Text end
	local short = {
		Meteor = "METEOR SHOWER · FIND A SHIELD",
		SolarFlare = "SOLAR FLARE · ALL BAYS x2",
		AuroraSurge = "AURORA SURGE · MUTATED CARGO",
	}
	if event.Name == "Gremlin" then
		return event.Text:find("CAPTAIN") and "CAPTAIN RAID · TAP ZAP" or "GREMLIN RAID · LOCK / ZAP"
	end
	return short[event.Name] or event.Text:gsub("%s*%[L%]", ""):gsub("%s*%[F%]", "")
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
		local compact = HudController.IsCompact()
		banner.Size = UDim2.fromOffset(compact and 680 or 1136, compact and 38 or 49)
		textLimit.MaxTextSize = compact and 24 or 40
		local selected
		for name, event in pairs(active) do
			if event.EndsAt <= now and not event.FrozenSeconds then active[name] = nil
			elseif not selected or (event.Priority or 0) > (selected.Priority or 0) then selected = event end
		end
		banner.Visible = selected ~= nil or nextMeteorAt ~= nil
		if selected then
			local countdown = selected.FrozenSeconds or math.ceil(selected.EndsAt - now)
			local eventText = HudController.EventCopy(selected, compact)
			banner.Text = selected.HideCountdown and eventText or (eventText .. "  ·  " .. countdown .. "s")
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
	local counts = HudController.Text(gui, "Counts", Config.CatalogCount .. " BRAINROTS · " .. Config.RarityCount
		.. " RARITIES · " .. Config.MutationCount .. " MUTATIONS · STEAL · LOCK · REBIRTH",
		UDim2.new(0.5, 0, 1, -120), UDim2.fromOffset(930, 24), 17, Config.Palette.Mint)
	local hint = HudController.Text(gui, "Hint", "",
		UDim2.new(0.5, 0, 1, -91), UDim2.fromOffset(940, 33), 17)
	local boss = HudController.Text(gui, "CaptainHealth", "", UDim2.new(0.5, 0, 0, 156),
		UDim2.fromOffset(640, 36), 22, Config.Palette.Sun)
	boss.BackgroundColor3 = Config.Palette.Ink
	boss.BackgroundTransparency = 0.12
	boss.Visible = false
	local healthFill = Instance.new("Frame")
	healthFill.Name = "CaptainHealthFill"
	healthFill.BackgroundColor3 = Config.Palette.Sun
	healthFill.BorderSizePixel = 0
	healthFill.Position = UDim2.fromScale(0, 0.9)
	healthFill.Size = UDim2.fromScale(1, 0.1)
	healthFill.Parent = boss
	local feed = {}
	local feedLabels = {}
	local feedTweens = {}
	local raidStatus = HudController.Text(gui, "RaidStatus", "", UDim2.fromOffset(134, 326),
		UDim2.fromOffset(236, 30), 17, Config.Palette.Sun)
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
	local function renderFeed(animate)
		for index, label in ipairs(feedLabels) do
			if feedTweens[index] then feedTweens[index]:Cancel() end
			local resting = UDim2.fromOffset(134, 168 + (index - 1) * 50)
			label.Position = resting
			label.Text = feed[index] or ""
			label.Visible = feed[index] ~= nil
			if animate and label.Visible then
				label.Position = resting - UDim2.fromOffset(index == 1 and 18 or 8, 0)
				local tween = TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out, 0, false, (index - 1) * 0.04), { Position = resting })
				feedTweens[index] = tween
				tween:Play()
			end
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
	beacon.Size = UDim2.fromOffset(140, 30)
	beacon.AlwaysOnTop = false
	beacon.MaxDistance = 190
	beacon.Enabled = false
	beacon.Parent = marker
	local home = HudController.Text(beacon, "Home", "YOUR BAY ↓", UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 1), 15, Config.Palette.Mint)
	local function showNotice(message)
		if HudController.IsCompact() then
			message = message:gsub("%s*%[L%]", ""):gsub("%s*%[F%]", "")
		end
		if feed[1] ~= message then table.insert(feed, 1, message) end
		feed[4] = nil
		feedGeneration += 1
		local generation = feedGeneration
		renderFeed(true)
		task.delay(12, function()
			if generation ~= feedGeneration then return end
			table.clear(feed)
			renderFeed()
		end)
	end
	local showedOfflineHaul = false
	local function update(snapshot)
		if not snapshot.Ready then return end
		state = snapshot
		boss.Visible = snapshot.Boss ~= nil
		if snapshot.Boss then
			boss.Text = "CAPTAIN · WAVE " .. snapshot.Boss.Wave .. " · " .. snapshot.Boss.Health .. "/" .. snapshot.Boss.MaxHealth .. " HP"
			healthFill.Size = UDim2.fromScale(snapshot.Boss.Health / snapshot.Boss.MaxHealth, 0.1)
		end
		cash.Text = Format.Money(snapshot.Cash)
		raidStatus.Text = "RAIDS DEFENDED  " .. (snapshot.RaidsDefended or 0)
		save.Text = snapshot.SaveStatus == "SAVED" and "PROGRESS SAVED" or snapshot.SaveStatus
		detail.Text = Format.Money(snapshot.Income) .. "/s  ·  REBIRTH " .. snapshot.Rebirths
			.. "  ·  x" .. snapshot.Multiplier .. " INCOME  ·  BAY " .. string.format("%02d", snapshot.BayIndex)
		carrying.Visible = snapshot.Carrying ~= false
		if snapshot.Carrying then carrying.Text = "CARRYING " .. snapshot.Carrying.Name .. " → RUN TO YOUR BAY" end
		marker.Position = snapshot.BayPosition + Vector3.new(0, 11, 0)
		if snapshot.OfflineHaul and not showedOfflineHaul then
			showedOfflineHaul = true
			showNotice("WHILE YOU WERE AWAY · +" .. Format.Money(snapshot.OfflineHaul))
		end
	end
	network.Snapshot.OnClientEvent:Connect(update)
	network.Notice.OnClientEvent:Connect(showNotice)
	network.Screenshot.OnClientEvent:Connect(function(scene)
		feedGeneration += 1
		feed = scene.Actions or {}
		renderFeed()
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
		local popScale = Instance.new("UIScale", text)
		popScale.Scale = 0.65
		TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }):Play()
		TweenService:Create(anchor, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = position + Vector3.new(0.35, 2.5, 0) }):Play()
		TweenService:Create(text, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In,
			0, false, 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
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
		local compact = HudController.IsCompact() and (not state or state.SaveStatus ~= "STUDIO PREVIEW")
		carrying.Position = compact and UDim2.new(0.45, 0, 1, -59) or UDim2.new(0.5, 0, 1, -91)
		carrying.Size = UDim2.fromOffset(compact and 600 or 940, 33)
		carrying.TextScaled = compact
		hint.Position = carrying.Position
		hint.Size = carrying.Size
		counts.Visible = not compact
		logo.Visible = not compact
		save.Visible = not compact
		raidStatus.Visible = not compact
		for index = 2, #feedLabels do feedLabels[index].Visible = not compact and feed[index] ~= nil end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		hint.Visible = false
		if state and root then
			local distance = math.floor((root.Position - state.BayPosition).Magnitude)
			home.Text = "YOUR BAY " .. string.format("%02d", state.BayIndex) .. " ↓  " .. distance .. "m"
			beacon.Enabled = distance > 24 and state.SaveStatus ~= "STUDIO PREVIEW"
			if state.Carrying and state.SaveStatus ~= "STUDIO PREVIEW" then
				carrying.Text = "CARRYING " .. state.Carrying.Name .. " → "
					.. (distance > 23 and ("YOUR BAY · " .. distance .. "m") or "DOCK AT AN EMPTY PEDESTAL")
			elseif not state.Carrying and (state.Income or 0) == 0 and #state.Inventory == 0 then
				hint.Text = "DOCK A BRAINROT AT YOUR BAY TO START EARNING"
				hint.Visible = state.SaveStatus ~= "STUDIO PREVIEW"
			elseif not state.Carrying and #state.Inventory >= state.Slots then
				hint.Text = "Bay full · retire cargo or upgrade your bay"
				hint.Visible = state.SaveStatus ~= "STUDIO PREVIEW"
			end
		end
	end)
	task.spawn(function()
		local ok, snapshot = pcall(function() return network.RequestSnapshot:InvokeServer() end)
		if ok then update(snapshot) end
	end)
	return { Gui = gui, Network = network, GetState = function() return state end }
end

return HudController
