# ROT ORBIT

An original space-station entry for make.fun's roblox-brainrot-01 bounty, built
Rojo-first from Luau and primitive geometry. Buy food astronauts from the neon
cargo orbit, carry them to your docking bay, and earn passive income. Steal from
rival crews, shelter from meteors, lock out gremlins, and zap thieves to recover cargo.
Solar flares double income; upgrades, rebirths, a discovery index, three rotating
contracts and protected DataStore saving provide progression.
Collect 43 original brainrots across seven rarities and six mutations, including
the x7 Aurora and x10 Supernova variants.

WASD moves; E buys, steals, recovers and docks; L locks; F zaps; U opens upgrades
and contracts; R opens rebirth (click again to confirm); B opens the index.

- `main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`, `screenshots/` and
  `PLAY.json` to `/output`, leaving out every name that starts with a dot (such as `.gitkeep` or `.DS_Store`, which
  fail an entry), and writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy, unchanged.
- `game.rbxl` is rebuilt from `src/` and `default.project.json` after every source
  change. `WorldBuilder` creates the sunny station, orange planet, bays and domes at runtime.
- `screenshots/` still contains starter placeholders. Genuine Studio captures and
  positive place/universe IDs in `PLAY.json` are required before submission.
- One of your screenshots must also be your game's first thumbnail on Roblox: the same picture, uploaded on the
  Creator Dashboard with your game's icon.
- `TOUR.json` names four Studio screenshot presets: Cover, Index, Raid and Upgrades.
  During a Studio playtest, switch Command Bar to Server and run
  `require(game.ReplicatedStorage.ScreenshotMode).Cover(0)` (replace Cover with
  another preset name). These previews disable saving of staged progress. Stop
  and restart the playtest to return to normal play. Capture the client viewport
  at 1280x720; save each JPEG under 256 KiB with the filename in the tour.

`node tools/verify.mjs` rebuilds the place, compiles every Luau script and checks
the exported dossier. Roblox Studio playtesting remains necessary: this machine
has no Studio. See NOTES.md for current progress and the next polish priorities.

Run it as the grader does, writing `out/` in place of `/output`:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the kit's RULES.txt,
which gives every command in order (Before you submit, then Enter).
