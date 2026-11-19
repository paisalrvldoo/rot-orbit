-- One binding per action, with matching clickable controls for touch and mouse.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local localPlayer = game:GetService("Players").LocalPlayer
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Format = Traits.Format
local HudController = require(script.Parent:WaitForChild("HudController"))
local InputController = {}
InputController.__index = InputController

-- Original glyphs drawn with GUI strokes: no uploaded art or font symbols.
local actionColors = {
	Sprint = { Color3.fromRGB(17, 111, 96), Config.Palette.Mint },
	Blink = { Color3.fromRGB(100, 52, 160), Color3.fromRGB(209, 175, 255) },
	Zap = { Color3.fromRGB(146, 85, 19), Config.Palette.Sun },
}
local actionGlyphs = {
	Sprint = { { 3, 11, 16, 3, 0 }, { 0, 20, 21, 3, 0 }, { 5, 29, 14, 3, 0 },
		{ 23, 14, 15, 4, 42 }, { 23, 25, 15, 4, -42 } },
	Blink = { { 11, 10, 17, 3, -45 }, { 27, 10, 17, 3, 45 },
		{ 11, 30, 17, 3, 45 }, { 27, 30, 17, 3, -45 }, { 20, 20, 5, 16, 18 } },
	Zap = { { 23, 10, 23, 5, -55 }, { 20, 20, 18, 5, 0 }, { 17, 30, 23, 5, -55 } },
}

local function styleAction(button, name)
	local colors = actionColors[name]
	button.BackgroundColor3 = colors[1]
	button:SetAttribute("AccentColor", colors[2])
	local icon = Instance.new("Frame")
	icon.Name = "ActionIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position, icon.Size = UDim2.new(0.5, 0, 0, 8), UDim2.fromOffset(40, 40)
	icon.BackgroundTransparency = 1
	icon.Parent = button
	for _, shape in ipairs(actionGlyphs[name]) do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromOffset(shape[1], shape[2])
		line.Size = UDim2.fromOffset(shape[3], shape[4])
		line.Rotation = shape[5]
		line.BackgroundColor3 = Config.Palette.White
		line.BorderSizePixel = 0
		line.Parent = icon
		Instance.new("UICorner", line).CornerRadius = UDim.new(1, 0)
	end
	local caption = Instance.new("TextLabel")
	caption.Name = "ActionCaption"
	caption.BackgroundTransparency = 1
	caption.TextColor3, caption.Font = Config.Palette.White, Enum.Font.GothamBold
	caption.TextSize = 18
	caption.Parent = button
	local progress = Instance.new("Frame")
	progress.Name, progress.BackgroundTransparency = "CooldownProgress", 1
	progress.Size = UDim2.new(1, 0, 1, 0)
	progress.Parent = button
	for index = 1, 12 do
		local angle = (index - 1) * math.pi / 6 - math.pi / 2
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. index
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5 + math.cos(angle) * 0.45, 0, 0.5 + math.sin(angle) * 0.45, 0)
		tick.Size, tick.Rotation = UDim2.fromOffset(7, 3), math.deg(angle) + 90
		tick.BackgroundColor3, tick.BorderSizePixel = colors[2], 0
		tick.Parent = progress
	end
end

local function updateAction(button, remaining, duration)
	local caption = button:FindFirstChild("ActionCaption")
	caption.Text = button.Text
	button.Text = ""
	caption.TextTransparency = remaining > 0 and 0.2 or 0
	local progress = button:FindFirstChild("CooldownProgress")
	for index = 1, 12 do
		progress:FindFirstChild("Tick" .. index).BackgroundTransparency =
			remaining > 0 and (index <= math.ceil(12 * remaining / duration) and 0.08 or 0.88) or 0.15
	end
	-- The first ready frame restores all twelve perimeter marks.
	button:SetAttribute("CooldownFraction", math.clamp(remaining / duration, 0, 1))
end

