# ROT ORBIT Studio handoff

Play link: https://www.roblox.com/games/75703852342218
Place ID: 75703852342218. Universe ID: 10777849208.
Public-link verification passes. The published starter still needs the latest
`game.rbxl` published to this same place; local commits do not update Roblox.

1. Open this repository's latest `game.rbxl` in Studio. Use **Play**, wait for
   your avatar and cash HUD, and set the client viewport to 1280×720, 16:9.
2. Switch the Command Bar to **Server** and run one command from the table.
   A successful preset returns true. If it says not ready, wait for loading and
   retry. Switch back to the client view before capturing.
3. Capture the running client viewport, excluding Studio panels and the Command
   Bar. Keep Studio running when it loses focus. Save each shot as a JPEG at
   1280×720 and at most 256 KiB, using the exact name below.
4. Stop and restart Play after the preview session to test normal gameplay.
   Presets freeze the world/camera, anchor the avatar, hide interaction prompts,
   and disable saving staged progress. They work only in Studio.

| File | Server Command Bar | Visible proof to check |
| --- | --- | --- |
| 01-cover.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Cover(0)` | $867.5M, live income, rebirth 3, 18s meteor banner, Diamond Cosmo Cornetto carry, five heroes with the Supernova SECRET in the middle, station title and orange planet. |
| 02-index.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Index(0)` | Exactly 32/43 FOUND, seven rarity counts, undiscovered silhouettes, six mutation tabs and next cash reward. |
| 03-raid.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Raid(0)` | 27s raid banner, crowned captain escaping with cargo (18/32 HP, wave 3), one zapped gremlin and dropped recoverable cargo, shared captain health bar. |
| 04-upgrades.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Upgrades(0)` | Five upgrade tracks with levels/costs; rebirth x3 → x4.5, +3s shield, next Orbit Ace aura and keep-best text; three contracts with progress/rewards and 4/15 done. |

Check the cover at 768 pixels wide and the three secondary pictures at 253
pixels wide. Keep the title and SECRET face clear of the HUD; confirm names,
rarity cards, income, banner and bottom controls remain readable. The saved
three-quarter camera gives the carry its own space left of the central SECRET.
Camera projection and staging were reviewed in source; actual brightness,
silhouettes, occlusion and text still require this Studio check.

Copy these four real captures into `screenshots/`, then remove its three starter
PNGs in the same change. Keep exactly four images. Verify and commit with
`node tools/verify.mjs`. Do not substitute generated images for Studio shots.
Then run `node tools/verify.mjs --submission`. This also checks exact final
filenames, four matching TOUR steps, JPEG frame dimensions and the 256 KiB cap.
It deliberately fails while the starter placeholders remain. This file check
cannot approve the actual scene, text readability or Roblox moderation.

Publish the latest game to the existing ROT ORBIT place. On Creator Dashboard,
select this experience → Configurations → Places → starred start place. Upload
an icon (512×512 recommended) and **the exact 01-cover.jpg** as the first
Experience Detail Page thumbnail. Wait for both to pass moderation and appear
on the Roblox page. The kit check validates Public/IDs/description; submission
also checks approved icon/thumbnail and screenshot correspondence.

Before final submission, use the current kit and rerun:

    node cli/makefun.mjs check --kit . --repo /workspace/rbx/rot-orbit

Normal-play smoke test on the owner laptop: buy a Common, carry and dock it,
observe income, retire with H, steal from a rival, lock with L, zap with F,
shelter through meteors, purchase an upgrade, rebirth with the confirmation,
inspect mutation tabs, then rejoin to confirm saved discoveries and offline haul.
Use two players to test theft and the owner's retirement prompt visibility.
An empty socket should offer Dock only to its owner while carrying; owned cargo
offers Retire and rival cargo offers Steal. Check that the world sign's lock
countdown agrees with the HUD. With DataStore API access, try a quick rejoin:
a still-held save lease should ask you to rejoin shortly, and an old connection
must not overwrite the new session. A departing player's final save freezes
raids and carried-cargo drops until their bay is released.

Live recovery / combat smoke test (19 November continuation):

- At **1024×460**, confirm the physical CREW RANKS board faces the hub without
  following the camera. Empty scores say No raids yet. The home marker should
  be small, respect world occlusion and hide inside 24 studs of home.
- Phone Menu reveals lock/upgrades/rebirth/index/crew/contracts; closing it
  clears the left side. Blink, Run and Zap sit near the right thumb.
  Confirm taps, cooldowns and the Roblox jump button do not compete.
- Rebirth with several docked cargo, including a valuable mutation. Confirm
  exactly one best-income cargo survives, its original mutation remains, and
  $/s is nonzero immediately. Rejoin to check persistence. R1 has 10 base pods;
  R2 Blink goes farther, R3 periodically adds shared Mythic supply, R4 has a
  title/aura. Check mint/blue/gold/rose bays, announcement and fireworks.

- Republish the rebuilt place first. Confirm **zero server errors**, the sunny
  deck, planet and bays all spawning. FallenPartsDestroyHeight is now authored
  in the place rather than written by a restricted runtime thread.
- Dock a Common. A rival thief can patrol after 30s; first raid is within 75s
  of loading and repeats every 135s. Check the six-second red warning, arrival
  portal, HP bars, F beam, stolen-cargo recovery and kill/defence cash. Third
  raid has a crowned captain and shared HUD health. Chase timing needs testing.
- Q blinks across open deck. Check shorter range while carrying, wall and
  shield blocking, and the cooldown. Shift gives a four-second running burst.
- With two clients, use Y or the coloured arrival pads to join the same crew.
  Teammates must not steal cargo; outsiders still can when unlocked. Check
  crew nameplates, bay status, nearby assist cash, shared raid score and gold
  leading banners. Switching while carrying or during a raid must be denied.
- With API access, check Y → ALL-TIME and the world board after at least 60s;
  crew scores combine across servers. Without API access, gameplay must stay
  playable with retry/local status. Test server close after earning points.
- Run `node tools/check-combat.mjs`, `node tools/check-collections.mjs` and
  `node tools/verify.mjs`. These are source regressions and artifact checks;
  they cannot confirm Roblox physics, rendering, audio or live capabilities.
