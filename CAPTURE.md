# ROT ORBIT Studio handoff

Play link: https://www.roblox.com/games/75703852342218
Place ID: 75703852342218. Universe ID: 10777849208.
Public-link verification passes. The published place still needs the latest
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
| 01-cover.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Cover(0)` | $867.5M, live income, rebirth 3, 18s meteor banner, Diamond Cosmo Cornetto carry, five docked heroes with the Supernova SECRET in the middle; a genuine buyable Aurora SECRET on the left cargo arc; low dark-metal showcase balcony, broad flat cargo ring, clear world title and deep-space backdrop. |
| 02-index.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Index(0)` | Exactly 32/43 FOUND, seven rarity counts, undiscovered silhouettes, six mutation tabs and next cash reward. |
| 03-raid.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Raid(0)` | 27s raid banner, crowned captain escaping with cargo (18/32 HP, wave 3), one zapped gremlin and dropped recoverable cargo, shared captain health bar. |
| 04-upgrades.jpg | `require(game.ReplicatedStorage.ScreenshotMode).Upgrades(0)` | Five upgrade tracks with levels/costs; rebirth x3 → x4.5, +3s shield, next Orbit Ace aura and keep-best text; three contracts with progress/rewards and 4/15 done. |

Check the cover at 768 pixels wide and the three secondary pictures at 253
pixels wide. Keep the title and SECRET face clear of the HUD; confirm names,
rarity cards, income, banner and bottom controls remain readable. The saved
55° camera sits at (5, 26, 70), looking toward (0, 8, 4). The temporary
showcase origin is at (0, 7.3, 35), beside the flat 9-stud cargo ring; the rail
should span the frame behind the docked heroes. Look for the Aurora SECRET on
the far-left cargo arc and the Diamond Cosmic on the right. Tall cargo now
stays farther back so its crown can fit below the event band. The avatar
carries its Cornetto between the left docked heroes; check silhouette separation.
Exactly one cargo BUY card stays
visible in the frozen cover, showing the Aurora SECRET's real price/income.
The five dock cards spread below their models with separate projected
rectangles. The existing station marquee shifts for Cover and restores its
normal pose for Index/Raid/Upgrades; repeat Cover to check there is no drift.
Foreground SECRET pillars stop just above their crowns to clear the title.
Check that the BUY card clears the dock cards, all six real pods fit cleanly,
the counts strip is clear, and the crew rank board stays outside the useful
frame. Source tests check actual balcony staging, rail width, title sightlines,
pillar clearance and five card rectangles. Actual brightness, faces, particles,
all pod occlusion and text readability still need Studio approval.

20 November v11 source update: the cargo rail is flat at Y=9. All orbit
centres share the hub axis X=0, Z=0. The three overhead cyan/violet/gold
halos share (0, 80, 0), radii 60/72/84 and tilts 0/+10/−10 degrees.
The arrival camera is at (0, 15, 64), looking at (0, 27, −2). Confirm the
rail stays low and both ramps reach it. Pan all the way around at the deck
edge: the sky should stay deep black/navy with stars and no cyan hills or
bright horizon band. Azure is far below the deck horizon; other small sky
bodies sit more than 1,000 studs away. Event colour stays on the domes.
Other presets restore the normal title and remove the balcony through the
existing preview cleanup. Phone review should include the concentric halos,
triple-rim portals, tall orbital hologram, dark bay floors at every rebirth,
short phone event banner, luxury trophy podium and sculpted brainrots. Check Toastronaut's rounded crust and crumb face,
the lettuce leaves and bean dish, rounded gloves/boots, large expressive eyes,
Epic capes, Mythic mantles, Cosmic moons and SECRET royal cape/crown.
The early parade now also has crimped ravioli, a satellite receiver dish,
turbo penguin flippers/goggles/skis and curved Cornetto pastry tips. Check that
the goggles frame the penguin's eyes and the pasta details leave faces clear.
The source harness builds all 602 plain/mutation and dock/cargo combinations;
confirm their faces, clipping and glow in Studio.
These changes pass source/build checks; their rendered appearance is unverified.

Final phone polish smoke pass (20 November): use **844×390**, then **390×844**,
and rotate back once. In ordinary play the portrait HUD uses a taller canvas;
landscape keeps the established framing. Cash, income and the event band should
have clear gaps. MENU, Run, Blink, Zap and each menu action must remain easy to
tap. Open MENU: check the crew and contracts actions, then close it. The action
feed should stay below MENU during play and hide while the menu is open. With a
captain active, its health bar must clear MENU and the first-orbit card. Carry a
brainrot and check its bottom strip clears all skill buttons. Keep the ROT ORBIT
world sign readable in the arrival view. Automated bounds and non-overlap checks
cover both sizes, including the sign projection; this still needs phone review.

On a fresh arrival, follow BUY at the rail → DOCK at YOUR bay → COLLECT the
first automatic income payment. One ground beam should change target from the
rail to your bay and disappear with the quest card after payment. Open a panel
mid-quest and check both hide temporarily. Buy, dock, steal and collect should
give a brief model pop and floating amount; a purchase shows its cost, docking
shows income per second, and stealing shows cargo value. There is at most one
brief burst emitter per client; it is removed within one second. On occupied
Legendary/Mythic/Cosmic/SECRET pedestals, inspect coloured rarity tags, layered
rings and gentle model-level idle motion. Enter a capture preset during a pop:
no leftover burst, pop label or enlarged model should remain.

For the phone smoke pass, also confirm the dark station deck separates the
teal/gold paths, a player with zero docked cargo sees a clear dock-a-brainrot
hint instead of a misleading `$0/s`, and joining-crew signs stay legible without
overlapping. Check the title flyby and first spawn for a nearby moving pod,
the pod buy prompt on both sides of the flat track, and the gap between the
world title and spinning core. Pan quickly to confirm cargo cards clear the
cash and event HUD. Keep the gremlin warning short enough to fit at 1024×460.

Occupied dock sockets now use a thick inner rarity ring and a thin broken outer
ring. Near the camera, the outer facets rotate/pulse gently; Epic+ has a faint
low aura and Legendary+ has sparse sparkles. SECRET cycles colour. Walk more
than 90 studs away and back to check that motion/particles stop and resume.
Retire or steal a character and confirm its empty socket has no lingering
accents. Cover uses the same layered sockets in a fixed pose, without random
socket particles; repeat Cover and check identical ring positions/colours.
Check the low auras do not obscure faces, dock cards or the foreground rail.

Run Cover → Index → Raid → Upgrades → Cover in the same Play session. Each
should replace the prior preview: six cargo pods (not twelve), one BUY card
only on Cover, no old showcase platform or meteors on the other presets, and
only the requested panels open. Index must remain 32/43 on every return. If a
pose/card overlaps at 768px wide, report the shot and object before capturing
the final file; the preset is adjustable in ScreenshotService. Existing source
checks cover cargo replacement, frozen card selection, repeat discoveries and
Cover-to-other-preset title restoration,
and the actual client camera/FOV and exclusive-panel transitions. `TOUR.json`
uses these exact four server entry points with argument `0` and a 1,000 ms wait;
it is checked during every normal verification, independently of image files.
These checks do not simulate the full Roblox renderer or approve these images.
Preset-to-preset cleanup does not resume normal gameplay: stop and restart Play
to restore prompts, the normal camera, avatar movement and the live saved profile.

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
  following the camera. Empty scores say No raids yet. Earn defence points and
  check the correct podium fills and the gold bar flashes on the update.
  The home marker should
  be small, respect world occlusion and hide inside 24 studs of home.
- Phone Menu reveals lock/upgrades/rebirth/index/crew/contracts; closing it
  clears the left side. Blink, Run and Zap sit near the right thumb.
  Confirm taps, cooldowns and the Roblox jump button do not compete.
- Rebirth with several docked cargo, including a valuable mutation. Confirm
  exactly one best-income cargo survives, its original mutation remains, and
  $/s is nonzero immediately. Rejoin to check persistence. R1 has 10 base pods;
  R2 Blink goes farther, R3 periodically adds shared Mythic supply, R4 has a
  title/aura. Check mint/blue/gold/rose bays, announcement and fireworks.

- Republish the rebuilt place first. Confirm **zero server errors**, the dark
  metal deck, black starfield, centered orbit and bays all spawning. FallenPartsDestroyHeight is authored
  in the place rather than written by a restricted runtime thread.
- Test LOCK twice quickly: one shield and one cooldown. Let it expire, wait
  for recharge and lock again. Upgrades/rebirth should extend its duration.
  With two clients, leave a locked bay and have the other player claim the
  released bay; the old timer must never clear the new owner's shield.
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
