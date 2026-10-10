# Slice 1 QA record (S1-11)

- **Build tested:** `main` at `41de1c9` (S1-01 to S1-10).
- **Date:** 2026-10-09.
- **Where:** Roblox Studio, Test with Clients and Servers, on one Windows machine with 12 GB RAM.
- **Method:** the scripts in `qa/snippets/`, run from the Studio command bar through the Studio MCP:
  - a HUD recorder on each client
  - a placement recorder on the server
  - an actor on each client that stands on a target tile, stands on a wrong tile, or drops off the arena during Run
  - server-side kills and kicks

  Results were read from the server log and these recordings.

## Summary

| SPEC QA item | Result |
| --- | --- |
| Plays through with 2 players | Pass |
| Plays through with 8 or more players | **Not met.** 8 Studio clients connected briefly but the machine ran out of memory. A full match passed with 7. See [#16](https://github.com/7kbytes/ColorPanic/issues/16). |
| Player leaves or rejoins mid-round without breaking the match | Pass for the match flow. **Fail for placement:** a rejoining player lands on the arena. See [#14](https://github.com/7kbytes/ColorPanic/issues/14). |
| Works with touch controls on a phone | Pass in the Device Simulator (Samsung Galaxy A06). Not tested on a real phone. |
| No new errors in the output window | Pass for game code. Two errors came from Roblox's own scripts (details below). |
| Tile shapes readable without relying on color alone | Not applicable: shapes are out of scope for slice 1. |

Bugs logged:

| Issue | Severity | Summary |
| --- | --- | --- |
| [#14](https://github.com/7kbytes/ColorPanic/issues/14) | High | Respawned and newly joined characters spawn above the arena instead of their area (fails S1-07 "done when") |
| [#15](https://github.com/7kbytes/ColorPanic/issues/15) | Medium, unconfirmed | Survivor on a target tile judged out, seen once and not reproduced |
| [#16](https://github.com/7kbytes/ColorPanic/issues/16) | Test gap | 8 or more players could not run on this machine |
| [#17](https://github.com/7kbytes/ColorPanic/issues/17) | Low | HUD shows `Round: -` for about 0.1 s at match start |

## 2 players

Session length was about 30 minutes, with 19 matches. All 19 resets logged `[Reset] Clean: 0 tiles, 27 parts, everyone in the lobby`. The server logged no warnings or errors.

| Case | Result | Evidence |
| --- | --- | --- |
| Full cycle: Lobby, Intermission, RoundIntro, Run, Elimination, RoundEnd, Victory, Reset, Lobby | Pass | Every transition logged. Both HUDs followed it, and the winner line matched the server's `Winners:` line. |
| Placement at match start (lobby to arena) and at Reset (everyone to lobby) | Pass | Placement recorder: all players moved within 0.1 s of the transition. |
| Eliminated while alive: moved to the spectator area | Pass | For example Player1 went from falling to SpectatorArea at RoundEnd. |
| Eliminated on a wrong tile (S1-08) | Pass | `Player2 is out, 1 left`, `Winners: Player1` |
| Eliminated by falling off (S1-08) | Pass | Player2 dropped off, died in the void, `died during round`, out |
| Eliminated by dying during the round (S1-08) | Pass, 3 of 3 | Server killed Player2 during Run: `Player2 died during round 1`, out, Player1 wins |
| Everyone out: round replays once with a longer timer (S1-08) | Pass | `All 2 would be out, replaying round 1`, then a replay Run of 13.3 s (10 s plus the 3 s bonus) |
| Everyone out again on the replay: shared win (S1-08) | Pass | `All 2 fell again on the replay, they share the win`, HUD `Winners: Player1 and Player2` |
| Survivor leaves mid-round | Pass | Player2 left 5 s into Run. Player1's HUD showed `Players left: 1` within 1.4 s, the round finished, Player1 won, and the reset was clean. |
| Players leave during Intermission so fewer than 2 remain (S1-04) | Pass | `Intermission -> Lobby (players 1)` 1.3 s after the leave. The match did not start. |
| Join while in Lobby | Match flow pass, **placement fail ([#14](https://github.com/7kbytes/ColorPanic/issues/14))** | Player3 joined. The match started with 2 players. Player3's character spawned above the empty arena and fell first. |
| Join mid-match (rejoin): waits as spectator, plays the next match | Match flow pass, **placement fail ([#14](https://github.com/7kbytes/ColorPanic/issues/14))** | Player4 joined in round 9. It was not counted as a survivor and the HUD was correct (`Players left: 2`). The next match had `players 3, survivors 3`. But Player4's character landed on the arena each round instead of in the spectator area. |
| Survivor on a target tile is safe | **Fail once ([#15](https://github.com/7kbytes/ColorPanic/issues/15))** | In one match Player1, on a target tile, was judged out twice (a replay, then a shared win). Correct in all 5 later tries. |

Studio cannot rejoin as the same account. A returning player always gets a new name (Player3, Player4), so a true same-account rejoin was not tested.

## 8 or more players

8 clients were started. The machine ran out of memory (400 MB free of 12 GB), clients loaded minutes apart, and two client processes died. The server stalled under load: a 2 s RoundEnd took 12.6 s. Logged as [#16](https://github.com/7kbytes/ColorPanic/issues/16).

| Case | Result |
| --- | --- |
| Players join a running match as spectators | Pass: survivors stayed at 2 while players went from 2 to 8 |
| Client lost mid-match | Pass: players went from 8 to 7, the match continued, and survivors were unaffected |
| Full match with 7 players | Pass. All 7 placed on the arena at RoundIntro. Round 1 eliminated 5 at once and round 2 eliminated 1. `Winners: Player7`. The reset was clean and all 7 returned to the lobby. |
| Errors | One Roblox CoreGui error under load: `FreeCameraInstaller` script timeout. None from game code. |

Server-side position samples during that run were noisy because of the load, so they are not used as evidence beyond the summary above.

## Touch controls and phone screen

Single-player build (Studio test flag on, scratch build only, not committed), Device Simulator on a Samsung Galaxy A06 (705x338 safe area):

| Check | Result |
| --- | --- |
| Device reports touch input | `TouchEnabled = true` |
| On-screen thumbstick moves the character | Pass: about 17 studs in 1.2 s, normal walk speed |
| On-screen jump button | Pass: Jumping, Freefall, Landed. A very short click did not register; a normal press did. |
| HUD clear of the thumbstick, jump button and Roblox menu | Pass |
| HUD text fits, including the winner line | Pass: every label `TextFits = true`, including `Winner: Asuraking7` |

## Errors in the output window

| Where | Message | Source |
| --- | --- | --- |
| Client, 2-player run | `ChatScript:116: Error calling SetCore CoreGuiChatConnections` | Roblox's legacy chat CoreScript, a known Studio timing error. Not game code. |
| Server, 8-player run | `FreeCameraInstaller:145: Script timeout` | Roblox CoreGui under heavy load. Not game code. |

Nothing from `ServerScriptService.Server`, `ReplicatedStorage.Shared` or `StarterPlayerScripts.Client` logged a warning or error in any session.

## Not covered

- A real phone, and a real rejoin by the same account. Both need a published private test place ([#16](https://github.com/7kbytes/ColorPanic/issues/16)).
- Tile shapes: out of scope for slice 1.
