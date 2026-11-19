-- Studio-only presets, callable from the server Command Bar or the review tour.
local RunService = game:GetService("RunService")
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local ScreenshotMode = {}
local handler

function ScreenshotMode.Configure(callback)
	assert(RunService:IsServer(), "Screenshot presets are configured by the server")
	handler = callback
end

local function prepare(shot, playerId)
	if RunService:IsServer() then
		assert(handler, "Start a Studio playtest before using ScreenshotMode")
		return handler(shot, playerId)
	end
	Remotes.Get().Action:FireServer("Screenshot", shot)
end

function ScreenshotMode.Cover(playerId) return prepare("Cover", playerId) end
function ScreenshotMode.Index(playerId) return prepare("Index", playerId) end
function ScreenshotMode.Raid(playerId) return prepare("Raid", playerId) end
function ScreenshotMode.Upgrades(playerId) return prepare("Upgrades", playerId) end

function ScreenshotMode.Listen(hud)
	Remotes.Get().Screenshot.OnClientEvent:Connect(function(scene)
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = scene.Camera
			camera.FieldOfView = scene.FieldOfView
		end
		for _, name in ipairs({ "UpgradePanel", "ContractPanel", "IndexPanel" }) do
			local panel = hud.Gui:FindFirstChild(name)
			if panel then panel.Visible = name == "IndexPanel" and scene.Shot == "Index"
				or (name ~= "IndexPanel" and scene.Shot == "Upgrades") end
		end
	end)
end

return ScreenshotMode
