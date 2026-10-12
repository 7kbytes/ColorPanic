# UI art

Source PNGs for the A-10 look pass, with the Roblox asset IDs they were uploaded to.

Uploaded 2026-10-12 from Studio, under the game owner's account (2042571185), the same
account that owns the other 33 assets. All twelve came back as **asset type 1, Image**, which
is what `Config.Assets.Images` needs. Add them to "Color Panic Asset IDs.xlsx" as well, since
that file is the record and it lives outside git.

Every file is PNG with an alpha channel. The buttons, banner, coin, calendar, badges and dust
puff were trimmed to their artwork, because the originals had the art floating in a much
larger transparent canvas, which would have made each one render small inside its frame.
`confetti.png` was deliberately **not** trimmed: its four strips have to stay in their 2 x 2
quarters so the emitter can pick one at random.

**Roblox does not serve these at the size they were drawn.** An upload is resized to fit 1024
on its long edge, so every picture here comes back smaller. That matters for the three things
read in image pixels, `SliceCenter`, `ImageRectOffset` and `ImageRectSize`: a figure taken from
the "Drawn" column below falls off the end of the image, the right and bottom slices collapse,
and the top left corner stretches over the whole panel. A-10 shipped that bug once. Every rect
in `Config.Art` is in the "Uploaded" column, and `tests/Art.spec.luau` checks them against it.

Read the uploaded sizes back with
`AssetService:CreateEditableImageAsync(Content.fromAssetId(id))` and its `.Size`.

| File | Drawn | Uploaded | Asset ID | Where it goes |
| --- | --- | --- | --- | --- |
| `panel.png` | 1264 x 1264 | 1024 x 1024 | 139563814522811 | 9-slice behind every panel, tinted in code |
| `button-green.png` | 1636 x 571 | 1023 x 357 | 93487180431341 | Confirm buttons |
| `button-blue.png` | 1594 x 544 | 1023 x 349 | 127774996997034 | Neutral buttons: Close, Stop, Back, volume steppers |
| `button-red.png` | 1598 x 523 | 1024 x 335 | 116158902545034 | Danger buttons: Leave and the like |
| `confetti.png` | 1264 x 1264 | 1024 x 1024 | 101025737887579 | Win confetti, 2 x 2 sheet, tinted per particle |
| `dust-puff.png` | 897 x 746 | 897 x 746 | 83737612681030 | Tile drop and landing puffs |
| `coin.png` | 1045 x 1131 | 946 x 1024 | 115834073753412 | Coin counter in the HUD, results and daily rewards |
| `banner-ribbon.png` | 1580 x 474 | 1023 x 307 | 138240925155465 | Round, Final and Replay banners |
| `daily-calendar.png` | 1168 x 1171 | 1021 x 1024 | 112125971066533 | Daily Rewards tile and panel header |
| `badge-trophy.png` | 1055 x 1056 | 1023 x 1024 | 78075871927232 | Roblox badge art: 10 Wins |
| `badge-star.png` | 1040 x 1095 | 972 x 1023 | 125949995129561 | Roblox badge art: First Win |
| `badge-shield-round8.png` | 1041 x 1212 | 879 x 1023 | 140047216638977 | Roblox badge art: Survive Round 8 |

The three badge images are for badges created on the Creator Dashboard, not for
`Config.Assets.Images`. The IDs above are the uploaded pictures; a badge gets its own ID when
it is created, and that is what `BadgeService:AwardBadge` takes.

Aspect ratios, for the Config entries that size art by its shape:

- button-green 2.864, button-blue 2.930, button-red 3.055
- banner-ribbon 3.333, daily-calendar 0.997, coin 0.924

## Not here

`../page/thumbnail-keyart.jpg` is the experience page key art, kept as given. It is 1680 x 944
rather than the 1920 x 1080 Roblox suggests, and it is uploaded through the Creator Dashboard
rather than read by any code, so it has no asset ID in this table.
