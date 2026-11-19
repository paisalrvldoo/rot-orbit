-- One binding per action, with matching clickable controls for touch and mouse.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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
	local lastLayout
	local previous
	RunService.RenderStepped:Connect(function()
		local state = hud.GetState()
		if not state then return end
		local now = workspace:GetServerTimeNow()
		local compact = HudController.IsCompact() and state.SaveStatus ~= "STUDIO PREVIEW"
		local layout = compact and (utility and "utility" or "primary") or "all"
		if layout ~= lastLayout then
			lastLayout = layout
			local skills = not compact and Config.Skills.Order
				or (utility and Config.Skills.TouchUtility or Config.Skills.TouchPrimary)
			local slots = compact and (#Config.Skills.TouchPrimary + 1) or #skills
			local spacing = 1000 / slots
			for _, name in ipairs(Config.Skills.Order) do
				local button = self.Buttons[name]
				local index = table.find(skills, name)
				button.Visible = index ~= nil
				if index then
					button.Position = UDim2.new(0.5, (index - (slots + 1) / 2) * spacing, 1, -168)
					button.Size = UDim2.fromOffset(spacing - 14, 48)
				end
			end
			more.Visible = compact
			more.Text = utility and "MAIN SKILLS" or "MORE SKILLS"
			more.Size = UDim2.fromOffset(spacing - 14, 48)
			more.Position = UDim2.new(0.5, (slots - 1) / 2 * spacing, 1, -168)
			more:SetAttribute("Selected", utility)
		end
		for _, name in ipairs(Config.Skills.Order) do
			local skill, button = Config.Skills[name], self.Buttons[name]
			local unlocked = Config.Skills.Unlocked(name, state)
			local left = math.max(0, ((state.SkillReadyAt or {})[name] or 0) - now)
			button.Text = skill.Name .. (compact and "" or (" [" .. (skill.KeyLabel or skill.Key) .. "]"))
				.. "\n" .. (not unlocked and skill.Unlock
				or (left > 0 and (math.ceil(left) .. "s") or "READY"))
			button:SetAttribute("Unavailable", not unlocked or left > 0)
			local ring = button:FindFirstChild("CooldownRing")
			if ring then
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
		self.Buttons.Rebirth.Text = "REBIRTH [R]\n" .. (state.Rebirths >= Config.Rebirth.MaxLevel and "MAXED" or Format.Money(cost))
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
	local activate = HudController.ButtonFeedback(button, callback,
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
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
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
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if phase == Enum.UserInputState.Begin then panel.Visible = not panel.Visible end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Y)
	RunService.Heartbeat:Connect(function()
		local state = hud.GetState()
		local view = state and state.Crew
		if not view then return end
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
require(shared:WaitForChild("ScreenshotMode")).Listen(hud)
