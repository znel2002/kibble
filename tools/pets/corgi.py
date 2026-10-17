"""Pembroke Welsh Corgi: red-and-white, big upright ears, long and low.

Sitting is front-facing (drawn as a left half and mirrored); running and
sleeping are a side view facing right.
"""
from pixelkit import Part, stack, mirrored, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "T": "E3924B",   # red coat
    "t": "C9763A",   # coat shade
    "W": "FFF9F0",   # white markings
    "w": "E6D8C6",   # white shade
}

# A soft line takes its tint from the fur it is drawn on, so a red part
# overlapping the white bib gets a pale line and not a dark orange one.
TINT = {"T": "t", "t": "t", "W": "w", "w": "w"}


def soft(part):
    return part.soft("~")


def layered(parts, ox=0, oy=0):
    """stack(), with every soft("~") line tinted by the pixel underneath."""
    marks = {}
    tagged = []
    for i, p in enumerate(parts):
        if p.ring == "~":
            tag = chr(0x100 + i)
            marks[tag] = i
            p = Part.from_px(p.px, tag)
        tagged.append(p)
    grid = stack(tagged, ox, oy)
    for tag, i in marks.items():
        under = None
        for y, row in enumerate(grid):
            for x, c in enumerate(row):
                if c == tag:
                    under = under or stack(tagged[:i], ox, oy)
                    row[x] = TINT.get(under[y][x], "t")
    return grid


# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred on the canvas.

S_EAR = [
    "      TT",
    "      TTT",
    "      TWTT",
    "      TWWTT",
    "      TWWWTT",
    "      TWWWWTT",
    "      TTWWWWTT",
    "       TWWWWWTT",
    "       TTWWWWTTT",
    "        TTTTTTTTT",
]

S_HEAD = [
    "             TTTTTTT",
    "           TTTTTTTTW",
    "          TTTTTTTTTW",
    "         TTTTTTTTTTW",
    "         TTTTTTTTTWW",
    "        TTTTTnnTTTWW",
    "        TTTTTnnTTWWW",
    "       TTTTTTTTTWWWW",
    "       TTTTTTTWWWWWW",
    "        TTTWWWWWWWnn",
    "         WWWWWWWWWWn",
    "          WWWWWWWWWW",
    "            WWWWWWWW",
    "              WWWWWW",
]
S_EYE_CLOSED = [
    "             TT",
    "             nn",
]
S_EYE_HAPPY = [
    "             nn",
    "            n  n",
]
S_MOUTH_OPEN = [
    "                  pp",
    "                 Wpp",
]

S_BODY = [
    "            TTTTTTTT",
    "          TTTTTTTTTT",
    "         TTTTWWWWWWW",
    "        TTTTWWWWWWWW",
    "        TTTWWWWWWWWW",
    "       TTTTWWWWWWWWW",
    "       TTTWWWWWWWWWW",
    "       TTTWWWWWWWWWW",
    "       TTTWWWWWWWWWW",
    "       TTTTWWWWWWWWW",
    "       TTTTTWWWWWWWW",
    "       TTTTTWWWWWWWW",
    "       TTTTTWWWWWWWW",
    "       TTTTTTWWWWWWW",
    "       TTTTTTWWWWWWW",
    "       TTTTTTWWWWWWW",
    "       TTTTTTWWWWWWW",
    "       TTTTTTWWWWWWW",
]

# The white ruff hangs over the tops of the front legs.
S_BIB = [
    "             WWWWWWW",
    "            WWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "            WWWWWWWW",
    "             WWWWWWW",
    "               WWWWW",
    "                  WW",
]

S_LEG = [
    "            WWWWW",
    "            WWWWW",
    "            WWWWW",
    "            WWWWW",
    "            WWWWW",
    "            WWWWW",
    "            WWWWW",
    "            WWWWW",
    "           WWWWWW",
    "           WWwWwW",
]

