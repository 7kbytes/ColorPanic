# Color Panic: work report for review

Written by Claude Code (the developer agent) for the producer, to send for an independent review. It covers everything done in this working session: what was built, how it was tested, the decisions taken, the problems found, and what is still open or uncertain.

## 1. Context

- **Project:** Color Panic, a round-based Roblox party game for kids. Players race to the tile matching a target color and shape; the other tiles drop; the last one standing wins.
- **Repository:** `7kbytes/ColorPanic` (GitHub). Built with Rojo.
- **Toolchain:** Luau `--!strict`, StyLua, Selene, a luau-lsp type check and Lune unit tests, all pinned with Rokit.
- **Roles:** the producer (the user) approves every task. The developer proposes a plan first, then builds on one branch with one pull request per task.
- **Working rules (from `CLAUDE.md`):**
  - Every tunable value goes in `shared/Config`; remotes are declared only in `shared/Remotes`.
  - The server decides every outcome.
  - Do not invent Roblox APIs; check the official docs.
  - No em dashes.
  - Run StyLua, Selene, the type check and the tests before every pull request.
- **Merging:** the producer reviews and merges by default, but asked me to merge from the D-05 batch onwards. I merged each pull request only after the producer said yes.
- **Schedule:** a 3-day demo plan (tasks D-01 to D-16, then D-10 as a stretch), with a feature freeze at midday on day 3.

## 2. Final state

- **`main`:** commit `85b4ba3`. All pull requests are merged or closed, and no other branches exist (local or remote).
- **Tests:** **265 Lune tests pass**. The strict type check passes. Selene reports 0 errors and 0 warnings on `src` and `tests`.
- **Issues:** #14 and #17 are fixed and closed. #15 and #16 are still open (see section 8).
- **Kept outside git on purpose** (in the project folder, untracked):
  - `Color Panic Asset IDs.xlsx`: the asset ID workbook
  - `Color Panic upload ready/` and its `.zip`: processed assets and `upload-results.json`
  - `Color Panic game page/`: icon, thumbnails and page text

## 3. Pull requests, in order