function InputController.Start(hud)
	local self = setmetatable({ Hud = hud, Buttons = {}, Order = {} }, InputController)
	self:Register("Lock", "LOCK [L]", Enum.KeyCode.L, function() hud.Network.Action:FireServer("Lock") end)
	self:Register("Zap", "ZAP [F]", Enum.KeyCode.F, function() hud.Network.Action:FireServer("Zap") end)
	for _, name in ipairs(Config.Skills.Order) do
		local definition = Config.Skills[name]
		self:Register(name, definition.Name, Enum.KeyCode[definition.Key], function()
			hud.Network.Action:FireServer("Skill", name)
		end)
	end
	local menu = Instance.new("TextButton")
	menu.Name, menu.Text = "MobileMenu", "MENU"
	menu.AnchorPoint = Vector2.new(0.5, 0)
	menu.TextColor3, menu.BackgroundColor3 = Config.Palette.White, Config.Palette.Ink
	menu.Font, menu.TextSize = Enum.Font.GothamBold, 17
	Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 10)
	menu.Size, menu.Position = UDim2.fromOffset(144, 72), UDim2.fromOffset(96, 156)
	menu.Visible = false
	menu.Parent = hud.Gui
	HudController.ButtonFeedback(menu, function()
		self.MenuOpen = not self.MenuOpen
		if self.MenuOpen then
			for _, name in ipairs({ "UpgradePanel", "IndexPanel", "CrewPanel" }) do
				local panel = hud.Gui:FindFirstChild(name)
				if panel then panel.Visible = false end
			end
		end
	end)
	local lastLayout
	local previous
	RunService.RenderStepped:Connect(function()
		local state = hud.GetState()
		if not state then return end
		local now = workspace:GetServerTimeNow()
		local compact = HudController.IsCompact() and state.SaveStatus ~= "STUDIO PREVIEW"
		for _, name in ipairs({ "UpgradePanel", "IndexPanel", "CrewPanel" }) do
			local panel = hud.Gui:FindFirstChild(name)
			if panel and panel.Visible then self.MenuOpen = false end
		end
		hud.Gui:SetAttribute("MobileMenuOpen", compact and self.MenuOpen == true)
		menu.Visible = compact
		menu.Text = self.MenuOpen and "CLOSE MENU" or "MENU"
		menu:SetAttribute("Selected", self.MenuOpen == true)
		local layout = compact and ("phone" .. tostring(self.MenuOpen)) or "desktop"
		if layout ~= lastLayout then
			lastLayout = layout
			local skills = Config.Skills.Order
			local arc = { Vector2.new(-198, -156), Vector2.new(-212, -286) }
			for index, name in ipairs(skills) do
				local button = self.Buttons[name]
				button.Position = compact and UDim2.new(1, arc[index].X, 1, arc[index].Y)
					or UDim2.new(0.5, (index * 2 - 3) * 94, 1, -173)
				button.Size = UDim2.fromOffset(compact and 100 or 176, compact and 100 or 64)
			end
			for index, name in ipairs({ "Lock", "Upgrades", "Rebirth", "Index" }) do
				local button = self.Buttons[name]
				if button then
					button.Visible = not compact or self.MenuOpen == true
					button.Position = compact and UDim2.fromOffset(144, 238 + (index - 1) * 78)
						or UDim2.new(0.5, (index - 3) * 188, 1, -53)
					button.Size = UDim2.fromOffset(compact and 240 or 176, compact and 72 or 48)
				end
			end
			self.Buttons.Zap.Position = compact and UDim2.new(1, -80, 1, -292) or UDim2.new(0.5, 376, 1, -69)
			self.Buttons.Zap.Size = compact and UDim2.fromOffset(112, 112) or UDim2.fromOffset(176, 64)
			for name in pairs(actionColors) do
				local button = self.Buttons[name]
				button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(compact and 1 or 0, compact and 0 or 16)
				local icon = button:FindFirstChild("ActionIcon")
				icon.Position = compact and UDim2.new(0.5, 0, 0, name == "Zap" and 16 or 10)
					or UDim2.fromOffset(27, 12)
				local caption = button:FindFirstChild("ActionCaption")
				caption.Position = compact and UDim2.new(0, 5, 1, -48) or UDim2.fromOffset(49, 6)
				caption.Size = compact and UDim2.new(1, -10, 0, 40) or UDim2.fromOffset(122, 50)
				caption.TextSize = compact and 18 or 16
				button:FindFirstChild("CooldownProgress").Visible = compact
			end
		end
		for _, name in ipairs(Config.Skills.Order) do
			local skill, button = Config.Skills[name], self.Buttons[name]
			local left = math.max(0, ((state.SkillReadyAt or {})[name] or 0) - now)
			button.Text = (compact and skill.Name or (skill.Name .. " [" .. (skill.KeyLabel or skill.Key) .. "]"))
				.. "\n" .. (left > 0 and (math.ceil(left) .. "s") or "READY")
			button:SetAttribute("Unavailable", left > 0)
			local ring = button:FindFirstChild("CooldownRing")
			if ring then
				ring.Visible = false
				ring.Text = left > 0 and tostring(math.ceil(left)) or "+"
				ring.BackgroundTransparency = left > 0 and (0.15 + 0.65 * left / skill.Cooldown) or 0.15
			end
			updateAction(button, left, skill.Cooldown)
		end
		local lock = self.Buttons.Lock
		if (state.LockUntil or 0) > now then
			lock.Text = "LOCK [L]\nLOCKED · " .. math.ceil(state.LockUntil - now) .. "s"
			lock.BackgroundColor3 = Config.Palette.Teal
		elseif (state.LockReadyAt or 0) > now then
			lock.Text = "LOCK [L]\nRECHARGE · " .. math.ceil(state.LockReadyAt - now) .. "s"
			lock.BackgroundColor3 = Config.Palette.Ink
		else
			lock.Text = "LOCK [L]\nREADY"
			lock.BackgroundColor3 = Config.Palette.Ink
		end
		self.Buttons.Zap.Text = (compact and "ZAP\n" or "ZAP [F]\n") .. ((state.ZapReadyAt or 0) > now
			and ((compact and "" or "RECHARGE · ") .. math.ceil(state.ZapReadyAt - now) .. "s") or "READY")
		lock:SetAttribute("Unavailable", (state.LockReadyAt or 0) > now)
		self.Buttons.Zap:SetAttribute("Unavailable", (state.ZapReadyAt or 0) > now)
		updateAction(self.Buttons.Zap, math.max(0, (state.ZapReadyAt or 0) - now), Config.Gremlin.ZapCooldown)
		for action, panelName in pairs({ Upgrades = "UpgradePanel", Rebirth = "UpgradePanel", Index = "IndexPanel" }) do
			local button = self.Buttons[action]
			local panel = hud.Gui:FindFirstChild(panelName)
			if button then button:SetAttribute("Selected", panel and panel.Visible or false) end
		end
		if state == previous or not (self.Buttons.Upgrades and self.Buttons.Rebirth and self.Buttons.Index) then return end
		previous = state
		local levels, maxLevels, found = 0, 0, 0
		for name, definition in pairs(Config.Upgrades) do
			levels += state.Upgrades[name] or 0
			maxLevels += definition.MaxLevel
		end
		for _, known in pairs(state.Found) do if known then found += 1 end end
		local cost = Config.Rebirth.Cost(state.Rebirths)
		self.Buttons.Upgrades.Text = "UPGRADES [U]\n" .. levels .. "/" .. maxLevels .. " BUILT"
		self.Buttons.Rebirth.TextSize = 13
		self.Buttons.Rebirth.Text = state.Rebirths >= Config.Rebirth.MaxLevel and "REBIRTH [R]\nMAXED"
			or ("REBIRTH [R] · " .. Format.Money(cost) .. "\nNEXT: " .. Config.Rebirth.NextUnlock(state.Rebirths))
		self.Buttons.Index.Text = "INDEX [B]\n" .. found .. "/" .. #state.Catalog .. " FOUND"
	end)
	return self