S_HAUNCH = [
    "         TT",
    "       TTTTT",
    "      TTTTTTT",
    "     TTTTTTTT",
    "     TTTTTTTTT",
    "    TTTTTTTTTT",
    "    TTTTTTTTTT",
    "    TTTTTTTTTT",
    "    TTTTTTTTTT",
    "   WWWTTTTTTTT",
    "   WWWWWTTTTTT",
    "   WWWWWWTTTTT",
]



def sitting(eyes="open", mouth="closed", sway=0, relaxed=False, bob=0):
    head = Part(17, S_HEAD)
    if eyes == "closed":
        head = head.patched(22, S_EYE_CLOSED)
    if eyes == "happy":
        head = head.patched(22, S_EYE_HAPPY)
    if mouth == "open":
        head = head.patched(27, S_MOUTH_OPEN)
    head = Part.from_px({**head.px, **flip(head).px})
    ear_l, ear_r = Part(10, S_EAR), flip(Part(10, S_EAR))
    if sway:
        # one ear twitches outward by a pixel
        ear_l = ear_l.moved(-sway, 0)
    if relaxed:
        # both ears ease outward: calm, content
        ear_l, ear_r = ear_l.moved(-1, 0), ear_r.moved(1, 0)
    body = mirrored(28, S_BODY)
    bib = mirrored(30, S_BIB)
    haunch_l, haunch_r = Part(34, S_HAUNCH), flip(Part(34, S_HAUNCH))
    leg_l, leg_r = Part(36, S_LEG), flip(Part(36, S_LEG))
    body, bib, ear_l, ear_r, head = [p.moved(0, bob) for p in (body, bib, ear_l, ear_r, head)]
    parts = [haunch_l, haunch_r, body, leg_l, leg_r, bib, ear_l, ear_r, head]
    return layered([soft(p) for p in parts], ox=5, oy=0)


# ------------------------------------------------------------ side view ----

SIDE_BODY = Part(28, [
    "                    TTTTTTTTTT",
    "            TTTTTTTTTTTTTTTTTTTT",
    "       TTTTTTTTTTTTTTTTTTTTTTTTTTTW",
    "     TTTTTTTTTTTTTTTTTTTTTTTTTTTTTWW",
    "    TTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWW",
    "   WTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWW",
    "  WWWTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWW",
    "   WWTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWW",
    "  WWWWTTTTTTTTTTTTTTTTTTTTTTTTWWWWWW",
    "    WWWTTTTTTTTTTTTTTTTTTTTTTWWWWWWW",
    "     WWWTTTTTTTTTTTTTTTTTTTTWWWWWWW",
    "       WWTTTTTTTTTTTTTWWWWWWWWWWWW",
    "                         WWWWWWW",
])

SIDE_HEAD = Part(13, [
    "                              T",
    "                              TT    T",
    "                              TWT  TT",
    "                             TTWT  TT",
    "                             TWWTTTTT",
    "                             TWWWTTTT",
    "                            TTWWWTTTT",
    "                            TTTWWTTTTT",
    "                           TTTTTTTTTTT",
    "                           TTTTTTTTTTTT",
    "                          TTTTTTTTnTTTTT",
    "                          TTTTTTTTTTTTWWTTT",
    "                          TTTTTTTTTTTWWWWWWWnn",
    "                          TTTTTTTTTTWWWWWWWWWn",
    "                          TTTTTTTTTWWWWWWWWW",
    "                          TTTTTTTWWWWWWWW",
    "                           TTTTWWWWW",
])
SIDE_EYE_CLOSED = [
    "                                  T",
    "                                 nn",
]


def run_body():
    """Head and body as one part, so the neck flows into the back with no seam.

    Only the jaw gets a soft line, where it sits over the white chest."""
    head = SIDE_HEAD.moved(-1, 2).px
    px = {**SIDE_BODY.px, **head}
    for (x, y) in head:
        below = (x, y + 1)
        if below not in head and px.get(below) == "W" and x >= 30:
            px[below] = "w"
    return Part.from_px(px)


RUN_BODY = run_body()


def thigh_of(body, cx, cy, rx, ry, open_back=True):
    """The haunch: an oval of the body's own fur. With open_back its rear half
    runs out to the rump, so its soft line draws only the front of the thigh."""
    def inside(x, y):
        return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 or (
            open_back and x <= cx and cy - ry < y < cy + ry)
    return Part.from_px({(x, y): c for (x, y), c in body.px.items() if inside(x, y)})


