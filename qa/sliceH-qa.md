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

## H-02 Session locking (P1-02), to run

ProfileStore now holds each profile on one server at a time. Rows 1 to 6 can be run in
Studio. **Rows 7 to 9 cannot**: they need two servers holding the same profile, and Studio
only ever runs one. Run those on the published place with two real servers, by joining on
one device, leaving and rejoining fast, or by joining the same place from two devices while
Roblox has you on different servers.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | Join with API Services on | `[Data] Loaded <name>: N wins, N coins (live)` | |
| 2 | Win a match, then leave and rejoin | Wins and coins come back, same as H-01 | |
| 3 | API Services off, join | `[Data] DataStore did not answer; running in memory with saving off`, then `(cache)`. Game plays. Nobody is kicked. | |
| 4 | API Services off, win a match, rejoin | Rewards show in the session but are gone after rejoin, and stored data is untouched | |
| 5 | API Services back on | `(live)` again, and the data from row 2 is intact | |
| 6 | `ServerPackages/` deleted, join | Warns that ProfileStore is not installed, runs in `(cache)`, no crash | |
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