The slice 1 work (#1 to #18) was done before this session's summary point. It is listed for completeness.

| PR | Task | Result |
| --- | --- | --- |
| #1, #2, #11, #12, #18 | Slice 1: tooling, Config and Types, status docs, placeholder HUD, QA pass | Merged |
| #3 to #10, #13 | Slice 1 stacked tasks (remotes, match service, arena, round director, placement, elimination, victory and reset, typecheck tooling, client double-run fix) | Closed; their commits landed through later stacked PRs |
| #19 | D-01 Respawn and late-join placement (fixed #14) | Merged |
| #20 | D-02 Final palette in Config, plus a test that no color or shape appears outside Config | Merged |
| #21 | D-03 Elimination decision log; QA actor made to walk (cause of #15) | Merged |
| #22 | D-04 Demo preset (`ACTIVE_PRESET`) with a round cap of 8 | Merged |
| #23 | D-16 Menu overlay and join queue (Play and Leave requests, `MatchRole` attribute) | Merged |
| #24 | D-05 Reveal-then-hide targets | Merged |
| #25 | D-06 HUD with real assets; fixed #17 | Merged |
| #26 | D-03b Shape art on tiles and the target card | Merged |
| #27 | D-12 Round intro and intermission banners | Merged |
| #28 | D-13 Lobby panel and the Leave button art | Merged |
| #29 | D-14 Eliminated card and watch-only spectating | Merged |
| #30 | D-15 Match results panel | Merged |
| #31 | D-08 Sound effects and music | Merged |
| #32 | D-07 Arena look | Merged |
| #33 | D-09 Title screen in the concept layout, color and shape naming, blue panels | Merged |
| #34 | D-09b Concept polish (lobby, spectator, eliminated, winner) | Merged |
| #35, #37 | D-11 QA checklist (`qa/demo-qa.md`), then the D-10 checks added to it | Merged |
| #36 | D-10 Shrinking tiles (stretch) | Merged early on the producer's call |
| #38 | README for the demo build | Merged |

## 4. Assets work (outside the code)

1. **Asset list:** listed every asset the code would load by ID and produced an Excel workbook, `Color Panic Asset IDs.xlsx` (Node exceljs 4.4.0, in the scratchpad), with fill-in columns, validation and a summary sheet.
2. **Verifying the producer's deliveries** (UI images, sounds, game page art). Checks covered size, transparency, fringes, levels, silence, clipping and loop seams. Findings:
   - The triangle and circle silhouettes were partly transparent.
   - The UI buttons were full colored buttons with text, not the white icons specified.
   - The two music loops clicked at the loop point.
   - The game page art showed things the game does not have (a shop, a castle, a podium, green tiles) and a heart on a pink tile, which contradicts the palette.
3. **Fixes, with the producer's approval:**
   - crossfaded the music loops (the seam jump dropped from 0.29 to 0.002)
   - made the triangle and circle bodies fully opaque
   - cut out the Play button's white background
   - resized everything to spec

   Tool: the image library sharp 0.33.5 (pinned, in the scratchpad only).
4. **Upload:** 33 assets went up through the Roblox Open Cloud Assets API under the producer's account (user 2042571185). All passed moderation, and the script filled their IDs into the workbook.
   - **The API key:** the producer first pasted it into chat. I refused to use it, asked for it to be regenerated, and had the producer save the new key to a local file. The script read that file and never printed the key.
   - **Decal vs Image IDs:** image uploads return Decal IDs, which UI elements cannot display, so the script resolved each Decal to its underlying Image ID.
5. **Game page draft (D-17, not on the original plan):**
   - a 1024×1024 icon composed from the logo and real tile art
   - four 1920×1080 thumbnails from real Studio captures, each with the logo and a short caption
   - page text with suggested settings

   The producer's AI-generated art was not used, because it misrepresents the game.

## 5. What each demo task does (short)

- **D-01 Placement:** a character is placed only once it is in the workspace and has a root part (a timeout covers failure), with a lobby SpawnLocation fallback. A `MatchRole` attribute mirrors each player's role.
- **D-02 Palette:**
  - the six colors, each with one shape (Red heart, Orange triangle, Yellow star, Blue circle, Purple square, Pink diamond), copied from `art/palette.json`, with a test keeping the two in step
  - a scan test that fails if a color or shape name appears outside Config
- **D-03 Decision log:** one log line per survivor per round, with the reason they were judged safe or out.
- **D-04 Demo preset:** presets override Config, with strict checks on keys and types. The demo preset uses a 5 s intermission, a cap of 8 rounds and its own difficulty table.
- **D-16 Menu and queue:**
  - players start in the menu with an orbiting camera
  - only players who pressed Play count toward a match
  - the server validates Play and Leave, with a cooldown
- **D-05 Reveal-then-hide:** from round 3 in the demo, the target shows for 2 s at the start of Run, then hides. Each client times the reveal from when the message arrives, so it always lasts at least 2 s.
- **D-06 HUD:**
  - round badge, target card, players left, a timer bar with a 3 s red pulse
  - text fallbacks if an image fails
  - the server now sends round data before the state change (a pure `Broadcast` module with tests), which fixed #17
- **D-03b Tile shapes:** each tile carries a Decal with its color-and-shape art, and the target card uses the same art. A greyscale check showed the shapes stay distinguishable without color.
- **D-12 Banners:** "Match starting" with a countdown, the round intro, "Final round!", and "Everyone fell!" for a replay. The banner pops in and fades out.
- **D-13 Lobby panel:** players ready and players still needed, from a new `LobbyInfo` remote. Leave uses the Back button art.
- **D-14 Eliminated and spectate:** an eliminated card; spectating points the local camera at a survivor (previous, next, stop). Spectating is client-only, and nothing about it reaches the server.
- **D-15 Results:** places with shared ranks, rounds survived, players who left marked "left", and the local player's row highlighted. Covers this match only; nothing is saved.
- **D-08 Audio:** 11 sounds played from cues the server already sends, with a music crossfade between lobby and match. Every sound is preloaded at client start; without that, each sound loaded only on its first play.
- **D-07 Look:**
  - glossy tiles with a darker base, client-side lighting, atmosphere, bloom and color correction
  - a lollipop prop ring around the arena
  - confetti at Victory
- **D-09 and D-09b:** these follow the concept board the producer shared.
  - **D-09:** the title screen layout; targets named by color and shape ("Red Heart"); blue panels with a white outline.
  - **D-09b:** the lobby panel at the top centre, "Spectator mode", an "Eliminated!" ribbon and a gold "Winner!" title.
- **D-10 Shrinking tiles:** from round 4 in the demo, tiles shrink 8% per round down to 60%, leaving gaps between them. Tile centres stay fixed, and elimination measures each tile's real size.
- **D-11:** `qa/demo-qa.md`, a 40-check checklist for a published private copy with 4 or more real players.

## 6. How it was tested

- **Unit tests:** pure modules were tested with Lune (265 tests at the end), mainly the game rules (`MatchFlow`, `RoundDirector`, `EliminationRules`, `MatchResults`, `QueueRules`, `Broadcast`) and every UI view model.
- **Every pull request:** StyLua, Selene and the strict type check were run before opening it.
- **Studio QA for every task:** Test with Server and Clients, 2 clients (8 local clients crash the machine).
  - Studio was driven by screenshots and clicks, because the Roblox Studio connection for scripts dropped early on.
  - Scratch builds with changed Config values made rare situations appear quickly: a round cap of 1, a longer Victory, a reveal in round 1, shrinking from round 1, and cue logging. None of these changes were committed, and `git status` confirmed Config was restored each time.
- **Measurements:**
  - pixel hue sampling of lit tiles, compared with the palette
  - greyscale checks for color-blind readability
  - reading Studio log files to confirm image and sound loads and the timing of each sound cue

## 7. Problems found and fixed during QA

| Task | Problem | Fix |
| --- | --- | --- |
| D-06 | Corner badges hidden under Roblox's player list and chat | Moved the badges beside the target card |
| D-03b | Preloading by bare asset ID wrongly reported working icons as failed | Preload the ImageLabel instead |
| D-12 | A CanvasGroup fade left the banner text visible | Fade the panel, text and outline directly |
| D-08 | Sounds only loaded on first play, so first cues were late | Preload every sound at client start |
| D-07 | Strong lighting shifted hues (Orange toward Yellow, Blue toward cyan) | Lighting kept near Roblox defaults. Sampled hues are now within about 6° of the palette, and Orange (28° to 30°) and Yellow (56°) stay clearly apart |
| D-09 | The Orange and Yellow labels touched | Narrowed the labels |

## 8. Open items, risks and uncertainties

1. **D-11 has not been run.** Nothing has been tested with more than 2 players or on a real phone.
2. **Not yet seen in Studio, covered only by unit tests:**
   - switching survivors with the arrows (needs 3 or more players)
   - the "left" row in results
   - the red "Eliminated!" ribbon
   - the reveal chime and the eliminated sound in a real match
   - rounds 4 to 8 at their real shrink sizes
   - "Everyone fell!" in a real replay
3. **Difficulty and look values are drafts:** timers, shrink rate, volumes and lighting all need tuning in playtests.
4. **Issue #15** (a survivor judged out while on a target tile) is still open. It was traced to the old QA actor's client-side teleport and has not been seen since. The decision log is in place to catch it.
5. **Issue #16** (no 8-player test) is still open and needs real players.
6. **Asset ownership:** all assets belong to the producer's personal account. Publishing under a group would silence the audio until permissions are granted.
7. **Open Cloud keys:** the producer should revoke the key that was pasted in chat and delete the local key file. I could not confirm that this has been done.
8. **Thumbnails** were taken from a capture build with a round cap of 2, so they show "Round 1/2" where the real game shows "Round 1/8". They should be recaptured from the published copy. They are also slightly soft (upscaled about 1.6×).
9. **Docs I could not fully confirm:**
   - how Roblox currently grants testers access to a private experience
   - whether `Lighting.Technology` can be set by script (the docs mark it deprecated, so I left it alone)
   - Roblox's current list of genres

   I flagged these to the producer instead of guessing.
10. **Process notes for the reviewer:**
    - D-10 was merged before the D-11 fixes, on the producer's explicit instruction, reversing the earlier plan.
    - One commit message (D-12) was amended before its pull request was opened, to correct a test count.
    - All the remote and local branches were deleted after checking that their work is in `main`. Five local branches were stale pre-restack copies, and I diffed them before deleting.
11. **Out of scope for the demo:**
    - shove, spectator pranks, saved data, custom chat, monetization
    - Settings and Shop beyond "Coming soon" tiles
    - the concept board's color and shape pairs (the producer chose to keep `art/palette.json`)

## 9. Suggested review questions

- Is the server-authority boundary sound? Clients send only Play and Leave; check `MatchService`, `QueueRules` and `shared/Remotes`.
- Are the pure-module tests testing the right things, and what important behaviour is untested because it lives in controllers or services?
- Are there race conditions in the remote ordering (`Broadcast`) or in character placement (`PlacementService`) that Studio QA with 2 clients would not reveal?
- Is the demo difficulty curve (`Config` demo preset plus `Shrink`) reasonable for kids?
- Does anything in the UI or game page misrepresent the game under Roblox's rules?
