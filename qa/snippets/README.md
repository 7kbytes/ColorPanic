# QA snippets

Small scripts for manual QA in Roblox Studio. They are not part of the game: Rojo does not map
this folder, so nothing here ships. Paste a snippet into the Studio command bar of the right
window (or run it through the Studio MCP `execute_luau` tool) while a Test, Clients and Servers
session is running.

| Snippet | Run in | What it does |
| --- | --- | --- |
| `press_play.client.luau` | each client | Sends Play (or Leave, with `LEAVE = true`), like the menu buttons. Since D-16, players start in the menu and only count toward a match after pressing Play, so run this first. |
| `hud_recorder.client.luau` | each client | Logs every HUD change with server time into `_G.hudlog`. Read it back with `hud_dump.client.luau`. |
| `hud_dump.client.luau` | each client | Returns the recorded HUD lines, optionally only the last N. |
| `actor.client.luau` | each client | Makes this player walk on its own during Run, set by `_G.qaMode`: `"target"` walks to a target tile, `"wrong"` to a non-target tile, `"fall"` off the nearest arena edge, `nil` does nothing. It walks with `Humanoid:MoveTo` like a real player; see the note below. |
| `where.server.luau` | server | Lists each player and where their character is: Lobby, Arena, SpectatorArea, falling or not spawned. |
| `placement_recorder.server.luau` | server | Logs into `_G.placelog` each time a player's location changes, with server time, to line up with the `[Match]` transitions. |
| `kill_during_run.server.luau` | server | Kills the named player's character during the next Run. |
| `log_summary.server.luau` | server | Returns the server log lines that matter for QA: transitions, eliminations, winners, reset audits, warnings and errors. |
| `soak.server.luau` | server | For the H-05 soak run. Paste once, then let matches play: it samples the workspace part count and server memory at every Reset and collects warnings, errors and any `[Reset] Problems`. Read the report with `_G.soakdump()`. |

**Do not teleport characters from the client in tests.** The first version of the actor moved
the character with `PivotTo` on the client. Some of those teleports never reached the server,
which then judged the player where they used to stand. That caused the wrong eliminations in
[#15](https://github.com/7kbytes/ColorPanic/issues/15). Walking always replicated.

The actor reads the target from the HUD. That is fine for testing, but a real client must never
decide outcomes; the server still judges every elimination.
