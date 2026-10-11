# Overnight work report, 2026-10-11

Written by Claude Code for the producer. Covers the session from about 02:30 to 07:20 while
you were asleep. Everything is on branches with pull requests; **nothing was merged to `main`
and nothing was published to Roblox.**

## Read this first

1. **Color Panic [BETA] is public.** The Studio activity log shows "Playability was changed to
   public" at 06:07 today, by your account. I did not do it and I have not changed it back:
   who can play an unplaytested demo is your call, not mine. If it was not deliberate, change
   it in Game Settings.
2. **The BETA place now contains the slice 2 build.** I synced my branch into it with Rojo to
   test, as earlier sessions did. It is ahead of `main`. Build the D-11 QA copy from `main`,
   as `qa/demo-qa.md` says, or from `slice2/integration` if you want the new scenery in it.
3. **Regenerate the Meshy API key.** You pasted it into chat, so it is in the transcript. I
   did not end up needing it; everything was built from the models you had already made.

## What I built

Eight pull requests, each one task, all stacked. Merge in number order.

| PR | Task | What it does |
| --- | --- | --- |
| #41 | 3D-00 | Maps `models/` into Workspace; a test that checks every model against the workbook's builder rules |
| #42 | 3D-01 | Blender script that prepares the Meshy models for Roblox |
| #43 | 3D-02 | `models/Lobby.rbxm`, the lobby island |
| #44 | 3D-03 | Skybox |
| #45 | 3D-04 | Spectator balcony, the island under the arena, the cloud sea |
| #46 | 3D-05 | README, CLAUDE.md status, `qa/slice2-3d-qa.md` |
| #47 | 3D-06 | Three fixes found by watching the game: streaming, menu camera, skybox seams |
| #48 | - | This report and `docs/game-page.md` |

`slice2/integration` is all eight merged together, for syncing and playing the whole thing
before you merge anything.

### The models

Your 12 Meshy exports were 7 to 43 times over Roblox's 20,000 triangle limit per mesh, with
4K textures. The Blender script cuts each to a budget and bakes its texture onto the lighter
mesh, so they stay sharp. 584 MB of source art became about 19 MB. Green was recoloured to
palette colours, as your own rule asks. The Shop Kiosk was left out: the workbook lists a
shop stall as something that would misrepresent the game.

From those meshes I built four models: the lobby island, a spectator balcony, an island under
the arena so falling players land somewhere, and a cloud sea that hides the baseplate.

### The three fixes in #47

These are the ones that changed how the game feels, and I would not have found them without
sitting and watching the title screen.

- **Content streaming was on.** A client only receives parts near its character, and in the
  menu there is no character, so no scenery ever arrived: the title screen was empty sky. Off
  now, with a test so it cannot come back quietly.
- **The menu camera circled the arena**, which is empty between matches because tiles only
  exist during a round. It circles the lobby island now.
- **The skybox had hard seams.** The six faces were generated separately so their edges never
  matched. I rebuilt the cube from one face, mirrored, so every vertical join matches exactly.
  Measured 0.00000 edge difference, and no seam at any angle over a full camera orbit.

## How it was tested

- **285 automated tests pass**, plus the strict type check, StyLua and Selene with no
  warnings. 20 of those tests are new this session.
- **Studio, solo**: full loop several times. Title, Play, lobby pad, match, fall onto the
  island, judged out correctly, Victory with confetti, results, Reset, next match. No script
  errors in the Studio logs.
- **Studio, 2 players**: one full match, including elimination, "Spectator mode" for the
  loser, "Winner!" with places for the winner, and both back on lobby pads after Reset.
- The model checker runs against every `.rbxm` on every test run.

## What is not done

- **No device test.** Nothing has run on a phone. The triangle budgets pass, but frame rate
  and join time on a low-end phone are unknown. This is the biggest open risk.
- **D-11 has still not been run.** It needs 4 or more real players; `qa/demo-qa.md` is still
  blank.
- **More than 2 players** has never been tested. The machine runs out of memory with more
  Studio clients.
- **The game page is a draft only.** `docs/game-page.md` has the copy and five screenshots,
  but applying it needs the Creator Dashboard or an Open Cloud key.
- The screenshots are 1339 x 753 rather than 1920 x 1080, because the Studio window could not
  be widened past the screen with its panels open. Sharp, but smaller than Roblox suggests.

## Small things you may want to change

- Palm leaves and bushes are now **blue**, because the no-green rule applies to everything.
  It reads as stylised, but it is unusual. Say the word and I will try another palette colour.
- Players walk through the palms, lamps, pillars and the arch; only the floor and railings
  stop them.
- Feet sink very slightly into the lobby floor in places, because the collision floor is flat
  and the mesh floor varies by about half a stud.
