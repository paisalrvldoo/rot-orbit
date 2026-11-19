# ROT ORBIT build notes

## Resume here

Started 19 November 2026, 18:18 WIB, from starter commit `4e93d12` on `main`.
Read `git log`, `git status`, and this file before continuing. Extend the existing
files in small patches; do not restart the game. All game code is authored in
the recorded session, with no downloaded packages or uploaded assets.

## First pass

1. Keep the starter publishable and document the build/check workflow.
2. Map shared modules; enable avatars; build a sunny station, orange planet,
   cargo ring, player/NPC bays, eight pedestals per bay, and shield domes at runtime.
3. Add a catalog of 30 original brainrots, seven rarities, five mutations, and
   primitive character models with readable billboards and idle animation.
4. Finish a playable purchase -> carry -> place -> passive income loop with a
   top-centre cash HUD and a carrying strip. Verify and commit each feature.
5. Stop at a clean, committed milestone, with the next features recorded here.

## Verification before every commit

`node tools/verify.mjs` rebuilds `game.rbxl` using the required Rojo command,
compiles every `.luau` file, and runs `main.ts` into a fresh gitignored scratch
directory under `out/`. It checks that the dossier and copied artifacts exist.
The kit check is `node cli/makefun.mjs check --kit . --repo
/workspace/rbx/rot-orbit`, run from `/workspace/rbx/kit`; it reads a commit.

Roblox Studio is on the owner's Windows laptop. Compilation and source/place
verification here do not replace a Studio playtest. Studio output reports take
priority over new features.

## Publishing and pictures

The owner publishes the starter as a new Public experience with the make.fun
play code in its description. Real place/universe IDs have not arrived.
Keep the starter's zero-valued `PLAY.json` until they do, then write the exact
rules shape with numeric IDs, commit, and rerun the kit check until `play_link`
passes. Never invent IDs or publish to an unrelated experience.

The starter PNGs remain until genuine Studio captures replace them. They are
placeholders and cannot represent the finished ROT ORBIT entry. Final captures:
`01-cover.jpg`, `02-index.jpg`, `03-raid.jpg`, `04-upgrades.jpg`; 1280x720, JPEG,
each <= 256 KiB. Cover is also the first approved Roblox thumbnail. Add
ScreenshotMode and an exact rules-format TOUR only when those features exist.

## Subsequent passes

NPC stealing; meteor warnings/impacts and safe domes; solar flare; green gremlin
raids with lock/zap; upgrades; rebirth; index; contracts; pcall-safe saving; final
HUD/effects; ScreenshotMode/TOUR; genuine captures and approved icon/thumbnail.
All tunable game numbers belong in Config; catalog data stays in one module.

## Decisions and open issues

- Station milestone: avatars enabled; all scenery is built by WorldBuilder;
  six player docks, three rival crew docks, 72 initial pedestals, four safe domes,
  a two-rail cargo orbit, an orange striped planet, and a seeded starfield.
- Local kit check on the starter: license, entrypoint, snapshot and opening
  checks pass; only `play_link` fails for the expected zero IDs. Description
  code 0 is `makefun-puddle-flask-sparrow`.

- Use anchored primitive geometry and client-side visual animation to keep the
  runtime world simple and the binary place small.
- Purchase/placement/cash decisions are server-authoritative. Clients receive
  snapshots and effects, never choose their own rewards or prices.
- Stop spending on a single problem after 20 minutes; record a simpler choice
  here and continue.
