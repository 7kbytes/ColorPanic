# Color Panic: instructions for Claude Code

Read `SPEC.md` fully before doing anything. It holds the requirements, architecture, tooling decision and the slice 1 task list.

## Working rules

- Work on one task at a time. Before writing code for a task, propose your plan in a few lines and wait for the producer to approve it.
- One branch and one small pull request per task, named `slice1/<task-id>-<short-name>`.
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

Slice 1 (S1-01 to S1-11) is merged to `main`. The S1-11 QA record is in `qa/slice1-qa.md`.

We are now on the 3-day demo build. Demo tasks use branches named `demo/<task-id>-<short-name>` (producer approved). Merged to `main`:

- D-01 Respawn and late-join placement (fixed #14), with a lobby SpawnLocation fallback and the `MatchRole` player attribute
- D-02 Final palette in `shared/Config`, from `art/palette.json`
- D-03 Elimination decision log (#15 traced to the QA actor, which now walks)
- D-04 Demo preset (`ACTIVE_PRESET` in Config) with a round cap of 8
- D-16 Menu overlay and join queue (players start in the menu; only queued players count)
- D-05 Reveal-then-hide
- D-06 HUD with real assets (fixed #17)

In progress: D-03b Shape markers on tiles. Remaining, in order: D-12, D-13, D-14, D-15, D-08 (day 2); D-07, D-09, D-11, then D-10 if time allows (day 3). No new features after midday on day 3. The README update is out of scope for the demo.

Open issues: #15 (cause found, waiting to be closed), #16 (a playtest need, not a bug), #17 is closed (fixed in D-06).

Assets: all 33 demo assets are uploaded under the game owner's account. Their IDs are in "Color Panic Asset IDs.xlsx", kept outside git. Code reads them from `Config.Assets`, and each task adds the ones it uses. Use Image IDs, not Decal IDs.

Tooling on `main`: a strict type check with luau-lsp (`scripts/typecheck.sh`) and pure-logic tests with Lune (`scripts/test.sh`). Run both, plus StyLua and Selene, before opening a pull request.

QA in Studio: use Test, Clients and Servers with 2 clients, never 8 (the machine runs out of memory). Players now start in the menu, so press Play first (`qa/snippets/press_play.client.luau`). Test actors must walk (`qa/snippets/actor.client.luau`); client-side teleports do not always reach the server.
