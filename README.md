# Color Panic

A round-based Roblox party game for kids, built with Rojo. 8 to 12 players race to stand on the tile matching a target color. See `SPEC.md` for requirements and `CLAUDE.md` for working rules.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit) (the toolchain manager that pins tool versions).
2. In the repo root, install the pinned tools:

   ```bash
   rokit install
   ```

   Rokit asks you to trust each tool the first time. Pinned versions live in `rokit.toml` (Rojo, StyLua, Selene).
3. Install the Rojo plugin in Roblox Studio. Its version should match the Rojo version in `rokit.toml`.

## Build and run

Build a place file:

```bash
rojo build -o ColorPanic.rbxl
```

Live sync into Studio:

```bash
rojo serve
```

Then open a place in Studio and click Connect in the Rojo plugin (default port 34872).

## Format and lint

```bash
stylua src
stylua --check src
selene src
```

Run both before opening a pull request.

## Layout

| Folder | Becomes | Contents |
| --- | --- | --- |
| `src/server` | `ServerScriptService.Server` | Server services |
| `src/shared` | `ReplicatedStorage.Shared` | Config, Types, Remotes, Util |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Client controllers |

Entry points are `Main.server.luau` and `Main.client.luau`. Module scripts use the `.luau` extension.
