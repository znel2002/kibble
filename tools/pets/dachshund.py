"""Dachshund: smooth-haired, black-and-tan. Long body, short legs, long ears.

Sitting is front-facing (drawn as a left half and mirrored); running and
sleeping are a side view facing right, where the long body does the talking.
"""
from pixelkit import Part, stack, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "K": "634E48",   # coat: warm espresso charcoal, clearly lighter than the outline
    "k": "4C3D3C",   # coat shade: soft inner lines, far legs
    "h": "8E7A73",   # sheen on the glossy coat
    "T": "CC8D50",   # tan points
    "t": "A56C3D",   # tan shade
    "e": "F3EBE1",   # catch-light in the eye
}


def at(x0, y0, rows, ring="o"):
    """A part whose rows start at column x0 (so rows need no leading spaces)."""
    return Part(y0, rows, ring).moved(x0, 0)


def layer(parts, ox=0, oy=0):
    """stack(), but a soft line never replaces the silhouette outline.

    stack() lets a soft part's inner line land on an earlier part's outer
    outline, which then gets outlined again and grows the silhouette by a
    pixel of shade. Here every pixel outside all fills is re-derived: outline
    if it touches a fill, empty otherwise.
    """
    grid = stack(parts, ox, oy)
    fill = set()
    for p in parts:
        fill |= set(p.moved(ox, oy).px)
    for y in range(len(grid)):
        for x in range(len(grid[0])):
            if (x, y) in fill:
                continue
            near = any((x + dx, y + dy) in fill for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            grid[y][x] = "o" if near else " "
    return grid


def joined(part):
    """A left-half part plus its mirror image."""
    return Part.from_px({**part.px, **flip(part).px}, part.ring)


# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred with ox=5.

S_HEAD = at(13, 9, [
    "   KKKK",
    " KKKKKK",
    "KKKKKKK",
    "KKKKKKK",
    "KKTKKKK",
    "KKKKKKK",
    "KKKeKKK",
    "KKnnKKK",
    "KTKKKKK",
    " TTTKKK",
    " TTTTKK",
    "  TTTKK",
    "  TTTnn",
    "   TTnn",
    "    TTT",
])
S_EYE_Y = 15
S_EYE_CLOSED = [  # patched at y0 = S_EYE_Y
    "               KK",
    "               nn",
]
S_EYE_HAPPY = [  # patched at y0 = S_EYE_Y: a smiling arc
    "               nn",
    "              nKKn",
]
S_MOUTH_Y = 23
S_MOUTH_OPEN = [  # patched at y0 = S_MOUTH_Y
    "                 Tpp",
    "                  pp",
    "                  TT",
]

S_EAR = at(10, 11, [
    "  KK",
    " KKK",
    "KKhK",
    "KhKK",
    "KhKK",
    "KhKK",
    "KhKK",
    "KKKK",
    "KKKK",
    "KKKK",
    "KKKK",
    "KKKK",
    "KKKk",
    "KKKk",
    " KKk",
    " Kk",
])

S_BODY = at(11, 22, [
    "   KKKKKK",
    "   KKKKKK",
    "   KKKKKK",
    "   KKKKKK",
    "  KKKKKKK",
    "  KKKKKTT",
    "  KKKKTTT",
    " KKKKKTTT",
    " KKKKKKTT",
    " KKKKKKTT",
    " KKKKKKKT",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
    " KKKKKKKK",
])

S_LEG = at(11, 35, [
    "   KK",
    "  KKK",
    " KKKK",
    " KKKK",
    " KKKK",
    " KKKT",
    " KKTT",
    " KTTT",
    "TTTTT",
    "TTTTT",
    "TtTtT",
])

S_HAUNCH = at(6, 35, [
    "     KK",
    "   KKKKK",
    "  KKKKKK",
    " KKKKKKK",
    " KKKKKKK",
    "KKKKKKKK",
    "KKKKKKKK",
    "KKKKKKKK",
    " KKKKKKK",
    "TTTTKKK",
    "TTTTT",
])

S_TAIL = at(31, 40, [  # pre-offset coords; curls out on the viewer's right
    "       K",
    "       K",
    "      KK",
    "    KKK",
    "  KKKK",
    "KKKK",
])


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    face = S_HEAD
    if eyes == "closed":
        face = face.patched(S_EYE_Y, S_EYE_CLOSED)
    if eyes == "happy":
        face = face.patched(S_EYE_Y, S_EYE_HAPPY)
    if mouth == "open":
        face = face.patched(S_MOUTH_Y, S_MOUTH_OPEN)
    face = joined(face)
    ear_l, ear_r = S_EAR, flip(S_EAR)
    if sway:
        # the tips of the ears swing by a pixel
        ear_l = Part.from_px({((x + sway) if y >= 20 else x, y): c for (x, y), c in ear_l.px.items()})
        ear_r = Part.from_px({((x + sway) if y >= 20 else x, y): c for (x, y), c in ear_r.px.items()})
    ear_l, ear_r = ear_l.soft("k"), ear_r.soft("k")
    body = joined(S_BODY)
    haunch_l = S_HAUNCH.soft("k")
    haunch_r = flip(haunch_l)
    leg_l = S_LEG.soft("k")
    leg_r = flip(leg_l)
    upper = [p.moved(0, bob) for p in (body, face, ear_l, ear_r)]
    return layer([S_TAIL, haunch_l, haunch_r, upper[0], leg_l, leg_r] + upper[1:], ox=5)


# --------------------------------------------------------- side, right ----

TORSO = at(7, 28, [
    "     KKKKKKKKKKKKKKKKKKKKKKK",
    "   KKKKKKKKKKKKKKKKKKKKKKKKKK",
    "  KKKKhhhKKKKKKhhhhhhhhhKKKKKK",
    " KKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    " KKKKKKKKKKKKKKKKKKKKKKKKKKKKKTT",
    " KKKKKKKKKKKKKKKKKKKKKKKKKKKKTTT",
    " KKKKKKKKKKKKKKKKKKKKKKKKKKKKTTT",
    " KKKKKKKKKKKKKKKKKKKKKKKKKKKKTTT",
    "  KKKKKKKKKKKKKKKKKKKKKKKKKKKKTT",
    "   KKKKKKKKKKKKKKKKKKKKKKKKKKKKT",
    "     KKKKKKKKKKKKKKKKKKKKKKKKKK",
    "                KKKKKKKKKKKKK",
])
THIGH = at(8, 30, [
    "  KKKKK",
    " KKKKKKK",
    "KKKKKKKKK",
    "KKKKKKKKK",
    "KKKKKKKKK",
    "KKKKKKKK",
    " KKKKKK",
])

HEAD = at(30, 19, [
    "     KKKK",
    "   KKKKKhKK",
    "  KKKKKKKKTKK",
    "  KKKKKKKKenKKK",
    "  KKKKKKKKKKKKKKnn",
    "  KKKKKKKKKKKKKKKn",
    "  KKKKKKKKTTTTTTT",
    "  KKKKKKKTTTTTTT",
    " KKKKKKKKTTTT",
    "KKKKKKKKKKT",
    "KKKKKKKKKT",
    "KKKKKKKKK",
])
EYE_SHUT = [  # patched at y0 = 22
    "                                        KK",
    "                                        nn",
]

EAR = at(32, 21, [
    "  KKK",
    " KKKKK",
    "KKhKKK",
    "KhKKKK",
    "KhKKKK",
    "KhKKKK",
    "KKKKKK",
    "KKKKKK",
    "KKKKKk",
    " KKKKk",
    "  KKk",
])

TAILS = [  # thin and tapering, carried out behind; the tip flicks a pixel
    at(1, 24, [
        "K",
        "K",
        " K",
        " KK",
        "  KKK",
        "   KKKKKK",
    ]),
    at(1, 25, [
        "K",
        " K",
        " KK",
        "  KKK",
        "   KKKKKK",
    ]),
]


def limb(top, mid, foot, coat, tan, tan_from, toe=1):
    """A short leg stroked through three joints with a 3px brush, ending in a
    paw that points forward. tan_from: how far from the foot the tan reaches."""
    px = {}
    pts = [top, mid, foot]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0)) * 4 or 1
        for i in range(n + 1):
            t = i / n
            cx, cy = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
            for dx in (-1, 0, 1):
                q = (cx + dx, cy)
                d = ((q[0] - foot[0]) ** 2 + (q[1] - foot[1]) ** 2) ** 0.5
                if px.get(q) != tan:
                    px[q] = tan if d <= tan_from else coat
    # the paw: two rows, toes forward
    fx, fy = foot
    for q in ((fx - 1, fy + 1), (fx, fy + 1), (fx + 1, fy + 1), (fx + 2 * toe, fy + 1), (fx + 2 * toe, fy)):
        px[q] = tan
    return Part.from_px(px)


