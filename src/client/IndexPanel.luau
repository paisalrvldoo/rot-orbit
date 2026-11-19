local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Traits = require(shared:WaitForChild("BrainrotTraits"))
local Rarity = Traits.Rarity
local Mutation = Traits.Mutation
local Style = require(script.Parent:WaitForChild("UpgradeRebirthContracts")).Style
local IndexPanel = {}

function IndexPanel.Start(hud, input)
	local panel = Style.Create(hud, "IndexPanel", "INDEX · 0/" .. Config.CatalogCount .. " FOUND", 1198, 446)
	panel.Position = UDim2.new(0.5, 0, 0, 159)
	local header = panel:FindFirstChildOfClass("TextLabel")
	header.Size = UDim2.fromOffset(1100, 49)
	header.TextSize = 43
	header.Font = Enum.Font.GothamBlack
	local milestoneLabel = Style.Text(panel, "", 629, 20, 501, 36, 20, Config.Palette.Sun)
	milestoneLabel.TextXAlignment = Enum.TextXAlignment.Right
	local selected = "All"
	hud.Network.Screenshot.OnClientEvent:Connect(function() selected = "All" end)
	local tabs = {}
	local function tab(name, text, x, width, color)
		local button = Style.Button(panel, text, x, 394, width, 39, function() selected = name end)
		button.TextSize = 16
		button.BackgroundColor3 = color or Config.Palette.Teal
		tabs[name] = button
	end
	tab("All", "ALL", 21, 98)
	local cells, counts = {}, {}
	for index, rarity in ipairs(Rarity.Order) do
		counts[rarity] = Style.Text(panel, rarity .. " 0/0", 21 + (index - 1) * 167, 61, 165, 27,
			19, Rarity.ByName[rarity].Color)
	end
	for index, name in ipairs(Mutation.Order) do
		local mutation = Mutation.ByName[name]
		tab(name, string.upper(name) .. " ×" .. mutation.Multiplier,
			129 + (index - 1) * 174, 164, Color3.fromRGB(43, 67, 83))
	end
	local function silhouette(parent, color)
		local parts = {}
		for _, shape in ipairs({ { 10, 9, 14, 14 }, { 7, 22, 20, 18 }, { 6, 36, 9, 7 }, { 19, 36, 9, 7 } }) do
			local piece = Instance.new("Frame")
			piece.Position = UDim2.fromOffset(shape[1], shape[2])
			piece.Size = UDim2.fromOffset(shape[3], shape[4])
			piece.BackgroundColor3 = color
			piece.BorderSizePixel = 0
			piece.ZIndex = 11
			piece.Parent = parent
			Instance.new("UICorner", piece).CornerRadius = UDim.new(0.4, 0)
			table.insert(parts, piece)
		end
		return parts
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.3 then return end
		elapsed = 0
		local state = hud.GetState()
		if not state or not panel.Visible then return end
		local found, total = {}, {}
		local discovered = 0
		local discoveries = selected == "All" and state.Found or ((state.Variants or {})[selected] or {})
		for name, button in pairs(tabs) do
			button:SetAttribute("Selected", name == selected)
			button.BackgroundColor3 = name == selected and Config.Palette.Teal or Color3.fromRGB(43, 67, 83)
			button.TextColor3 = name == "All" and Config.Palette.White or Mutation.ByName[name].Color
		end
		for index, entry in ipairs(state.Catalog) do
			local rarity = Rarity.ByName[entry.Rarity]
			local known = discoveries[tostring(entry.Id)] == true
			total[entry.Rarity] = (total[entry.Rarity] or 0) + 1
			if known then
				discovered += 1
				found[entry.Rarity] = (found[entry.Rarity] or 0) + 1
			end
			local cell = cells[entry.Id]
			if not cell then
				local frame = Instance.new("Frame")
				frame.Position = UDim2.fromOffset(21 + (index - 1) % 9 * 129, 93 + math.floor((index - 1) / 9) * 61)
				frame.Size = UDim2.fromOffset(124, 55)
				frame.BackgroundColor3 = Color3.fromRGB(23, 46, 66)
				frame.BorderSizePixel = 0
				frame.ZIndex = 11
				frame.Parent = panel
				Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 9)
				local stroke = Instance.new("UIStroke", frame)
				stroke.Thickness = 1.2
				local name = Style.Text(frame, "", 32, 3, 89, 34, 13)
				name.TextWrapped = true
				cell = { Name = name, Rarity = Style.Text(frame, "", 32, 37, 89, 15, 10),
					Stroke = stroke, Parts = silhouette(frame, rarity.Color) }
				cells[entry.Id] = cell
			end
			local color = known and rarity.Color or Color3.fromRGB(9, 24, 39)
			cell.Name.Text = known and entry.Name or "UNDISCOVERED"
			cell.Name.TextColor3 = known and Config.Palette.White or Config.Palette.Muted
			cell.Rarity.Text = string.upper(entry.Rarity)
			cell.Rarity.TextColor3 = known and rarity.Color or Config.Palette.Muted
			cell.Stroke.Color = color
			for _, piece in ipairs(cell.Parts) do piece.BackgroundColor3 = color end
		end
		header.Text = (selected == "All" and "INDEX" or string.upper(selected))
			.. " · " .. discovered .. "/" .. #state.Catalog .. " FOUND"
		local earned = selected == "All" and (state.IndexMilestone or 0)
			or ((state.MutationMilestones or {})[selected] or 0)
		local milestones = selected == "All" and Config.IndexMilestones or Config.MutationMilestones
		local milestone = milestones[earned + 1]
		local multiplier = selected == "All" and 1 or Mutation.Multiplier(selected)
		milestoneLabel.Text = milestone and (discovered .. "/" .. milestone.Goal .. "  ·  +"
			.. Traits.Format.Money(milestone.Reward * multiplier) .. " AUTO") or "ALL REWARDS EARNED"
		for rarity, label in pairs(counts) do
			label.Text = string.upper(rarity) .. " " .. (found[rarity] or 0) .. "/" .. (total[rarity] or 0)
		end
	end)
	input:Register("Index", "INDEX [B]", Enum.KeyCode.B, function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			for _, child in ipairs(hud.Gui:GetChildren()) do
				if child.Name == "UpgradePanel" or child.Name == "ContractPanel" then child.Visible = false end
			end
		end
	end)
	return panel
end

return IndexPanel
