# Slice 6 QA record

Studio QA, run through the Roblox Studio MCP.

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

### Two-client match run, 2026-10-12

Studio Test, Server and Clients, two clients, driven through the desktop. Both clients
pressed Play from the menu. **Six matches ran back to back** before the session was ended.

| # | Check | Expected | Result |
| --- | --- | --- | --- |
| 16 | Two clients join | Both reach the menu, both show in the lobby board | Pass, Player1 and Player2 |
| 17 | First Play | Lobby panel pops in, "1 player ready, waiting for 1 more" | Pass |
| 18 | Second Play | Match starts, round banner and target card appear | Pass, "Round 1, Find the Yellow Star" |
| 19 | Glow in a live round | Only the target colour's tiles glow, at the configured strength | Pass, 12 tiles, fill 0.70, outline 0.10, colour id matched the card |
| 20 | Results panel at Victory | Pops in rather than snapping | Pass, scale 0.96 at the first frame, 1 by 0.15s |
| 21 | Win celebration, winner | Confetti emitter runs, camera punches and returns | Pass, rate 45, FOV 66.6 then 64.5 then back to 70 |
| 22 | Confetti art | Uses the uploaded confetti image, not the default particle | Pass, `rbxassetid://96276252812980` |
| 23 | Win celebration, loser | No confetti on the eliminated player | Pass, no attachment on Player2 when Player1 won |
| 24 | Reset audit, six matches | Clean every time | Pass, six `[Reset] Clean: 0 tiles, 172 parts, everyone in the lobby` |
| 25 | Server log | No errors or warnings | Pass, 0 of 137 lines |

### Found while testing

**Both confetti effects fire together on the winner's screen.** Measured at the moment of a
win: 36 screen confetti pieces from `LookController` and the world emitter at rate 45, at the
same time. It is not broken, but it is two effects doing a similar job. Producer call.

**The eliminated card and the results panel show at the same time.** On the losing client the
spectator card ("Spectator mode, Watch the remaining players, Spectate") was still on the
left while the results panel covered the middle of the screen. This is not from A-09: the
card's visibility condition is unchanged, only the way it appears. It looks cluttered and is
worth its own small task.
