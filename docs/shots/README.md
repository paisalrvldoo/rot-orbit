# Owner gate 0a: genuine spawn screenshot required

**0a remains pending.** There is no Roblox renderer in this workspace.
No generated picture, source projection or old v8 capture counts as proof.

1. Open the latest committed `game.rbxl` in Roblox Studio. Start **Play** with
   a client viewport of **1170x540** (19.5:9). Click PLAY on the title screen.
2. Capture during the two-second arrival view while standing still. The normal
   HUD appears immediately, and moving restores the follow camera. If you
   miss the window, wait for the follow camera and restore the same arrival
   view in the **client** Command Bar:

   ```lua
   local c = workspace.CurrentCamera; c.CameraType = Enum.CameraType.Scriptable; c.CFrame = require(game.ReplicatedStorage.Config).World.SpawnCamera(); c.FieldOfView = 65
   ```

   Use a fresh Play session, not Cover/Index/Raid/Upgrades: this is the real
   spawn view, with ordinary cargo, money and the normal phone HUD. Do not
   stage high income or hide the HUD. The new arrival faces toward the title
   and the existing planetary background instead of away from them.
3. Capture only the client viewport as `docs/shots/0a-spawn-phone.jpg`. Check:
   - The huge real conveyor arcs overhead across the upper half, distinct
     from the deck; both thick rarity rails and moving pods are obvious.
   - ROT ORBIT is fully readable below the arc with no track/support clipping.
   - The nearest pods are clearly larger than the avatar; portal rims do not
     cut through SECRET crowns. Pan during live shopping to inspect headroom.
   - Walk up either broad side ramp and buy a Common at normal prompt range.
     Carry it down, dock it, and confirm income; try Run and Blink on the ramps.
   - After restoring `CameraType = Enum.CameraType.Custom`, the live arrival
     remains useful. Check the owner's phone as well as Studio's emulation.
4. Inspect the genuine image before marking 0a complete. Commit it with an
   `0a:` commit message, and only then begin override item 0. If the live
   camera differs from the locked view or the arc is unimpressive, keep 0a
   pending and adjust this orbit pass first. Current math projects the rail
   centres to x220–950, y111–233; lighting/occlusion cannot be approved by math.

`node tools/verify.mjs` includes the actual Luau orbit builder's geometry
checks. It validates access, bounds and placement; it does not produce or
approve this screenshot. The four final 1280x720 entry screenshots still
belong in `screenshots/` under the existing capture rules in CAPTURE.md.
