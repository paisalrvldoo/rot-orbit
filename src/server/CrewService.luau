-- Original station crews: server-owned membership, friendly cargo and shared defence.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Format = require(shared:WaitForChild("BrainrotTraits")).Format
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CrewService = {}
CrewService.__index = CrewService

function CrewService.new(world, bases, economy, raids)
	local self = setmetatable({ World = world, Bases = bases, Economy = economy, Raids = raids,
		Crews = {}, Connections = {}, Banners = {}, Global = {}, GlobalStatus = "CONNECTING ALL-TIME",
		Token = HttpService:GenerateGUID(false), Saved = {}, Unpublished = {} }, CrewService)
	for id, definition in ipairs(Config.Crews.Teams) do
		self.Crews[id] = { Id = id, Name = definition.Name, Color = definition.Color, Score = 0, Raids = 0, Bosses = 0 }
	end
	bases.Crews = self
	economy.Crews = self
	raids.Crews = self
	self:BuildBoard()
	local stores, ledger, ordered = pcall(function()
		return DataStoreService:GetDataStore("RotOrbitCrewLedger_v1"),
			DataStoreService:GetOrderedDataStore("RotOrbitCrewRanks_v1")
	end)
	if stores then self.Ledger, self.Ordered = ledger, ordered end
	task.spawn(function()
		while true do
			self:SyncGlobal()
			task.wait(Config.Crews.GlobalRefresh)
		end
	end)
	game:BindToClose(function()
		local deadline = os.clock() + 24
		while self.Syncing and os.clock() < deadline do task.wait(0.1) end
		if not self.Syncing then self:SyncGlobal(true) end
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			self:Refresh()
		end
	end)
	return self
end

-- The ledger records this server's cumulative contribution before publishing a
-- monotonic ordered score. Retrying either write cannot apply a payout twice.
function CrewService:WriteCrew(id)
	local crew = self.Crews[id]
	local amount = crew.Score
	if amount > (self.Saved[id] or 0) then
		local ok, document = pcall(function()
			return self.Ledger:UpdateAsync("crew_" .. id, function(previous)
				local data = type(previous) == "table" and previous or { Total = 0, Sessions = {} }
				data.Sessions = type(data.Sessions) == "table" and data.Sessions or {}
				local before = tonumber(data.Sessions[self.Token]) or 0
				data.Total = math.min(Config.MaxCash, (tonumber(data.Total) or 0) + math.max(0, amount - before))
				data.Sessions[self.Token] = math.max(before, amount)
				return data
			end)
		end)
		if not ok or type(document) ~= "table" or type(document.Total) ~= "number" then return false end
		self.Saved[id] = amount
		self.Unpublished[id] = math.max(self.Unpublished[id] or 0, document.Total)
	end
	if self.Unpublished[id] then
		local total = self.Unpublished[id]
		local ok = pcall(function()
			self.Ordered:UpdateAsync(tostring(id), function(previous)
				return math.max(tonumber(previous) or 0, total)
			end)
		end)
		if not ok then return false end
		self.Unpublished[id] = nil
	end
	return true
end

function CrewService:SyncGlobal(closing)
	if self.Syncing then return end
	if not self.Ledger or not self.Ordered then self.GlobalStatus = "LOCAL ONLY · API UNAVAILABLE"; return end
	self.Syncing = true
	local success = true
	for id in ipairs(self.Crews) do
		if not self:WriteCrew(id) then success = false end
	end
	if not closing then
		local ok, page = pcall(function() return self.Ordered:GetSortedAsync(false, 3):GetCurrentPage() end)
		if ok and type(page) == "table" then
			local rows, present = {}, {}
			for _, item in ipairs(page) do
				local id = tonumber(item.key)
				local crew = id and self.Crews[id]
				if crew and type(item.value) == "number" then
					present[id] = true
					table.insert(rows, { Id = id, Name = crew.Name, Color = crew.Color, Score = item.value })
				end
			end
			for id, crew in ipairs(self.Crews) do
				if not present[id] then table.insert(rows, { Id = id, Name = crew.Name, Color = crew.Color, Score = 0 }) end
			end
			table.sort(rows, function(a, b) if a.Score == b.Score then return a.Id < b.Id end; return a.Score > b.Score end)
			self.Global = rows
		else success = false end
	end
	self.GlobalStatus = success and "ALL-TIME SYNCED" or "GLOBAL RETRYING · LOCAL PLAY CONTINUES"
	self.Syncing = false
