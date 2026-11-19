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
	local utility = false
	local more = Instance.new("TextButton")
	more.Name = "SkillPage"
	more.AnchorPoint = Vector2.new(0.5, 0)
	more.TextColor3, more.BackgroundColor3 = Config.Palette.White, Config.Palette.Ink
	more.Font, more.TextSize = Enum.Font.GothamBold, 14
	more.Visible = false
	more.Parent = hud.Gui
	Instance.new("UICorner", more).CornerRadius = UDim.new(0, 10)
	HudController.ButtonFeedback(more, function() utility = not utility end)
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
	local trap = Instance.new("TextButton")
	trap.Name, trap.AnchorPoint = "PlaceTrap", Vector2.new(0.5, 0)
	trap.BackgroundColor3, trap.TextColor3 = Config.Palette.Ink, Config.Palette.White
	trap.Font, trap.TextSize = Enum.Font.GothamBold, 14
	trap.Parent = hud.Gui
	Instance.new("UICorner", trap).CornerRadius = UDim.new(0, 10)
	local placeTrap = HudController.ButtonFeedback(trap, function()
		hud.Network.Action:FireServer("Skill", "Bomb", "Trap")
	end, 0.35)
	ContextActionService:BindAction("RotOrbitTrap", function(_, phase)
		if hud.InTitle or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if phase == Enum.UserInputState.Begin then placeTrap() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.T)
	local lastLayout
	local previous
	RunService.RenderStepped:Connect(function()
		local state = hud.GetState()
		if not state then return end
		local now = workspace:GetServerTimeNow()
		local compact = HudController.IsCompact() and state.SaveStatus ~= "STUDIO PREVIEW"
		local bombLeft = math.max(0, ((state.SkillReadyAt or {}).Bomb or 0) - now)
		trap.Visible = state.SaveStatus ~= "STUDIO PREVIEW" and (not compact or utility)
		trap.Position = compact and UDim2.new(1, -300, 1, -320) or UDim2.new(1, -106, 1, -224)
		trap.Size = compact and UDim2.fromOffset(128, 72) or UDim2.fromOffset(176, 48)
		trap.Text = (compact and "TRAP" or "TRAP [T]") .. "\n" .. (bombLeft > 0 and (math.ceil(bombLeft) .. "s") or "READY")
		trap:SetAttribute("Unavailable", bombLeft > 0)
		for _, name in ipairs({ "UpgradePanel", "IndexPanel", "CrewPanel" }) do
			local panel = hud.Gui:FindFirstChild(name)
			if panel and panel.Visible then self.MenuOpen = false end
		end
		hud.Gui:SetAttribute("MobileMenuOpen", compact and self.MenuOpen == true)
		menu.Visible = compact
		menu.Text = self.MenuOpen and "CLOSE MENU" or "MENU"
		menu:SetAttribute("Selected", self.MenuOpen == true)
		local layout = compact and ((utility and "utility" or "primary") .. tostring(self.MenuOpen)) or "all"
		if layout ~= lastLayout then
			lastLayout = layout
			local skills = not compact and Config.Skills.Order
				or (utility and Config.Skills.TouchUtility or Config.Skills.TouchPrimary)
			local spacing = 1000 / #skills
			local arc = { Vector2.new(-274, -142), Vector2.new(-190, -226), Vector2.new(-84, -272) }
			for _, name in ipairs(Config.Skills.Order) do
				local button = self.Buttons[name]
				local index = table.find(skills, name)
				button.Visible = index ~= nil
				if index then
					button.Position = compact and UDim2.new(1, arc[index].X, 1, arc[index].Y)
						or UDim2.new(0.5, (index - (#skills + 1) / 2) * spacing, 1, -168)
					button.Size = compact and UDim2.fromOffset(92, 72) or UDim2.fromOffset(spacing - 14, 48)
				end
			end
			more.Visible = compact
			more.Text = utility and "MAIN" or "MORE"
			more.Size = UDim2.fromOffset(84, 72)
			more.Position = UDim2.new(1, -292, 1, -224)
			more:SetAttribute("Selected", utility)
			for index, name in ipairs({ "Lock", "Upgrades", "Rebirth", "Index" }) do
				local button = self.Buttons[name]
				if button then
					button.Visible = not compact or self.MenuOpen == true
					button.Position = compact and UDim2.fromOffset(144, 238 + (index - 1) * 78)
						or UDim2.new(0.5, (index - 3) * 188, 1, -53)
					button.Size = UDim2.fromOffset(compact and 240 or 176, compact and 72 or 48)
				end
			end
			self.Buttons.Zap.Position = compact and UDim2.new(1, -80, 1, -172) or UDim2.new(0.5, 376, 1, -53)
			self.Buttons.Zap.Size = compact and UDim2.fromOffset(100, 76) or UDim2.fromOffset(176, 48)
		end
		for _, name in ipairs(Config.Skills.Order) do
			local skill, button = Config.Skills[name], self.Buttons[name]
			local unlocked = Config.Skills.Unlocked(name, state)
			local left = math.max(0, ((state.SkillReadyAt or {})[name] or 0) - now)
			local short = ({ Slam = "SLAM", Dash = "DASH", Bubble = "SHIELD" })[name] or skill.Name
			button.Text = (compact and short or (skill.Name .. " [" .. (skill.KeyLabel or skill.Key) .. "]"))
				.. "\n" .. (not unlocked and (compact and "LOCKED" or skill.Unlock)
				or (left > 0 and (math.ceil(left) .. "s") or "READY"))
			button:SetAttribute("Unavailable", not unlocked or left > 0)
			local ring = button:FindFirstChild("CooldownRing")
			if ring then
				ring.Visible = not compact
				ring.Text = not unlocked and "-" or (left > 0 and tostring(math.ceil(left)) or "+")
				ring.BackgroundTransparency = left > 0 and (0.15 + 0.65 * left / skill.Cooldown) or 0.15
			end
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
		self.Buttons.Zap.Text = "ZAP [F]\n" .. ((state.ZapReadyAt or 0) > now
			and ("RECHARGE · " .. math.ceil(state.ZapReadyAt - now) .. "s") or "READY")
		lock:SetAttribute("Unavailable", (state.LockReadyAt or 0) > now)
		self.Buttons.Zap:SetAttribute("Unavailable", (state.ZapReadyAt or 0) > now)
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
			local spacing = 1000 / #Config.Skills.Order
			self.Buttons[action].Position = UDim2.new(0.5,
				(skillIndex - (#Config.Skills.Order + 1) / 2) * spacing, 1, -168)
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
