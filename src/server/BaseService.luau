local Catalog = require(script.Parent:WaitForChild("BrainrotCatalog"))
local BrainrotModel = require(script.Parent:WaitForChild("BrainrotModel"))
local BaseService = {}
BaseService.__index = BaseService

function BaseService.new(world, network)
	return setmetatable({ World = world, Network = network, Players = {} }, BaseService)
end

function BaseService:SeedRivals()
	local lineup = { 1, 4, 7, 8, 11, 13, 15, 18 }
	for crewIndex, bay in ipairs(self.World.RivalBays) do
		for index, pedestal in ipairs(bay.Slots) do
			if not pedestal.Occupant then
				local record = { Id = lineup[index] + crewIndex - 1,
					Guid = "rival_" .. crewIndex .. "_" .. index }
				if crewIndex == 2 and index == 8 then record.Mutation = "Gold" end
				if crewIndex == 3 and index == 6 then record.Mutation = "Diamond" end
				pedestal.Occupant = { Record = record,
					Model = BrainrotModel.Create(record, pedestal.Frame, bay.Model) }
				pedestal.Label.Visible = false
			end
		end
	end
end

return BaseService