end

function CrewService:Same(first, second)
	local a, b = self.Bases.Players[first], self.Bases.Players[second]
	return a ~= nil and b ~= nil and a.CrewId ~= nil and a.CrewId == b.CrewId
end

function CrewService:Join(player, id)
	local state, profile = self.Bases.Players[player], self.Economy.Profiles[player]
	if type(id) ~= "number" or id % 1 ~= 0 or not self.Crews[id] or not state or not profile
		or state.Loading or state.Closing or profile.Demo then return end
	if state.CrewId == id then return end
	local now = workspace:GetServerTimeNow()
	if state.Carry or self.Raids.Active or now < (state.CrewReadyAt or 0) then
		self.Economy.Network.Notice:FireClient(player, "CREW · DOCK CARGO, FINISH THE RAID OR WAIT 15s TO SWITCH")
		return
	end
	state.CrewId, state.CrewReadyAt = id, now + Config.Crews.SwitchCooldown
	player:SetAttribute("OrbitCrewId", id)
	self:Paint(player)
	if self.Connections[player] then self.Connections[player]:Disconnect() end
	self.Connections[player] = player.CharacterAdded:Connect(function()
		task.delay(1, function() if self.Bases.Players[player] then self:Paint(player) end end)
	end)
	self.Economy.Network.Notice:FireClient(player, "JOINED " .. string.upper(self.Crews[id].Name) .. " · TEAM CARGO PROTECTED")
	self:Refresh()
end

function CrewService:Paint(player)
	local state = self.Bases.Players[player]
	local crew = state and self.Crews[state.CrewId]
	if not crew then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local old = root:FindFirstChild("CrewNameplate")
		if old then old:Destroy() end
		local tag = WorldBuilder.Billboard(root, crew.Name, crew.Color, Vector3.new(0, 4.4, 0), 210, 26)
		tag.Parent.Name = "CrewNameplate"
		tag.TextSize = 16
	end
	if self.Banners[player] then self.Banners[player].Parent:Destroy() end
	local banner = WorldBuilder.Billboard(state.Bay.Floor, crew.Name, crew.Color, Vector3.new(0, 13, 0), 360, 30)
	banner.Parent.Name = "PlayerCrewBanner"
	self.Banners[player] = banner
end

function CrewService:Remove(player)
	if self.Connections[player] then self.Connections[player]:Disconnect(); self.Connections[player] = nil end
	if self.Banners[player] then self.Banners[player].Parent:Destroy(); self.Banners[player] = nil end
end

function CrewService:OnDefeat(player, enemy)
	local state = self.Bases.Players[player]
	local crew = state and self.Crews[state.CrewId]
	if not crew then return end
	crew.Score += enemy.Boss and Config.Crews.BossScore or Config.Crews.KillScore
	if enemy.Boss then crew.Bosses += 1 end
	for member, other in pairs(self.Bases.Players) do
		local profile = self.Economy.Profiles[member]
		if member ~= player and self:Same(player, member) and profile and not profile.Demo
			and not other.Loading and not other.Closing and self.Bases:Near(member, enemy.Position, Config.Crews.RewardRadius) then
			local reward = enemy.Boss and Config.Crews.BossAssist or Config.Crews.KillAssist
			profile.Cash = math.min(Config.MaxCash, profile.Cash + reward)
			self.Economy.Network.Notice:FireClient(member, "CREW ASSIST! +$" .. reward)
			self.Economy:Send(member)
		end
	end
end

function CrewService:Defended(players)
	local awarded = {}
	for _, player in ipairs(players) do
		local state = self.Bases.Players[player]
		local crew = state and self.Crews[state.CrewId]
		if crew and not awarded[crew.Id] then
			awarded[crew.Id] = true
			crew.Raids += 1
			crew.Score += Config.Crews.RaidScore
		end
	end
