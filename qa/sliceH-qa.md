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

- Two players saving at once, and two servers holding the same player (no session locking yet;
  the spec calls for a session-locking library in slice 5).
- Autosave on the 120 second timer was not waited out; save on leave and on close were the
  paths exercised.
- Real DataStore throttling under load.
