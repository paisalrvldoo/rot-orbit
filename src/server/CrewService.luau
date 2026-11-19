-- Original station crews: server-owned membership, friendly cargo and shared defence.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CrewService = {}
CrewService.__index = CrewService

function CrewService.new(world, bases, economy, raids)
	local self = setmetatable({ World = world, Bases = bases, Economy = economy, Raids = raids,
		Crews = {}, Connections = {}, Banners = {}, Global = {}, GlobalStatus = "LOCAL SESSION" }, CrewService)
	for id, definition in ipairs(Config.Crews.Teams) do
		self.Crews[id] = { Id = id, Name = definition.Name, Color = definition.Color, Score = 0, Raids = 0, Bosses = 0 }
	end
	bases.Crews = self
	economy.Crews = self
	raids.Crews = self
	self:BuildBoard()
	task.spawn(function()
		while true do
			task.wait(3)
			self:Refresh()
		end
	end)
	return self
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
	local board = WorldBuilder.Part("CrewRankingBoard", Vector3.new(26, 15, 0.8), CFrame.new(22, 9, 18),
		Config.Palette.Ink, Enum.Material.SmoothPlastic, self.World.Geometry, nil, false)
	self.Board = WorldBuilder.Billboard(board, "CREW RANKS", Config.Palette.White, Vector3.zero, 510, 290)
	self.Board.TextSize = 22
	for id, crew in ipairs(self.Crews) do
		local pad = WorldBuilder.Part("Join" .. id, Vector3.new(6, 0.35, 6), CFrame.new(14 + (id - 1) * 8, 0.3, 26),
			crew.Color, Enum.Material.SmoothPlastic, self.World.Geometry)
		WorldBuilder.Billboard(pad, "JOIN " .. string.upper(crew.Name), crew.Color, Vector3.new(0, 2, 0), 200, 30).TextSize = 14
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
	local lines = { "CREW RANKS · [Y]", "SERVER · SCORE / RAIDS / BOSSES" }
	for rank, row in ipairs(view.Rows) do
		table.insert(lines, string.format("#%d %s · %d / %d / %d", rank, row.Name, row.Score, row.Raids, row.Bosses))
	end
	table.insert(lines, "JOIN A COLOUR PAD · TEAM UP TO DEFEND")
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
