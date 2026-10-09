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

The repository has only an initial commit and no code. Start with task S1-01 (repo and tooling) and propose your approach first.
