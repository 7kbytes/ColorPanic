# Slice H tasks: harden to playable

**Status: proposed, not yet approved.** The ordering and the cut line are the
producer's call. Nothing below is started except where it says so.

Goal: take a build that demonstrates well and make it survive real players. Slice H adds no
features. Every task either proves something works, or fixes what proving it turned up.

Out of scope for slice H, so it does not quietly grow: shove and moving tiles (slice 3),
spectator pranks (slice 4), lobby polish and the shop (slice 5), the art pass and difficulty
tuning (slice 6). If a playtest says the game is not fun, that is slice 6 work, not this.

Branches `sliceH/<task-id>-<short-name>`. QA records go in `qa/sliceH-qa.md`, one section per
task. Working rules: see `SPEC.md`, section 7.

## Why this slice exists

Nearly everything in the build has been verified by one person in Studio with at most two
clients. The things that break games at launch, which are load, real devices, and real
players leaving at awkward moments, are exactly the things that have never been tested. Slice
H is about closing that gap before any more features go in.

## Tasks, in order

1. **H-01 Verify persistence.** Done, merged as #51. Studio QA of P1-01, plus the two bugs it
   exposed: a failed read could be saved over real stored data, and the autosave wrote whether
   or not anything had changed. Record in `qa/sliceH-qa.md`.
2. **H-02 Verify session locking.** The code is #52. Rows 1 to 6 of the H-02 table can be run
   in Studio; rows 7 to 9 need two servers on a published place and only the producer can run
   them. Done when rows 7 to 9 are filled in and any Fail is fixed. **Blocked on a publish.**
3. **H-03 Device pass on a real phone.** The largest open risk: nothing has ever run on a
   phone. The producer plays a full match on the lowest-end phone available while the client
   log is captured, and reports frame rate, join time, and anything unreadable or untappable.
   Done when a full match completes on a real phone at a frame rate the producer accepts, or
   the problems are written up as their own tasks. **Needs a device, so the producer runs it;
   I fix what it finds.**
4. **H-04 Eight or more players.** Closes #16. Cannot be faked: Roblox has no way to add
   synthetic players, and the test machine runs out of memory past two Studio clients, so this
   needs real people on a published copy. Watch the fairness rule (at least one target tile
   per two survivors), tile crowding, and the results panel with many rows. Done when a match
   with 8 or more players runs to a winner with no stuck states and no server errors.
   **Needs real players.**
5. **H-05 Soak test.** Five or more matches back to back without a server restart, watching
   for `[Reset] Problems` in the server log, leaked parts, and client memory growth across
   matches. Done when the reset audit is clean every time and nothing grows without bound.
   I can run this solo in Studio with `Config.Match.studioSinglePlayerEnabled` set locally
   and never committed.
6. **H-06 Mid-match churn.** Players joining, leaving and rejoining at the awkward moments:
   during the starting countdown, between elimination and reset, while being spectated, and as
   the last survivor. Each case gets an automated test where the logic is pure, and a QA row
   where it is not. Done when every case has a known, deliberate outcome rather than whatever
   happens to occur.
7. **H-07 Close #15.** The cause was traced in D-03 to the QA actor not walking, but the issue
   is still open on the strength of a single sighting. Run the elimination path enough times
   with walking actors to say it is gone, or reproduce it. Done when #15 is closed with
   evidence, or reopened as a real bug with a failing test.
8. **H-08 Triage the playtest.** Depends on D-11 and H-03 and H-04 being run. Take the Fail
   rows, sort them into fix-now, fix-later and will-not-fix, and open one task per fix-now.
   Done when every Fail row has a decision recorded against it.

## Done when

Slice H is complete when H-01 to H-08 are merged, `qa/demo-qa.md` and `qa/sliceH-qa.md` are
filled in rather than blank, and the producer has watched 8 or more real players finish a
match on a published copy without a stuck state.

## What I cannot do myself

Worth stating plainly, because four of these eight tasks are gated on it: H-02, H-03 and H-04
need either a published place, a physical phone, or real players, and H-08 needs their
results. I can write the checklists, run everything Studio can reach, and fix what comes
back, but I cannot sign off on the parts that need other people. The honest state today is
that the build is demonstrated, not tested.
