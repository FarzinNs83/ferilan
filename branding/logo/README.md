# Feri LAN — Logo guide

**Idea:** an F drawn as a route map: every terminal is a player. Feri LAN is one route that puts friends on the same LAN.

## Colours
| Name | HEX | RGB | Use |
|---|---|---|---|
| Neon | `#39FF6E` | 57 255 110 | Mark and "LAN" on dark backgrounds |
| Night | `#0A0F0C` | 10 15 12 | Main background, app-icon tile |
| Deep | `#00A846` | 0 168 70 | Mark on light backgrounds (neon is too faint on white) |
| Mist | `#F4FFF7` | 244 255 247 | "FERI" on dark backgrounds |

Rule: **neon only on dark backgrounds.** On light backgrounds use Deep or plain black.

## Files (`final/`)
- `feri-symbol.svg`: black master of the mark. `-neon` and `-deep` are the colour versions.
- `feri-symbol-small.svg`: heavier cut for 16–48 px (favicon, Windows icon).
- `feri-horizontal-*.svg` / `feri-stacked-*.svg`: lockups with the name.
  - `-dark`: with the Night background included
  - `-on-dark`: transparent, for dark backgrounds
  - `-light`: for light backgrounds
  - no suffix: one-colour black
- `icons/`: favicon.ico, PNGs, white/black/mono versions, app icon, webmanifest.
- `build.py`: generator for all masters. Change a value there and run `python build.py` again.

The "FERI LAN" letters are drawn as paths, so no font licence is needed.

## Rules
- **Clear space:** at least one terminal dot's diameter on every side of the logo.
- **Minimum size:** the mark at 16 px uses the small cut. The horizontal lockup should be at least 100 px wide.
- **Don't:** rotate it, stretch it, add a shadow or gradient, change the colours, use neon on white, or thicken the letters.
- A neon glow is fine for splash screens or posters, but never on the master file.

## Status
- The app's Windows icon (`windows/runner/resources/app_icon.ico`) has been replaced with this logo.
- Trademark search: not done; recommended before public release.