# Joint positions (shoulder/hip, elbow/hock, paw) relative to the leg's root.
FORE = {
    "reach": ((1, 0), (3, 3), (6, 5)),
    "plant": ((0, 0), (0, 4), (0, 7)),
    "push":  ((0, 0), (-1, 4), (-4, 7)),
    "tuck":  ((0, 0), (1, 3), (-2, 4)),
}
HIND = {
    "reach": ((1, 0), (4, 3), (5, 6)),
    "plant": ((0, 0), (-1, 4), (0, 7)),
    "push":  ((0, 0), (-3, 4), (-6, 6)),
    "tuck":  ((0, 0), (2, 3), (-1, 4)),
}


def side_leg(table, pose, root, coat, tan, tan_from):
    rx, ry = root
    top, mid, foot = [(rx + x, ry + y) for x, y in table[pose]]
    return limb(top, mid, foot, coat, tan, tan_from)


# (fore, hind) poses per frame for the near side; the far side lags a frame.
GALLOP = [("reach", "push"), ("plant", "tuck"), ("tuck", "reach"), ("push", "plant")]


def runner(i):
    fore_n, hind_n = GALLOP[i]
    fore_f, hind_f = GALLOP[(i + 3) % 4]
    bob = -1 if i in (1, 3) else 0
    far = [side_leg(HIND, hind_f, (15, 37), "k", "t", 1.5),
           side_leg(FORE, fore_f, (34, 37), "k", "t", 2.5)]
    near = [side_leg(HIND, hind_n, (11, 37), "K", "T", 1.5).soft("k"),
            side_leg(FORE, fore_n, (31, 37), "K", "T", 2.5).soft("k")]
    up = [TAILS[i % 2], TORSO.soft("k"), THIGH.soft("k"), HEAD.soft("k"), EAR.moved(0, i % 2).soft("k")]
    up = [p.moved(0, bob) for p in up]
    return layer(far + near + up)


