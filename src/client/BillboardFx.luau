-- Visual animation stays on the client; cash and interaction decisions stay on the server.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local BillboardFx = {}
local started = false

local function updateCargoCards(visuals, frozen)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local candidates, placed = {}, {}
	for model in pairs(visuals) do
		local root = model.PrimaryPart
		local gui = root and root:FindFirstChild("BrainrotBillboard")
		if model.Parent and gui and model:GetAttribute("VisualState") == "Cargo" then
			gui.Enabled = frozen and model:GetAttribute("ScreenshotCard") == true or false
			if camera and playerRoot and not frozen and (root.Position - camera.CFrame.Position).Magnitude < gui.MaxDistance then
				local point, onScreen = camera:WorldToViewportPoint(root.Position + gui.StudsOffsetWorldSpace)
				if onScreen then
					table.insert(candidates, { Gui = gui, Point = point,
						Distance = (root.Position - playerRoot.Position).Magnitude })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		-- Close cargo is the focus. Beyond prompt range, favour what is in front.
		local closeA, closeB = a.Distance <= Config.InteractionDistance, b.Distance <= Config.InteractionDistance
		if closeA ~= closeB then return closeA end
		if closeA then return a.Distance < b.Distance end
		return a.Point.Z < b.Point.Z
	end)
	local narrow = camera and camera.ViewportSize.Y <= 540
	for index, item in ipairs(candidates) do
		local full = index == 1 and item.Distance <= Config.InteractionDistance
		local width, height = full and 206 or (narrow and 128 or 148), full and 64 or 40
		local overlaps = false
		for _, other in ipairs(placed) do
			if math.abs(item.Point.X - other.Point.X) < (width + other.Width) * 0.5 + 8
				and math.abs(item.Point.Y - other.Point.Y) < (height + other.Height) * 0.5 + 8 then
				overlaps = true
				break
			end
		end
		if not overlaps then
			item.Gui.Size = UDim2.fromOffset(width, height)
			local card = item.Gui:FindFirstChildOfClass("Frame")
			card.Details.Visible = full
			item.Gui.Enabled = true
			table.insert(placed, { Point = item.Point, Width = width, Height = height })
			if #placed >= (narrow and 2 or 4) then break end
		end
	end
end

