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
local bay = { Frame = { Position = {} } }
local players = { [player] = { Bay = bay }, [other] = { Bay = bay }, [preview] = { Bay = bay }, [loading] = { Bay = bay, Loading = true } }
local notices, sends, stunned, recovered = 0, 0, 0, 0
local raid = setmetatable({ Gremlins = {}, Wave = 1, WaveCount = 2, Defeated = 0, Active = true,
    Bases = { Players = players, Near = function() return true end }, Economy = { Profiles = profiles,
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
skills.Sprint = function() end
for _, name in ipairs({ 'Unknown', 'Slam', 'Dash', 'Bubble', 'Bomb' }) do skills:Skill(user, name) end
skills:Skill(user, {})
assert(uses == 0 and next(skillState.SkillReadyAt) == nil, 'removed/malformed skills must be denied')
skills:Skill(user, 'Sprint')
assert(uses == 1 and skillState.SkillReadyAt.Sprint == 111, 'run must start a server-owned cooldown')
skills:Skill(user, 'Sprint')
assert(uses == 1, 'spam must not bypass cooldown')
skillState.SkillReadyAt.Sprint = 0
skillState.Closing = true
skills:Skill(user, 'Sprint')
assert(uses == 1, 'departing profiles must not activate skills')
skillState.Closing, skillProfile.Demo = false, true
skills:Skill(user, 'Sprint')
assert(uses == 1, 'capture staging must not invoke live skills')
do
    local friendly = {}
    skills.Crews = { Same = function(_, _, other) return other == friendly end }
    assert(not skills:TargetableThief(user, user, { Carry = { Stolen = true } }))
    assert(not skills:TargetableThief(user, friendly, { Carry = { Stolen = true } }))
    assert(not skills:TargetableThief(user, {}, { Carry = { Stolen = false } }))
    assert(not skills:TargetableThief(user, {}, { Closing = true, Carry = { Stolen = true } }))
    assert(skills:TargetableThief(user, {}, { Carry = { Stolen = true } }))
end
local Format = ${moduleBody('src/shared/BrainrotTraits.luau', 'local Rarity =')}.Format
local shineCount = 0
local TweenInfo = { new = function() return {} end }
local TweenService = { Create = function() return { Play = function() shineCount += 1 end } end }
local CrewService = ${moduleBody('src/server/CrewService.luau', 'local CrewService =')}
do
    local rows, display = {}, {}
    for rank, name in ipairs({ 'Solar', 'Lunar', 'Comet' }) do
        rows[rank] = { Name = name, Id = rank, Score = 0, Raids = 0, Bosses = 0 }
        display[rank] = { Rank = {}, Name = {}, Score = {}, Stats = {}, Strip = {} }
    end
    local board = setmetatable({ Board = {}, BoardRows = display, BoardShine = {}, Banners = {},
        View = function() return { Rows = rows } end }, CrewService)
    board:Refresh()
    assert(string.find(board.Board.Text, 'No raids yet') and not display[1].Rank.Visible and shineCount == 0)
    rows[1].Score, rows[1].Raids, rows[2].Score = 1000, 5, 500
    board:Refresh()
    assert(board.Board.Text == '' and display[1].Name.Text == 'Solar' and display[2].Rank.Visible)
    assert(display[1].Score.Text == '1K PTS' and display[1].Stats.Text:find('5 RAIDS'))
    assert(not display[3].Rank.Visible and not display[3].Score.Visible)
    board:Refresh()
    assert(shineCount == 1, 'periodic refresh should shine once per standings change')
end
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
local ledgerDocument, orderedScore
local failLedger, failOrdered = false, false
local persistent = setmetatable({ Crews = { { Score = 100 } }, Token = 'server-a', Saved = {}, Unpublished = {},
    Ledger = { UpdateAsync = function(_, key, callback)
        ledgerDocument = callback(ledgerDocument)
        if failLedger then error('timeout after committed ledger write') end
        return ledgerDocument
    end },
    Ordered = { UpdateAsync = function(_, key, callback)
        orderedScore = callback(orderedScore)
        if failOrdered then error('timeout after ordered publish') end
    end } }, CrewService)
failLedger = true
assert(not persistent:WriteCrew(1) and ledgerDocument.Total == 100)
failLedger = false
assert(persistent:WriteCrew(1) and ledgerDocument.Total == 100 and orderedScore == 100,
    'retry after ambiguous ledger response must not double-add')
persistent.Crews[1].Score = 160
failOrdered = true
assert(not persistent:WriteCrew(1) and orderedScore == 160)
failOrdered = false
assert(persistent:WriteCrew(1) and orderedScore == 160 and ledgerDocument.Total == 160,
    'ordered publication retry must keep the same cumulative score')
persistent.Token, persistent.Saved, persistent.Crews[1].Score = 'server-b', {}, 50
assert(persistent:WriteCrew(1) and ledgerDocument.Total == 210 and orderedScore == 210,
    'independent server contributions must combine')
orderedScore = 500
persistent.Crews[1].Score = 60
assert(persistent:WriteCrew(1) and orderedScore == 500, 'a stale publisher cannot lower another server score')
local captainView = setmetatable({ Wave = 3, Gremlins = { { Boss = true, Health = 12, MaxHealth = 32 } } }, GremlinRaid)
assert(captainView:BossView().Health == 12 and captainView:BossView().Wave == 3)
captainView.Gremlins[1].Health = 0
assert(captainView:BossView() == nil, 'defeated captain must leave the shared health bar')
raid.Active, raid.Defeated, raid.Participants = true, raid.WaveCount, { [player] = true }
raid:Finish()
assert(players[player].RaidsDefended == 2 and players[other].RaidsDefended == 1,
    'joining after the wave starts must not grant an unearned defence bonus')
raid.Active, raid.Defeated, raid.Participants = true, raid.WaveCount, { [player] = true }
raid.Bases.Near = function() return false end
raid:Finish()
assert(players[player].RaidsDefended == 2, 'absent or dead players must not receive nearby defence rewards')
local priorGlobal = { { Id = 1, Score = 77 } }
local unavailable = setmetatable({ Crews = { {} }, Ledger = {}, Global = priorGlobal,
    Ordered = { GetSortedAsync = function() error('API access unavailable') end },
    WriteCrew = function() return false end }, CrewService)
unavailable:SyncGlobal()
assert(not unavailable.Syncing and unavailable.Global == priorGlobal
    and unavailable.GlobalStatus == 'GLOBAL RETRYING · LOCAL PLAY CONTINUES',
    'API outage must keep local play and the last successful global snapshot')
local replicated
one.SetAttribute = function(_, _, value) replicated = value end
one.CharacterAdded = { Connect = function() return { Disconnect = function() end } end }
crews.Crews[2].Name = 'Lunar Linguini'
crews.Connections, crews.Raids.Active = {}, false
crews.Paint, crews.Refresh = function() end, function() end
crews:Join(one, 2)
assert(crewPlayers[one].CrewId == 2 and replicated == 2 and crewPlayers[one].CrewReadyAt == 115,
    'valid membership must replicate and start the switch cooldown')
crews:Join(one, 1)
assert(crewPlayers[one].CrewId == 2, 'switch cooldown cannot be bypassed')
print('Global crew checks passed: combined servers, ambiguous ledger retry, ordered retry and monotonic publication.')
print('Crew checks passed: friendly protection, nearby assist payout, outsider exclusion, once-per-crew raid score and membership guards.')
print('Skill checks passed: removed and invalid names, Run cooldown, departure and preview guards.')
print('Combat checks passed: damage, stun, death once, boss reward, cargo recovery, wave reward once, cash cap and profile guards.')
`;
mkdirSync('out/combat-check', { recursive: true });
writeFileSync('out/combat-check/check.luau', harness);
const result = spawnSync('luau', ['out/combat-check/check.luau'], { encoding: 'utf8' });
process.stdout.write(result.stdout ?? '');
process.stderr.write(result.stderr ?? '');
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
