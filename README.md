# Color Panic

A round-based Roblox party game for kids, built with Rojo. Players race to stand on the tile that matches the target color before the timer runs out. Every other tile drops, and the last one standing wins. Every color has its own shape, so the game never relies on color alone.

See `SPEC.md` for requirements and `CLAUDE.md` for working rules and current status.

## Status: 3-day demo build

Slice 1 (the core loop) and the demo tasks are merged to `main`:

- **Title screen:** logo, Play, a how-to-play card with the six color and shape pairs, and Settings and Shop marked "Coming soon" (not built).
- **Join queue:** players start in the menu. Only players who press Play count toward a match, and Leave returns to the menu before a match starts.
- **Lobby panel:** players ready, players still needed, and a countdown banner.
- **Rounds:**
  - an intro banner: "Round 3 / Find the Red Heart · 12 seconds"
  - a timer with a 3-second warning
  - tiles that show their shape
  - reveal-then-hide targets from round 3
  - shrinking tiles from round 4
  - a replay if everyone falls
  - a round cap of 8 with "Final round!"
- **Eliminated players:** an "Eliminated!" card, then spectating (the camera follows a survivor; switch or stop at any time).
- **Results:** winner, places and rounds survived for this match only. Nothing is saved.
- **Look and sound:** glossy tiles, soft lighting, bloom, a prop ring, confetti, 9 sound effects and 2 music loops.

Out of scope for the demo: shove, spectator pranks, saved data, custom chat, monetization, and Settings and Shop beyond the "Coming soon" tiles.

## How to play

1. Press **Play** on the title screen. A match starts when at least 2 players are ready.
2. Each round shows a target, for example **Red Heart**. Run to a tile with that color and shape before the timer ends.
3. The other tiles drop. Anyone not on a target tile is out and can spectate.
4. Rounds get faster, the target hides after a short reveal from round 3, and tiles shrink from round 4. The last player standing wins. Anyone still standing after round 8 shares the win.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit) (the toolchain manager that pins tool versions).
2. In the repo root, install the pinned tools:

   ```bash
   rokit install
   ```

   Rokit asks you to trust each tool the first time. Pinned versions live in `rokit.toml` (Rojo, StyLua, Selene, luau-lsp, Lune).
3. Install the Rojo plugin in Roblox Studio. Its version should match the Rojo version in `rokit.toml`.

## Build and run

Build a place file:

```bash
rojo build default.project.json -o ColorPanic.rbxl
```

Live sync into Studio:

```bash
rojo serve
```

Then open a place in Studio and click Connect in the Rojo plugin (default port 34872).

### Testing in Studio

- Use **Test, Server and Clients with 2 clients**. Do not run 8 local clients; one machine runs out of memory.
- Players start in the menu, so press **Play** in each client window. `qa/snippets/press_play.client.luau` does the same from a client command bar.
- A match needs 2 queued players. For a one-player match in Studio only, set `Config.Match.studioSinglePlayerEnabled = true` (it never applies to live servers).
- Test actors must walk (`qa/snippets/actor.client.luau`). Client-side teleports do not always reach the server.

### Publishing the demo

Build from `main` and publish the place as a private experience under the **same account that owns the uploaded images and sounds** (the asset IDs in `Config.Assets`). Roblox audio is private to its owner, so under another account or a group the sounds stay silent until you grant that experience access. The QA steps for a published copy are in `qa/demo-qa.md`.

## Configuration

Every tunable value lives in `src/shared/Config.luau`. Services never hardcode numbers, colors or shapes. A test fails if a color or shape name appears anywhere outside Config.

| Table | What it controls |
| --- | --- |
| `Colors` | The six colors, their hex values and shapes, copied from `art/palette.json` (a test keeps them in step) |
| `Difficulty`, `Match`, `StateSeconds` | Round timers, color counts, reveal times, the round cap and state lengths |
| `Shrink` | Shrinking tiles: from which round, how much per round, the smallest size |
| `Assets` | Roblox asset IDs for images and sounds. Use Image IDs, not Decal IDs. An ID of 0 skips the asset and shows a text fallback. |
| `Hud`, `Banner`, `Lobby`, `Spectate`, `Results`, `Menu` | UI sizes, positions, colors and fonts |
| `Look`, `Audio` | Lighting, bloom, tile gloss, props, confetti; sound and music volumes |

**Presets:** `ACTIVE_PRESET` at the top of `Config.luau` picks a preset applied on top of the normal values. `"demo"` (the current one) shortens the intermission, caps a match at 8 rounds, sets the demo difficulty and turns on shrinking tiles. `"normal"` changes nothing. Presets list only the values that differ, and an unknown key or a wrong type is an error at startup.

## Format, lint, type check and test

```bash
stylua src tests
stylua --check src tests
selene src tests
bash scripts/typecheck.sh
bash scripts/test.sh
```

Run all of these before opening a pull request. On Windows, run the scripts from Git Bash.

- **Tests:** `scripts/test.sh` runs the pure-logic tests in `tests/*.spec.luau` with [Lune](https://github.com/lune-org/lune), outside Studio. `tests/harness.luau` reads the Rojo sourcemap, so modules keep their Roblox-style requires (`script.Parent.X`, `game:GetService(...)`).
- **What can be tested:** only pure modules, with no real services or instances. Game rules (`MatchFlow`, `RoundDirector`, `EliminationRules`, `MatchResults`, `QueueRules`) and every `*Model` behind the UI are pure for this reason.
- **Adding tests:** create `tests/<Name>.spec.luau` using `describe`, `it` and `expect` from the harness.
- **Type check:** `scripts/typecheck.sh` uses luau-lsp with Roblox API types and a Rojo sourcemap, so `--!strict` errors and bad requires are caught outside Studio. On first run it downloads the Roblox type definitions for the pinned luau-lsp version into `.luau-lsp/` (git-ignored).

## Layout

| Folder | Becomes | Contents |
| --- | --- | --- |
| `src/server` | `ServerScriptService.Server` | Server services and pure game rules |
| `src/shared` | `ReplicatedStorage.Shared` | Config, Types, Remotes, Util |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Client controllers and their pure view models |
| `tests` | (not in the game) | Lune tests and the test harness |
| `qa` | (not in the game) | QA records, the demo QA checklist and Studio command bar snippets |
| `art` | (not in the game) | The artist's palette (`palette.json`) |
| `scripts` | (not in the game) | Type check and test runners |

Entry points are `Main.server.luau` and `Main.client.luau`. Module scripts use the `.luau` extension.

**How the code fits together:**

- **Server authority:** the server decides everything: match state (`MatchService`, with the pure `MatchFlow`), rounds (`RoundDirector`), tiles (`ArenaService`), who is out (`EliminationService` and `EliminationRules`), placement and results.
- **Remotes:** declared only in `shared/Remotes`. Clients send just two requests, Play and Leave, which the server validates.
- **Clients only draw:** they render what the server sends. Each controller (HUD, menu, spectate, audio, look) draws from a pure model (`HudModel`, `BannerModel`, `LobbyModel`, `ResultsModel`, `SpectateModel`, `AudioModel`, `MenuModel`), and the models are what the tests cover.
