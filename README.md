# ROT ORBIT

An original space-station entry for make.fun's roblox-brainrot-01 bounty, built
Rojo-first from Luau and primitive geometry. Buy food astronauts from the neon
cargo orbit, carry them to your docking bay, and earn passive income. Steal from
rival crews, shelter from meteors, lock out gremlins, and zap thieves to recover cargo.
Gremlins arrive through a bright portal after a six-second warning: first raid
at 75 seconds, then every 135 seconds. ZAP [F] damages and stuns visible enemies,
returns stolen cargo and pays cash on defeat. Every third wave has a crowned
captain with player-scaled health. Clear the wave for a defence bonus.
Solar flares double income; upgrades, rebirths, a discovery index, three rotating
contracts and protected DataStore saving provide progression.
Collect 43 original brainrots across seven rarities and six mutations, including
the x7 Aurora and x10 Supernova variants.
The index tracks each mutation separately and pays automatic cash milestones
for 10, 22, 33 and 43 distinct variants. Discoveries survive rebirths. Saved
docks earn a 25% offline haul for up to two hours away.

WASD moves; E buys, steals, recovers and docks; L locks; F zaps; U opens upgrades
and contracts; R opens rebirth (click again to confirm); B opens the index.
Skills also have touch buttons and server-enforced cooldowns. X Jet Dash is
free; Q Gravity Slam unlocks with Carry Speed 1 or rebirth 1; C Bay Bubble
unlocks with Lock Duration 1 or rebirth 2. Bubble protects your nearby bay for
12 seconds independently of the main lock recharge.
Y opens crews and live server ranks. Join Solar Sporks, Lunar Linguini or Comet
Cannoli from the panel or coloured arrival pads. Crewmates cannot steal each
other's cargo; nearby allies share kill cash. Crew score awards 10 per gremlin,
150 per captain and 100 per defended raid. Gold dock banners mark the leading
crew. Crew membership lasts for the current server session. ALL-TIME ranks
combine these three named crews across servers using a protected score ledger
and OrderedDataStore, refreshing every 60 seconds. If APIs are unavailable,
local crew play and rankings continue.
Hold G beside your docked cargo to retire it and free the slot; discoveries stay.

- `main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`, `screenshots/` and
  `PLAY.json` to `/output`, leaving out every name that starts with a dot (such as `.gitkeep` or `.DS_Store`, which
  fail an entry), and writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy, unchanged.
- `game.rbxl` is rebuilt from `src/` and `default.project.json` after every source
  change. `WorldBuilder` creates the sunny station, orange planet, bays and domes at runtime.
- [Play ROT ORBIT](https://www.roblox.com/games/75703852342218). The kit verified
  the Public start place, universe and description code on 19 November 2026.
- `screenshots/` still contains starter placeholders. Genuine Studio captures
  are required before submission.
- One of your screenshots must also be your game's first thumbnail on Roblox: the same picture, uploaded on the
  Creator Dashboard with your game's icon.
- `TOUR.json` names four Studio screenshot presets: Cover, Index, Raid and Upgrades.
  See [CAPTURE.md](CAPTURE.md) for all four commands, expected frame contents,
  image replacement and publishing steps.
  During a Studio playtest, switch Command Bar to Server and run
  `require(game.ReplicatedStorage.ScreenshotMode).Cover(0)` (replace Cover with
  another preset name). These previews disable saving of staged progress. Stop
  and restart the playtest to return to normal play. Capture the client viewport
  at 1280x720; save each JPEG under 256 KiB with the filename in the tour. Before
  keeping a shot, check that the title sign is inside the frame, the orange planet
  is visible behind the deck, hero billboards are readable, and the top-left Roblox
  menu area stays clear. The Cover preset stages 32/43 found and a Diamond Cosmo
  Cornetto carry; Index should visibly read 32/43 FOUND.

`node tools/verify.mjs` rebuilds the place, compiles every Luau script and checks
the exported dossier. Roblox Studio playtesting remains necessary: this machine
has no Studio. See NOTES.md for current progress and the next polish priorities.
After replacing the starter pictures, run `node tools/verify.mjs --submission`
to also check all four final JPEGs and their TOUR presets.
`node tools/check-collections.mjs` checks one-time collection payouts, save
snapshot isolation and per-connection save leases using the real server
functions in the Luau interpreter.

Run it as the grader does, writing `out/` in place of `/output`:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the kit's RULES.txt,
which gives every command in order (Before you submit, then Enter).
