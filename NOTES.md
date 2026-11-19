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
3. Add a catalog of 43 original brainrots, seven rarities, six mutations, and
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

The owner published ROT ORBIT as Public: place `75703852342218`, universe
`10777849208`. PLAY.json now contains these numeric IDs and the real play URL.
The kit check passed `play_link` on 19 November at 21:20 WIB: correct start
place/universe, Public, creator xiaaoxiee, description includes our play code.

The starter PNGs remain until genuine Studio captures replace them. They are
placeholders and cannot represent the finished ROT ORBIT entry. Final captures:
`01-cover.jpg`, `02-index.jpg`, `03-raid.jpg`, `04-upgrades.jpg`; 1280x720, JPEG,
each <= 256 KiB. Cover is also the first approved Roblox thumbnail. Add
ScreenshotMode and an exact rules-format TOUR only when those features exist.

## Subsequent passes

## Progress (19 November continuation)

- [x] Recovered catalog/model/pedestal work; verified and committed `50e5c42`.
- [x] Sunny runtime world, 30 original brainrots, seven rarities, five mutations.
- [x] Player bay assignment, server-owned carry/drop/dock logic and passive economy.
- [x] Moving cargo and buy prompts; money HUD, carrying strip and income pops.
  Minimum loop is implemented; Studio playtest still required. Follow the mint
  YOUR BAY beacon; buy Common cargo on the ring, then E at a free home pedestal.
  Source review corrected capsule pivot orientation and moved responsive HUD
  scaling onto a fixed-size GuiObject canvas.
- [x] Rival stealing and restocking; player theft checks bay shield state.
- [x] Meteor shower every 90s: warning rings, falling impacts, safe dome checks,
  dropped cargo and a full-width countdown banner. Mythic survival activity hook.
- [x] Lock [L] and touch/mouse button: 40s shield, then recharge countdown;
  locks deny theft, remote actions are rate-limited, leaving cleans up shields.
- [x] Green primitive gremlins raid player bays, steal and escape; locks block
  them and ZAP [F] stuns nearby thieves, returning their loot as recoverable drops.
- [x] Solar flare: all dock income doubles for 20s every 150s, with a banner.
- [x] Upgrade [U] panel: walk/carry speed, lock duration, +2 slots up to 16;
  server recomputes costs and enforces upgrade caps.
- [x] Rebirth [R] opens the upgrade panel; a second click confirms resetting
  cash/upgrades/bay for permanent income. Found index entries survive resets.
- [x] Index [B]: all 43 cast entries in a nine-column grid; found count, seven
  rarity counts and coloured found icons / dark undiscovered silhouettes.
- [x] Three simultaneous contracts, rotating through nine missions with cash
  rewards. U/R show contracts beside upgrades/rebirth. All rewards are server-owned.
- [x] Pcall-safe progress saving: cash, rebirths, upgrades, inventory, discoveries,
  contracts; autosave/leave/shutdown, validated loads and renewable server leases.
  API-disabled Studio sessions play without saving; failed loads cannot overwrite
  real saves. Reconnecting docks owned carried cargo into a free home slot.
- [x] HUD edges, event/carry strips, five ordered stateful buttons, income pops,
  rarity/mutation effects and idle bobbing (including cargo); Zero-G carries spin.
  Review fixed bay-slot cleanup between owners, unique restocked cargo IDs and
  releasing a save lease when someone leaves during loading.
- [x] Studio-only ScreenshotMode Cover/Index/Raid/Upgrades and corresponding
  TOUR presets: high-rarity bay, Diamond carry, exactly 23/30 found, staged raid
  and paired progression panels. Preview changes never overwrite real progress.
- [x] README describes the implemented game, controls, verification and Studio presets.
- [x] Published IDs committed; Public play link passes the kit check.
- [ ] Genuine Studio pictures (owner laptop; no Studio here).

