# A-10 background UI art: what to make

A spec for the stretchable background art, so the pieces can be drawn once and wired up
without guessing. Everything here is a **background**: a shape that other things are drawn on
top of. The icons and one-off pictures already uploaded (coin, dust puff, calendar, the three
badges) are fine and are not in this list.

Read "The two rules" first. They are the whole reason this document exists.

## The two rules

### 1. Nothing may be larger than 1024 pixels on its long edge

Roblox resizes an upload to fit 1024 on its long edge, and it does not tell you. `panel.png`
went up at 1264 square and came back 1024 square. The buttons lost about a third of their
width.

This matters because a 9-slice is described by a rectangle **in the uploaded image's pixels**.
Measure the artwork at 1264 and the rectangle lands off the end of a 1024 image, the right and
bottom slices collapse, and the top left corner stretches over the whole panel. That is the
bug you spotted in the leaderboard and settings panels.

Draw at the exact canvas sizes below and the number on your canvas is the number in the code.
Nothing has to be measured or converted.

### 2. The artwork must touch all four edges of the canvas

No drop shadow, no glow, no transparent margin outside the shape. The game sizes a panel and
then draws the title, the rows and the buttons inside that same rectangle. If the visible art
sits inset from the canvas edge, everything the game draws at the edge of the panel falls
outside the picture. That is why the leaderboard's score column currently sits just off the
right edge of the blue panel.

If a piece wants a shadow, it has to be inside the canvas, in the corner region.

## How a 9-slice works, in one paragraph

The picture is cut into nine pieces by a rectangle. The four corners are never stretched. The
top and bottom edges stretch sideways, the left and right edges stretch up and down, and the
middle stretches both ways. So the art needs **corners that carry all the shape and detail**,
and a **middle that is flat enough to stretch without smearing**. A gradient across the middle
is fine. A highlight, a sparkle or a texture in the middle is not: it will smear into a streak
when the panel is wide.

## The pieces

| # | File | Canvas | Shape | Slice rect the code will use |
| --- | --- | --- | --- | --- |
| 1 | `panel-dialog.png` | 512 x 512 | rounded square, 64 px corner radius | 64, 64, 448, 448 |
| 2 | `panel-badge.png` | 256 x 128 | rounded rect, 24 px corner radius | 24, 24, 232, 104 |
| 3 | `button-confirm.png` | 512 x 160 | pill, fully round ends | 80, 0, 432, 160 |
| 4 | `button-neutral.png` | 512 x 160 | pill, fully round ends | 80, 0, 432, 160 |
| 5 | `button-danger.png` | 512 x 160 | pill, fully round ends | 80, 0, 432, 160 |
| 6 | `button-small.png` | 160 x 160 | rounded square, 40 px corner radius | 40, 40, 120, 120 |
| 7 | `banner-ribbon.png` | 1024 x 320 | ribbon with tails, 220 px each | 220, 0, 804, 320 |

PNG with an alpha channel, sRGB, no colour profile.

---

### 1. `panel-dialog.png`, 512 x 512

The background behind every dialog: Top Winners, Settings, Daily Rewards, the results panel,
How to play, the eliminated card and the lobby panel.

**Draw it white or light grey, not blue.** The game tints it with each panel's own colour, so
whatever colour is painted here gets multiplied by that and comes out muddy. All the shading
has to be in light and dark, not in hue. Think of it as the panel lit from above: a soft
top-to-bottom sheen, a slightly brighter inner rim a few pixels in from the edge, and a
slightly darker outer line.

- Corner radius exactly 64 px, touching all four canvas edges.
- The centre 384 x 384 must be flat or a plain vertical gradient, and nothing else. No
  sparkles in the middle: they will smear.
- Any sparkle or bevel detail goes in the 64 px corners, where it is safe.

It renders between about 375 x 238 and 500 x 320 on a desktop window, smaller on a phone.

### 2. `panel-badge.png`, 256 x 128

The background behind the small HUD chips: the round badge, players left, the coin counter,
the target card and the timer bar.

Same white or light grey treatment as the dialog panel, and the same reason: it is tinted in
code. It is a separate piece from the dialog panel because these are much smaller and much
flatter, and the dialog's 64 px corners would swallow them whole.

- Corner radius exactly 24 px, touching all four canvas edges.
- The flattest thing that uses it is the timer bar at roughly 336 x 45, so keep the detail
  shallow and the middle plain.
- The smallest is the players badge at roughly 72 x 66.

### 3, 4, 5. The three buttons, 512 x 160 each

Pills, sliced across the width only, so the round ends stay whole and only the flat middle
between them stretches.

**These keep their own colour.** They are not tinted, so paint them as they should look:

- `button-confirm.png` green. Claim, and both Spectate buttons.
- `button-neutral.png` blue. Close, Stop, Back, the volume steppers.
- `button-danger.png` red. Nothing uses it yet, so it is the lowest priority of the three.
  Leave already has its own art from A-09. Worth having for the first destructive button
  that comes along, but skip it if you are short of time.

- The round ends occupy the leftmost and rightmost 80 px. Make them properly semicircular:
  radius 80 on a 160 tall canvas.
- The middle 352 px must be a flat colour or a plain vertical gradient. A gloss band running
  horizontally is fine. A gloss *blob* is not.
- Touch all four canvas edges: top, bottom and both ends.

A button renders between about 145 x 48 and 260 x 64.

### 6. `button-small.png`, 160 x 160

The volume steppers in Settings are nearly square, about 50 x 48, and a long pill squashed to
that size reads badly. This is the same blue as the neutral button but as a rounded square.

- Corner radius 40 px, touching all four canvas edges.
- Blue, matching `button-neutral.png`, and not tinted in code.

Only four things in the game use it, so this is a nice-to-have rather than a blocker.

### 7. `banner-ribbon.png`, 1024 x 320

The ribbon behind the centre banner: "Round 3", "Final round!", "Everyone fell!".

- The tails are the leftmost and rightmost 220 px and hold all the shape: the notch, the fold,
  the darker underside.
- The middle 584 px is the flat band the title sits on. Keep it plain.
- Touch all four canvas edges.
- Keep it at exactly 1024 wide. That is the ceiling, so it will upload untouched.

It renders at roughly 368 x 132, with the title and a subtitle drawn inside it, so the flat
middle has to be tall enough to hold two lines of text.

## When you have them

Upload all of them under the game owner's account, the same one that owns the other assets,
and send me the IDs with the filenames. Roblox has to serve them as asset type 1, Image, so
use the Image ID and not the Decal ID.

I will put the IDs and the slice rects above into `Config.Art`, point `makePanel` at the badge
piece for the HUD chips and the dialog piece for everything else, and check each one on screen
at both ends of its size range.

Worth saying plainly: the art currently in the game **does work** now. The slice rects have
been corrected to the uploaded sizes and the corners scale themselves to each panel, so
nothing is broken while these are drawn. This set would replace a workaround with art that is
right by construction, and it fixes the two things the current pieces cannot: the dialog
corners are too big for the small HUD chips, and the outer shadow pushes content off the
visible panel.
