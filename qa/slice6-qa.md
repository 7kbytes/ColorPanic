# Slice 6 QA record

Studio QA by Claude Code, through the Roblox Studio MCP.

## A-09 Feel pass, 2026-10-12

Run in Color Panic [BETA] (placeId 95448694004978) with Rojo syncing `slice6/A-09-feel-pass`,
Play mode, one client. Nothing was published.

The three effects are render-side, so they were driven directly rather than through a full
match: a single Studio client cannot reach Victory, and what needed proving was the behaviour
of the helpers, not the match flow that calls them.

### Panel motion (UiStyle.setShown and isShown)

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 1 | Show a hidden panel | Visible, scale starts at panelPopStartScale | Pass, scale 0.88 |
| 2 | After panelPopSeconds | Scale settles at 1 | Pass |
| 3 | Call setShown(true) five more times | Nothing re-animates | Pass, scale stayed 1 |
| 4 | Hide it | Still Visible while the tween runs, isShown false | Pass |
| 5 | After panelHideSeconds | Visible false, scale reset to 1 | Pass |
| 6 | Show it again | Pops in cleanly from 0.88 | Pass |

Row 3 is the one that matters: the HUD calls this every Heartbeat.

### Target tile glow (TileGlow)

Arena built with colors 1, 2, and 3: 36 tiles, 12 of each.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 7 | Target 2, no reveal limit | The 12 colour 2 tiles glow at full strength | Pass, fill 0.70, outline 0.10 |
| 8 | The other 24 tiles | No Highlight created at all | Pass |
| 9 | Halfway through a reveal fade | Glow part faded | Pass, fill 0.85, outline 0.55 |
| 10 | Target hidden (colorId nil) | Nothing glows | Pass, 12 Highlights at transparency 1 |
| 11 | ArenaService.cleanup() | Tiles and their Highlights both gone | Pass, 0 tiles, 0 Highlights in the workspace |

### Win celebration (WinFx)

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 12 | celebrate() | Confetti emitter over the character, camera punches in | Pass, FOV 70 to 63.5, rate running |
| 13 | After fovBackSeconds | FOV back to the value it found | Pass, 70 |
| 14 | celebrate() again mid celebration | Does nothing, no second emitter | Pass |
| 15 | After the emit plus the longest lifetime | Attachment and emitter destroyed | Pass, 0 emitters left |

### Console

No errors or warnings for the whole session. The tiles built for rows 7 to 11 were cleaned up
and play was stopped.

### What this did not cover

- **A real match.** Nothing here saw the HUD drive these effects through RoundIntro, Run,
  Elimination and Victory with the server in charge. That needs two clients at least.
- **A phone.** The button press shrink uses MouseButton1Down and Up, which Roblox fires for
  taps too, but that is taken on trust until H-03.
- **Whether the glow is too generous.** A functional check cannot answer that; it needs
  someone playing rounds 1 to 3.

### Found while testing

The game already drops screen confetti for everyone at Victory (`LookController`, D-07),
which the A-09 plan missed. WinFx now uses the same confetti art and half the particle rate,
so the two read as one effect rather than competing. Whether both should stay is a producer
call: see the pull request.