end

function InputController:Register(name, label, key, callback)
	if self.Buttons[name] then return end
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = label
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Size = UDim2.fromOffset(176, 48)
	button.BackgroundColor3 = Config.Palette.Ink
	button.TextColor3 = Config.Palette.White
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.BorderSizePixel = 0
	button.Parent = self.Hud.Gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", button)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Config.Palette.Teal
	stroke.Thickness = 2
	if actionColors[name] then styleAction(button, name) end
	local activate = HudController.ButtonFeedback(button, function()
		callback()
		if name ~= "Zap" and not Config.Skills[name] then self.MenuOpen = false end
	end,
		(name == "Lock" or name == "Zap" or Config.Skills[name]) and 0.35 or nil)
	self.Buttons[name] = button
	table.insert(self.Order, name)
	local priority = { Lock = 1, Upgrades = 2, Rebirth = 3, Index = 4, Zap = 5 }
	table.sort(self.Order, function(a, b) return (priority[a] or 9) < (priority[b] or 9) end)
	for index, action in ipairs(self.Order) do
		local skillIndex = table.find(Config.Skills.Order, action)
		if skillIndex then
			local spacing = 188
			self.Buttons[action].Position = UDim2.new(0.5,
				(skillIndex - (#Config.Skills.Order + 1) / 2) * spacing, 1, -173)
			self.Buttons[action].Size = UDim2.fromOffset(spacing - 14, 48)
			self.Buttons[action].TextSize = 13
		else
			self.Buttons[action].Position = UDim2.new(0.5, (index - 3) * 188, 1, -53)
		end
	end
	if table.find(Config.Skills.Order, name) then
		local ring = Instance.new("TextLabel")
		ring.Name = "CooldownRing"
		ring.Size = UDim2.fromOffset(28, 28)
		ring.Position = UDim2.new(1, -17, 0, -10)
		ring.Text = "+"
		ring.TextColor3 = Config.Palette.White
		ring.BackgroundColor3 = Config.Palette.Teal
		ring.Font = Enum.Font.GothamBold
		ring.TextSize = 14
		ring.Parent = button
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
		local rim = Instance.new("UIStroke", ring)
		rim.Color = Config.Palette.Mint
		rim.Thickness = 2
	end
	ContextActionService:BindAction("RotOrbit" .. name, function(_, inputState)
		if self.Hud.InTitle or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then activate() end
		return Enum.ContextActionResult.Sink
	end, false, key)
end

local function startCrewPanel(hud)
	local panel = Instance.new("Frame")
	panel.Name = "CrewPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(960, 410)
	panel.BackgroundColor3 = Config.Palette.Ink
	panel.Visible = false
	panel.Parent = hud.Gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local title = HudController.Text(panel, "Title", "CREW RANKS", UDim2.fromOffset(480, 10),
		UDim2.fromOffset(700, 38), 30, Config.Palette.Sun)
	local function button(parent, name, text, pos, size, callback)
		local b = Instance.new("TextButton")
		b.Name, b.Text, b.Position, b.Size = name, text, pos, size
		b.BackgroundColor3, b.TextColor3 = Config.Palette.Teal, Config.Palette.White
		b.TextSize, b.Font = 17, Enum.Font.GothamBold
		b.Parent = parent
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
		HudController.ButtonFeedback(b, callback, 0.3)
		return b
	end
	local global = false
	local serverTab = button(panel, "ServerTab", "SERVER", UDim2.fromOffset(24, 54), UDim2.fromOffset(170, 34), function() global = false end)
	local globalTab = button(panel, "GlobalTab", "ALL-TIME", UDim2.fromOffset(204, 54), UDim2.fromOffset(170, 34), function() global = true end)
	button(panel, "Close", "CLOSE", UDim2.fromOffset(820, 16), UDim2.fromOffset(116, 34), function() panel.Visible = false end)
	local footer = HudController.Text(panel, "Status", "", UDim2.fromOffset(480, 370), UDim2.fromOffset(910, 30), 14)
	local rows = {}
	for index = 1, 3 do
		local top = 98 + (index - 1) * 87
		local row = HudController.Text(panel, "Crew" .. index, "", UDim2.fromOffset(400, top),
			UDim2.fromOffset(746, 78), 16)
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		local id = index
		local join = button(panel, "Join" .. index, "JOIN", UDim2.fromOffset(790, top + 10),
			UDim2.fromOffset(144, 54), function() hud.Network.Action:FireServer("Crew", id) end)
		rows[index] = { Label = row, Button = join, SetId = function(value) id = value end }
	end
	local open = button(hud.Gui, "CrewButton", "CREWS [Y]", UDim2.fromOffset(16, 365), UDim2.fromOffset(236, 44), function() panel.Visible = not panel.Visible end)
	open.TextSize = 14
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			for _, name in ipairs({ "UpgradePanel", "ContractPanel", "IndexPanel" }) do
				local other = hud.Gui:FindFirstChild(name)
				if other then other.Visible = false end
			end
		end
	end)
	ContextActionService:BindAction("RotOrbitCrews", function(_, phase)
		if hud.InTitle or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if phase == Enum.UserInputState.Begin then panel.Visible = not panel.Visible end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Y)
	RunService.Heartbeat:Connect(function()
		local state = hud.GetState()
		local view = state and state.Crew
		if not view then return end
		local compact = HudController.IsCompact() and state.SaveStatus ~= "STUDIO PREVIEW"
		open.Visible = not compact or hud.Gui:GetAttribute("MobileMenuOpen") == true
		open.Position = compact and UDim2.fromOffset(24, 550) or UDim2.fromOffset(16, 365)
		open.Size = compact and UDim2.fromOffset(240, 72) or UDim2.fromOffset(236, 44)
		open:SetAttribute("Selected", panel.Visible)
		open.Text = "CREWS [Y] · " .. (view.Current and Config.Crews.Teams[view.Current].Name or "JOIN A CREW")
		if not panel.Visible then return end
		serverTab:SetAttribute("Selected", not global)
		globalTab:SetAttribute("Selected", global)
		title.Text = global and "ALL-TIME CREW RANKS" or "SERVER CREW RANKS"
		local entries = global and view.Global or view.Rows
		for index, item in ipairs(rows) do
			local row = entries[index]
			item.Label.Visible = row ~= nil
			item.Button.Visible = row ~= nil and not global
			if row then
				item.SetId(row.Id)
				local members = {}
				for _, member in ipairs(row.Members or {}) do
					table.insert(members, member.Name .. " B" .. member.Bay .. (member.Locked and " LOCKED" or " OPEN"))
				end
				item.Label.TextColor3 = index == 1 and row.Score > 0 and Config.Palette.Sun or row.Color
				item.Label.Text = "#" .. index .. "  " .. row.Name .. "  ·  " .. row.Score .. " SCORE"
					.. (global and "\nCOMBINED ALL-SERVER CREW DEFENCE TOTAL" or ("  ·  " .. row.Raids .. " RAIDS  ·  " .. row.Bosses .. " BOSSES\n"
					.. Format.Money(row.Cash) .. " CASH  ·  " .. Format.Money(row.Income) .. "/s  ·  " .. table.concat(members, " / ")))
				item.Button.Text = view.Current == row.Id and "YOUR CREW" or "JOIN CREW"
				item.Button:SetAttribute("Unavailable", view.Current == row.Id)
			end
		end
		footer.Text = global and (view.Status .. " · REFRESHES EVERY 60s") or "TEAM CARGO PROTECTED · NEARBY ALLIES SHARE COMBAT CASH · NO SWITCHING DURING RAIDS"
	end)
	return panel
end

local function startTitle(hud, crewPanel)
	local screen = Instance.new("ScreenGui")
	screen.Name = "RotOrbitTitle"
	screen.DisplayOrder = 20
	screen.ResetOnSpawn = false
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.Parent = hud.Gui.Parent.Parent
	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "ArrivalTitle"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(1280, 720)
	canvas.BackgroundTransparency = 1
	canvas.Parent = screen
	local scale = Instance.new("UIScale", canvas)
	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(46, 153)
	panel.Size = UDim2.fromOffset(410, 402)
	panel.BackgroundColor3 = Config.Palette.Ink
	panel.BackgroundTransparency = 0.07
	panel.Parent = canvas
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)
	local title = HudController.Text(panel, "Title", Config.Title, UDim2.fromOffset(205, 20),
		UDim2.fromOffset(380, 72), 59, Config.Palette.White)
	title.Font = Enum.Font.GothamBlack
	local help = HudController.Text(panel, "HowTo", "Buy or steal brainrots.\nDock them to earn cash.\nLock your bay and use skills to defend it.",
		UDim2.fromOffset(205, 278), UDim2.fromOffset(358, 86), 19)
	help.TextWrapped = true
	help.TextXAlignment = Enum.TextXAlignment.Left
	local status = HudController.Text(panel, "Status", "Preparing your dock…", UDim2.fromOffset(205, 92),
		UDim2.fromOffset(360, 30), 17, Config.Palette.Muted)
	local squad = false
	local function action(name, text, x, y, width, height)
		local button = Instance.new("TextButton")
		button.Name, button.Text = name, text
		button.Position, button.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
		button.BackgroundColor3, button.TextColor3 = Config.Palette.Teal, Config.Palette.White
		button.TextSize, button.Font = 23, Enum.Font.GothamBold
		button.Parent = panel
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
		return button
	end
	local soloButton = action("Solo", "SOLO", 26, 128, 172, 50)
	local squadButton = action("Squad", "SQUAD", 212, 128, 172, 50)
	local play = action("Play", "PLAY", 26, 194, 358, 68)
	play.Font, play.TextSize = Enum.Font.GothamBlack, 35
	play.BackgroundColor3, play.TextColor3 = Config.Palette.Mint, Config.Palette.Ink
	play:SetAttribute("Unavailable", true)
	local function mode(isSquad)
		squad = isSquad
		soloButton:SetAttribute("Selected", not squad)
		squadButton:SetAttribute("Selected", squad)
	end
	HudController.ButtonFeedback(soloButton, function() mode(false) end)
	HudController.ButtonFeedback(squadButton, function() mode(true) end)
	mode(false)
	local screenHud = hud.Gui.Parent
	screenHud.Enabled = false
	hud.InTitle = true
	local started = os.clock()
	local function close(forScreenshot)
		if not hud.InTitle then
			if forScreenshot and screen.Parent then screen:Destroy() end
			return
		end
		hud.InTitle = false
		RunService:UnbindFromRenderStep("OrbitTitleCamera")
		ContextActionService:UnbindAction("OrbitTitlePlay")
		screenHud.Enabled = true
		if forScreenshot then screen:Destroy(); return end
		local camera = workspace.CurrentCamera
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if camera then
			if humanoid then camera.CameraSubject = humanoid end
			camera.CameraType = Enum.CameraType.Custom
		end
		if squad then crewPanel.Visible = true end
		local fade = TweenService:Create(canvas, TweenInfo.new(0.24, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
		fade.Completed:Once(function() if screen.Parent then screen:Destroy() end end)
		fade:Play()
	end
	local activate = HudController.ButtonFeedback(play, function() close(false) end)
	ContextActionService:BindAction("OrbitTitlePlay", function(_, phase)
		if phase == Enum.UserInputState.Begin then activate() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Return)
	local screenshotConnection
	screenshotConnection = hud.Network.Screenshot.OnClientEvent:Connect(function()
		screenshotConnection:Disconnect()
		close(true)
	end)
	RunService:BindToRenderStep("OrbitTitleCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if camera then
			local size = screen.AbsoluteSize
			scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.33, 1.4)
			local angle = 0.20 + math.sin((os.clock() - started) * 0.21) * 0.36
			local target = Vector3.new(-13, 9, -9)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 102, 29, math.cos(angle) * 102),
				target)
			camera.Focus = CFrame.new(target)
		end
		local ready = hud.GetState() ~= nil
		play:SetAttribute("Unavailable", not ready)
		status.Visible = not ready
	end)