NPC stealing; meteor warnings/impacts and safe domes; solar flare; green gremlin
raids with lock/zap; upgrades; rebirth; index; contracts; pcall-safe saving; final
HUD/effects; ScreenshotMode/TOUR; genuine captures and approved icon/thumbnail.
All tunable game numbers belong in Config; catalog data stays in one module.

## Top-10 polish plan (owner research read 19 November, 19:43 WIB)

Core systems above are implemented; finish this checklist in small verified commits.
The research is prose guidance, not source or reusable names. Rank is not guaranteed.

1. [x] Staged Cover at $867.5M, rebirth 3, 18s meteor, a Diamond carry and five
   lined-up heroes around the Supernova SECRET. Title, planet and meteor streaks
   frame the shot. Studio framing and readability checks remain.
2. [x] Grow to 43 originals: 8 Common, 8 Rare, 7 Epic, 7 Legendary, 6 Mythic,
   5 Cosmic, 2 SECRET; distinct primitive silhouettes; update all count strings.
3. Four genuine Studio shots. The cover and 32/43 discovery grid are staged.
   Raid shows one thief escaping with cargo and another zapped with recoverable
   loot. The progression preset opens upgrades, rebirth and contracts together.
   The owner captures all four in Studio.
4. [x] 24 scripts. BrainrotTraits groups rarity, mutation and number formatting.
   The client groups HUD/banner, progression panels and input/bootstrap. Server
   progression and orbital events are grouped by purpose. The disabled starter
   screen is gone.
5. [x] Built a two-sided 40-stud lit station title and player dock signs with live
   OPEN/LOCKED badges beside the owner's name.
6. [x] Meteor streaks, red warnings, warmer sky, pulsing domes, a cargo drop
   marker and the between-event countdown are implemented.
7. [x] Sixth mutation Aurora at x7, with three coloured orbit ribbons.
   [x] Aurora Surge guarantees mutations for newly spawned cargo for 20 seconds
   every 270 seconds, including an affordable Gold capsule in the rotation.
8. [x] Edge HUD has live upgrade/found/cost/cooldown buttons, a three-action feed,
   larger money and event text, a right quest card with saved completion and
   separate income pops above occupied pedestals.
9. [x] Large income and rarity cards, BUY prices on cargo, Cosmic beams and
   SECRET crowns/light pillars. Cover cards sit beneath the hero models.
10. [x] Progression has 15 rotating contracts, saved first completions, 25 upgrade
    levels, a visible rebirth multiplier step and saved cash rewards every ten discoveries.

This continuation is capped at ~25 minutes, starting near 19:50 WIB. The owner
research was reread at the start. Verify and commit each working piece, at most
10 minutes between commits. Next: stage the cover, fix the 43-entry index layout,
then fill out the HUD, hazard feedback, and script outline.

## Decisions and open issues

## Visual continuation (19 November, 20:30 WIB; 25-minute cap)

Initial verification passed with a clean tree at `42a8eeb`; no recovered edits
needed committing. Read the full owner research and the added visual guidance.
The ten top-10 priorities above remain the plan: core systems precede polish;
43 originals, six mutations, title, 24 scripts, staged cover, live HUD, quests
and feed are implemented in source. Genuine captures and IDs remain pending.

Visual order for this pass (compile/source checks here; Studio review pending):
- [x] Save a three-quarter cover camera and restrained fill/rim lamps; freeze
  client idle poses in screenshot mode for repeatable captures.
- [x] Add light atmospheric depth and lower fill relative to the warm sunlight;
  source-reviewed only, owner must confirm brightness in Studio.
- [x] Fix detached boot/antenna/cap joins, add satellite struts and a sceptre
  grip, bring capes onto the bodies. Clay/second-angle Studio review is pending.
- [x] Bottom controls share mouse/touch/gamepad hover, gold focus/selected border,
  press scale, short pending guard and real lock/zap cooldown disabling; keys use
  the same guarded activation. Upgrade/rebirth/close controls share this feedback;
  unavailable purchases say NEED or MAXED and cannot submit. Rebirth confirmation
  has a gold selected border. Server notices remain the success/error feedback.
