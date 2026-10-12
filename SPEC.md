# Color Panic: Spec and Slice 1 Tasks

This file is the working copy of the spec for the repository. If it conflicts with anything else, ask the producer (Kofi).

## 1. Overview

Color Panic is a round-based Roblox party game. 8 to 12 players race to stand on the tile matching a target color before the timer ends. Everyone on a wrong tile falls out. The last player standing wins.

- Reference feel: Floor is Lava (escalating chaos and near-miss tension).
- Audience: kids, mostly on mobile phones. Touch-friendly, short rounds, readable UI.
- Platform: Roblox, mobile first.
- Competitor to be aware of: Color Block already uses the plain stand-on-the-color mechanic. Our difference is the hooks in section 3.

## 2. Locked requirements

| Area | Decision |
| --- | --- |
| Players per server | 8 to 12 |
| Minimum to start a match | 2 players (1 allowed only behind a Studio test flag) |
| Audience | Kids, mobile first |
| Art style | Bright, bubbly cartoon |
| Monetization | None at launch; leave room for cosmetics later |
| Hooks | Shrinking or moving tiles, reveal-then-hide target, shove, spectator prank power-ups |
| Language | Luau, `--!strict` on core modules |
| Workflow | Rojo, VS Code, Git |

Accessibility: every color is paired with a unique shape. The HUD shows the target as swatch plus shape plus name.

Kid safety: no free-text input in game UI. Spectator pranks are cosmetic and audio only and never affect survivors.

## 3. Game design

One round:

1. The arena floor is a grid of colored tiles, reshuffled every round.
2. The target color is announced on the HUD.
3. A countdown starts and players run to a matching tile.
4. At zero, every non-matching tile drops away.
5. Players who fall are eliminated and become spectators.
6. Survivors move on; the next round is harder.
7. The last player standing wins, rewards are granted, and the lobby resets.

Match states, in order: Lobby, Intermission, RoundIntro, Run, Elimination, RoundEnd. After RoundEnd, if two or more players remain, go back to RoundIntro for the next round. Otherwise go to Victory, then Reset, then back to Lobby. Only the server moves between states.

Hooks (later slices):

- Shrinking or moving tiles (round 7 onward). The generator guarantees at least one matching tile per two surviving players.
- Reveal-then-hide (round 4 onward). Early rounds reveal for at least 2 seconds.
- Shove. Long cooldown, low knockback, server validates range, cooldown and state. Prototype early because knockback on Roblox characters can behave unpredictably with network ownership.
- Spectator pranks. Confetti, emoji pop-ups, sound stings. They never move or block survivors.

Edge cases (proposed, confirm in playtests):

- If every remaining player would be eliminated in the same round, the round replays once with a longer timer. If that repeats, they share the win.
- If a player leaves mid-match, remove them from the survivor count without ending the round.
- If fewer than 2 players remain connected during intermission, the match does not start.
- Players who join mid-match wait as spectators.

## 4. Architecture

Stack:

- Luau with `--!strict` on core modules.
- Rojo project file mapping `src/` into the place.
- Git, StyLua for formatting, Selene for linting.
- Wally only where a package clearly earns its place (not in slice 1).
- A session-locking DataStore library for player data (slice 5; verify the current choice before adopting).

Tooling decision (made by the producer):

- Rojo + VS Code + Git. No Studio-only scripting.
- Pin tool versions with a toolchain manager. Prefer Rokit; before adopting it, check that it is currently maintained, and fall back to Aftman if not. Report which one you chose and why.
- Use the script file naming convention supported by the pinned Rojo version (`.lua` or `.luau`, with `.server` and `.client` suffixes for entry points). Check the Rojo documentation rather than assuming.
- Propose a way to run tests on pure logic outside Roblox Studio and justify the choice before adding it.

Repository layout:

```
default.project.json
<tool manifest>          pinned versions
stylua.toml
selene.toml
README.md
SPEC.md
src/
  server/    MatchService, ArenaService, RoundDirector,
             EliminationService, ShoveService, SpectatorService,
             DataService
  client/    HUDController, TileFX, AudioController,
             ShoveInput, SpectatorUI
  shared/    Config, Types, Remotes, Util
```

Rojo mapping:

- `src/server` into `ServerScriptService` (folder named `Server`)
- `src/shared` into `ReplicatedStorage` (folder named `Shared`)
- `src/client` into `StarterPlayer/StarterPlayerScripts` (folder named `Client`)

Services:

| Service | Side | Responsibility |
| --- | --- | --- |
| MatchService | Server | Owns the match state machine and timers |
| ArenaService | Server | Builds the tile grid, assigns colors, removes tiles |
| RoundDirector | Server | Reads the difficulty table and sets each round's parameters |
| EliminationService | Server | Decides who is eliminated at zero |
| ShoveService | Server | Validates and applies shove (slice 3) |
| SpectatorService | Server | Tracks eliminated players and prank uses (slice 4) |
| DataService | Server | Loads and saves wins and coins (slice 5) |
| HUDController | Client | Target, timer, players left, round number |
| TileFX | Client | Tile drop, shrink, slide visuals |
| AudioController | Client | Countdown ticks, cues, win stinger |
| ShoveInput | Client | On-screen shove button (slice 3) |
| SpectatorUI | Client | Prank picker (slice 4) |

Principles:

- The server owns all game truth. Clients only render and send requests.
- Every tuning number lives in `shared/Config`.
- All remotes are declared in `shared/Remotes`, and the server validates every request.
- Each service is a self-contained module with a small public interface.