end

function CrewService:View(player)
	local state = self.Bases.Players[player]
	local rows = {}
	for _, crew in ipairs(self.Crews) do
		local row = { Id = crew.Id, Name = crew.Name, Color = crew.Color, Score = crew.Score,
			Raids = crew.Raids, Bosses = crew.Bosses, Members = {}, Cash = 0, Income = 0 }
		for member, other in pairs(self.Bases.Players) do
			local profile = self.Economy.Profiles[member]
			if other.CrewId == crew.Id and profile and not other.Loading and not other.Closing then
				row.Cash += profile.Cash
				row.Income += self.Economy:Income(member)
				table.insert(row.Members, { Name = member.DisplayName, Bay = other.Bay.Index,
					Locked = (other.Bay.Model:GetAttribute("LockedUntil") or 0) > workspace:GetServerTimeNow() })
			end
		end
		table.sort(row.Members, function(a, b) return a.Bay < b.Bay end)
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		if a.Score ~= b.Score then return a.Score > b.Score end
		if a.Income ~= b.Income then return a.Income > b.Income end
		return a.Id < b.Id
	end)
	return { Current = state and state.CrewId, Rows = rows, Global = self.Global, Status = self.GlobalStatus }
end

function CrewService:BuildBoard()
	local palette = Config.Palette
	local frame = CFrame.lookAt(Vector3.new(35, 7.5, 43), Vector3.new(0, 7.5, 0))
	local board = WorldBuilder.Part("CrewRankingBoard", Vector3.new(26, 10.6, 0.8),
		frame, palette.Ink, Enum.Material.Metal, self.World.Geometry)
	local shine = WorldBuilder.Part("CrownLight", Vector3.new(25, 0.16, 0.14),
		frame * CFrame.new(0, 4.98, -0.48), palette.Sun, Enum.Material.Neon, board, nil, false)
	shine.Transparency = 0.48
	self.BoardShine = shine
	local medallions = { palette.Sun, Color3.fromRGB(192, 222, 239), Color3.fromRGB(219, 144, 106) }
	local displayOrder = { 2, 1, 3 }
	local crown = Instance.new("Model")
	crown.Name = "CrewRankCrown"
	local crownFrame = frame * CFrame.new(0, 6.32, -0.3)
	local band = WorldBuilder.Part("GoldBand", Vector3.new(0.36, 2.5, 2.5),
		crownFrame * CFrame.Angles(0, 0, math.pi / 2), palette.Sun,
		Enum.Material.Metal, crown, Enum.PartType.Cylinder, false)
	for index = 1, 5 do
		local angle = index * math.pi * 2 / 5
		local prong = crownFrame * CFrame.Angles(0, angle, 0) * CFrame.new(1, 0.42, 0)
		WorldBuilder.Part("CrownProng", Vector3.new(0.35, 0.94, 0.42), prong,
			palette.Sun, Enum.Material.Metal, crown, nil, false)
		WorldBuilder.Part("CrownGem", Vector3.one * 0.48, prong * CFrame.new(0, 0.48, 0),
			palette.Sun, Enum.Material.Neon, crown, Enum.PartType.Ball, false)
	end
	crown.PrimaryPart = band
	band.PivotOffset = CFrame.Angles(0, 0, -math.pi / 2)
	crown:SetAttribute("CrownFrame", crownFrame)
	crown.Parent = board
	CollectionService:AddTag(crown, "OrbitCrewCrown")
	local surface = Instance.new("SurfaceGui")
	surface.Name = "CrewRanks"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(780, 318)
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0
	surface.MaxDistance = 90
	surface.Parent = board
	local function caption(name, x, y, width, height, size, color, value)
		local label = Instance.new("TextLabel")
		label.Name, label.Text = name, value or ""
		label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height)
		label.BackgroundTransparency = 1
		label.TextColor3, label.Font = color, Enum.Font.GothamBold
		label.TextSize = size
		label.Parent = surface
		return label
	end
	caption("Title", 0, 19, 780, 48, 39, palette.Sun, "CREW  RANKS")
	self.Board = caption("Empty", 0, 120, 780, 65, 35, palette.White)
	caption("Footer", 0, 268, 780, 37, 21, palette.Muted, "SERVER DEFENCE  ·  ALL-TIME IN CREWS [Y]")
	self.BoardRows = {}
	for column, rank in ipairs(displayOrder) do
		local x = 7 + (column - 1) * 258
		local y = rank == 1 and 86 or 109
		local color = medallions[rank]
		local podiumHeight = ({ 2.2, 1.5, 1.15 })[rank]
		local display = WorldBuilder.Part("RankPodium" .. rank, Vector3.new(7.2, podiumHeight, 2.3),
			frame * CFrame.new((column - 2) * 8.6, -7.5 + podiumHeight / 2, -0.25),
			color, Enum.Material.Metal, board, nil, false)
		local strip = WorldBuilder.Part("CrewColour" .. rank, Vector3.new(6.8, 0.18, 0.12),
			display.CFrame * CFrame.new(0, podiumHeight * 0.29, -1.19),
			color, Enum.Material.Neon, board, nil, false)
		self.BoardRows[rank] = {
			Rank = caption("Rank" .. rank, x, y, 250, 33, 28, color, "#" .. rank),
			Name = caption("Crew" .. rank, x, y + 36, 250, 31, 24, color),
			Score = caption("Score" .. rank, x, y + 71, 250, 32, 28, palette.White),
			Stats = caption("Stats" .. rank, x, y + 107, 250, 25, 17, palette.Muted),
			Strip = strip,
		}
	end
	for id, crew in ipairs(self.Crews) do
		local angle = (id - 1) * math.pi * 2 / #self.Crews
		local pad = WorldBuilder.Part("Join" .. id, Vector3.new(6, 0.35, 6),
			CFrame.new(math.cos(angle) * 29, 0.3, math.sin(angle) * 29),
			crew.Color, Enum.Material.SmoothPlastic, self.World.Geometry)
		local joinLabel = WorldBuilder.Billboard(pad, "JOIN " .. string.upper(crew.Name), crew.Color,
			Vector3.new(0, 2, 0), 142, 26)
		joinLabel.TextSize = 13
		joinLabel.Parent.MaxDistance = 34
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Join Crew", crew.Name
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			if self.Bases:Near(player, pad.Position, 12) then self:Join(player, id) end
		end)
	end
	self:Refresh()
