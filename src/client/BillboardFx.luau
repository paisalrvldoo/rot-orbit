-- Visual animation stays on the client; cash and interaction decisions stay on the server.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local BillboardFx = {}
local started = false

function BillboardFx.Start()
	if started then return end
	started = true
	local visuals = {}
	local function add(instance)
		if instance:IsA("Model") then visuals[instance] = true end
	end
	for _, model in ipairs(CollectionService:GetTagged("OrbitBrainrot")) do add(model) end
	CollectionService:GetInstanceAddedSignal("OrbitBrainrot"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("OrbitBrainrot"):Connect(function(model)
		visuals[model] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local time = workspace:GetServerTimeNow()
		local world = workspace:FindFirstChild("ROT_ORBIT")
		if world and world:GetAttribute("ScreenshotFrozen") then return end
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
				model:PivotTo(frame * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0))
			end
		end
	end)
end

return BillboardFx
