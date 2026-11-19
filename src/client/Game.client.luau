-- One binding per action, with matching clickable controls for touch and mouse.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Format = Traits.Format
local InputController = {}
InputController.__index = InputController

function InputController.Start(hud)
	local self = setmetatable({ Hud = hud, Buttons = {}, Order = {} }, InputController)
	self:Register("Lock", "LOCK [L]", Enum.KeyCode.L, function() hud.Network.Action:FireServer("Lock") end)
	self:Register("Zap", "ZAP [F]", Enum.KeyCode.F, function() hud.Network.Action:FireServer("Zap") end)
	local previous
	RunService.RenderStepped:Connect(function()
		local state = hud.GetState()
		if not state then return end
		local now = workspace:GetServerTimeNow()
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
	button.Activated:Connect(callback)
	self.Buttons[name] = button
	table.insert(self.Order, name)
	local priority = { Lock = 1, Upgrades = 2, Rebirth = 3, Index = 4, Zap = 5 }
	table.sort(self.Order, function(a, b) return (priority[a] or 9) < (priority[b] or 9) end)
	for index, action in ipairs(self.Order) do
		self.Buttons[action].Position = UDim2.new(0.5, (index - (#self.Order + 1) / 2) * 188, 1, -53)
	end
	ContextActionService:BindAction("RotOrbit" .. name, function(_, inputState)
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then callback() end
		return Enum.ContextActionResult.Sink
	end, false, key)
end

-- Start the controls and panels after creating the HUD.
require(script.Parent:WaitForChild("BillboardFx")).Start()
local hud = require(script.Parent:WaitForChild("HudController")).Start()
local input = InputController.Start(hud)
local progression = require(script.Parent:WaitForChild("UpgradeRebirthContracts"))
local upgrades = progression.StartUpgrades(hud, input)
progression.AddRebirth(hud, input, upgrades)
require(script.Parent:WaitForChild("IndexPanel")).Start(hud, input)
progression.StartContracts(hud, upgrades)
require(shared:WaitForChild("ScreenshotMode")).Listen(hud)
