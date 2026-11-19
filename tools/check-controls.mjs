// Run the real input/layout controller with a small GUI host; this is not a render.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = path => readFileSync(join(root, path), 'utf8');
const moduleBody = (path, marker) => `(function()\n${source(path).slice(source(path).indexOf(marker))}\nend)()`;
const client = source('src/client/Game.client.luau');
const harness = `
local Color3 = { fromRGB = function(...) return {...} end }
local Vector3 = { new = function(...) return {...} end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim = { new = function(...) return {...} end }
local UDim2 = { new = function(xs, x, ys, y) return { X = { Scale = xs, Offset = x }, Y = { Scale = ys, Offset = y } } end }
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local function signal()
    local s = { Callbacks = {} }
    function s:Connect(callback) table.insert(self.Callbacks, callback) end
    function s:Fire(...) for _, callback in ipairs(self.Callbacks) do callback(...) end end
    return s
end
local Instance = {}
function Instance.new(class, parent)
    local object = { ClassName = class, Attributes = {}, Visible = true, AnchorPoint = Vector2.new(0, 0), Size = UDim2.fromOffset(0, 0) }
    function object:SetAttribute(key, value) self.Attributes[key] = value end
    function object:GetAttribute(key) return self.Attributes[key] end
    function object:FindFirstChild(name)
        for _, child in ipairs(self.Children or {}) do if child.Name == name then return child end end
    end
    setmetatable(object, { __newindex = function(t, key, value)
        rawset(t, key, value)
        if key == 'Parent' and value then
            value.Children = value.Children or {}; table.insert(value.Children, t)
        end
    end })
    object.Parent = parent
    return object
end
local Enum = { KeyCode = setmetatable({}, { __index = function(_, key) return key end }), Font = { GothamBold = 1 },
    ApplyStrokeMode = { Border = 1 }, UserInputState = { Begin = 1 }, ContextActionResult = { Sink = 1, Pass = 2 } }
local ContextActionService = { Bindings = {} }
function ContextActionService:BindAction(name, callback) self.Bindings[name] = callback end
local UserInputService = { GetFocusedTextBox = function() return nil end }
local RunService = { RenderStepped = signal() }
local workspace = { GetServerTimeNow = function() return 100 end }
local Config = ${moduleBody('src/shared/Config.luau', 'local Config =')}
local Traits = ${moduleBody('src/shared/BrainrotTraits.luau', 'local Rarity =')}
local Format = Traits.Format
local compact = true
local HudController = { IsCompact = function() return compact end,
    ButtonFeedback = function(button, callback) button.Activate = callback; return callback end }
${client.slice(client.indexOf('local InputController ='), client.indexOf('local function startCrewPanel'))}
local state = { Upgrades = {}, Found = {}, Catalog = table.create(43), Rebirths = 0, SaveStatus = 'SAVED' }
local sent = {}
local hud = { Gui = Instance.new('Frame'), GetState = function() return state end,
    Network = { Action = { FireServer = function(_, ...) table.insert(sent, {...}) end } } }
local input = InputController.Start(hud)
local upgrades = Instance.new('Frame', hud.Gui); upgrades.Name, upgrades.Visible = 'UpgradePanel', false
for _, name in ipairs({ 'Upgrades', 'Rebirth', 'Index' }) do
    input:Register(name, name, name, function() upgrades.Visible = true end)
end
local function frame() RunService.RenderStepped:Fire() end
frame()
local menu, more = hud.Gui:FindFirstChild('MobileMenu'), hud.Gui:FindFirstChild('SkillPage')
assert(menu.Visible and more.Visible and not input.Buttons.Lock.Visible and not input.Buttons.Index.Visible)
assert(input.Buttons.Blink.Visible and input.Buttons.Sprint.Visible and input.Buttons.Bomb.Visible)
assert(not input.Buttons.Slam.Visible and not input.Buttons.Bubble.Visible)
local scale = 460 / 720 -- Actual HUD scale at the reported 1024x460 phone viewport.
local rectangles = {}
for _, button in ipairs(hud.Gui.Children) do
    if button.ClassName == 'TextButton' and button.Visible then
        assert(button.Size.X.Offset * scale >= 44 and button.Size.Y.Offset * scale >= 44,
            button.Name .. ' must have a 44px phone tap target')
        local p, s, a = button.Position, button.Size, button.AnchorPoint
        local x, y = 1280 * p.X.Scale + p.X.Offset - s.X.Offset * a.X, 720 * p.Y.Scale + p.Y.Offset - s.Y.Offset * a.Y
        assert(x >= 0 and y >= 0 and x + s.X.Offset <= 1280 and y + s.Y.Offset <= 720, button.Name .. ' is clipped')
        for _, r in ipairs(rectangles) do
            assert(x + s.X.Offset <= r.x or r.x + r.w <= x or y + s.Y.Offset <= r.y or r.y + r.h <= y,
                button.Name .. ' overlaps ' .. r.name)
        end
        table.insert(rectangles, { x = x, y = y, w = s.X.Offset, h = s.Y.Offset, name = button.Name })
    end
end
more.Activate(); frame()
assert(input.Buttons.Slam.Visible and input.Buttons.Bubble.Visible and input.Buttons.Dash.Visible and not input.Buttons.Blink.Visible)
local trap = hud.Gui:FindFirstChild('PlaceTrap')
assert(trap.Visible)
trap.Activate()
assert(sent[#sent][1] == 'Skill' and sent[#sent][2] == 'Bomb' and sent[#sent][3] == 'Trap')
ContextActionService.Bindings.RotOrbitTrap(nil, Enum.UserInputState.Begin)
assert(sent[#sent][3] == 'Trap', 'T and touch must place the same server-checked trap')
state.SkillReadyAt = { Bomb = 110 }; frame()
assert(trap:GetAttribute('Unavailable') and input.Buttons.Bomb:GetAttribute('Unavailable'), 'throw/trap must share cooldown UI')
menu.Activate(); frame()
assert(input.Buttons.Lock.Visible and input.Buttons.Rebirth.Visible and hud.Gui:GetAttribute('MobileMenuOpen'))
input.Buttons.Upgrades.Activate(); frame()
assert(upgrades.Visible and not input.Buttons.Lock.Visible and not hud.Gui:GetAttribute('MobileMenuOpen'))
upgrades.Visible = false
ContextActionService.Bindings.RotOrbitBlink(nil, Enum.UserInputState.Begin)
assert(sent[#sent][1] == 'Skill' and sent[#sent][2] == 'Blink', 'keyboard must retain the same skill action')
state.SaveStatus = 'STUDIO PREVIEW'; frame()
assert(not menu.Visible and not more.Visible and not trap.Visible and input.Buttons.Lock.Visible and input.Buttons.Blink.Visible and input.Buttons.Bubble.Visible)
state.SaveStatus = 'SAVED'; compact = false; frame()
assert(input.Buttons.Index.Visible and input.Buttons.Rebirth.Visible and not menu.Visible)
print('Control checks passed: phone arc bounds/44px targets, no overlaps, menu, utility page, keyboard, panels and staged/desktop restoration.')
`;
const directory = join(root, 'out', 'control-check');
mkdirSync(directory, { recursive: true });
const script = join(directory, 'check.luau');
writeFileSync(script, harness);
const result = spawnSync('luau', [script], { encoding: 'utf8', cwd: root });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
