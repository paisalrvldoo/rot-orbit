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
print("Collection checks passed: unique variants, independent tabs, one-time rewards, preview/load guards, cap, save isolation.")
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
