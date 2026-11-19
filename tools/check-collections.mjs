// Exercise real collection/reward/serialization functions without Roblox Studio.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = path => readFileSync(join(root, path), 'utf8');
const moduleBody = (path, marker) => `(function()\n${source(path).slice(source(path).indexOf(marker))}\nend)()`;
const harness = `
local Color3 = { fromRGB = function(...) return {...} end }
local Vector3 = { new = function(...) return {...} end }
local Config = ${moduleBody('src/shared/Config.luau', 'local Config =')}
local Traits = ${moduleBody('src/shared/BrainrotTraits.luau', 'local Rarity =')}
local Format = Traits.Format
local Mutation = Traits.Mutation
local Rarity = Traits.Rarity
local Catalog = ${moduleBody('src/server/BrainrotCatalog.luau', 'local Catalog =')}
local guid = 0
local HttpService = { GenerateGUID = function() guid += 1; return tostring(guid) end }
local BaseService = ${moduleBody('src/server/BaseService.luau', 'local BaseService =')}
local EconomyService = ${moduleBody('src/server/EconomyService.luau', 'local EconomyService =')}
local UpgradeRebirthService = ${moduleBody('src/server/UpgradeRebirthService.luau', 'local UpgradeRebirthService =')}
local ConveyorService = ${moduleBody('src/server/ConveyorService.luau', 'local ConveyorService =')}
local DataService = ${moduleBody('src/server/DataService.luau', 'local DataService =')}
local ScreenshotService = ${moduleBody('src/server/ScreenshotService.luau', 'local ScreenshotService =')}
local MeteorSolarEvents = ${moduleBody('src/server/MeteorSolarEvents.luau', 'local MeteorSolarEvents =')}
local events = setmetatable({}, MeteorSolarEvents)
assert(events:EventLook() == Config.EventLooks.Calm)
events.SolarActive = true
assert(events:EventLook() == Config.EventLooks.Solar)
events.AuroraActive = true
assert(events:EventLook() == Config.EventLooks.Aurora)
events.ShowerLook = true
assert(events:EventLook() == Config.EventLooks.Meteor)
events.ShowerLook = false
assert(events:EventLook() == Config.EventLooks.Aurora, "meteor end must restore ongoing Aurora")
events.AuroraActive = false
assert(events:EventLook() == Config.EventLooks.Solar, "Aurora end must restore ongoing solar flare")
events.SolarActive = false
assert(events:EventLook() == Config.EventLooks.Calm)
local player, notices = {}, {}
local state = { Found = {}, Variants = {}, Bay = { Slots = {} } }
local profile = { Cash = 0, IndexMilestone = 0, MutationMilestones = {}, Upgrades = {},
    Rebirths = 0, Contracts = { {}, {}, {} } }
local bases = setmetatable({ Players = { [player] = state } }, BaseService)
local economy = setmetatable({ Profiles = { [player] = profile }, Bases = bases,
    Network = { Notice = { FireClient = function(_, _, message) table.insert(notices, message) end } } }, EconomyService)
-- Use actual selection, reset orchestration and income functions: a mutation can
-- make a lower-rarity cargo worth keeping over the higher-rarity gate unit.
do
    local user = {}
    local kept = { Id = 11, Mutation = 'Supernova', Guid = 'keep-this-one' }
    local function occupied(record) return { Occupant = { Record = record } } end
    local s = { Found = { ['11'] = true, ['13'] = true }, Bay = { Slots = {
        occupied({ Id = 13, Guid = 'qualifies' }), occupied(kept) } } }
    local p = { Cash = Config.Rebirth.Cost(0), Rebirths = 0, Multiplier = 1, Upgrades = {} }
    local b = setmetatable({ Players = { [user] = s } }, BaseService)
    local e = setmetatable({ Bases = b, Profiles = { [user] = p }, IncomeMultiplier = 1,
        Network = { Notice = { FireClient = function() end } }, Activity = function() end,
        Send = function() end }, EconomyService)
    b.Reset = function() s.Bay.Slots = {} end
    b.AddSlot = function() table.insert(s.Bay.Slots, {}) end
    b.Restore = function(_, _, record, slot)
        assert(slot == 1 and record ~= kept and record.Guid == kept.Guid and record.Mutation == 'Supernova')
        s.Bay.Slots[slot] = occupied(record)
    end
    b.ApplyRebirthLook = function() end
    local rebirth = UpgradeRebirthService.new(b, e)
    rebirth.Celebrate = function() end
    p.Cash = 0; rebirth:Perform(user)
    assert(p.Rebirths == 0 and #s.Bay.Slots == 2, 'unaffordable rebirth must not clear cargo')
    p.Cash = Config.Rebirth.Cost(0)
    for _, flag in ipairs({ 'Loading', 'Closing' }) do
        s[flag] = true; rebirth:Perform(user); s[flag] = nil
        assert(p.Rebirths == 0, 'inactive profiles must not rebirth')
    end
    p.Demo = true; rebirth:Perform(user); p.Demo = nil
    assert(p.Rebirths == 0, 'preview must not reset real inventory')
    rebirth:Perform(user)
    assert(p.Rebirths == 1 and p.Cash == Config.StartingCash and s.Found['13'])
    assert(e:Income(user) == Catalog.Income(kept) * Config.Rebirth.Multiplier(1),
        'kept cargo must earn immediately after rebirth with mutation and new multiplier')
    rebirth:Perform(user)
    assert(p.Rebirths == 1, 'repeated confirm cannot rebirth twice without the next cash gate')
    assert(Config.Rebirth.BonusSlots(0) == 0 and Config.Rebirth.BonusSlots(1) == 2)
    assert(Config.Rebirth.BonusSlots(15) == Config.Rebirth.BonusSlotCap)
    assert(Config.Rebirth.BlinkDistance(0, false) == Config.Skills.Blink.Distance)
    assert(Config.Rebirth.BlinkDistance(2, true) == Config.Skills.Blink.CarryDistance + Config.Rebirth.CarryBlinkBonus)
    local supply = setmetatable({ Economy = e, Random = {
        NextInteger = function(_, minimum) return minimum end, NextNumber = function() return 99 end } }, ConveyorService)
    assert(supply:RebirthSupply() == nil, 'early orbit must keep its normal cargo odds')
    p.Rebirths = 3
    assert(Catalog.Get(supply:RebirthSupply().Id).Rarity == 'Mythic')
    p.Demo = true
    assert(supply:RebirthSupply() == nil, 'preview must not unlock live rare supply')
    p.Demo = nil; s.Closing = true
    assert(supply:RebirthSupply() == nil, 'departing players cannot keep rare supply active')
end
for id = 1, 10 do
    local fresh, variant = bases:Discover(state, { Id = id, Mutation = "Gold" })
    assert(fresh and variant, "first docking should discover both forms")
end
local fresh, variant = bases:Discover(state, { Id = 1, Mutation = "Gold" })
assert(not fresh and not variant, "duplicate cargo must not add discoveries")
economy:ClaimIndexMilestones(player)
assert(profile.Cash == 105000, "10 originals plus 10 Gold should pay both rewards")
assert(#notices == 2 and profile.MutationMilestones.Gold == 1)
economy:ClaimIndexMilestones(player)
assert(profile.Cash == 105000 and #notices == 2, "repeat claim must not pay twice")
fresh, variant = bases:Discover(state, { Id = 1, Mutation = "Diamond" })
assert(not fresh and variant, "different mutation should count independently")
for id = 11, 43 do bases:Discover(state, { Id = id, Mutation = "Gold" }) end
profile.Demo = true
economy:ClaimIndexMilestones(player)
assert(profile.Cash == 105000, "screenshot presets must never earn real rewards")
profile.Demo = false
state.Loading = true
economy:ClaimIndexMilestones(player)
assert(profile.Cash == 105000, "no payout during profile loading")
state.Loading = false
profile.Cash = Config.MaxCash - 1
economy:ClaimIndexMilestones(player)
assert(profile.Cash == Config.MaxCash, "combined milestones must respect cash cap")
assert(profile.IndexMilestone == 4 and profile.MutationMilestones.Gold == 4)
local count = #notices
economy:ClaimIndexMilestones(player)
assert(#notices == count, "catch-up milestones must remain claimed")
local data = setmetatable({ Bases = bases, Economy = economy }, DataService)
economy.Income = function() return 25 end
local saved = data:Serialize(player)
assert(saved.Variants.Gold["43"] and saved.MutationMilestones.Gold == 4)
assert(saved.Found["43"] and saved.DockRate == 25)
state.Variants.Gold["43"] = nil
profile.MutationMilestones.Gold = 0
assert(saved.Variants.Gold["43"] and saved.MutationMilestones.Gold == 4,
    "queued save snapshots must not change with live discoveries")
local screenshots = setmetatable({ Bases = bases }, ScreenshotService)
screenshots:StageDiscoveries(state)
local found, gold = 0, 0
for _ in pairs(state.Found) do found += 1 end
for id in pairs(state.Variants.Gold) do
    gold += 1
    assert(state.Found[id], "every staged mutation must have a discovered original")
end
assert(found == 32 and gold == 10, "staged index must truthfully show 32 originals and 10 Gold")
assert(state.Variants.Supernova["30"] and state.Found["30"], "cover SECRET must be discovered")
screenshots:StageDiscoveries(state)
found = 0
for _ in pairs(state.Found) do found += 1 end
assert(found == 32, "switching presets must not accumulate discoveries")
-- Rejoining the same server must create a new lease identity.
local document
local store = { UpdateAsync = function(_, _, callback)
    local updated = callback(document)
    if updated then document = updated end
    return updated
end }
local connections, loadedProfiles = {}, {}
local saveBases = { Players = connections, SetSpeed = function() end, AddSlot = function() end,
    ApplyRebirthLook = function() end }
local saveEconomy = { Profiles = loadedProfiles, Send = function() end, ClaimIndexMilestones = function() end }
local saves = setmetatable({ Bases = saveBases, Economy = saveEconomy, Sessions = {},
    Store = store, Token = "same-server" }, DataService)
local function connection()
    local p = { UserId = 7, Parent = true, Kick = function(self, reason) self.Kicked = reason end }
    connections[p] = { Found = {}, Variants = {} }
    loadedProfiles[p] = { Upgrades = {}, MutationMilestones = {}, Contracts = {} }
    return p
end
local first = connection()
saves:Load(first)
local firstSession = saves.Sessions[first]
assert(firstSession.CanSave and document.Session.Token == firstSession.Token)
local second = connection()
saves:Load(second)
assert(second.Kicked and not saves.Sessions[second].CanSave,
    "same-server rejoin must not take a live departing session lease")
document.Session.ExpiresAt = 0
local third = connection()
saves:Load(third)
local thirdSession = saves.Sessions[third]
assert(thirdSession.CanSave and thirdSession.Token ~= firstSession.Token)
local token = document.Session.Token
saves:Write(firstSession, { Cash = 999 }, true)
assert(not firstSession.CanSave and first.Kicked and document.Session.Token == token,
    "stale writes must neither overwrite nor release the new connection")
saves:Write(thirdSession, { Cash = 42 }, false)
assert(document.Cash == 42 and document.Session.Token == token and thirdSession.Profile.SaveStatus == "SAVED",
    "renewal must preserve the connection lease identity")
saves.Store = { UpdateAsync = function() error("temporary store failure") end }
saves:Write(thirdSession, { Cash = 43 }, false)
assert(thirdSession.CanSave and not third.Kicked and thirdSession.Profile.SaveStatus == "SAVE RETRY",
    "transient write failures must remain retryable")
saves.Store = store
thirdSession.FinalPayload = { Cash = 44 }
saves:Write(thirdSession, { Cash = 43 }, false)
assert(document.Cash == 44 and document.Session == nil and thirdSession.FinalPayload == nil,
    "queued departure must write final state and release its own lease")
local closingState = { Bay = { Owner = first }, Carry = { Record = { Id = 1 } } }
local closingBases = setmetatable({ Players = { [first] = closingState } }, BaseService)
assert(closingBases:IsBayReady(closingState.Bay))
closingState.Loading = true
assert(not closingBases:IsBayReady(closingState.Bay), "loading cargo cannot be raided")
closingState.Loading = false
local captured = false
local closingData = setmetatable({ Bases = closingBases, Sessions = { [first] = {} },
    Save = function(_, who, release)
        assert(who == first and release and closingState.Closing,
            "departure must freeze before the yielding final save")
        assert(not closingBases:IsBayReady(closingState.Bay), "departing cargo cannot be raided")
        assert(not closingBases:Near(first, {}), "departing players cannot trigger cargo prompts")
        closingBases:Drop(first)
        assert(closingState.Carry, "a death or meteor during final save cannot duplicate owned carry as a drop")
        captured = true
    end }, DataService)
closingData:Close(first)
assert(captured and closingData.Sessions[first] == nil)
assert(closingBases:IsBayReady({}), "NPC bays remain raidable")
print("Collection checks passed: unique variants, independent tabs, one-time rewards, preview/load guards, cap, save isolation.")
print("Screenshot discovery checks passed: 32/43, 10 Gold, owned SECRET and repeatable presets.")
print("Save lease checks passed: same-server rejoin, stale write rejection, renewal, transient failure and queued release.")
print("Departure checks passed: freeze before save, block raids/prompts/drops and retain NPC stealing.")
`;
const directory = join(root, 'out', 'collection-check');
mkdirSync(directory, { recursive: true });
const script = join(directory, 'check.luau');
writeFileSync(script, harness);
const result = spawnSync('luau', [script], { encoding: 'utf8', cwd: root });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