end

local function filterDockPrompts(hud)
	local dockPrompts = {}
	local carrying = false
	local function update(prompt)
		local ownerId = prompt:GetAttribute("OwnerUserId")
		local own = ownerId == localPlayer.UserId
		local owner = game:GetService("Players"):GetPlayerByUserId(ownerId or 0)
		local crew = localPlayer:GetAttribute("OrbitCrewId")
		local friendly = crew ~= nil and owner and owner:GetAttribute("OrbitCrewId") == crew
		if prompt.Name == "PlaceBrainrot" then
			prompt.Enabled = own and carrying and prompt:GetAttribute("SocketOpen") == true
		elseif prompt.Name == "StealCargo" then
			prompt.Enabled = not own and not friendly and not carrying
		else
			prompt.Enabled = own
		end
	end
	local function watch(prompt)
		if dockPrompts[prompt] then return end
		dockPrompts[prompt] = { prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function() update(prompt) end),
			prompt:GetAttributeChangedSignal("SocketOpen"):Connect(function() update(prompt) end) }
		update(prompt)
	end
	for _, tag in ipairs({ "OrbitDockPrompt", "OrbitRetirePrompt" }) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(prompt)
			for _, connection in ipairs(dockPrompts[prompt] or {}) do connection:Disconnect() end
			dockPrompts[prompt] = nil
		end)
		for _, prompt in ipairs(CollectionService:GetTagged(tag)) do watch(prompt) end
	end
	local lastState
	RunService.Heartbeat:Connect(function()
		local state = hud.GetState()
		local hasCargo = state and state.Carrying and true or false
		if carrying == hasCargo and state == lastState then return end
		lastState = state
		carrying = hasCargo
		for prompt in pairs(dockPrompts) do update(prompt) end
	end)
end

-- Start the controls and panels after creating the HUD.
require(script.Parent:WaitForChild("BillboardFx")).Start()
local hud = HudController.Start()
filterDockPrompts(hud)
local crewPanel = startCrewPanel(hud)
local input = InputController.Start(hud)
local progression = require(script.Parent:WaitForChild("UpgradeRebirthContracts"))
local upgrades = progression.StartUpgrades(hud, input)
progression.AddRebirth(hud, input, upgrades)
require(script.Parent:WaitForChild("IndexPanel")).Start(hud, input)
progression.StartContracts(hud, upgrades)
for _, name in ipairs({ "UpgradePanel", "IndexPanel" }) do
	local panel = hud.Gui:FindFirstChild(name)
	if panel then panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then crewPanel.Visible = false end
	end) end
end
startTitle(hud, crewPanel)
require(shared:WaitForChild("ScreenshotMode")).Listen(hud)
