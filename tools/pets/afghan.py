"""Afghan Hound: the original Kibble. White, centre-parted silky coat.

Sitting is front-facing (drawn as a left half and mirrored); running and
sleeping are a side view facing right.
"""
from pixelkit import Part, stack, mirrored, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "W": "FFFDF8",   # coat
    "w": "E8DFD3",   # shade
    "s": "CBBFB3",   # deep shade
}

TAIL = Part(2, [
    "      WWW",
    "     W   W",
    "     W    W",
    "      WW  W",
    "          W",
    "          W",
    "          W",
    "          WW",
    "           W",
    "           W",
    "           WW",
    "            W",
    "            W",
])

COAT = Part(14, [
    "             WWWWWWWWWWWWWWWWW",
    "            WWWWWWWWWWWWWWWWWWWW",
    "           WWWWWWWWWWWWWWWWWWWWWW",
    "           WWWWWWWWWWWWWWWWWWWWWWW",
    "           WWWWWWWWWWWWWWWWWWWWWWWW",
    "           WWWwWWWWWwWWWWWwWWWWWWWW",
    "           WWWwWWWWWwWWWWWwWWWWWwWW",
    "           WWwWWWWWwWWWWWwWWWWWWwWW",
    "           WWwWWWWWwWWWWWwWWWWWwWWW",
    "            WwWWWWWwWWWWWwwWWWWwWWW",
    "            wwWWWWwwWWWWwwWWWWWwWWW",
    "            ww WWWww WWWww WWWwwW W",
    "             w  WW w  WW w  WW w  W",
])

HEAD = Part(1, [
    "                               wWWWw",
    "                             wwWWWWWWW",
    "                            w wWWWWWWWWW",
    "                              WWWWWWWWWWW",
    "                              WWWWWWWWWWWWW",
    "                              WWWWWWWnnWWWWWW",
    "                               WWWWWWWWWWWWWWWWW",
    "                               WWWWWWWWWWWWWWWWWWnn",
    "                               WWWWWWWWWWWWWWWWWWn",
    "                              WWWWWWWWWWwwwww",
    "                             WWWWWWWWW",
    "                            WWWWWWWWW",
    "                           WWWWWWWWWW",
    "                          WWWWWWWWWWW",
    "                          WWWWWWWWWWW",
    "                           WWWWWWWWWW",
    "                            WWWWWWWWW",
    "                            WWWwWWWWW",
    "                            WWWwWWWWw",
    "                            WWwWWWWwW",
    "                            WwWWWWwWW",
    "                            wWWW wWW",
    "                             W   W",
])

EAR = Part(4, [
    "                                WWW",
    "                               WwWWW",
    "                              WWwWWW",
    "                              WwWWwW",
    "                             WWwWWwW",
    "                             WwWWwWW",
    "                             WwWWwWW",
    "                            WWwWWwWW",
    "                            WwWWwWWw",
    "                            WwWWwWWw",
    "                            WwWWwWWw",
    "                            WwWWwWw",
    "                            Ww wW w",
    "                            w  w",
])

# Eye / mouth variants patched onto HEAD.
EYE_CLOSED = [
    "                                    __",
    "                                    nn",
]
MOUTH_OPEN = [
    "                               WWWWWWWWWWWWWWWWWWn_",
    "                               WWWWWWWWWWWpppppp__",
    "                              WWWWWWWWWWpppppp",
    "                             WWWWWWWWWWWwwwww",
]


def leg(xtop, dx, lift, fill, ytop=25, ybot=39):
    """A feathered leg from the coat line down to a foot.

    dx shifts the foot forward/back (stride); lift raises it (bend)."""
    px = {}
    bottom = ybot - lift
    span = bottom - ytop
    for y in range(ytop, bottom + 1):
        t = (y - ytop) / max(span, 1)
        x = round(xtop + dx * t)
        width = 4 if y < bottom - 3 else 3
        for i in range(width):
            px[(x + i, y)] = fill
        if (y - ytop) % 3 == 1 and y < bottom - 3:  # feathering
            px[(x - 1, y)] = fill
    fx = round(xtop + dx)
    for i in range(5):
        px[(fx + i - 1, bottom)] = fill
    return Part.from_px(px)


def legs(stride, lift):
    """stride/lift: (hind_far, hind_near, fore_far, fore_near)."""
    hf, hn, ff, fn = stride
    lhf, lhn, lff, lfn = lift
    far = [leg(17, hf, lhf, "s"), leg(29, ff, lff, "s")]
    near = [leg(13, hn, lhn, "W").soft(), leg(33, fn, lfn, "W").soft()]
    return far, near


def hound(stride=(0, 0, 0, 0), lift=(0, 0, 0, 0), bob=0, head=HEAD, ear=EAR,
          tail=TAIL, coat=COAT, lean=0):
    far, near = legs(stride, lift)
    up = [tail, coat.soft(), head.soft(), ear.soft()]
    up = [p.moved(lean, bob) for p in up]
    return stack(far + near + up, ox=-2, oy=6)


