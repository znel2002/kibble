"""Siamese cat (seal point): ivory body, seal-brown points, sapphire eyes.

Sitting is front-facing (drawn as a left half and mirrored); running and
sleeping are a side view facing right. Rows are written as "col:pixels" so
the column of every stroke is explicit.
"""
from pixelkit import Part, stack, flip, BASE_PALETTE, W, H

PALETTE = {
    **BASE_PALETTE,
    "C": "F7F0E4",   # ivory coat
    "c": "EADCC7",   # warm cream (back, flanks)
    "s": "D6C3A8",   # soft fold line
    "m": "A47F66",   # light point (mask edge, upper legs)
    "M": "6B4A3B",   # seal point
    "D": "4E352B",   # deep seal (inner lines on points)
    "B": "5BA9F2",   # sapphire eyes
}


def rows(y0, spec):
    """Part from lines of "col:pixels"; an empty string is an empty row."""
    lines = []
    for line in spec:
        col, _, px = line.partition(":")
        lines.append(" " * int(col) + px if px else "")
    return Part(y0, lines)


def patch(part, y0, spec):
    return Part.from_px({**part.px, **rows(y0, spec).px}, part.ring)


def half(part):
    return Part.from_px({**part.px, **flip(part).px}, part.ring)


def stroke(points, fill, w=2):
    """A w x w brush dragged through points; fill is a char or f(t), t 0-1."""
    px = {}
    segs = list(zip(points, points[1:]))
    total = sum(max(abs(b[0] - a[0]), abs(b[1] - a[1])) for a, b in segs) or 1
    done = 0
    for a, b in segs:
        n = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
        for i in range(n + 1):
            t = i / n
            x = round(a[0] + (b[0] - a[0]) * t)
            y = round(a[1] + (b[1] - a[1]) * t)
            c = fill((done + i) / total) if callable(fill) else fill
            for dx in range(w):
                for dy in range(w):
                    px.setdefault((x + dx, y + dy), c)
        done += n
    return Part.from_px(px)


def build(parts, ox=0, oy=0):
    """stack(), but a soft ring never replaces the silhouette outline.

    A soft part's ring is drawn wherever something is already on the canvas,
    including an earlier part's outline; there it would turn the silhouette
    edge light. Put the outline back and drop the stray outline it caused."""
    g = stack(parts, ox, oy)
    fill = set()
    for p in parts:
        fill |= {(x + ox, y + oy) for (x, y) in p.px}

    def near(x, y):
        return any((x + dx, y + dy) in fill for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))

    for y in range(H):
        for x in range(W):
            if g[y][x] != " " and (x, y) not in fill:
                g[y][x] = "o" if near(x, y) else " "
    return g


# ------------------------------------------------------- sitting, front ----
# Left half only (cols 0-19); mirrored around x=20, then offset by ox=5.

F_EAR = [
    "9:M",
    "9:MM",
    "9:MmM",
    "10:MmM",
    "10:MmmM",
    "10:MmmmM",
    "11:MmmMMM",
    "11:MMMMMM",
    "11:MM",
]

F_HEAD = [
    "16:CCCC",
    "14:CCCCCC",
    "12:CCCCCCCc",
    "11:CCCCCCcmm",
    "11:CCCmmmMMM",
    "11:CCmBBnBMM",
    "12:CmMBnBMM",
    "12:CmMMMMMM",
    "13:CmMMMMn",
    "14:CmMMMD",
    "15:mMMMM",
    "16:mMMM",
    "18:MM",
]
EYES_SHUT = [            # patched at row 19
    "11:CCmnmmmMM",
    "12:CmMnnnMM",
]
EYES_HAPPY = [
    "11:CCmmnnmMM",
    "12:CmnmmnMM",
]
MOUTH_OPEN = [           # patched at row 23
    "14:CmMMMp",
    "15:mMMpp",
    "16:mMMM",
]