RUN_THIGH = thigh_of(RUN_BODY, 12, 35, 6, 5)


def side_leg(x, dx, lift, fill, foot, ytop=38, ybot=45):
    """A short leg from inside the body down to a forward-pointing foot.

    A lifted leg also folds its paw back a pixel."""
    px = {}
    bottom = ybot - lift
    span = bottom - ytop
    for y in range(ytop, bottom + 1):
        t = (y - ytop) / max(span, 1)
        xx = round(x + dx * t) - (1 if lift >= 2 and y >= bottom - 1 else 0)
        for i in range(3):
            px[(xx + i, y)] = foot if y >= bottom - 1 else fill
    fx = round(x + dx) - (1 if lift >= 2 else 0)
    px[(fx + 3, bottom)] = foot
    return Part.from_px(px)


def corgi_side(stride=(0, 0, 0, 0), lift=(0, 0, 0, 0), bob=0):
    hf, hn, ff, fn = stride
    lhf, lhn, lff, lfn = lift
    far = [side_leg(13, hf, lhf, "w", "w", ytop=37), side_leg(32, ff, lff, "w", "w")]
    near = [side_leg(10, hn, lhn, "W", "W", ytop=37), side_leg(28, fn, lfn, "W", "W")]
    up = [p.moved(0, bob) for p in (RUN_BODY, RUN_THIGH)]
    return layered([soft(p) for p in far + near + up], ox=2, oy=0)


def lying():
    body = Part(33, [
        "             TTTTTTTTTTT",
        "         TTTTTTTTTTTTTTTTTT",
        "       TTTTTTTTTTTTTTTTTTTTTT",
        "      TTTTTTTTTTTTTTTTTTTTTTTT",
        "     TTTTTTTTTTTTTTTTTTTTTTTTTT",
        "    TTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "    TTTTTTTTTTTTTTTTTTTTTTTTTTTW",
        "   WTTTTTTTTTTTTTTTTTTTTTTTTTTWW",
        "   WWTTTTTTTTTTTTTTTTTTTTTTTTWWW",
        "   WWTTTTTTTTTTTTTTTTTTTTTTTWWWW",
        "   WWWTTTTTTTTTTTTTTTTTTTTTTWWWW",
        "    WWTTTTTTTTTTTTTTTTTTTTTWWWWWW",
        "     WWTTTTTTTTTTTTTTTTTTWWWWWWW",
    ])
    paws = Part(43, [
        "                           WWWWWWWWWWWW",
        "                          WWWWWWWWWWWWWW",
        "                          WWWWWWWWWWWWWW",
    ])
    head = SIDE_HEAD.patched(23, SIDE_EYE_CLOSED).moved(-3, 13)
    # head and body are one piece; the chin gets its soft line from the paws below
    body = Part.from_px({**body.px, **head.px})
    foot = Part(43, [
        "             WWWWWW",
        "          WWWWWWWWWW",
        "          WWWWWWWWWWW",
    ])
    thigh = Part.from_px({**thigh_of(body, 13, 40, 7.5, 4.5, open_back=False).px, **foot.px})
    return layered([soft(p) for p in (paws, body, thigh)], ox=2, oy=0)


def frames():
    run = [
        dict(stride=(-3, -4, 3, 4), lift=(0, 1, 1, 2), bob=0),
        dict(stride=(0, 1, -1, 0), lift=(2, 2, 0, 0), bob=-1),
        dict(stride=(3, 4, -3, -2), lift=(0, 0, 0, 0), bob=0),
        dict(stride=(-1, 0, 1, 2), lift=(0, 0, 2, 2), bob=-1),
    ]
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="closed", relaxed=True),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": lying(),
    }
    for i, r in enumerate(run):
        out[f"run{i}"] = corgi_side(**r)
    return out


PET = {
    "id": "corgi",
    "name": "Corgi",
    "kind": "dog",
    "palette": PALETTE,
    "frames": frames(),
}