def lying():
    """Lying down, head resting on stretched front paws."""
    drop = 11
    paws = Part(36, [
        "                              WWWWWWWWWWW",
        "                              WWWWWWWWWWWW",
    ])
    hind = Part(34, [
        "            WWWWWWW",
        "           WWWWWWWWW",
        "          WWWWWWWWWWW",
        "          WWWWWWWWWWWW",
    ])
    coat = COAT.moved(0, drop).patched(0, [])
    # trim coat fringe that would sink below the floor
    coat = Part.from_px({k: v for k, v in coat.px.items() if k[1] <= 37})
    head = HEAD.patched(5, EYE_CLOSED).moved(-1, drop + 2)
    head = Part.from_px({k: v for k, v in head.px.items() if k[1] <= 35})
    ear = EAR.moved(-2, drop + 2)
    ear = Part.from_px({k: v for k, v in ear.px.items() if k[1] <= 37})
    tail = Part(30, [
        "      WWWWW",
        "     W",
        "    W",
    ])
    return stack([tail, hind, coat.soft(), paws.soft(), head.soft(), ear.soft()], ox=-1, oy=8)


# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred on the canvas.

S_HAIR = [
    "                 WWW",
    "               WWWWW",
    "             WWWWWWW",
    "            WWwWWW",
    "            WwWWW",
    "           WWwWW",
    "           WwWWW",
    "           WwWW",
    "           WwWW",
    "           WwWW",
    "           WwWW",
    "           WwWW",
    "          WWwWW",
    "          WwWWwW",
    "          WwWWwW",
    "          WwWWwW",
    "          WwWWwW",
    "         WWwWWwW",
    "         WwWWWwWW",
    "         WwWWWwWW",
    "         WwWWWwWw",
    "         WwWW WwW",
    "         w W   w",
]

S_FACE = [
    "               WWWWW",
    "              WWWWWW",
    "              WWWWWW",
    "              WWWWWW",
    "              WWWnWW",
    "              WWWnWW",
    "              WWWWWW",
    "               WWWWW",
    "               WWWWW",
    "                WWWW",
    "                WWnn",
    "                 Wnn",
    "                 WWW",
]
S_EYE_CLOSED = [
    "                 W",
    "                nn",
]
S_MOUTH_OPEN = [
    "                 Wpp",
    "                  pp",
    "                 WWW",
]

S_BODY = [
    "                 WWW",
    "                WWWW",
    "               WWWWW",
    "              WWWWWW",
    "             WWWWWWW",
    "            WWWWWWWW",
    "            WWWWWWWW",
    "            WWWWWWWW",
    "            WWWWWwWW",
    "           WWWWWWwWW",
    "           WWWWWWwWW",
    "           WWWWWwWWW",
    "           WWWWWwWWW",
    "           WWWWWwWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "           WWWWWWWWW",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
    "          WWWWWWWWss",
]

S_HAUNCH = [
    "        WWWW",
    "       WWWWWW",
    "      WWWwWWW",
    "      WWWwWWW",
    "      WWwWWWW",
    "      WWwWWWW",
    "      WWwWWWW",
    "      WWwWWWW",
    "      WwWWWWW",
    "      WwWWWWW",
    "      WWWWWWW",
    "     wwwwwwww",
    "     wwwwwww",
]

S_LEG = [
    "              WWWWW",
    "              WwWWW",
    "              WwWWW",
    "              WwWWW",
    "              WwWwW",
    "              WwWwW",
    "              WwWwW",
    "              WwWwW",
    "              WwWwW",
    "             WWwWwW",
    "             WWwWwW",
    "             WwWWwW",
    "             WwWWwWW",
    "            WWwWWwWW",
    "            WWWWWWWW",
    "           WWWWWWWWW",
    "           WsWWsWWsW",
    "            WWWWWWW",
]

S_TAIL = Part(37, [
    " W",
    " WW",
    "  WW",
    "  WWWWW",
    "   WWWWWW",
])


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    face = Part(2, S_FACE)
    if eyes == "closed":
        face = face.patched(5, S_EYE_CLOSED)
    if mouth == "open":
        face = face.patched(12, S_MOUTH_OPEN)
    face = Part.from_px({**face.px, **flip(face).px})
    hair_l = Part(0, S_HAIR)
    if sway:
        # let the bottom of the ear curtains swing by a pixel
        hair_l = Part.from_px({((x + sway) if y >= 20 else x, y): c for (x, y), c in hair_l.px.items()})
    hair_r = flip(Part(0, S_HAIR))
    hair_l, hair_r = hair_l.soft(), hair_r.soft()
    if sway:
        hair_r = Part.from_px({((x + sway) if y >= 20 else x, y): c for (x, y), c in hair_r.px.items()})
    body = mirrored(13, S_BODY)
    haunch_l, haunch_r = Part(30, S_HAUNCH).soft(), flip(Part(30, S_HAUNCH)).soft()
    leg_l, leg_r = Part(25, S_LEG).soft(), flip(Part(25, S_LEG)).soft()
    upper = [p.moved(0, bob) for p in (body, face, hair_l, hair_r)]
    return stack([S_TAIL.moved(-1, 0), haunch_l, haunch_r] + upper[:1] + [leg_l, leg_r] + upper[1:], ox=5, oy=3)


def frames():
    run = [
        dict(stride=(-6, -3, 6, 3), lift=(0, 3, 0, 3), bob=0),
        dict(stride=(-2, 2, 2, -2), lift=(3, 0, 3, 0), bob=-1),
        dict(stride=(3, 6, -3, -6), lift=(3, 0, 3, 0), bob=0),
        dict(stride=(2, -2, -2, 2), lift=(0, 3, 0, 3), bob=-1),
    ]
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=-1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="closed", sway=1),
        "sit_happy": sitting(eyes="closed", mouth="open", bob=-1),
        "sleep": lying(),
    }
    for i, r in enumerate(run):
        out[f"run{i}"] = hound(**r)
    return out


PET = {
    "id": "afghan",
    "name": "Afghan Hound",
    "kind": "dog",
    "palette": PALETTE,
    "frames": frames(),
}
