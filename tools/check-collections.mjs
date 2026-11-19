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
local BaseService = ${moduleBody('src/server/BaseService.luau', 'local BaseService =')}
local EconomyService = ${moduleBody('src/server/EconomyService.luau', 'local EconomyService =')}
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
print("Collection checks passed: unique variants, independent tabs, one-time rewards, preview/load guards, cap, save isolation.")
print("Screenshot discovery checks passed: 32/43, 10 Gold, owned SECRET and repeatable presets.")
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