end

function CrewService:Refresh()
	local view = self:View(nil)
	local populated = view.Rows[1] and view.Rows[1].Score > 0
	self.Board.Text = populated and "" or "No raids yet · be the first crew!"
	local standings = {}
	for rank, slot in ipairs(self.BoardRows) do
		local row = view.Rows[rank]
		local visible = row ~= nil and row.Score > 0
		slot.Rank.Visible, slot.Name.Visible, slot.Score.Visible, slot.Stats.Visible = visible, visible, visible, visible
		slot.Strip.Transparency = visible and 0 or 0.82
		if visible then
			slot.Name.Text, slot.Name.TextColor3 = row.Name, row.Color
			slot.Strip.Color = row.Color
			slot.Score.Text = Format.Number(row.Score) .. " PTS"
			slot.Stats.Text = string.format("%d RAIDS   ·   %d BOSSES", row.Raids, row.Bosses)
			standings[rank] = string.format("%d:%d:%d:%d", row.Id, row.Score, row.Raids, row.Bosses)
		end
	end
	local signature = table.concat(standings, "|")
	if populated and signature ~= self.BoardSignature then
		self.BoardShine.Transparency = 0.04
		TweenService:Create(self.BoardShine, TweenInfo.new(0.9), { Transparency = 0.48 }):Play()
	end
	self.BoardSignature = signature
	local leader = view.Rows[1]
	for player, banner in pairs(self.Banners) do
		local state = self.Bases.Players[player]
		local crew = state and self.Crews[state.CrewId]
		if crew then
			local first = leader and leader.Score > 0 and crew.Id == leader.Id
			banner.Text = (first and "#1 CREW · " or "") .. crew.Name
			banner.TextColor3 = first and Config.Palette.Sun or crew.Color
		end
	end
end

return CrewService
