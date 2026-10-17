"""Dalmatian: white short coat, crisp black spots, black drop ears, long legs.

Sitting is front-facing (drawn as a left half and mirrored, then spotted
asymmetrically); running and sleeping are a side view facing right.
"""
from pixelkit import Part, stack, mirrored, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "W": "FBFAF7",   # coat
    "w": "E2DFE0",   # light shade
    "s": "C3BEC4",   # deep shade
    "k": "2B2730",   # spots and ears
    "g": "4E4858",   # ear highlight
}


def spans(rows, fill="W"):
    """{y: [(x0, x1), ...]} -> Part. Ranges are inclusive."""
    px = {}
    for y, rs in rows.items():
        for x0, x1 in rs:
            for x in range(x0, x1 + 1):
                px[(x, y)] = fill
    return Part.from_px(px)


SPOT = {
    "dot": ["k"],
    "h2": ["kk"],
    "v2": ["k", "k"],
    "sq": ["kk", "kk"],
    "ob": ["kkk", "kk"],
    "big": [" kk", "kkkk", "kkk"],
    "egg": [" kk", "kkk", "kk"],
}


def dab(part, spots, only="Ww"):
    """Paint spots onto a part, clipped to the part's own fill."""
    px = dict(part.px)
    for x0, y0, shape in spots:
        for dy, row in enumerate(SPOT[shape]):
            for dx, c in enumerate(row):
                q = (x0 + dx, y0 + dy)
                if c != " " and px.get(q) in only:
                    px[q] = c
    return Part.from_px(px, part.ring)


def put(part, pts, c):
    px = dict(part.px)
    for q in pts:
        if c == "_":
            px.pop(q, None)
        else:
            px[q] = c
    return Part.from_px(px, part.ring)