## 5. Difficulty curve (draft values, tune in playtests)

| Rounds | Run timer | Colors | Modifiers |
| --- | --- | --- | --- |
| 1 to 3 | 10s down to 8s | 3 | Target stays visible |
| 4 to 6 | 7s to 6s | 4 | Reveal-then-hide, 2s reveal |
| 7 to 9 | 5s | 5 | Tiles shrink during the run |
| 10 and up | 4s | 6 | Moving rows, shorter reveal |

Arena starting guess: 6 by 6 grid of 10-stud tiles (60 by 60 studs). Six colors, each with a fixed shape (palette and shapes come from the artist; reserve six color ids now).

## 6. Build plan

| Slice | Deliverable | Done when |
| --- | --- | --- |
| 1. Core loop | State machine, arena generation, target color, timer, tile removal, elimination, placeholder visuals | Two or more test players can play a full match from lobby to win and reset |
| 2. Feel and flow | HUD, countdown audio, win screen, Config-driven difficulty | Rounds 1 to 10 follow the curve with no code changes needed to tune |
| 3. Hooks | Reveal-then-hide, shrinking and moving tiles, shove | Each hook toggles by round in Config and survives a 10-player test |
| 4. Spectators | Spectator mode with prank power-ups | Eliminated players stay engaged and never affect survivors |
| 5. Persistence | Wins and coins saved, lobby polish | Data survives rejoin and server shutdown in testing |
| 6. Art and tuning | Art pass, playtest, tuning | Playtest feedback applied and a low-end phone holds a stable frame rate |

## 7. Conventions

Git:

- `main` is always playable and protected.
- One branch per task, named `slice1/<task-id>-<short-name>`, merged by pull request.
- The producer reviews and merges every pull request. Nobody reviews their own work.

Code:

- `--!strict` on core modules. Format with StyLua and lint with Selene before opening a pull request.
- No magic numbers. Timers, counts, cooldowns and distances live in `shared/Config`.
- Remotes are declared only in `shared/Remotes`.
- Clients render and request; they never decide outcomes.

QA checklist per slice:

- Plays through with 2 players and with 8 or more
- Player leaves or rejoins mid-round without breaking the match
- Works with touch controls on a phone
- No new errors in the output window
- Tile shapes readable without relying on color alone

## 8. Slice 1 tasks

Goal: a playable core loop with placeholder visuals. Two or more players can play a full match from lobby to win and back to lobby. Everything is server authoritative.

Out of scope for slice 1: tile shapes and art, audio, reveal-then-hide, shrinking or moving tiles, shove, spectator pranks, DataStore, shop.

Working rules: see section 7, Conventions.

Tasks, in order:

1. **S1-01 Repo and tooling.** The repo currently has only an initial commit. Add the Rojo project file mapping the three `src` folders as above, the pinned tool manifest, StyLua and Selene configs, and a README with setup steps. Done when `rojo build` produces a place file and `rojo serve` syncs into Studio.
2. **S1-02 Config and Types.** Create `shared/Config` (colors with ids and names, six color ids reserved for later shapes, grid size, tile size, intermission length, per-round timer and color count from the difficulty table, minimum players) and `shared/Types`. Include a Studio test flag that allows a one-player match. Done when no other module hardcodes these values.
3. **S1-03 Remotes.** Create `shared/Remotes` declaring every remote event in one place (state changed, round info, target announced, player eliminated, match result). Done when the server and client both require remotes only from this module.
4. **S1-04 MatchService state machine.** Implement the states in section 3 with timers from Config, player join and leave handling, and a log line on every transition. Done when the state machine cycles correctly with one test player and with two.
5. **S1-05 ArenaService.** Generate the 6 by 6 tile grid in a dedicated folder, give each tile a color id attribute, and expose functions to build, remove non-target tiles, and clean up. Done when a round builds a fresh shuffled grid and cleanup leaves nothing behind.
6. **S1-06 RoundDirector.** Read the round number and return the timer, color count and target color, and enforce the fairness rule (at least one matching tile per two surviving players). Keep the logic in pure functions that do not touch the DataModel. Done when the pure functions have tests covering the fairness rule and the round table lookup.
7. **S1-07 Spawning and placement.** Move players to lobby, arena or spectator area as the state requires, using placeholder spawn locations. Done when players land in the right place at every transition, including mid-match joins (who wait as spectators).
8. **S1-08 EliminationService.** After non-target tiles are removed, decide who is eliminated (fell below the arena or was not on a target tile), mark them as spectators, and update the survivor count. Implement the all-eliminated edge case. Done when each case is reproducible in a Studio test with multiple players.
9. **S1-09 Placeholder HUD.** Plain text elements showing state, round number, target color name, timer and players left, driven only by server remotes. Done when the HUD matches the server on every transition and works with touch controls and phone screen sizes.
10. **S1-10 Victory and reset.** Announce the winner or winners, wait briefly, clean up the arena, return everyone to the lobby and restart the cycle. Done when three consecutive matches run without leaked parts or stuck states.
11. **S1-11 Manual QA pass.** Run the QA checklist with 2 and with 8 or more players, test leave and rejoin mid-round, and record results in the pull request. Done when the checklist is ticked or each failure has a bug logged.
12. **S1-12 README update.** Document how to run the project, the folder layout, how to change Config values, and known limitations. Done when a new contributor can run a match from the README alone.

Slice 1 is complete when all twelve tasks are merged to `main`, a full match plays from lobby to victory and reset without errors in the output window, and the producer has played it.
