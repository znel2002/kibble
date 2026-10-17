"""Shiba Inu: red coat with cream "urajiro" markings, upright ears, curled tail.

Sitting is front-facing (drawn as a left half and mirrored); running and
sleeping are a side view facing right.
"""
from pixelkit import Part, stack, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "R": "D9803E",   # russet coat
    "r": "B9622D",   # russet shade
    "d": "8F4523",   # deep shade
    "C": "F8EBD6",   # cream (urajiro)
    "c": "E2CBA9",   # cream shade
}


def at(y0, rows):
    """Part from (x, run) rows: each run of fill starts at column x."""
    px = {}
    for dy, (x0, s) in enumerate(rows):
        for i, c in enumerate(s):
            if c != " ":
                px[(x0 + i, y0 + dy)] = c
    return Part.from_px(px)


def over(part, patch):
    """part with patch's pixels painted on top (keeps part's ring)."""
    return Part.from_px({**part.px, **patch.px}, part.ring)


def both(part):
    """A left half plus its mirror image."""
    return Part.from_px({**part.px, **flip(part).px}, part.ring)


def clip(part, ymax):
    return Part.from_px({k: v for k, v in part.px.items() if k[1] <= ymax}, part.ring)


# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred on the canvas.

F_EAR = at(0, [
    (11, "RR"),
    (10, "RRRR"),
    (10, "RRCRR"),
    (9, "RRCCRR"),
    (9, "RRCCCRR"),
    (9, "RCCCCCRR"),
    (9, "RCCCCCCRR"),
])

F_HEAD = at(3, [
    (15, "RRRRR"),
    (13, "RRRRRRR"),
    (11, "RRRRRRRRR"),
    (10, "RRRRRRRRRR"),
    (9, "RRRRRRRRRRR"),
    (9, "RRRRCRRRRRR"),           # y8  cream brow spot
    (9, "RRRRRRRRRRR"),
    (8, "RRRRnnnRRRRR"),          # y10 eye
    (8, "RRCCCnnRRRRR"),          # y11
    (7, "RCCCCCCCCRRRR"),
    (7, "CCCCCCCCCCRRR"),
    (7, "CCCCCCCCCCCnn"),         # y14 nose
    (7, "CCCCCCCCCCCCn"),
    (8, "CCCCCCCCCCCc"),          # y16 mouth
    (9, "CCCCCCCCCcC"),
    (12, "CCCCCCCC"),
])
F_EYE_CLOSED = at(10, [(12, "RRR"), (12, "nnn")])
F_EYE_HAPPY = at(10, [(12, "RnR"), (12, "nCn")])
F_MOUTH_OPEN = at(16, [(17, "ppp"), (18, "pp")])

F_BODY = at(17, [
    (12, "RRCCCCCC"),
    (11, "RRRCCCCCC"),
    (11, "RRRCCCCCC"),
    (11, "RRRRCCCCC"),
    (10, "RRRRRCCCCC"),
    (10, "RRRRRCCCCC"),
    (10, "RRRRRCCCCC"),
    (10, "RRRRRCCCCC"),
    (10, "RRRRRRCCCC"),
    (10, "RRRRRRCCCC"),
    (10, "RRRRRRRCCC"),           # y27
    (12, "RRRRRCCC"),
] + [(13, "RRRRRCC")] * 11 + [
    (13, "RRRRRcc"),              # y40
])

