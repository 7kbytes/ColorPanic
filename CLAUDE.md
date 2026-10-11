# Color Panic: instructions for Claude Code

Read `SPEC.md` fully before doing anything. It holds the requirements, architecture, tooling decision and the slice 1 task list.

## Working rules

- Work on one task at a time. Before writing code for a task, propose your plan in a few lines and wait for the producer to approve it.
- One branch and one small pull request per task, named `<slice>/<task-id>-<short-name>`, for example `slice5/P1-02-session-locking`. Slices used so far: `slice1`, `demo`, `slice2`, `slice5`, `sliceH` (harden to playable).
- Use `--!strict` on core modules. Format with StyLua and lint with Selene before opening a pull request.
- Put every tunable number in `shared/Config`. No magic numbers in services.
- The server decides all outcomes. The client renders and sends requests; the server validates every request.
- Declare remotes only in `shared/Remotes`.
- Do not invent Roblox APIs, Rojo options or library names. If you are unsure whether something exists or still works, say so and check the official documentation, or ask.
- Pin tool versions. When you choose a tool version or a toolchain manager, say which one and why.
- After each task, report what you built, how you tested it, and anything you are unsure about.
- Do not use em dashes in code comments, documentation or commit messages.
- You cannot review your own pull requests. The producer reviews and merges.

## Current status

Last updated 2026-10-11, after P1-02.

### Merged to `main`

- **Slice 1** (S1-01 to S1-11), the core loop. QA record in `qa/slice1-qa.md`.
- **The 3-day demo build** (D-01 to D-16, branches `demo/<task-id>-<short-name>`): respawn and late-join placement with a lobby SpawnLocation fallback and the `MatchRole` player attribute (D-01, fixed #14); the final palette in `shared/Config` from `art/palette.json` (D-02); the elimination decision log (D-03); the demo preset with a round cap of 8, `ACTIVE_PRESET` in Config (D-04); reveal-then-hide (D-05); HUD with real assets (D-06, fixed #17); shape markers on tiles and the target card (D-03b); arena look, lighting kept near defaults so tiles keep their palette hues (D-07); audio (D-08); the title screen and concept polish (D-09, D-09b); shrinking tiles from round 4, `Config.Shrink` (D-10); banners (D-12); the lobby panel (D-13); the eliminated card and watch-only spectating (D-14); the results panel (D-15); the menu overlay and join queue, so players start in the menu and only queued players count (D-16).
- **Slice 2, the 3D models** (3D-00 to 3D-08, #41 to #49, branches `slice2/<task-id>-<short-name>`): `models/` mapped into Workspace with a builder rules checker (`tests/ModelRules.luau`); Blender prep for the Meshy models (`tools/blender/prep_models.py`); the lobby island, with lobbyOrigin at y 45; the skybox (`Config.Assets.Images.sky`); the spectator balcony, arena island and cloud sea, with spectatorOrigin at z -70; three flow fixes (streaming off, the menu camera orbiting the lobby, seamless skybox); the game page draft (`docs/game-page.md`); and the phone pass. QA record in `qa/slice2-3d-qa.md`. The Shop Kiosk model was left out: it would show a shop the game does not have.
- **P1-01 player persistence** (#50, branch `slice5/P1-01-data-service`): DataService, DataRules, rewards and leaderstats.

### Open pull requests

Stacked, so merge in this order:

- **#51 H-01** (`sliceH/H-01-verify-persistence`), Studio verification of P1-01, plus the two data bugs it exposed: a failed read could be saved over real stored data, and an autosave wrote whether or not anything had changed.
- **#52 P1-02** (`slice5/P1-02-session-locking`), based on #51. ProfileStore through Wally for player data session locking, with the decisions in the pure `shared/SessionRules`.

### Slice H, harden to playable

The current slice. Task list in `docs/sliceH-tasks.md` (H-01 to H-08, proposed, awaiting
producer approval). It adds no features: each task either proves something works with real
players, devices or servers, or fixes what that turned up. H-01 is merged as #51. Four of
the eight tasks are gated on a publish, a phone, or real players.

### Not done

- **D-11, the demo playtest, has never been run.** `qa/demo-qa.md` is still entirely blank. It needs 4 or more real players on a published copy. Watch whether 60% tiles by round 8 are too hard (`Config.Shrink`). Most of the tuning questions are waiting on this, so it is the critical path.
- **H-02, the two-server session handoff** (rows 7 to 9 of `qa/sliceH-qa.md`). Studio runs one server, so the locking added in #52 is written but not verified.
- **No device test.** Nothing has run on a real phone. Triangle budgets pass, but frame rate and join time on a low-end phone are unknown. The biggest open risk.
- **More than 2 players** has never been tested anywhere (#16).
- **Slice 3** (shove, moving tiles): not started. `ShoveService` and `ShoveInput` are in the spec's module table but do not exist. Reveal-then-hide (D-05) and shrinking (D-10) shipped early as demo tasks.
- **Slice 4** (spectator pranks): not started. `SpectatorService` and the prank picker do not exist; D-14 shipped watch-only spectating.
- **Slice 5 remainder**: lobby polish.
- **Slice 6** (art pass, playtest, tuning): waiting on the playtest.
- The game page draft needs the Creator Dashboard or an Open Cloud key to apply. Its screenshots are 1339 x 753, not the 1920 x 1080 Roblox suggests.
- Small model issues: players walk through the palms, lamps, pillars and the arch, and feet sink about half a stud into the lobby floor.

### Decisions and open questions

Design reference: the concept board (not final art). Color and shape pairs follow `art/palette.json`, not the concept board (producer decision). Green was recoloured everywhere, which is why the palm leaves and bushes are blue.

Open producer questions: the Meshy licence plan; whether blue palm leaves are wanted; and, in #52, whether Wally pinned at 0.3.2 is acceptable given that its last stable release was June 2023.

Open issues: #15 (cause found in D-03, traced to the QA actor, waiting to be closed), #16 (a playtest need, not a bug). #17 is closed (fixed in D-06).

The Color Panic [BETA] place was set to public by the producer on 2026-10-11. Build QA copies from `main`.

Assets: all 33 demo assets are uploaded under the game owner's account. Their IDs are in "Color Panic Asset IDs.xlsx", kept outside git. Code reads them from `Config.Assets`, and each task adds the ones it uses. Use Image IDs, not Decal IDs.

Tooling on `main`: a strict type check with luau-lsp (`scripts/typecheck.sh`) and pure-logic tests with Lune (`scripts/test.sh`). Run both, plus StyLua and Selene, before opening a pull request.

Packages: Wally, pinned in `rokit.toml`. Run `wally install` after cloning or after `wally.toml` changes. The only dependency is ProfileStore, which gives player data session locking. `ServerPackages/` is not in git; `wally.lock` is.

QA in Studio: use Test, Clients and Servers with 2 clients, never 8 (the machine runs out of memory). Players now start in the menu, so press Play first (`qa/snippets/press_play.client.luau`). Test actors must walk (`qa/snippets/actor.client.luau`); client-side teleports do not always reach the server.
