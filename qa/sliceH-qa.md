# Slice H QA record: harden to playable

Studio QA by Claude Code. Solo runs use `Config.Match.studioSinglePlayerEnabled` set locally and never committed.

## H-01 Persistence (P1-01), 2026-10-11

Run in Color Panic [BETA] with Rojo syncing `main`, Studio Access to API Services on.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | Join | Profile loads, leaderstats folder created | Pass, `[Data] Loaded luxygee: 0 wins` |
| 2 | Leaderboard | Wins and Coins columns show | Pass |
| 3 | Win a match | Wins +1, coins +50 | Pass, 1 win / 50 coins |
| 4 | Survive a round | Coins +5 | Pass, totals reached 2 wins / 105 coins |
| 5 | Leave and rejoin | Same wins and coins come back | **Pass**, `Loaded luxygee: 2 wins, 105 coins` |
| 6 | API services off | Retries, warns, loads defaults, no crash, game still plays | Pass, 3 attempts then `502: API Services rejected request` |
| 7 | API services back on | Stored data still intact | Pass, 2 wins / 105 coins |

The setting was returned to on afterwards.

## Two bugs found and fixed

**Lost progress after a failed read.** If `GetAsync` failed for a transient reason, the player
loaded as a fresh profile, and on leave that fresh profile was written straight over whatever
was still in the DataStore. One brief outage would wipe a player's wins and coins for good.
Saving is now blocked for the rest of the session for any player whose profile could not be
read, so their stored data is left alone.

**Writes on every autosave whether or not anything changed.** Studio logged
`DataStore request was added to queue. If request queue fills, further requests will be
dropped.` `saveProfile` now compares `DataRules.signature(profile)` against the last
successful save and skips the write when nothing changed. A failed write deliberately leaves
the signature alone so the next autosave retries. Confirmed: zero queue warnings after the
change.

## Not covered

- Two players saving at once, and two servers holding the same player. Session locking was
  added afterwards in P1-02; see H-02 below.
- Autosave on the 120 second timer was not waited out; save on leave and on close were the
  paths exercised. P1-02 handed autosaving to ProfileStore, so that timer is gone.
- Real DataStore throttling under load.

## H-02 Session locking (P1-02), Studio rows run 2026-10-12

ProfileStore now holds each profile on one server at a time. Rows 1 to 6 can be run in
Studio. **Rows 7 to 9 cannot**: they need two servers holding the same profile, and Studio
only ever runs one. Run those on the published place with two real servers, by joining on
one device, leaving and rejoining fast, or by joining the same place from two devices while
Roblox has you on different servers.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | Join with API Services on | `[Data] Loaded <name>: N wins, N coins (live)` | **Pass**, `[Data] Loaded luxygee: 0 wins, 25 coins (live)` with `[profilestore]: Roblox API services available` |
| 2 | Win a match, then leave and rejoin | Wins and coins come back, same as H-01 | Not run. Needs a match played to a win, which needs the solo flag and a walking actor. H-01 row 3 already covers it under P1-01 |
| 3 | API Services off, join | `[Data] DataStore did not answer; running in memory with saving off`, then `(cache)`. Game plays. Nobody is kicked. | **Pass**, both warnings after 3 retries, `(cache)`, player stayed connected, menu and panels all worked |
| 4 | API Services off, win a match, rejoin | Rewards show in the session but are gone after rejoin, and stored data is untouched | Not run, same reason as row 2. Row 5 covers the part that matters, that stored data is untouched after an offline session |
| 5 | API Services back on | `(live)` again, and the data from row 2 is intact | **Pass**, `(live)` with 25 coins and the streak intact. The blank cache profile was not written over the stored one, which is the H-01 guarantee holding |
| 6 | `ServerPackages/` deleted, join | Warns that ProfileStore is not installed, runs in `(cache)`, no crash | **Pass**, `WARN [Data] ProfileStore is not installed (run `wally install`); saving is off` then `(cache)`. No errors, nobody kicked |
| 7 | Leave and rejoin within a second or two | Loads normally. The old server hands the lock over rather than both saving. | |
| 8 | Same account on two servers at once | The second join is kicked with "Your saved data is still in use on another server", or the first is kicked with "...was opened on another server". Either is correct; note which. | |
| 9 | Earn coins on server A, then get taken over by server B | No progress is lost or doubled. Check the totals after both servers are empty. | |

Not covered even by the above: real DataStore throttling under load, and what happens when
ProfileStore's own retries outlast the 30 second session timeout in `Config.Data.Session`.

## H-05 Soak test, part done

