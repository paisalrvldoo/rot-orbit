-- Original station crews: server-owned membership, friendly cargo and shared defence.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
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
	-- Face the hub from a real panel; text must never follow the camera or cover play.
	local board = WorldBuilder.Part("CrewRankingBoard", Vector3.new(22, 12, 0.8),
		CFrame.lookAt(Vector3.new(31, 7, 39), Vector3.new(0, 7, 0)),
		Config.Palette.Ink, Enum.Material.SmoothPlastic, self.World.Geometry)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "CrewRanks"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(660, 360)
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0
	surface.MaxDistance = 90
	surface.Parent = board
	local label = Instance.new("TextLabel")
	label.Position, label.Size = UDim2.fromOffset(24, 18), UDim2.fromOffset(612, 324)
	label.BackgroundTransparency = 1
	label.TextColor3, label.Font = Config.Palette.White, Enum.Font.GothamBold
	label.TextSize, label.TextYAlignment = 26, Enum.TextYAlignment.Top
	label.Parent = surface
	self.Board = label
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
	local lines = { "CREW RANKS · DEFENCE SCORE" }
	local populated = false
	for rank, row in ipairs(view.Rows) do
		if row.Score > 0 then
			populated = true
			table.insert(lines, string.format("#%d %s · %d", rank, row.Name, row.Score))
		end
	end
	if not populated then table.insert(lines, "No raids yet · defend together!") end
	-- Full global results and sync status have their own HUD tab.
	table.insert(lines, "ALL-TIME RANKS · OPEN [Y]")
	self.Board.Text = table.concat(lines, "\n")
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