# Chest, front legs and haunches in one fill; a short crease rounds the thigh.
F_BODY = [
    "16:CCCC",
    "16:CCCC",
    "16:CCCC",
    "15:CCCCC",
    "15:CCCCC",
    "14:CCCCCC",
    "14:CCCCCC",
    "14:CCCCCC",
    "13:CCCCCCC",
    "12:CCCCCmCC",
    "11:CsCCCmmmC",
    "10:CCsCCCMMMC",
    "10:CCCsCCMMMC",
    "9:CCCCsCCMMMC",
    "9:CCCCCsCMMMC",
    "9:CCCCCCCMMMC",
    "9:CCCCCCCMMMC",
    "9:CCCCCCCMMMC",
    "9:cCCCCCCMMMs",
    "9:cCCCCCCMMMs",
    "9:cCMMMsMMMMs",
    "9:cCMDMsMDMDs",
]


def f_tail(sway=0):
    pts = [(29, 44), (33, 44), (35, 42), (36, 39), (36, 37), (35 + sway, 35), (33 + sway, 34)]
    return stroke(pts, "M")


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    head = rows(14, F_HEAD)
    if eyes == "closed":
        head = patch(head, 19, EYES_SHUT)
    if eyes == "happy":
        head = patch(head, 19, EYES_HAPPY)
    if mouth == "open":
        head = patch(head, 23, MOUTH_OPEN)
    head = half(head)
    ears = [rows(9, F_EAR), flip(rows(9, F_EAR))]
    body = half(rows(24, F_BODY))
    upper = [p.moved(0, bob) for p in ears + [head.soft("D")]]
    return build([f_tail(sway), body] + upper, ox=5)


# ------------------------------------------------------------ side view ----

S_BODY = [
    "18:cccccccccccc",
    "15:cccccccccccccccccc",
    "14:cCCCCCCCCCCCCCCCCCCCCC",
    "13:cCCCCCCCCCCCCCCCCCCCCCCC",
    "13:CCCCCCCCCCCCCCCCCCCCCCCC",
    "13:CCCCCCCCCCCCCCCCCCCCCCC",
    "13:CCCCCCCCCCCCCCCCCCCCCC",
    "14:CCCCCCCCCCCCCCCCCCC",
    "15:CCCCCC      CCCCCC",
]
S_NECK = [
    "32:ccCC",
    "31:cCCCCC",
    "31:CCCCCCC",
    "31:CCCCCCC",
    "30:CCCCCCCC",
    "30:CCCCCCCC",
]

S_HEAD = [
    "36:M",
    "36:MM",
    "35:MmM",
    "35:MmmM",
    "35:MmmMM",
    "34:cCMMMCC",
    "33:cCCCmMMCCC",
    "33:cCCCmMMMMMMM",
    "33:cCCmMMBnBMMMM",
    "33:cCCmMMMBMMMMMn",
    "33:cCCCmMMMMMMMD",
    "34:cCCmMMMMMM",
    "34:cCCCmMMM",
]
S_EYE_SHUT = [           # patched at row 23
    "39:MmmmM",
    "39:MnnnM",
]


def leg_fill(near):
    def f(t):
        if t < 0.25:
            return "C" if near else "c"
        if t < 0.5:
            return "m" if near else "M"
        return "M" if near else "D"
    return f


def s_tail(tip=0):
    pts = [(14, 28), (11, 27), (9, 24), (8, 21), (8, 18), (9 + tip, 16), (11 + tip, 15)]
    return stroke(pts, lambda t: "m" if t < 0.15 else "M")


def hind(pts, near):
    """Hind leg: a thick thigh into a slim shank."""
    thigh = stroke(pts[:2], "C" if near else "c", w=4)
    shank = stroke(pts[1:], leg_fill(near))
    shank = Part.from_px({k: ("m" if near else "M") if v in "Cc" else v for k, v in shank.px.items()})
    return Part.from_px({**shank.px, **thigh.px})