- [x] Income pops spring in, drift upward and fade after a readable hold; action
  rows enter with a tight stagger, panels slide in with Quad Out. Repeated
  entrances cancel the prior tween. Screenshot feeds appear without animation.
- [x] Review cover/title bounds in source: the three-quarter camera targets the
  lit title sign, orange planet and five-hero showcase; the preset now stages a
  truthful 32/43 index. README documents the Studio framing checks (1280x720,
  title and planet in frame, readable cards, clear top-left menu area).
- [ ] Capture genuine Studio pictures and verify the title, silhouettes and HUD
  at the owner's 1280x720 viewport. No generated image can replace that check.

## Decisions and open issues (continued)

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

## Continuation checkpoint (19 November, 25-minute cap)

Started from clean `0c2a7e1`. Initial verification passed for all 24 scripts.
Reviewed both owner research files. Keep the first ten priorities above as the
submission checklist, with genuine 16:9 captures and the published play link
still open. Finish gameplay gaps before adding polish. Keep the existing 43
originals, six mutations, station title, 24 scripts, dense HUD and staged cover.

- [x] Owners can hold G near docked cargo to retire it and free a pedestal.
  Retirement leaves index discoveries intact and awards no cash. Studio
  multiplayer prompt visibility still needs a playtest.
- [x] Docks and the index use the billboard rarity palette. Socket colors
  reset on theft, retirement and rebirth and are restored with saved cargo.
- [x] SECRET arrivals get a named announcement, yielding to safety banners.
  Moving sleds use the same rarity rim color as the docks.
- [x] Rebirth shows its income step, permanent shield time and bonus slot.
  Cash and docked rarity requirements match client and server. Existing
  rebirth levels receive the perks on load without moving saved cargo.
- [x] Mutation index tabs record distinct docked variants, keep discoveries on
  rebirth, and auto-pay one-time milestones at 10/22/33/43 per mutation. New
  fields are optional in old saves; owned variants are recovered from inventory.
  Cash rewards scale with the mutation multiplier. Studio UI/save test pending.
- [x] Offline haul pays 25% of the saved dock rate for up to two hours and
  appears in the HUD feed on return. The lease acquisition credits each
  departure once. Previous saves earn offline cash after their next save.
  Needs a Studio DataStore playtest.
- [x] Source-reviewed the four presets; CAPTURE.md has the capture/publish handoff.

## Public-link continuation (19 November, 21:20 WIB; 25-minute cap)

Initial status/diff were clean at c0ba8a8; verify passed all 24 scripts, so no
uncommitted WIP needed recovery. PLAY.json committed as 8941507; the requested
kit check passed (5 passed, 0 failed). Kit reports level 26 versus site level 27;
refresh the kit before final submission. The check does not validate pictures.

Read owner refs.md and visual guidance. Retain the ten priorities above: 43
originals, six mutations, 24 meaningful scripts, large title, late-game cover,
four distinct shots, visible hazards, live HUD, quests/feed and earned progression.
Core systems precede more spectacle. This pass's remaining order:
- [x] Persist mutation discoveries and make the index tabs reward real collecting.
  `node tools/check-collections.mjs` exercises the actual server functions:
  duplicate docking, independent mutations, repeat/catch-up claims, preview/load
  guards, cash cap and immutable queued save snapshots all pass.
- [x] Correct/review deterministic staging, then document the four-shot handoff.
  Fixed 36 actual discoveries behind the advertised 32/43: every owned hero
  stays found, now with exactly 32 originals and 10 Gold. Regression checks run
  the actual staging function twice. Each preset resets the index to ALL;
  prompts are hidden and staged raid drops no longer expire during framing.
  Cover projection at 1280x720 showed carry/SECRET overlap; moved the avatar
  left and tightened the lineup/widened FOV to leave the right quest card clear.
  Source projection is not a render approval. All four real captures remain
  pending Studio, as do approved icon/thumbnail and publishing the latest place.
- [ ] Reverify, retry the Public link check, and leave a clean committed tree.
