-- One binding per action, with matching clickable controls for touch and mouse.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local InputController = {}
InputController.__index = InputController

function InputController.Start(hud)
	local self = setmetatable({ Hud = hud, Buttons = {}, Order = {} }, InputController)
	self:Register("Lock", "LOCK [L]", Enum.KeyCode.L, function() hud.Network.Action:FireServer("Lock") end)
	self:Register("Zap", "ZAP [F]", Enum.KeyCode.F, function() hud.Network.Action:FireServer("Zap") end)
	RunService.RenderStepped:Connect(function()
		local state = hud.GetState()
		if not state then return end
		local now = workspace:GetServerTimeNow()
		local lock = self.Buttons.Lock
		if (state.LockUntil or 0) > now then
			lock.Text = "LOCKED · " .. math.ceil(state.LockUntil - now) .. "s"
			lock.BackgroundColor3 = Config.Palette.Teal
		elseif (state.LockReadyAt or 0) > now then
			lock.Text = "LOCK · " .. math.ceil(state.LockReadyAt - now) .. "s"
			lock.BackgroundColor3 = Config.Palette.Ink
		else
			lock.Text = "LOCK [L]"
			lock.BackgroundColor3 = Config.Palette.Ink
		end
		if self.Buttons.Zap then
			self.Buttons.Zap.Text = (state.ZapReadyAt or 0) > now
				and ("ZAP · " .. math.ceil(state.ZapReadyAt - now) .. "s") or "ZAP [F]"
		end
	end)
	return self
end

function InputController:Register(name, label, key, callback)
	if self.Buttons[name] then return end
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = label
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Size = UDim2.fromOffset(176, 40)
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
	for index, action in ipairs(self.Order) do
		self.Buttons[action].Position = UDim2.new(0.5, (index - (#self.Order + 1) / 2) * 188, 1, -52)
	end
	ContextActionService:BindAction("RotOrbit" .. name, function(_, inputState)
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then callback() end
		return Enum.ContextActionResult.Sink
	end, false, key)
end

return InputController