def runner(fn, ff, hn, hf, bob=0, tip=0):
    """Fore legs: shoulder, elbow, wrist, toe. Hind legs: hip, knee, hock, toe."""
    far_legs = [stroke(ff, leg_fill(False)), hind(hf, False)]
    near_legs = [hind(hn, True).soft(), stroke(fn, leg_fill(True)).soft()]
    body = Part.from_px({**rows(26, S_BODY).px, **rows(22, S_NECK).px}, "s")
    up = [p.moved(0, bob) for p in (s_tail(tip), body)]
    head = rows(15, S_HEAD).soft().moved(0, bob)
    return build(far_legs + up + near_legs + [head])


FORE = {
    "reach":  [(31, 31), (34, 35), (37, 38), (40, 39)],
    "land":   [(31, 31), (32, 37), (32, 42), (34, 44)],
    "fold":   [(31, 31), (30, 36), (28, 39), (26, 39)],
    "gather": [(31, 31), (31, 37), (29, 42), (28, 44)],
    "swing":  [(31, 31), (34, 36), (35, 40), (38, 41)],
}
HIND = {
    "back":   [(18, 30), (15, 36), (11, 40), (8, 44)],
    "plant":  [(18, 30), (20, 36), (17, 41), (18, 44)],
    "swing":  [(18, 30), (22, 35), (21, 39), (24, 41)],
    "tuck":   [(18, 30), (21, 36), (21, 41), (22, 44)],
}


def far(pts, dx=-2, dy=0):
    """The far leg: same joints, set back a little; the hip/shoulder stays put."""
    return [pts[0]] + [(x + dx, y + dy) for x, y in pts[1:]]


def run_frames():
    return [
        # flight: fore legs reaching, hind legs trailing
        runner(fn=FORE["reach"], ff=far(FORE["reach"], -2, 1), hn=HIND["back"], hf=far(HIND["back"], -1, -1), bob=-1),
        # fore paws land, hind legs swing through
        runner(fn=FORE["land"], ff=far(FORE["swing"]), hn=HIND["swing"], hf=far(HIND["swing"], -2, 1), tip=1),
        # gathered: fore paws pass under the chest, hind paws land under the belly
        runner(fn=FORE["gather"], ff=far(FORE["fold"], -1, 0), hn=HIND["tuck"], hf=far(HIND["swing"], -1, 0), bob=-1),
        # hind legs push off, fore legs swing forward
        runner(fn=FORE["swing"], ff=far(FORE["swing"], -3, -1), hn=HIND["plant"], hf=far(HIND["plant"], 2, 0), tip=1),
    ]


def sleeping():
    """A loaf: head down on tucked paws, eyes shut, tail wrapped round."""
    body = rows(32, [
        "17:cccccccccc",
        "14:cccccccccccccccc",
        "12:ccCCCCCCCCCCCCCCcc",
        "11:cCCCCCCCCCCCCCCCCCCcc",
        "10:cCCCCCCCCCCCCCCCCCCCCCc",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCCCC",
        "10:CCCCCCCCCCCCCCCCCCCCCCCCCCCC",
        "11:CCCCCCCCCCCCCCCCCCCCCCCCCCC",
    ])
    haunch = rows(35, [
        "15:cCCCC",
        "13:cCCCCCCC",
        "12:cCCCCCCCCC",
        "12:cCCCCCCCCCC",
        "12:cCCCCCCCCCC",
        "13:cCCCCCCCCC",
        "14:cCCCCCCMMM",
        "16:CCCCMMMMM",
    ])
    paws = rows(43, [
        "33:MMMMMMM",
        "32:MMMMMMMMM",
        "32:MDMMMDMMM",
    ])
    head = patch(rows(15, S_HEAD), 23, S_EYE_SHUT).moved(-3, 14)
    tail = stroke([(11, 36), (8, 38), (7, 41), (9, 44), (16, 44), (29, 44)], "M")
    return build([body, haunch.soft(), tail, paws, head.soft()])


def frames():
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="closed", sway=-1),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": sleeping(),
    }
    for i, f in enumerate(run_frames()):
        out[f"run{i}"] = f
    return out


PET = {
    "id": "siamese",
    "name": "Siamese",
    "kind": "cat",
    "palette": PALETTE,
    "frames": frames(),
}
