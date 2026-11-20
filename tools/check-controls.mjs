// Run the real input/layout controller with a small GUI host; this is not a render.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = path => readFileSync(join(root, path), 'utf8');
const moduleBody = (path, marker) => `(function()\n${source(path).slice(source(path).indexOf(marker))}\nend)()`;
const client = source('src/client/Game.client.luau');
const hudSource = source('src/client/HudController.luau');
const section = (text, start, end) => text.slice(text.indexOf(start), text.indexOf(end, text.indexOf(start)));
const harness = `
local Color3 = { fromRGB = function(...) return {...} end }
local Vector3 = { new = function(...) return {...} end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim = { new = function(...) return {...} end }
local UDim2 = { new = function(xs, x, ys, y) return { X = { Scale = xs, Offset = x }, Y = { Scale = ys, Offset = y } } end }
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
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
    function object:FindFirstChildOfClass(class)
        for _, child in ipairs(self.Children or {}) do if child.ClassName == class then return child end end
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
${source('src/client/HudController.luau').slice(source('src/client/HudController.luau').indexOf('function HudController.EventCopy('), source('src/client/HudController.luau').indexOf('local function startEventBanner('))}
local meteor={Name='Meteor',Text='METEOR SHOWER! GET UNDER THE SHIELD DOME'}
assert(HudController.EventCopy(meteor,true)=='METEOR SHOWER · FIND A SHIELD')
assert(HudController.EventCopy(meteor,false)==meteor.Text,'desktop event instructions must be preserved')
assert(HudController.EventCopy({Name='Gremlin',Text='CAPTAIN RAID! ZAP [F]'},true)=='CAPTAIN RAID · TAP ZAP')
assert(not HudController.EventCopy({Name='Other',Text='LOCK [L] OR ZAP [F]'},true):find('%['))
assert(HudController.FirstStep({Inventory={},Carrying=false},false)==1,'first arrival must point to BUY')
assert(HudController.FirstStep({Inventory={},Carrying={Id=1}},false)==2,'carried cargo must point to YOUR bay')
assert(HudController.FirstStep({Inventory={{Id=1}},Carrying=false},false)==3,'docked cargo must explain income collection')
assert(HudController.FirstStep({Inventory={{Id=1}}},true)==0,'first payment must hide the guide')
assert(HudController.FirstStep({Inventory={},Rebirths=1},false)==0,'rebirth players must skip first steps')
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
local menu = hud.Gui:FindFirstChild('MobileMenu')
assert(menu.Visible and not input.Buttons.Lock.Visible and not input.Buttons.Index.Visible)
assert(input.Buttons.Blink.Visible and input.Buttons.Sprint.Visible and input.Buttons.Zap.Visible)
for _, name in ipairs({ 'Dash', 'Slam', 'Bubble', 'Bomb', 'Trap' }) do
    assert(not input.Buttons[name] and not ContextActionService.Bindings['RotOrbit' .. name])
end
assert(not hud.Gui:FindFirstChild('SkillPage') and not hud.Gui:FindFirstChild('PlaceTrap'))
local scale = 460 / 720 -- Actual HUD scale at the reported 1024x460 phone viewport.
local function checkBounds()
 local rectangles = {}
 for _, button in ipairs(hud.Gui.Children) do
    if button.ClassName == 'TextButton' and button.Visible then
        assert(button.Size.X.Offset * scale >= 44 and button.Size.Y.Offset * scale >= 44,
            button.Name .. ' must have a 44px phone tap target')
        local p, s, a = button.Position, button.Size, button.AnchorPoint
        local x, y = 1280 * p.X.Scale + p.X.Offset - s.X.Offset * a.X, 720 * p.Y.Scale + p.Y.Offset - s.Y.Offset * a.Y
        assert(x >= 0 and y >= 0 and x + s.X.Offset <= 1280 and y + s.Y.Offset <= 720, button.Name .. ' is clipped')
        -- Conservative default jump envelope on a 16:9 phone canvas. At the
        -- reported wider viewport the HUD letterbox adds more clearance.
        assert(x + s.X.Offset <= 1140 or y + s.Y.Offset <= 550,
            button.Name .. ' overlaps the reserved Roblox jump area')
        for _, r in ipairs(rectangles) do
            assert(x + s.X.Offset <= r.x or r.x + r.w <= x or y + s.Y.Offset <= r.y or r.y + r.h <= y,
                button.Name .. ' overlaps ' .. r.name)
        end
        table.insert(rectangles, { x = x, y = y, w = s.X.Offset, h = s.Y.Offset, name = button.Name })
    end
 end
end
checkBounds()
state.SkillReadyAt = { Sprint = 110 }; frame()
assert(input.Buttons.Sprint:GetAttribute('Unavailable') and not input.Buttons.Blink:GetAttribute('Unavailable'))
assert(input.Buttons.Sprint:FindFirstChild('ActionCaption').Text == 'RUN\\n10s')
assert(input.Buttons.Sprint:GetAttribute('CooldownFraction') == 10 / Config.Skills.Sprint.Cooldown)
assert(input.Buttons.Blink:GetAttribute('CooldownFraction') == 0)
assert(input.Buttons.Blink:FindFirstChild('ActionIcon') and input.Buttons.Zap:FindFirstChild('ActionIcon'))
assert(input.Buttons.Sprint:FindFirstChild('CooldownProgress').Visible)
assert(input.Buttons.Lock.Text == 'LOCK\\nREADY' and not input.Buttons.Zap:FindFirstChild('ActionCaption').Text:find('%[F%]'),
    'touch controls should show button names without keyboard-only hints')
state.SkillReadyAt = {}; state.ZapReadyAt = 102; frame()
assert(not input.Buttons.Sprint:GetAttribute('Unavailable'))
assert(input.Buttons.Sprint:FindFirstChild('ActionCaption').Text == 'RUN\\nREADY')
assert(input.Buttons.Sprint:GetAttribute('CooldownFraction') == 0)
assert(input.Buttons.Zap:GetAttribute('Unavailable') and input.Buttons.Zap:GetAttribute('CooldownFraction') == 2 / 3)
menu.Activate(); frame()
checkBounds()
assert(input.Buttons.Lock.Visible and input.Buttons.Rebirth.Visible and hud.Gui:GetAttribute('MobileMenuOpen'))
state.LockUntil = 104; frame()
assert(input.Buttons.Lock.Text == 'LOCK\\nLOCKED · 4s', 'touch lock state must stay readable without a key hint')
input.Buttons.Upgrades.Activate(); frame()
assert(upgrades.Visible and not input.Buttons.Lock.Visible and not hud.Gui:GetAttribute('MobileMenuOpen'))
upgrades.Visible = false
ContextActionService.Bindings.RotOrbitBlink(nil, Enum.UserInputState.Begin)
assert(sent[#sent][1] == 'Skill' and sent[#sent][2] == 'Blink', 'keyboard must retain the same skill action')
state.SaveStatus = 'STUDIO PREVIEW'; frame()
assert(not menu.Visible and input.Buttons.Lock.Visible and input.Buttons.Blink.Visible and input.Buttons.Sprint.Visible)
assert(not input.Buttons.Sprint:FindFirstChild('CooldownProgress').Visible)
state.SaveStatus = 'SAVED'; state.LockUntil = nil; state = table.clone(state); compact = false; frame()
assert(input.Buttons.Index.Visible and input.Buttons.Rebirth.Visible and not menu.Visible)
assert(input.Buttons.Lock.Text == 'LOCK [L]\\nREADY' and input.Buttons.Zap:FindFirstChild('ActionCaption').Text:find('%[F%]'),
    'desktop controls should retain keyboard hints')
-- Instantiate the real chrome declarations alongside the actual input controller.
${section(hudSource, 'function HudController.Text(', 'function HudController.EventCopy(')}
${section(hudSource, 'function HudController.Canvas(', 'local function startEventBanner(')}
${section(hudSource, 'local function startEventBanner(', 'function HudController.Start(')}
local gui = hud.Gui
${section(hudSource, '\tlocal cash = HudController.Text(', '\tlocal function renderFeed(')}
${section(hudSource, '\tlocal quest = Instance.new("Frame")', '\tlocal marker = Instance.new("Part")')}
local events = { Event = { OnClientEvent = signal() }, Snapshot = { OnClientEvent = signal() } }
startEventBanner(gui, events)
events.Snapshot.OnClientEvent:Fire({ Ready = true, NextMeteorAt = 200 })
local open = Instance.new('TextButton', gui); open.Name = 'CrewButton'
local questTab = Instance.new('TextButton', gui); questTab.Name = 'ContractsTab'
for _, viewport in ipairs({ Vector2.new(844,390), Vector2.new(390,844) }) do
 for _, expanded in ipairs({ false, true }) do
  compact = true; input.MenuOpen = expanded; state.SaveStatus = 'SAVED'; frame()
  local width, height, factor = HudController.Canvas(viewport, true)
  gui.Size = UDim2.fromOffset(width, height)
  -- Run the same compact carrying/status declarations as the live frame loop.
  ${section(hudSource, '\t\tcarrying.Position = compact', '\t\tlocal root = player.Character')}
  ${section(client, '\t\topen.Position = compact', '\t\topen:SetAttribute("Selected"')}
  ${section(source('src/client/UpgradeRebirthContracts.luau'), '\t\tquestTab.Position =', '\t\tquest.Position =')}
  open.Visible, questTab.Visible = expanded, expanded
  quest.Visible, carrying.Visible, hint.Visible = not expanded, true, false
  boss.Visible = true -- Worst case: captain bar, first quest, cash and event coexist.
  for _, row in ipairs(feedLabels) do row.Text = 'LIVE ACTION FEED' end
  HudController.LayoutChrome(gui, true, expanded)
  local rects = {}
  for _, object in ipairs(gui.Children) do
   if (object.ClassName == 'TextButton' or object.ClassName == 'TextLabel' or object.Name == 'QuestCard')
    and object.Visible and object.Text ~= '' then
    local p, size, anchor = object.Position, object.Size, object.AnchorPoint
    local w, h = (size.X.Scale * width + size.X.Offset) * factor, (size.Y.Scale * height + size.Y.Offset) * factor
    local x = (viewport.X - width * factor) / 2 + (p.X.Scale * width + p.X.Offset) * factor - anchor.X * w
    local y = (viewport.Y - height * factor) / 2 + (p.Y.Scale * height + p.Y.Offset) * factor - anchor.Y * h
    assert(x >= -0.01 and y >= -0.01 and x+w <= viewport.X+0.01 and y+h <= viewport.Y+0.01, object.Name..' clips phone viewport')
    if object.ClassName == 'TextButton' then assert(w >= 44 and h >= 44, object.Name..' needs a 44px touch target') end
    for _, r in ipairs(rects) do
     assert(x+w <= r.x+0.01 or r.x+r.w <= x+0.01 or y+h <= r.y+0.01 or r.y+r.h <= y+0.01,
      object.Name..' overlaps '..r.name..' at '..viewport.X..'x'..viewport.Y)
    end
    table.insert(rects, {name=object.Name,x=x,y=y,w=w,h=h})
    print(string.format('HUDRECT|%d|%d|%s|%.6f|%.6f|%.6f|%.6f',viewport.X,viewport.Y,object.Name,x,y,w,h))
   end
  end
 end
end
print('Phone HUD checks passed: 844x390 and 390x844 chrome, quest, captain, feed, crew/menu states and 44px targets.')
print('Control checks passed: round skill icons, phone arc/44px targets, jump clearance, cooldown/recovery, menu, keyboard, panels and staged/desktop restoration.')
`;
const directory = join(root, 'out', 'control-check');
mkdirSync(directory, { recursive: true });
const script = join(directory, 'check.luau');
writeFileSync(script, harness);
const result = spawnSync('luau', [script], { encoding: 'utf8', cwd: root });
const rects = [];
for (const line of (result.stdout ?? '').split('\n')) {
  if (line.startsWith('HUDRECT|')) {
    const [, width, height, name, x, y, w, h] = line.split('|');
    rects.push({ width: +width, height: +height, name, x: +x, y: +y, w: +w, h: +h });
  } else if (!process.argv.includes('--json-rects') && line) process.stdout.write(line + '\n');
}
if (process.argv.includes('--json-rects') && result.status === 0) process.stdout.write(JSON.stringify(rects));
process.stderr.write(result.stderr ?? '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
