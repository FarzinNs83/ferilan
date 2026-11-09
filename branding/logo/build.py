"""Builds the Feri LAN logo masters (all filled paths, no strokes/text) into final/."""
from pathlib import Path

NEON, NIGHT, DEEP, WHITE = "#39FF6E", "#0A0F0C", "#00A846", "#F4FFF7"
OUT = Path(__file__).parent / "final"
OUT.mkdir(exist_ok=True)


def circle(cx, cy, r):
    return f"M{cx - r} {cy}a{r} {r} 0 1 1 {2 * r} 0a{r} {r} 0 1 1 {-2 * r} 0Z"


def symbol(w=28, r=24, dx=0, dy=0):
    """Route F: stem + rounded top bar + mid bar, a player dot on every terminal."""
    h = w / 2
    sx, top, cr, mid_y, top_end, mid_end = 80 + dx, 64 + dy, 36, 136 + dy, 176 + dx, 152 + dx
    cx, cy = sx + cr, top + cr  # corner centre
    o, i = cr + h, cr - h
    body = (f"M{sx - h} {196 + dy}V{cy}A{o} {o} 0 0 1 {cx} {top - h}H{top_end}V{top + h}H{cx}"
            f"A{i} {i} 0 0 0 {sx + h} {cy}V{mid_y - h}H{mid_end}V{mid_y + h}H{sx + h}V{196 + dy}Z")
    dots = [circle(sx, 196 + dy, r), circle(top_end, top, r), circle(mid_end, mid_y, r)]
    return " ".join([body, *dots])


# Wordmark "FERI LAN": monoline caps, cap height 112, stem 20; each glyph is (width, path at x=0).
def rect(x, y, w, h):
    return f"M{x} {y}h{w}v{h}h{-w}Z"


GLYPHS = {
    "F": (64, rect(0, 0, 20, 112) + rect(0, 0, 64, 20) + rect(0, 46, 54, 20)),
    "E": (64, rect(0, 0, 20, 112) + rect(0, 0, 64, 20) + rect(0, 46, 56, 20) + rect(0, 92, 64, 20)),
    "R": (76, rect(0, 0, 20, 112) + "M0 0H43A33 33 0 0 1 43 66H0V46H43A13 13 0 0 0 43 20H0Z"
              + "M38 66H60L80 112H58Z"),
    "I": (20, rect(0, 0, 20, 112)),
    "L": (60, rect(0, 0, 20, 112) + rect(0, 92, 60, 20)),
    "A": (84, "M0 112L30 0H54L84 112H63L56.03 86H27.97L21 112ZM42 33.6L33.32 66H50.68Z"),
    "N": (84, "M0 112V0H22L64 72.75V0H84V112H62L20 39.25V112Z"),
}
# optical spacing after each glyph (open-sided letters get less)
SPACE = {"F": 18, "E": 22, "R": 18, "I": 0, "L": 6, "A": 14, "N": 0}


def word(text, x0, y0, scale=1.0):
    parts, x = [], 0
    for ch in text:
        w, d = GLYPHS[ch]
        parts.append(f'<path transform="translate({x0 + x * scale} {y0}) scale({scale})" d="{d}"/>')
        x += w + SPACE[ch]
    return "".join(parts), x * scale


def svg(vb, body, title="Feri LAN"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"><title>{title}</title>'
            f'{body}</svg>\n')


def lockup(mark, feri, lan, bg=None):
    s = 0.85  # cap height ≈ 95 → about half the mark height
    feri_p, fw = word("FERI", 0, 0, s)
    lan_p, lw = word("LAN", 0, 0, s)
    gap_word = 40
    # horizontal: text vertically centred on the mark's optical centre (y≈130)
    tx, ty = 236, 130 - 112 * s / 2
    f_p, _ = word("FERI", tx, ty, s)
    l_p, _ = word("LAN", tx + fw + gap_word, ty, s)
    width = round(tx + fw + gap_word + lw + 48)
    back = f'<rect width="{width}" height="256" fill="{bg}"/>' if bg else ""
    horiz = svg(f"0 0 {width} 256", back + f'<path fill="{mark}" d="{symbol()}"/>'
                + f'<g fill="{feri}">{f_p}</g><g fill="{lan}">{l_p}</g>')
    # stacked: mark above smaller centred text
    s = 0.6
    _, fw = word("FERI", 0, 0, s)
    _, lw = word("LAN", 0, 0, s)
    gw = 28
    tw = fw + gw + lw
    W = max(256, round(tw + 96))
    sx = (W - tw) / 2
    f_p, _ = word("FERI", sx, 252, s)
    l_p, _ = word("LAN", sx + fw + gw, 252, s)
    back = f'<rect width="{W}" height="360" fill="{bg}"/>' if bg else ""
    stacked = svg(f"0 0 {W} 360", back + f'<path transform="translate({(W - 256) / 2} 0)" fill="{mark}" '
                  f'd="{symbol()}"/><g fill="{feri}">{f_p}</g><g fill="{lan}">{l_p}</g>')
    return horiz, stacked


files = {
    "feri-symbol.svg": svg("0 0 256 256", f'<path d="{symbol()}"/>'),
    # small-size cut: heavier route, same dots → gaps stay open at 16 px
    "feri-symbol-small.svg": svg("0 0 256 256", f'<path d="{symbol(w=36, r=26)}"/>'),
    "feri-symbol-neon.svg": svg("0 0 256 256", f'<path fill="{NEON}" d="{symbol()}"/>'),
    "feri-symbol-deep.svg": svg("0 0 256 256", f'<path fill="{DEEP}" d="{symbol()}"/>'),
}
h, s = lockup(NEON, WHITE, NEON, NIGHT)
files["feri-horizontal-dark.svg"], files["feri-stacked-dark.svg"] = h, s
h, s = lockup(NEON, WHITE, NEON)
files["feri-horizontal-on-dark.svg"], files["feri-stacked-on-dark.svg"] = h, s
h, s = lockup(DEEP, NIGHT, DEEP)
files["feri-horizontal-light.svg"], files["feri-stacked-light.svg"] = h, s
h, s = lockup("#000", "#000", "#000")
files["feri-horizontal.svg"], files["feri-stacked.svg"] = h, s

for name, text in files.items():
    (OUT / name).write_text(text, encoding="utf-8")
    print("wrote", OUT / name)