function BillboardFx.Start()
	if started then return end
	started = true
	local visuals, reveals, quieted = {}, {}, {}
	local function tagged(tag)
		local items = {}
		for _, item in ipairs(CollectionService:GetTagged(tag)) do items[item] = true end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(item) items[item] = true end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(item) items[item] = nil end)
		return items
	end
	local chasers = tagged("OrbitRailChaser")
	local relays = tagged("OrbitCargoRelay")
	local function restore(model)
		if reveals[model] and model.Parent then model:ScaleTo(1) end
		reveals[model] = nil
		local saved = quieted[model]
		if saved and saved.Highlight.Parent then saved.Highlight.OutlineTransparency = saved.Outline end
		quieted[model] = nil
	end
	local function add(instance)
		if instance:IsA("Model") then visuals[instance] = true end
	end
	for _, model in ipairs(CollectionService:GetTagged("OrbitBrainrot")) do add(model) end
	CollectionService:GetInstanceAddedSignal("OrbitBrainrot"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("OrbitBrainrot"):Connect(function(model)
		restore(model)
		visuals[model] = nil
	end)
	local cardElapsed = math.huge
	local railFrozen
	RunService.RenderStepped:Connect(function(dt)
		local time = workspace:GetServerTimeNow()
		local world = workspace:FindFirstChild("ROT_ORBIT")
		local frozen = world and world:GetAttribute("ScreenshotFrozen")
		if not frozen or not railFrozen then
			for tracer in pairs(chasers) do
				local phase = tracer:GetAttribute("OrbitPhase")
				if phase then
					local angle = phase + (frozen and 0 or time * 0.64)
					tracer.CFrame = CFrame.Angles(0, -angle, 0)
						* CFrame.new(Config.World.RailRadius + 4.55, Config.World.RailHeight + 0.18, 0)
				end
			end
			for relay in pairs(relays) do
				local frame, phase = relay:GetAttribute("RelayFrame"), relay:GetAttribute("RelayPhase")
				if frame and phase then
					local bob = frozen and 0 or math.sin(time * 1.1 + phase) * 0.45
					relay:PivotTo(frame * CFrame.new(0, bob, 0))
				end
			end
		end
		railFrozen = frozen
		cardElapsed += dt
		if cardElapsed >= 0.07 then
			updateCargoCards(visuals, frozen)
			cardElapsed = 0
		end
		if frozen then
			for model in pairs(visuals) do restore(model) end
			return
		end
		local camera = workspace.CurrentCamera
		local revealPosition
		for model in pairs(visuals) do
			local dockedAt = model:GetAttribute("DockedAt")
			if model.Parent and dockedAt and (model:GetAttribute("RarityRank") or 1) == 7
				and time - dockedAt >= 0 and time - dockedAt < Config.SecretDock.Duration then
				revealPosition = model:GetPivot().Position
				break
			end
		end
		for model in pairs(visuals) do
			local frame = model:GetAttribute("RestFrame")
			local state = model:GetAttribute("VisualState")
			if state == "Cargo" and model.Parent and model.Parent:IsA("Model") and model.Parent.PrimaryPart then
				local sled = model.Parent:GetPivot()
				local position = sled.Position
				frame = sled * CFrame.Angles(0, math.pi, 0)
				if camera then
					local offset = camera.CFrame.Position - position
					local direction = Vector3.new(offset.X, 0, offset.Z)
					if direction.Magnitude > 1 and direction.Magnitude < 48 then
						-- Let shoppers on either side of the orbit see the face.
						frame = CFrame.lookAt(position, position + direction)
					end
				end
			end
			if model.Parent and model.PrimaryPart and frame and (state == "Pedestal" or state == "Cargo") then
				local seed = model:GetAttribute("BrainrotId") or 0
				local zeroG = model:GetAttribute("Mutation") == "Zero-G"
				local bob = math.sin(time * 2 + seed) * 0.16 + (zeroG and 0.65 or 0)
				local rareWobble = (model:GetAttribute("RarityRank") or 1) >= 5 and 0.19 or 0.09
				local spin = zeroG and time * 0.6 or math.sin(time * 0.8 + seed) * rareWobble
				local age = time - (model:GetAttribute("DockedAt") or -math.huge)
				local secret = (model:GetAttribute("RarityRank") or 1) == 7
				local config = Config.SecretDock
				local tilt = 0
				if secret and state == "Pedestal" and age >= 0 and age < config.Duration then
					local progress = math.clamp((age - config.Anticipation) / config.Settle, 0, 1)
					local ease = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					local scale = config.StartScale + (config.PeakScale - config.StartScale) * ease
					if age < config.Anticipation then
						scale = 1 - (1 - config.StartScale) * TweenService:GetValue(age / config.Anticipation,
							Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					elseif progress == 1 then
						local settle = (age - config.Anticipation - config.Settle)
							/ (config.Duration - config.Anticipation - config.Settle)
						scale = config.PeakScale + (1 - config.PeakScale) * TweenService:GetValue(settle,
							Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					end
					model:ScaleTo(scale)
					reveals[model] = true
					bob = -config.Drop * (1 - progress)
					spin = 0
					tilt = math.sin(progress * math.pi * 3) * config.Tilt * (1 - progress)
				elseif reveals[model] then model:ScaleTo(1); reveals[model] = nil end
				local quiet = revealPosition and not secret and state == "Pedestal"
					and (frame.Position - revealPosition).Magnitude < config.Radius
				local highlight = model:FindFirstChild("RarityGlow")
				if quiet and highlight and not quieted[model] then
					quieted[model] = { Highlight = highlight, Outline = highlight.OutlineTransparency }
					highlight.OutlineTransparency = 0.92
				elseif not quiet and quieted[model] then
					local saved = quieted[model]
					if saved.Highlight.Parent then saved.Highlight.OutlineTransparency = saved.Outline end
					quieted[model] = nil
				end
				if quiet then bob, spin = 0, 0 end
				model:PivotTo(frame * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, tilt))
			end
		end
	end)
end

return BillboardFx
