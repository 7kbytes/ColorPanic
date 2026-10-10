# Demo QA checklist (D-11)

QA for the 3-day demo build on a **published private copy**, with **4 or more real players**. Do not run 8 local Studio clients (the machine runs out of memory). Fill in the Result column (Pass, Fail or Skip) and add notes or screenshots. Then send the file back and I will fix what fails before the freeze.

- **Build:** `main` at the commit you publish, `56e3f9f` or later so it includes D-10 (write it here): `________`
- **Date:** `________`
- **Testers and devices:** `________`

## 1. Setup

1. Build the place from `main`:

   ```bash
   rojo build default.project.json -o ColorPanic_demo.rbxl
   ```

2. Open `ColorPanic_demo.rbxl` in Studio and publish it as a **new, private** experience under **your own account (2042571185)**.
   - The sounds and images are owned by that account, so publishing under a group or another account would leave the audio silent until you grant it access.
3. Give the testers access. Keep the experience private and use Roblox's current access options for testers, for example adding them as collaborators. Check the Creator Dashboard for what your account offers.
4. Devices: at least **4 players**, including **one phone** (the Galaxy A06 if possible) and one desktop. More players make the spectating and results checks better.
5. Each tester opens the Developer Console (F9 on desktop, or the in-game menu on a phone) when asked below. The **Server** tab shows the server log for the owner.

## 2. Checklist

### Title screen (D-09, D-16)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 1 | Join the game | Title screen: logo top left, green PLAY, greyed Settings and Shop marked "Coming soon", how-to card with 6 color and shape tiles. Camera circles the arena. Lobby music plays. | | |
| 2 | Press Settings and Shop | Nothing happens (not wired yet) | | |
| 3 | Press PLAY | Click sound. You spawn in the lobby. Lobby panel at the top centre with BACK under it. | | |

### Lobby and queue (D-13)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 4 | First player presses PLAY | "Lobby / 1 player ready / Waiting for 1 more" | | |
| 5 | Second player presses PLAY | Both see "2 players ready". The "Match starting 5, 4..." banner appears in the middle. | | |
| 6 | During "Match starting", one player presses BACK | That player returns to the title screen. The others' count drops. If fewer than 2 remain, the countdown stops. | | |
| 7 | Everyone presses PLAY again | Match starts after the countdown | | |

### Round flow and HUD (D-05, D-06, D-12, D-03b)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 8 | Round intro | Banner "Round 1 / Find the <Color Shape> · N seconds". Round start sound. Match music fades in. | | |
| 9 | HUD during Run | Top: "Round 1/8" with crown, target card ("Yellow Star" with its tile art), players-left badge. Bottom: timer bar with stopwatch. | | |
| 10 | Tiles | Every tile shows its shape. Each color always has the same shape. | | |
| 11 | Last 3 seconds of Run | Timer bar turns red and pulses. Three ticks, the last one higher. | | |
| 12 | Elimination | Tile drop sound. Non-target tiles fall. Players on wrong tiles fall (fall sound). | | |
| 13 | Rounds 3 and later (reveal rounds) | Intro says "Memorize the color!". The card shows "?" until Run starts, then shows the target for about 2 s (chime), then "?" again (lower chime). | | |
| 14 | Everyone falls in a round | "Everyone fell! / Round N again" banner and the round replays | | |
| 15 | Round 8 (round cap) | Intro says "Final round!" in yellow | | |

### Shrinking tiles (D-10)

Numbered 37 to 40 so the other checks keep their numbers. Rounds 4 to 8 need 2 or more players to survive the early rounds, so stand on the target on purpose.

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 37 | Rounds 1 to 3 | Tiles at full size, no gaps between them | | |
| 38 | Round 4 intro | Banner adds "Tiles are shrinking!". Tiles are a little smaller (92%) with thin gaps. Server log: `[Round] 4 tiles at 92% size`. | | |
| 39 | Rounds 5 to 8 | Tiles get smaller each round (84%, 76%, 68%, then 60% at round 8). Tile art and the darker base shrink with them. No "Tiles are shrinking!" after round 4. | | |
| 40 | Standing near a tile edge, and in a gap | Near the edge of a target tile you stay safe. In the gap between tiles you fall and are out. Note whether 60% at round 8 feels too hard. | | |

