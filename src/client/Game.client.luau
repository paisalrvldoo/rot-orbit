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
	local previous
	RunService.RenderStepped:Connect(function()
		local state = hud.GetState()
		if not state then return end
		local now = workspace:GetServerTimeNow()
		for _, name in ipairs(Config.Skills.Order) do
			local skill, button = Config.Skills[name], self.Buttons[name]
			local unlocked = Config.Skills.Unlocked(name, state)
			local left = math.max(0, ((state.SkillReadyAt or {})[name] or 0) - now)
			button.Text = skill.Name .. " [" .. skill.Key .. "]\n" .. (not unlocked and skill.Unlock
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
			self.Buttons[action].Position = UDim2.new(0.5, (skillIndex - 2) * 254, 1, -168)
			self.Buttons[action].Size = UDim2.fromOffset(244, 48)
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

local function filterDockPrompts(hud)
	local dockPrompts = {}
	local carrying = false
	local function update(prompt)
		local own = prompt:GetAttribute("OwnerUserId") == localPlayer.UserId
		if prompt.Name == "PlaceBrainrot" then
			prompt.Enabled = own and carrying and prompt:GetAttribute("SocketOpen") == true
		elseif prompt.Name == "StealCargo" then
			prompt.Enabled = not own and not carrying
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
	RunService.Heartbeat:Connect(function()
		local state = hud.GetState()
		local hasCargo = state and state.Carrying and true or false
		if carrying == hasCargo then return end
		carrying = hasCargo
		for prompt in pairs(dockPrompts) do update(prompt) end
	end)
end

-- Start the controls and panels after creating the HUD.
require(script.Parent:WaitForChild("BillboardFx")).Start()
local hud = HudController.Start()
filterDockPrompts(hud)
local input = InputController.Start(hud)
local progression = require(script.Parent:WaitForChild("UpgradeRebirthContracts"))
local upgrades = progression.StartUpgrades(hud, input)
progression.AddRebirth(hud, input, upgrades)
require(script.Parent:WaitForChild("IndexPanel")).Start(hud, input)
progression.StartContracts(hud, upgrades)
require(shared:WaitForChild("ScreenshotMode")).Listen(hud)
