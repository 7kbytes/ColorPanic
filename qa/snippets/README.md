# QA snippets

Small scripts for manual QA in Roblox Studio. They are not part of the game: Rojo does not map
this folder, so nothing here ships. Paste a snippet into the Studio command bar of the right
window (or run it through the Studio MCP `execute_luau` tool) while a Test, Clients and Servers
session is running.

| Snippet | Run in | What it does |
| --- | --- | --- |
| `hud_recorder.client.luau` | each client | Logs every HUD change with server time into `_G.hudlog`. Read it back with `hud_dump.client.luau`. |
| `hud_dump.client.luau` | each client | Returns the recorded HUD lines, optionally only the last N. |
| `actor.client.luau` | each client | Makes this player act on its own during Run, set by `_G.qaMode`: `"target"` stands on a target tile, `"wrong"` on a non-target tile, `"fall"` drops off the arena, `nil` does nothing. |
| `where.server.luau` | server | Lists each player and where their character is: Lobby, Arena, SpectatorArea, falling or not spawned. |
| `placement_recorder.server.luau` | server | Logs into `_G.placelog` each time a player's location changes, with server time, to line up with the `[Match]` transitions. |
| `kill_during_run.server.luau` | server | Kills the named player's character during the next Run. |
| `log_summary.server.luau` | server | Returns the server log lines that matter for QA: transitions, eliminations, winners, reset audits, warnings and errors. |

The actor reads the target from the HUD. That is fine for testing, but a real client must never
decide outcomes; the server still judges every elimination.
