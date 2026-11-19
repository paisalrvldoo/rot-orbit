local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Rarity = require(shared:WaitForChild("Rarity"))
local Style = require(script.Parent:WaitForChild("PanelStyle"))
local IndexPanel = {}

function IndexPanel.Start(hud, input)
	local panel = Style.Create(hud, "IndexPanel", "INDEX · 0/30 FOUND", 980, 458)
	local header = panel:FindFirstChildOfClass("TextLabel")
	local cells, counts = {}, {}
	for index, rarity in ipairs(Rarity.Order) do
		counts[rarity] = Style.Text(panel, rarity .. " 0/0", 22 + (index - 1) * 134, 57, 134, 28,
			14, Rarity.ByName[rarity].Color)
	end
	local function silhouette(parent, color)
		local parts = {}
		for _, shape in ipairs({ { 13, 8, 18, 18 }, { 9, 25, 26, 22 }, { 8, 43, 11, 7 }, { 25, 43, 11, 7 } }) do
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
		if not state then return end
		local found, total = {}, {}
		local discovered = 0
		for index, entry in ipairs(state.Catalog) do
			local rarity = Rarity.ByName[entry.Rarity]
			local known = state.Found[tostring(entry.Id)] == true
			total[entry.Rarity] = (total[entry.Rarity] or 0) + 1
			if known then
				discovered += 1
				found[entry.Rarity] = (found[entry.Rarity] or 0) + 1
			end
			local cell = cells[entry.Id]
			if not cell then
				local frame = Instance.new("Frame")
				frame.Position = UDim2.fromOffset(22 + (index - 1) % 6 * 157, 100 + math.floor((index - 1) / 6) * 68)
				frame.Size = UDim2.fromOffset(150, 62)
				frame.BackgroundColor3 = Color3.fromRGB(23, 46, 66)
				frame.BorderSizePixel = 0
				frame.ZIndex = 11
				frame.Parent = panel
				Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 9)
				local stroke = Instance.new("UIStroke", frame)
				stroke.Thickness = 1.2
				local name = Style.Text(frame, "", 42, 5, 102, 33, 13)
				name.TextWrapped = true
				cell = { Name = name, Rarity = Style.Text(frame, "", 42, 42, 104, 15, 10),
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
		header.Text = "INDEX · " .. discovered .. "/" .. #state.Catalog .. " FOUND"
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