def stk(parts, ox=0, oy=0):
    """stack(), then redraw the silhouette outline from the union of fills.

    A soft part's ring can land on an underlying part's outline and turn it
    into a shade pixel on the silhouette; this puts the dark edge back."""
    g = stack(parts, ox, oy)
    fill = {(x + ox, y + oy) for p in parts for (x, y), c in p.px.items() if c != "o"}
    for y in range(len(g)):
        for x in range(len(g[0])):
            if (x, y) in fill:
                continue
            near = any((x + dx, y + dy) in fill for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            g[y][x] = "o" if near else " "
    return g


# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred on the canvas.

S_HEAD = [
    "               WWWWW",
    "            kkWWWWWW",
    "           gkkkWWWWW",
    "          gkkkkWWWWW",
    "          gkkkkWWWWW",
    "          gkkkWWnWWW",
    "          gkkkWWnWWW",
    "          gkkkWWWWWW",
    "          kkkk WWWWW",
    "           kk  WWWWW",
    "               WWWnn",
    "                WWWn",
    "                 WWW",
]
S_EYE_CLOSED = [
    "                W",
    "               nn",
]
S_EYE_HAPPY = [
    "                n",
    "               nWn",
]
S_MOUTH_OPEN = [
    "                 Wpp",
    "                 WWW",
]

S_BODY = [
    "              WWWWWW",
    "              WWWWWW",
    "              WWWWWW",
    "             WWWWWWW",
    "             WWWWWWW",
    "             WWWWWWW",
    "            WWWWWWWW",
    "            WWWWWWWW",
    "            WWWWWWWW",
    "            WWWWWWWW",
    "            WWWWWWWW",
    "             WWWWWWW",
    "             WWWWWWW",
    "             WWWWWWW",
    "             WWWWWWW",
    "             WWWWWWW",
    "             WWWWWww",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
    "             WWWWWss",
]

S_LEG = [
    "             WW",
    "             WWW",
    "             WWWW",
    "             WWWWW",
    "             WWWWW",
    "             WWWWW",
    "             WWWWW",
    "             WWWWw",
    "             WWWWw",
    "             WWWWw",
    "             WWWWw",
    "             WWWWw",
    "             WWWWw",
    "             WWWWw",
    "            WWWWWW",
    "            WWWWWWW",
    "            WWWWWWW",
    "            WsWsWWW",
]

S_HAUNCH = [
    "         WWW",
    "        WWWWW",
    "       WWWWWW",
    "      WWWWWWW",
    "      WWWwWWW",
    "      WWwWWWW",
    "      WWwWWWW",
    "      WwWWWWW",
    "      WwWWWWW",
    "      WwWWWWW",
    "      WWWWWWW",
    "      WWWWWWW",
    "      WWWWWWW",
    "      WWWWWWW",
    "      WWWWWWW",
    "      WWWWWWW",
]

S_PAW = [
    "     WWWWWW",
    "    WWWWWWW",
    "    WWWWWWW",
    "    WsWsWWW",
]

S_TAIL = [
    "                                         W",
    "                                        WW",
    "                                       WW",
    "                                    WWWW",
    "                                  WWWWW",
    "                                 WWWW",
]
S_TAIL_UP = [
    "                                        _WW",
    "                                       _WW",
    "                                       W_",
]


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    face = Part(6, S_HEAD)
    if eyes == "closed":
        face = face.patched(11, S_EYE_CLOSED)
    elif eyes == "happy":
        face = face.patched(11, S_EYE_HAPPY)
    if mouth == "open":
        face = face.patched(17, S_MOUTH_OPEN)
    face = Part.from_px({**face.px, **flip(face).px})
    face = dab(face, [(22, 7, "h2"), (23, 8, "dot")])

    body = mirrored(17, S_BODY)
    body = dab(body, [(14, 24, "sq"), (23, 26, "ob"), (16, 20, "dot")])
    leg_l = dab(Part(28, S_LEG), [(14, 37, "sq")]).soft()
    leg_r = dab(flip(Part(28, S_LEG)), [(23, 32, "dot"), (23, 40, "h2")]).soft()

    haunch_l = dab(Part(30, S_HAUNCH), [(8, 35, "big"), (10, 40, "dot")])
    haunch_r = dab(flip(Part(30, S_HAUNCH)), [(30, 33, "sq"), (28, 39, "dot")])
    paw_l = Part(42, S_PAW).soft()
    paw_r = flip(Part(42, S_PAW)).soft()
    tail = Part(39, S_TAIL)
    if sway:
        tail = tail.patched(39, S_TAIL_UP)
    tail = dab(tail, [(37, 43, "h2")])
    face = face.moved(0, bob)   # the head lifts a pixel to bark
    return stk([tail, haunch_l, haunch_r, paw_l, paw_r, body, leg_l, leg_r, face.soft()], ox=5, oy=0)


# --------------------------------------------------------- side, running ----

BODY = spans({
    12: [(34, 37)],
    13: [(33, 38)],
    14: [(32, 39)],
    15: [(31, 39)],
    16: [(30, 39)],
    17: [(29, 39)],
    18: [(28, 39)],
    19: [(26, 40)],
    20: [(20, 40)],
    21: [(13, 40)],
    22: [(11, 40)],
    23: [(10, 40)],
    24: [(10, 40)],
    25: [(10, 39)],
    26: [(10, 39)],
    27: [(10, 38)],
    28: [(11, 38)],
    29: [(12, 21), (24, 38)],
    30: [(13, 21), (26, 37)],
    31: [(14, 20), (27, 37)],
    32: [(15, 20), (29, 36)],
    33: [(30, 35)],
})
BODY = dab(BODY, [
    (25, 21, "big"), (17, 23, "sq"), (12, 26, "egg"), (22, 27, "h2"),
    (32, 25, "sq"), (34, 16, "v2"), (16, 30, "dot"), (35, 30, "dot"), (29, 19, "dot"),
])

HEAD = spans({
    8: [(37, 41)],
    9: [(35, 43)],
    10: [(34, 44)],
    11: [(34, 48)],
    12: [(34, 49)],
    13: [(34, 49)],
    14: [(35, 48)],
    15: [(36, 46)],
    16: [(37, 44)],
})
HEAD = put(HEAD, [(42, 9), (42, 10)], "n")               # eye
HEAD = put(HEAD, [(48, 11), (48, 12), (49, 12)], "n")    # nose
HEAD = put(HEAD, [(43, 14), (44, 14), (45, 14)], "s")    # mouth line
HEAD = dab(HEAD, [(45, 12, "dot")])

EAR = spans({
    8: [(36, 38)],
    9: [(35, 38)],
    10: [(35, 38)],
    11: [(35, 38)],
    12: [(35, 38)],
    13: [(35, 38)],
    14: [(36, 38)],
    15: [(36, 37)],
}, "k")
EAR = put(EAR, [(37, 10), (37, 11), (37, 12)], "g")

TAIL = spans({
    17: [(3, 3)],
    18: [(3, 4)],
    19: [(4, 4)],
    20: [(4, 5)],
    21: [(5, 8)],
    22: [(6, 11)],
    23: [(8, 11)],
})
TAIL = dab(TAIL, [(7, 21, "dot")])
# mid-stride the tip swings down a pixel
TAIL_LOW = spans({
    18: [(2, 2)],
    19: [(2, 3)],
    20: [(3, 4)],
    21: [(4, 8)],
    22: [(6, 11)],
    23: [(8, 11)],
})
TAIL_LOW = dab(TAIL_LOW, [(7, 21, "dot")])


def limb(pts, widths, fill="W"):
    """A leg through joints pts (top to foot), one width per segment, plus a paw."""
    px = {}
    for (x0, y0), (x1, y1), w in zip(pts, pts[1:], widths):
        n = max(abs(x1 - x0), abs(y1 - y0)) * 3 + 1
        for i in range(n + 1):
            t = i / n
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            left = round(cx - (w - 1) / 2)
            for k in range(w):
                px[(left + k, round(cy))] = fill
    fx, fy = pts[-1]
    for x in range(fx - 1, fx + 3):
        px[(x, fy)] = fill
    for x in range(fx - 1, fx + 2):
        px[(x, fy - 1)] = fill
    return Part.from_px(px)


FORE = {
    "mid":  [(34, 28), (33, 34), (33, 41), (33, 45)],
    "fwd":  [(34, 28), (36, 34), (38, 40), (40, 44)],
    "back": [(33, 28), (31, 34), (28, 40), (26, 45)],
    "lift": [(34, 28), (36, 33), (37, 37), (34, 40)],
}
HIND = {
    "mid":  [(17, 26), (19, 32), (16, 39), (17, 45)],
    "fwd":  [(18, 26), (22, 32), (21, 39), (23, 45)],
    "back": [(16, 26), (15, 32), (11, 38), (8, 44)],
    "lift": [(17, 26), (21, 31), (17, 36), (18, 41)],
}
FW, HW = [4, 3, 2], [5, 3, 2]


def shift(pts, dx):
    return [(x + dx, y) for x, y in pts]


def running(near_fore, far_fore, near_hind, far_hind, bob=0, tail=TAIL):
    far = [limb(shift(HIND[far_hind], 2), HW, "w"), limb(shift(FORE[far_fore], -2), FW, "w")]
    near = [limb(HIND[near_hind], HW).soft(), limb(FORE[near_fore], FW).soft()]
    up = [tail, BODY.soft(), HEAD.soft(), EAR]
    up = [p.moved(0, bob) for p in up]
    return stk(far + near + up, ox=-1, oy=0)


# ---------------------------------------------------------- side, asleep ----

def lying():
    body = spans({
        32: [(14, 20)],
        33: [(12, 23)],
        34: [(11, 31)],
        35: [(10, 34)],
        36: [(10, 36)],
        37: [(9, 37)], 38: [(9, 37)], 39: [(9, 37)], 40: [(9, 37)],
        41: [(9, 37)], 42: [(9, 37)], 43: [(9, 37)], 44: [(9, 37)],
        45: [(10, 37)],
    })
    body = dab(body, [(26, 34, "big"), (24, 40, "sq"), (31, 38, "h2"), (29, 42, "dot")])
    haunch = spans({
        32: [(14, 18)],
        33: [(12, 20)],
        34: [(11, 21)],
        35: [(10, 22)], 36: [(10, 22)], 37: [(10, 23)], 38: [(10, 23)],
        39: [(10, 23)], 40: [(10, 23)], 41: [(10, 23)], 42: [(11, 22)],
        43: [(12, 21)],
    })
    haunch = dab(haunch, [(13, 36, "egg"), (18, 33, "dot"), (20, 40, "h2")])
    hind_paw = spans({44: [(16, 25)], 45: [(15, 26)]})
    paws = spans({43: [(33, 44)], 44: [(32, 45)], 45: [(32, 45)]})
    tail = spans({
        40: [(2, 2)],
        41: [(2, 2)],
        42: [(2, 3)],
        43: [(3, 8)],
        44: [(5, 9)],
    })
    dx, dy = -3, 26
    head = put(HEAD, [(42, 9), (42, 10)], "W")
    head = put(head, [(41, 10), (42, 10)], "n")
    head = head.moved(dx, dy)
    ear = EAR.moved(dx, dy)
    return stk([tail, body, haunch.soft(), hind_paw.soft(), paws.soft(), head.soft(), ear], ox=0, oy=0)


def frames():
    return {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="closed", sway=1),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": lying(),
        "run0": running("fwd", "back", "back", "fwd", bob=0),
        "run1": running("mid", "lift", "lift", "mid", bob=-1, tail=TAIL_LOW),
        "run2": running("back", "fwd", "fwd", "back", bob=0),
        "run3": running("lift", "mid", "mid", "lift", bob=-1, tail=TAIL_LOW),
    }


PET = {
    "id": "dalmatian",
    "name": "Dalmatian",
    "kind": "dog",
    "palette": PALETTE,
    "frames": frames(),
}
