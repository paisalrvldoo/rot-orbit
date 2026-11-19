// Run actual damage/reward functions with deterministic server stubs.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const moduleBody = (path, marker) => {
  const source = readFileSync(path, 'utf8');
  return `(function()\n${source.slice(source.indexOf(marker))}\nend)()`;
};
const harness = `
local Color3 = { fromRGB = function(...) return {...} end }
local Vector3 = { new = function(...) return {...} end }
local workspace = { GetServerTimeNow = function() return 100 end }
local Config = ${moduleBody('src/shared/Config.luau', 'local Config =')}
local GremlinRaid = ${moduleBody('src/server/GremlinRaid.luau', 'local GremlinRaid =')}
local player, other, preview, loading = {}, {}, {}, {}
local profiles = { [player] = { Cash = 0 }, [other] = { Cash = Config.MaxCash - 1 },
    [preview] = { Cash = 0, Demo = true }, [loading] = { Cash = 0 } }
local players = { [player] = {}, [other] = {}, [preview] = {}, [loading] = { Loading = true } }
local notices, sends, stunned, recovered = 0, 0, 0, 0
local raid = setmetatable({ Gremlins = {}, Wave = 1, WaveCount = 2, Defeated = 0, Active = true,
    Bases = { Players = players }, Economy = { Profiles = profiles,
      Network = { Notice = { FireClient = function() notices += 1 end } },
      Send = function() sends += 1 end },
    Stun = function() stunned += 1 end,
    Remove = function(self, enemy, recover) self.Gremlins[enemy.Model] = nil; if recover then recovered += 1 end end
}, GremlinRaid)
local function enemy(hp, boss)
    local e = { Model = {}, Health = hp, MaxHealth = hp, Boss = boss, Wave = 1 }
    raid.Gremlins[e.Model] = e
    return e
end
raid.HealthView = function(_, e) assert(e.Health >= 0 and e.Health <= e.MaxHealth) end
local first, boss = enemy(4), enemy(6, true)
assert(not raid:Damage(first, player, 2) and first.Health == 2 and stunned == 1)
assert(raid:Damage(first, player, 2) and profiles[player].Cash == Config.Gremlin.KillReward)
assert(not raid:Damage(first, player, 999) and raid.Defeated == 1, 'dead target must not repay')
assert(raid:Damage(boss, player, 99) and not raid.Active)
assert(profiles[player].Cash == Config.Gremlin.KillReward + Config.Gremlin.BossReward + Config.Gremlin.DefendReward)
assert(players[player].RaidsDefended == 1 and players[other].RaidsDefended == 1)
assert(profiles[other].Cash == Config.MaxCash, 'defence payout must respect cash cap')
assert(profiles[preview].Cash == 0 and profiles[loading].Cash == 0, 'no preview/loading payouts')
local paid = profiles[player].Cash
raid:Finish()
assert(profiles[player].Cash == paid and players[player].RaidsDefended == 1, 'delayed finish must not double reward')
raid.Active, raid.Defeated = true, 1
raid:Finish()
assert(profiles[player].Cash == paid, 'escaped wave cannot earn defended reward')
assert(recovered == 2 and sends == 2)
local skillState = { Bay = {}, SkillReadyAt = {} }
local skillProfile = { Rebirths = 0, Upgrades = {} }
local avatar = { FindFirstChild = function() return { Position = {} } end }
local user = { Character = avatar }
local uses = 0
local skills = setmetatable({ Bases = { Players = { [user] = skillState }, Near = function() return true end },
    Economy = { Profiles = { [user] = skillProfile }, Network = { Notice = { FireClient = function() end } },
        Send = function() uses += 1 end }, Gremlins = {}, Pulse = function() end }, GremlinRaid)
skills:Skill(user, 'Unknown')
skills:Skill(user, {})
skills:Skill(user, 'Slam')
assert(uses == 0 and not skillState.SkillReadyAt.Slam, 'locked/malformed skills must be denied')
skillProfile.Upgrades.CarrySpeed = 1
skills:Skill(user, 'Slam')
assert(uses == 1 and skillState.SkillReadyAt.Slam == 112, 'upgrade must unlock server-owned cooldown')
skills:Skill(user, 'Slam')
assert(uses == 1, 'spam must not bypass cooldown')
skillState.SkillReadyAt.Slam = 0
skillState.Closing = true
skills:Skill(user, 'Slam')
assert(uses == 1, 'departing profiles must not activate skills')
skillState.Closing, skillProfile.Demo = false, true
skills:Skill(user, 'Slam')
assert(uses == 1, 'capture staging must not invoke live skills')
assert(Config.Skills.Unlocked('Bubble', { Rebirths = 2 }))
assert(not Config.Skills.Unlocked('Bubble', { Rebirths = 1 }))
assert(Config.Skills.Unlocked('Dash', {}))
local CrewService = ${moduleBody('src/server/CrewService.luau', 'local CrewService =')}
local one, two, rival, far = {}, {}, {}, {}
local crewPlayers = { [one] = { CrewId = 1 }, [two] = { CrewId = 1 }, [rival] = { CrewId = 2 }, [far] = { CrewId = 1 } }
local crewProfiles = { [one] = { Cash = 0 }, [two] = { Cash = 0 }, [rival] = { Cash = 0 }, [far] = { Cash = 0 } }
local crews = setmetatable({ Bases = { Players = crewPlayers, Near = function(_, p) return p ~= far end },
    Economy = { Profiles = crewProfiles, Network = { Notice = { FireClient = function() end } }, Send = function() end },
    Crews = { { Id = 1, Score = 0, Raids = 0, Bosses = 0 }, { Id = 2, Score = 0, Raids = 0, Bosses = 0 } },
    Raids = { Active = false } }, CrewService)
assert(crews:Same(one, two) and not crews:Same(one, rival) and not crews:Same(one, nil))
crews:OnDefeat(one, { Boss = true, Position = {} })
assert(crews.Crews[1].Bosses == 1 and crews.Crews[1].Score == Config.Crews.BossScore)
assert(crewProfiles[two].Cash == Config.Crews.BossAssist and crewProfiles[far].Cash == 0 and crewProfiles[rival].Cash == 0)
crews:Defended({ one, two, rival })
assert(crews.Crews[1].Raids == 1 and crews.Crews[2].Raids == 1, 'crew defence counts once per crew, not per member')
crews:Join(one, {})
crews:Join(one, 1.5)
crews:Join(one, 999)
crewPlayers[one].Carry = {}
crews:Join(one, 2)
assert(crewPlayers[one].CrewId == 1, 'cannot transfer crew while carrying')
crewPlayers[one].Carry = nil
crews.Raids.Active = true
crews:Join(one, 2)
assert(crewPlayers[one].CrewId == 1, 'cannot hop crews during a raid')
print('Crew checks passed: friendly protection, nearby assist payout, outsider exclusion, once-per-crew raid score and membership guards.')
print('Skill checks passed: invalid names, unlocks, upgrade/rebirth paths, cooldown spam and departure/preview guards.')
print('Combat checks passed: damage, stun, death once, boss reward, cargo recovery, wave reward once, cash cap and profile guards.')
`;
mkdirSync('out/combat-check', { recursive: true });
writeFileSync('out/combat-check/check.luau', harness);
const result = spawnSync('luau', ['out/combat-check/check.luau'], { encoding: 'utf8' });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