F_HAUNCH = at(27, [
    (8, "RRR"),
    (6, "RRRRRR"),
    (5, "RRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "RRRRRRRRR"),
    (4, "rRRRRRRRR"),
    (4, "CCCCCRRRR"),             # y38 hind paw
    (4, "CCCCCCRRR"),
    (4, "CcCcCCCRR"),
    (5, "ccccc"),                 # y41
])

F_LEG = at(25, [
    (16, "RR"),
    (15, "RRR"),
    (14, "RRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRR"),
    (13, "RRRRC"),
    (13, "CCCCC"),
    (13, "CCCCC"),
    (12, "CCCCCCC"),
    (12, "CcCCcCC"),
    (12, "ccccccc"),              # y41
])

# The curl of the tail, peeking out behind the right flank.
F_TAIL = at(18, [
    (28, "RRRR"),
    (28, "RRRRRR"),
    (28, "RRRRRRRR"),
    (29, "RRRRCCRR"),
    (29, "RRRC  CRR"),
    (29, "RC     RR"),
    (35, "CRR"),
    (34, "CCR"),
    (34, "CC"),
])


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    face = F_HEAD
    if eyes == "closed":
        face = over(face, F_EYE_CLOSED)
    elif eyes == "happy":
        face = over(face, F_EYE_HAPPY)
    if mouth == "open":
        face = over(face, F_MOUTH_OPEN)
    face = both(face)
    ear_l, ear_r = F_EAR, flip(F_EAR)
    tail = F_TAIL
    if sway:
        # flick the right ear tip and the tail curl by a pixel
        ear_r = Part.from_px({((x + sway) if y <= 1 else x, y): c for (x, y), c in ear_r.px.items()})
        tail = tail.moved(0, -sway)
    body = both(F_BODY)
    haunches = [F_HAUNCH.soft("r"), flip(F_HAUNCH).soft("r")]
    legs = [F_LEG.soft("r"), flip(F_LEG).soft("r")]
    upper = [p.moved(0, bob) for p in (face.soft("c"), ear_l.soft("R"), ear_r.soft("R"))]
    return stack([tail.moved(0, bob)] + haunches + [body.moved(0, bob).soft("r")] + legs + upper, ox=5, oy=4)


# ------------------------------------------------------- side, facing right ----

S_HEAD = at(14, [
    (35, "RRRRR"),
    (34, "RRRRRRRR"),
    (33, "RRRRRRRCRR"),           # y16 brow spot
    (33, "RRRRRRRnnRRR"),         # y17 eye
    (33, "RRRRRRCCnRRRRR"),       # y18
    (33, "RRRRRCCCCCRRRnn"),      # y19 nose
    (33, "RRRRCCCCCCCCCCn"),
    (33, "RRRRCCCCCCcccC"),       # y21 mouth line
    (33, "RRRRCCCCCCCCC"),
    (33, "RRRRCCCCCCC"),
    (32, "RRRRRCCCCC"),
    (31, "RRRRRRCCCC"),
    (30, "RRRRRRRCCC"),
    (30, "RRRRRRRCCC"),
    (31, "RRRRRRCCC"),
])
S_EYE_CLOSED = at(17, [(40, "RR"), (39, "nnn")])

S_EAR = at(9, [
    (36, "RR"),
    (35, "RRCR"),
    (34, "RRCCR"),
    (34, "RRRCCR"),
    (33, "RRRRCCR"),
    (33, "RRRRRCRR"),
])

S_TAIL = at(13, [
    (14, "RRRR"),
    (12, "RRRRRRRR"),
    (11, "RRRRCCRRRR"),
    (11, "RRRC  CRRRR"),
    (11, "RRC    CRRR"),
    (11, "RRC     RRR"),
    (11, "RRC     CCR"),
    (11, "RRR"),
    (11, "RRRR"),
    (12, "RRRR"),
    (12, "RRRRR"),
    (13, "RRRR"),
])

S_TORSO = at(24, [
    (16, "RRRRRRRRRRRRRRR"),
    (13, "RRRRRRRRRRRRRRRRRRRRR"),
    (12, "RRRRRRRRRRRRRRRRRRRRRRRR"),
    (11, "RRRRRRRRRRRRRRRRRRRRRRRRRC"),
    (11, "RRRRRRRRRRRRRRRRRRRRRRRRCC"),
    (11, "RRRRRRRRRRRRRRRRRRRRRRRCCC"),
    (11, "RRRRRRRRRRRRRRRRRRRRRRCCCC"),
    (11, "RRRRRRRRRRRRRRRRRRRRRCCCCC"),
    (12, "RRRRRRRRRRRRRRRRRRRRCCCCC"),
    (13, "RRRRRRRRRRCCCCCCCCCCCCCC"),
    (15, "RRRCCCCCCCCCCCCCCCCCC"),
    (25, "CCCCCCCCC"),
])


def s_leg(x0, knee, paw, near, hind, ytop=32, ybot=45):
    """A side-view leg as a thick polyline from the body to a paw facing right.

    knee = (dx, y) and paw = (dx, lift) are relative to x0 / the floor."""
    main, sock = ("R", "C") if near else ("r", "c")
    kx, ky = x0 + knee[0], knee[1]
    px_, py = x0 + paw[0], ybot - paw[1]
    pts = {}
    for y in range(ytop, py + 1):
        if y <= ky:
            t = (y - ytop) / max(ky - ytop, 1)
            x = x0 + (kx - x0) * t
        else:
            t = (y - ky) / max(py - ky, 1)
            x = kx + (px_ - kx) * t
        x = round(x)
        if y < ytop + 4:
            width = 5 if hind else 4
        elif y < ky:
            width = 4
        else:
            width = 3
        fill = sock if y >= py - 3 else main
        for i in range(width):
            pts[(x + i, y)] = fill
    for i in range(4 if paw[1] == 0 else 3):
        pts[(px_ + i, py)] = sock
    return Part.from_px(pts)


# Leg phases of a trot: (knee, paw) relative to the leg's top.
PHASES = {
    "reach": ((3, 38), (5, 1)),
    "plant": ((1, 38), (0, 0)),
    "push":  ((-2, 38), (-5, 0)),
    "lift":  ((3, 37), (0, 4)),
}


def shiba_side(phase_a, phase_b, bob=0):
    """phase_a drives near hind + far fore, phase_b far hind + near fore."""
    def leg(x0, phase, near, hind):
        knee, paw = PHASES[phase]
        if hind:
            knee = (knee[0] - 2, knee[1] + 2)
        return s_leg(x0, knee, paw, near, hind)
    far = [leg(18, phase_b, False, True), leg(31, phase_a, False, False)]
    near = [leg(14, phase_a, True, True).soft("r"), leg(27, phase_b, True, False).soft("r")]
    up = [S_TORSO, S_HEAD.soft("r"), S_EAR.soft("r"), S_TAIL.soft("r")]
    up = [p.moved(0, bob) for p in up]
    return stack(far + near + [up[0].soft("r")] + up[1:], ox=-1)


def lying():
    """Curled into a loaf, chin resting on a front paw, eyes closed."""
    body = at(31, [
        (17, "RRRRRRRRRR"),
        (14, "RRRRRRRRRRRRRRRR"),
        (12, "RRRRRRRRRRRRRRRRRRR"),
        (11, "RRRRRRRRRRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRRRRRRRRRRRRC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRRRRCC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRRRCCC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRRRCCC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRRCCCC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRRCCCC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRCCCCC"),
        (9, "RRRRRRRRRRRRRRRRRRRRRCCCCC"),
        (10, "RRRRRRRRRRRRRRRRRRRCCCCCC"),
    ])
    thigh = at(35, [
        (13, "RRRRRR"),
        (11, "RRRRRRRRRR"),
        (10, "RRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRRR"),
        (10, "RRRRRRRRRRRCCCC"),       # y43 hind paw
        (11, "RRRRRRRRRRCCCCC"),
        (12, "RRRRRRRRRcCcCC"),
    ])
    fore = at(42, [
        (30, "RRRRRRRRRCCCC"),
        (29, "RRRRRRRRRRCCCCC"),
        (29, "CCCCCCCCCCCCcCC"),
        (30, "cccccccccccccc"),
    ])
    head = over(S_HEAD, S_EYE_CLOSED)
    head = clip(head, 23).moved(-3, 18)   # head only, no neck
    ear = S_EAR.moved(-3, 18)
    tail = S_TAIL.moved(-2, 13)
    parts = [body, thigh.soft("r"), tail.soft("r"), fore.soft("r"), head.soft("r"), ear.soft("r")]
    return stack(parts)


def frames():
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="closed", sway=1),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": lying(),
        "run0": shiba_side("reach", "push"),
        "run1": shiba_side("plant", "lift", bob=-1),
        "run2": shiba_side("push", "reach"),
        "run3": shiba_side("lift", "plant", bob=-1),
    }
    return out


PET = {
    "id": "shiba",
    "name": "Shiba Inu",
    "kind": "dog",
    "palette": PALETTE,
    "frames": frames(),
}
