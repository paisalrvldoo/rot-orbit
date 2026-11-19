local shared = game:GetService("ReplicatedStorage")
local Config = require(shared:WaitForChild("Config"))
local Rarity = require(shared:WaitForChild("Rarity"))
local Format = require(shared:WaitForChild("Format"))
local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local ContractService = {}
ContractService.__index = ContractService

function ContractService.new(economy)
	local self = setmetatable({ Economy = economy }, ContractService)
	economy.Contracts = self
	economy.Activities.Event:Connect(function(player, kind, record) self:Progress(player, kind, record) end)
	return self
end

function ContractService:AddPlayer(player)
	local profile = self.Economy.Profiles[player]
	profile.Contracts = {}
	for index in ipairs(Config.Contracts.Tracks) do profile.Contracts[index] = { Stage = 1, Progress = 0 } end
end

function ContractService:View(player)
	local profile = self.Economy.Profiles[player]
	local view = {}
	for index, progress in ipairs(profile and profile.Contracts or {}) do
		local definition = Config.Contracts.Tracks[index][progress.Stage]
		table.insert(view, { Title = definition.Title, Goal = definition.Goal,
			Reward = definition.Reward, Progress = progress.Progress })
	end
	return view
end

function ContractService:Progress(player, kind, record)
	local profile = self.Economy.Profiles[player]
	if not profile or not profile.Contracts then return end
	local entry = record and Catalog.Get(record.Id)
	local rank = entry and Rarity.ByName[entry.Rarity].Rank or 0
	for index, progress in ipairs(profile.Contracts) do
		local track = Config.Contracts.Tracks[index]
		local definition = track[progress.Stage]
		if definition.Kind == kind and rank >= (definition.MinRank or 0) then
			progress.Progress += 1
			if progress.Progress >= definition.Goal then
				profile.Cash = math.min(Config.MaxCash, profile.Cash + definition.Reward)
				progress.Progress = 0
				progress.Stage = progress.Stage % #track + 1
				self.Economy.Network.Notice:FireClient(player, "CONTRACT COMPLETE! +" .. Format.Money(definition.Reward))
			end
		end
	end
	self.Economy:Send(player)
end

return ContractService