def lying():
    """Stretched out flat, chin resting on the front paws."""
    body = at(6, 36, [
        "     KKKKKKKKKKKKKKKKKKKKKKKK",
        "   KKKKKKKKKKKKKhhhhhhhhKKKKKK",
        "  KKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        " KKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        " KKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
        "  KKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
    ])
    haunch = at(8, 37, [
        "  KKKKKK",
        " KKKKKKKK",
        "KKKKKKKKKK",
        "KKKKKKKKKK",
        "KKKKKKKKKK",
        "KKKKKKKKKK",
        "KKKKKKKKKTT",
        " KKKKKKKTTTT",
        "  KKKKKTTTTT",
    ])
    paws = at(31, 42, [
        "KKKKKKKKKKKK",
        "KKKKKKKKKKKKTT",
        "KKKKKKKKKKKTTTT",
        "KKKKKKKKKKTTTTT",
    ])
    head = at(32, 34, [
        "   KKKKK",
        " KKKKKKKTK",
        " KKKKKKKKKKK",
        " KKKKKKKnnKKKK",
        " KKKKKKKKKKKKKnn",
        " KKKKKKKKTTTTTTn",
        "  KKKKKKTTTTTTT",
        "   KKKKKTTTTTT",
    ])
    ear = at(34, 35, [
        "  KK",
        " KKKK",
        "KKhKK",
        "KhKKK",
        "KhKKK",
        "KKKKK",
        "KKKKk",
        " KKKk",
        " KKk",
    ])
    tail = at(1, 43, [
        "K",
        " KKKKKKK",
        "  KKKKK",
    ])
    return layer([tail, body, haunch.soft("k"), paws.soft("k"), head.soft("k"), ear.soft("k")])


def frames():
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=-1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="closed", sway=1),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": lying(),
    }
    for i in range(4):
        out[f"run{i}"] = runner(i)
    return out


PET = {
    "id": "dachshund",
    "name": "Dachshund",
    "kind": "dog",
    "palette": PALETTE,
    "frames": frames(),
}
