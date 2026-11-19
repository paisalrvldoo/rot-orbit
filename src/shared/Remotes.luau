-- A shared registry; only the server creates network instances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = {}
local cached

local definitions = {
	Snapshot = "RemoteEvent",
	Notice = "RemoteEvent",
	CashPop = "RemoteEvent",
	Event = "RemoteEvent",
	Action = "RemoteEvent",
	RequestSnapshot = "RemoteFunction",
}

function Remotes.Get()
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild("OrbitRemotes")
	if not folder and RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "OrbitRemotes"
		folder.Parent = ReplicatedStorage
	end
	folder = folder or ReplicatedStorage:WaitForChild("OrbitRemotes")
	local registry = {}
	for name, className in pairs(definitions) do
		local remote = folder:FindFirstChild(name)
		if not remote and RunService:IsServer() then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
		registry[name] = remote or folder:WaitForChild(name)
	end
	cached = registry
	return registry
end

return Remotes
