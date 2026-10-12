# Slice 2 QA record: 3D models (3D-00 to 3D-04)

Studio QA run on 2026-10-11 in the Color Panic [BETA] place, with `rojo serve` syncing the slice 2 branches. Test, Server and Clients with 2 clients, plus solo runs with `Config.Match.studioSinglePlayerEnabled` set locally (never committed).

## Automated

| Check | Result |
| --- | --- |
| `bash scripts/test.sh` | 284 passed, 0 failed |
| Builder rules on `Lobby`, `SpectatorArea`, `ArenaIsland`, `CloudSea` | Pass (anchored, palette or neutral colours, nothing in or beside the tile square, 12 flat spawns, part and triangle budgets) |
| `bash scripts/typecheck.sh`, StyLua, Selene | Pass |

## Studio

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 1 | Press Play (solo) | Character lands on a lobby spawn pad; no grey placeholder lobby | Pass | |
| 2 | Walk at the lobby edge | Railing stops the character | Pass | Feet sit slightly into the rim mesh |
| 3 | Sky | Painted clouds and floating islands in every direction from the lobby and arena | Pass | Not orbited around every face edge |
| 4 | Match start | Players placed on arena tiles | Pass | |
| 5 | Fall from a wrong tile | Lands on the arena island, judged out (below the fall margin) | Pass | Decision log: not on a tile, 8.7 below the top |
| 6 | Spectator placement | `toSpectator` puts the player on a balcony pad | Pass | (10, 53.1, -70) |
| 7 | 2 players, full match | Eliminated player gets "Spectator mode", winner gets "Winner!" with places | Pass | |
| 8 | Reset | Everyone back on lobby pads, next match starts | Pass | |
| 9 | Script errors in the Studio logs | None | Pass | |

## Not covered

- Phones: no device test of frame rate with the full scene (lobby about 75k triangles, spectator area about 57k, arena island 10k, clouds 20k).
- More than 2 players.
- Spectating from the balcony with the camera turned toward the arena (the arena is in view from the balcony by layout, not checked on screen).
