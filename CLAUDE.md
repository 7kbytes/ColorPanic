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

Slice 1 tasks S1-01 to S1-08 are merged to `main`:

- S1-01 Repo and tooling, S1-02 Config and Types, S1-03 Remotes
- S1-04 MatchService state machine, S1-05 ArenaService, S1-06 RoundDirector
- S1-07 Spawning and placement, S1-08 EliminationService

Tooling on `main` also includes a strict type check with luau-lsp (`scripts/typecheck.sh`) and pure-logic tests with Lune (`scripts/test.sh`). Run both, plus StyLua and Selene, before opening a pull request.

S1-04, S1-07 and S1-08 have not yet been checked against their multiplayer "done when" criteria in Studio.

Next task: S1-09 Placeholder HUD. Propose your approach first. Remaining after that: S1-10, S1-11 and S1-12.
