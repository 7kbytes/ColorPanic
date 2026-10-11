# Color Panic: game page content

Draft copy and images for the Roblox experience page. Nothing here has been applied: the page
is changed by hand on the Creator Dashboard, or through Open Cloud once an API key exists.

## Before you publish anything

- **The BETA place is currently public.** The Studio activity log shows "Playability was changed
  to public" at 06:07 on 2026-10-11. Decide whether that is what you want before putting more
  effort into the page. The demo has not had the D-11 playtest yet.
- The build on this page's screenshots is the slice 2 build (3D models, skybox, cloud sea). It
  is on the `slice2/*` branches, not yet on `main`.

## Name

Color Panic

## Description (paste into the experience description)

```
Find the color. Survive the chaos. Be the last one standing!

A target color and shape flashes up: Red Heart, Blue Circle, Purple Square. You have seconds
to reach a matching tile before every other tile drops away. Miss it and you fall into the
clouds.

Each round is faster than the last. From round 3 the target hides after a quick look, so you
have to remember it. From round 4 the tiles shrink. Last player standing wins.

- 2 to 12 players
- Short rounds, quick restarts
- Every color has its own shape, so you never need to tell colors apart to play
- Built for phones as much as PC

Made for a jam. More coming.
```

Why it reads this way: it opens with the hook, explains the loop in one short paragraph, then
lists what is actually in the build. It claims nothing the game does not do, which matters
because the page previously showed a shop, a podium and green tiles that do not exist.

## Genre and settings

| Setting | Suggested | Why |
| --- | --- | --- |
| Genre | Party and Casual (or Obby and Platformer if that fits better) | Round-based elimination party game |
| Devices | Computer, Phone, Tablet | Built mobile first; console and VR are untested |
| Age guide | All Ages | No violence, no chat input, no purchases |
| Private server | Off | Nothing to gain while the game is a demo |
| Monetization | None | Locked in the spec for launch |

Check Roblox's current genre list before choosing: it changes, and I could not confirm the
present set.

## Screenshots

In `Downloads/3d models/processed/gamepage/` (outside git, they are large):

| File | Shows |
| --- | --- |
| `thumb_1_title.png` | Title screen with the lobby island behind it |
| `thumb_2_round.png` | Round 1 banner, "Find the Red Heart", tiles with their shapes |
| `thumb_3_arena.png` | Mid-round on the arena, timer running |
| `thumb_4_winner.png` | Winner panel with confetti |
| `thumb_5_fall.png` | After a fall, down on the island under the arena |

All are 1339 x 753, 16:9, captured from the slice 2 build in Studio. Roblox suggests
1920 x 1080. These are narrower because the Studio window could not be made wider than the
screen with its panels open, and I would rather hand over a sharp smaller image than a soft
upscaled one. To recapture at full size: run the game, hide every Studio panel, and take a
full screen grab, or publish and capture from the Roblox player.

## Icon

Not redone this session. The existing icon still applies.

## Still to confirm

- Which Meshy plan the 3D models were made on, for the asset licence.
- Whether the BETA place should be public.