### Eliminated and spectating (D-14, D-09b)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 16 | A player is eliminated | Their card shows a sad face, a red "Eliminated!" ribbon, "You survived N rounds" and a purple Spectate button. Eliminated sound. | | |
| 17 | Press Spectate | Camera follows a survivor. Bar at the bottom reads "Watching <name>" with Stop. | | |
| 18 | With 2 or more survivors, press the arrows | Camera switches between survivors. The name updates. | | |
| 19 | Watched player is eliminated | Camera moves to another survivor on its own | | |
| 20 | Press Stop | Camera returns to your own character. A Spectate button appears under the "Spectator mode" panel. | | |
| 21 | A new player joins mid-match and presses PLAY | "Spectator mode / Watch the remaining players" panel with a Spectate button. They play in the next match. | | |

### Results (D-15, D-09b, D-07)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 22 | Match ends with one winner | Gold "Winner!" title, "<name> · Match lasted N rounds", rows best first with place and rounds survived, your row highlighted. Fanfare and confetti. | | |
| 23 | Two players out in the same round | They share a place (for example 2nd, 2nd, 4th) | | |
| 24 | A player leaves the game mid-match | They appear last as "left" in the results | | |
| 25 | Match ends with a shared win | "Shared win!", all winners 1st | | |
| 26 | After the results | Everyone returns to the lobby. The next match starts if 2 or more are queued. Lobby music returns. | | |

### Look and sound (D-07, D-08)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 27 | Orange and Yellow tiles side by side | Clearly different colors in game lighting | | |
| 28 | Prop ring | Colored lollipops around the arena, never blocking the view of the tiles | | |
| 29 | Sound volume | Music under the effects. Nothing too loud or too quiet. Note which sounds to change. | | |
| 30 | Music loop | No click or gap when the music loops (about every 60 s) | | |

### Phone (touch)

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 31 | HUD on the phone | Badges, target card and timer readable. Nothing under the thumbstick or jump button. Nothing cut off by the notch. | | |
| 32 | Buttons on the phone | PLAY, BACK, Spectate, the arrows and Stop are easy to tap | | |
| 33 | Play a full match on the phone | Movement works. The game stays smooth. | | |

### Stability

| # | Check | Expected | Result | Notes |
| --- | --- | --- | --- | --- |
| 34 | Play 3 or more matches in a row | No stuck states. Every reset returns everyone to the lobby. | | |
| 35 | Server log (Developer Console, Server tab) | `[Reset] Clean` after each match. No `[Reset] Problems`. No red errors from game scripts. | | |
| 36 | Client log (Developer Console, Client tab) | No `[Audio] ... did not load`, no `[HUD] Image ... did not load`, no `[Menu] ... did not load` | | |

## 3. Known issues to keep an eye on

- On desktop, the Roblox chat window can overlap the logo and the left edge of the lobby panel. Phones collapse the chat.
- **Not seen in Studio yet:**
  - the red "Eliminated!" ribbon
  - switching with the arrows
  - the "left" row in the results
  - the reveal chime and eliminated sound

  Checks 13, 16, 18, 24 and 25 cover them. The gold "Winner!" title, the "Spectator mode" panel and the purple Spectate button were seen in Studio during D-10 QA.
- Shrinking tiles (checks 37 to 40) were only seen in Studio at 60% in round 1. Rounds 4 to 8 at their real sizes need a real match.
- #15 (a survivor on a target tile judged out) was traced to the old QA actor and not seen since. If someone is knocked out while clearly standing on the target, copy the server log lines that start with `[Elimination]`.

## 4. How to report

- For each Fail: what you did, what happened, the device, and a screenshot if you can.
- Copy any red error lines from the Developer Console, Server and Client tabs.
- Send this file back, or just paste the Fail rows. I will fix them in order of severity before the freeze.
