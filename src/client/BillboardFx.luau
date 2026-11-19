-- Visual animation stays on the client; cash and interaction decisions stay on the server.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local BillboardFx = {}
local started = false

function BillboardFx.Start()
	if started then return end
	started = true
	local visuals, reveals, quieted = {}, {}, {}
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
	RunService.RenderStepped:Connect(function()
		local time = workspace:GetServerTimeNow()
		local world = workspace:FindFirstChild("ROT_ORBIT")
		if world and world:GetAttribute("ScreenshotFrozen") then
			for model in pairs(visuals) do restore(model) end
			return
		end
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
				frame = model.Parent:GetPivot()
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