**Headless half, done 2026-10-11.** `tests/Soak.spec.luau` drives MatchFlow through full
matches with a 500 transition cap, so a state that loops or sticks fails the test instead of
hanging it. 12 tests: a single match to the lobby, a match where nobody is ever eliminated
(which is the match that would never end without the round cap, and it ends at round 8), a
match where everyone falls as fast as the rules allow, every participant leaving mid-match,
ten matches back to back with the player count varying from 2 to 8, identical matches staying
identical so nothing accumulates, and the reset audit over ten matches including a two parts
per match leak. All pass, 330 tests in total.

Traces were checked by hand rather than trusted: 4 players losing one per round gives 3
rounds, 1 survivor, Victory, Reset, Lobby in 17 transitions; nobody eliminated runs to the
round cap at 8 and ends with 4 sharing the win in 37.

**Live half, to run.** The headless test cannot see leaked Instances or client memory, which
are the things a soak is really for. Paste `qa/snippets/soak.server.luau` into the server
command bar, let 5 or more matches play, then run `_G.soakdump()` and paste the table in.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | 5 or more matches without restarting the server | Every row of `_G.soakdump()` says clean, `problems: 0` | |
| 2 | Part count drift | The drift column stays at 0 for every match | |
| 3 | Memory drift | Memory comes back to near the baseline, with no climb across matches | |
| 4 | Server log | No `[Reset] Problems`, no red errors from game scripts | |
| 5 | Client log after the run | No repeated asset or HUD load failures building up | |
| 6 | The lobby after the last match | Everyone back on a lobby pad, no leftover tiles visible | |

Not covered: a soak with more than 2 clients, which needs H-04 and real players, and a soak
long enough to cross ProfileStore's own autosave interval.

### H-05 live rows: still to run, but the way in is known

2026-10-11. The live rows were not run. Recording how to reach Studio, so the next attempt
does not spend the time this one did working it out.

- The Studio MCP proxy is `StudioMCP.exe`, launched by `%LOCALAPPDATA%\Roblox\mcp.bat`. It
  answers plain JSON-RPC on stdio, so it can be driven without the harness loading
  `.mcp.json`, which only happens when a session starts.
- **The proxy process has to stay alive.** Studio registers with whichever proxy is listening,
  and that takes a few seconds. A proxy spawned per call reports `{"studios":[]}` every time
  and looks like a broken bridge. Hold one process open, wait about 10 seconds, then call.
- Studio also has to have been started after `Enable Studio as MCP server` was turned on, under
  Assistant, Manage MCP Servers. Toggling it does not attach an already running instance.
- Once attached, `list_roblox_studios` returns a studio id that every other tool needs. The
  useful tools for the soak are `execute_luau`, `get_console_output`, `start_stop_play` and
  `get_studio_state`.
- Driving Play from the MCP gives a solo session, so a soak run that way needs
  `Config.Match.studioSinglePlayerEnabled` set locally, and it will not exercise elimination
  with several survivors. Leaked tiles are likeliest there, so a 2 client pass is still worth
  doing by hand.
- At the time of this attempt the bridge worked and `get_studio_state` answered
  `Place is not open`, so the place has to be open in the attached instance as well. Studio
  being up and synced by Rojo is not enough on its own.

### H-02 notes from the run

**The session lock is real and visible.** Reading the stored profile directly showed
ProfileStore's own `MetaData.ActiveSession` holding a place id and a JobId, next to
`SessionLoadCount`. That is the lock this task added, written to the DataStore. It does not
prove the handover between two servers, which is rows 7 to 9, but it is more than the code
compiling.

**Everything degrades honestly.** With the store unreachable the leaderboard panel said
"Leaderboard unavailable" rather than "No winners yet", which is the distinction
`LeaderboardRules.statusMessage` exists for, and the settings panel fell back to 100% rather
than showing a stale saved value.

**One thing worth knowing about cache mode.** With saving off, the daily panel offers a claim
again, because the cached profile has no claim recorded. Claiming in that state pays coins
that are never saved. It is not a duplication risk, since nothing is written, but a player in
a server that lost its DataStore would see a reward appear and then vanish on rejoin.

**One unexplained reading.** Midway through, the stored `musicPercent` was 60 when the last
deliberate change had been 80. No code path writes a value nobody asked for, and a
deterministic retest passed: 60 stepped to 80 through the UI, stored as 80, and came back as
80 after a full restart. The likeliest cause is one of my own test clicks landing on the
stepper while the panel was open, but that is a guess, so it is written down rather than
dismissed. Worth a second look if anyone sees a volume change they did not make.
