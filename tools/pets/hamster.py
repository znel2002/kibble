"""Happy Hamster: the white meme blob with the wide, contented smile.

Sitting is front-facing: one tall pear-shaped blob that is head and body at
once. Its face is drawn as a full-width overlay of thin dark line art (as in
the original doodle), so the scribbly eyes can be a little lopsided. Running
is a side view facing right: the hamster screaming with joy on a galloping,
rainbow-maned unicorn. Sleeping is the blob loafed flat, smiling.
"""
from pixelkit import Part, stack, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "W": "FFFFFF",   # hamster white
    "w": "E9E4EE",   # hamster shade
    "s": "D3CCDC",   # soft inner line
    "b": "F5A9BE",   # blush hatching
    "k": "F28FA8",   # nose / lower lip / tongue pink
    "t": "FFFFFF",   # buck teeth
    "T": "D9D2E0",   # tooth shade
    "U": "FFFDFB",   # unicorn white
    "u": "E4DEEA",   # unicorn shade
    "g": "F5D272",   # gold horn / hooves
    "G": "D5A23E",   # gold shade
    "r": "F6A9C0",   # rainbow pink
    "y": "F8E08A",   # rainbow yellow
    "m": "A8E6CC",   # rainbow mint
    "c": "9CC8F2",   # rainbow blue
    "l": "C6AEEE",   # rainbow lilac
}
RAINBOW = "rymcl"


def spans(y0, rows):
    """A Part from (x, text) rows, so shapes need no space counting."""
    px = {}
    for dy, row in enumerate(rows):
        if row is None:
            continue
        x0, text = row
        for i, ch in enumerate(text):
            if ch != " ":
                px[(x0 + i, y0 + dy)] = ch
    return Part.from_px(px)


def paint(part, y0, rows, dx=0, dy=0):
    """Overlay rows onto a copy of part. Each row is a list of (x, text)
    pairs (or None); spaces keep the pixel underneath."""
    px = dict(part.px)
    for i, pairs in enumerate(rows):
        for x0, text in pairs or []:
            for j, ch in enumerate(text):
                if ch != " ":
                    px[(x0 + j + dx, y0 + i + dy)] = ch
    return Part.from_px(px, part.ring)


def blob(top, halves, cx=20, odd=False, right=None, shade_from=0.6, base=True):
    """A blob from half-widths, one per row. Even width is centred between
    cx-1 and cx; odd width is centred on cx. right: optional separate
    right-hand half-widths, for a lopsided shape. The bottom and lower rim
    get a pale shade for a little volume."""
    px = {}
    n = len(halves)
    for i, h in enumerate(halves):
        y = top + i
        dx = 0
        hr = right[i] if right else h
        x0, x1 = cx - h, cx + hr - (0 if odd else 1)
        for x in range(x0, x1 + 1):
            edge = (base and i >= n - 2) or (i >= n * shade_from and x in (x0, x1))
            px[(x + dx, y)] = "w" if edge else "W"
    return Part.from_px(px)


# ------------------------------------------------------- sitting, front ----
# Drawn in a 40px-wide space (centre between x=19 and x=20), then ox=5.

S_TOP = 8
# left and right half-widths: the narrow top tips a little to the right, as
# in the doodle, and the left side is the longer, rounder curve
S_LEFT = [1, 3, 4, 5, 5, 6, 6, 7, 7, 8,
          8, 9, 9, 10, 11, 11, 11, 12, 12, 13,
          13, 13, 14, 14, 14, 15, 15, 15, 15, 16,
          16, 16, 16, 16, 16, 16, 15, 14]
S_RIGHT = [3, 5, 6, 7, 7, 8, 8, 9, 9, 10,
           10, 11, 11, 11, 11, 11, 11, 12, 12, 13,
           13, 13, 14, 14, 14, 15, 15, 15, 15, 16,
           16, 16, 16, 16, 16, 16, 15, 14]
FACE_DX = 1

EYE_Y = 15
EYES = {
    "open": [
        [(13, " nn"), (24, "nn")],
        [(13, "nnn"), (24, "nnn")],
        [(13, "nnn"), (24, "nnn")],
        [(13, "nn"), (25, "nn")],
    ],
    "closed": [
        None,
        [(12, "n  n"), (24, "n  n")],
        [(13, "nn"), (25, "nn")],
    ],
    "happy": [
        None,
        [(13, "nn"), (25, "nn")],
        [(12, "n  n"), (24, "n  n")],
    ],
}
# pink hatching under each eye, slanting the same way on both sides
BLUSH = [
    [(13, "b b"), (24, "b b")],
    [(12, "b b"), (23, "b b")],
]
NOSE = [[(18, "kkkk")], [(18, "kkkk")], [(19, "kk")]]

# The smile: a wide U with a puffy cheek bulge at each end, and a pink
# lower lip under it.
SMILE = [
    [(12, "o  o"), (24, "o  o")],
    [(12, "o  o"), (24, "o  o")],
    [(13, "oo o"), (23, "o oo")],
    [(17, "oooooo")],
    [(17, "kkkkkk")],
    [(18, "kkkk")],
]
# Being petted: the same cheeks, the U opened up with a pink tongue.
GRIN = [
    [(12, "o  oooooooooo  o")],
    [(12, "o  onnnnnnnno  o")],
    [(13, "ooonnkkkknnooo")],
    [(16, "okkkkkko")],
    [(17, "oooooo")],
]
# The scream: a huge dark oval, two square buck teeth on top, pink tongue.
SCREAM = [
    [(16, "oooooooo")],
    [(15, "onttTttTno")],
    [(15, "onttTttTno")],
    [(14, "onnttTttTnno")],
    [(14, "onnnnnnnnnno")],
    [(14, "onnnnnnnnnno")],
    [(14, "onnnnnnnnnno")],
    [(14, "onnkkkkkknno")],
    [(15, "onkkkkkkno")],
    [(16, "okkkkkko")],
    [(17, "oooooo")],
]
ARMS = [
    [(12, "o o"), (25, "oo")],
    [(13, "oo"), (24, "o")],
    [(14, "o"), (25, "oo")],
]


def sitting(eyes="open", mouth="smile", arms=0, bob=0):
    body = blob(S_TOP, S_LEFT, right=S_RIGHT)
    d = FACE_DX
    body = paint(body, EYE_Y, EYES[eyes], dx=d)
    body = paint(body, EYE_Y + 4, BLUSH, dx=d)
    if mouth == "scream":
        # the nose sits a little higher, out of the way of the open mouth
        body = paint(body, EYE_Y + 3, NOSE[:1] + [[(19, "kk")]], dx=d)
        body = paint(body, EYE_Y + 6, SCREAM, dx=d)
    else:
        body = paint(body, EYE_Y + 3, NOSE, dx=d)
        body = paint(body, EYE_Y + 6, SMILE if mouth == "smile" else GRIN, dx=d)
    body = paint(body, 39 - arms, ARMS)
    return stack([body.moved(0, bob)], ox=5)


# ------------------------------------------------------------ side view ----

def unicorn_leg(xtop, dx, lift, fill, ytop=35, ybot=45):
    """A leg from inside the body to a gold hoof; dx is the stride, lift
    raises the hoof off the floor."""
    px = {}
    bottom = ybot - lift
    span = bottom - ytop
    for y in range(ytop, bottom - 1):
        x = round(xtop + dx * (y - ytop) / max(span, 1))
        for i in range(3):
            px[(x + i, y)] = fill
    fx = round(xtop + dx)
    for i in range(3):
        px[(fx + i, bottom - 1)] = "g"
        px[(fx + i, bottom)] = "G"
    return Part.from_px(px)


U_BODY = spans(27, [
    (15, "UUUUUUUUUUUUUUUUU"),
    (12, "UUUUUUUUUUUUUUUUUUUUUUU"),
    (11, "UUUUUUUUUUUUUUUUUUUUUUUUU"),
    (10, "UUUUUUUUUUUUUUUUUUUUUUUUUU"),
    (10, "UUUUUUUUUUUUUUUUUUUUUUUUUU"),
    (10, "UUUUUUUUUUUUUUUUUUUUUUUUUU"),
    (10, "UUUUUUUUUUUUUUUUUUUUUUUUUU"),
    (11, "uUUUUUUUUUUUUUUUUUUUUUUu"),
    (12, "uuUUUUUUUUUUUUUUUUUUuu"),
    (14, "uuuuuuuuuuuuuuuuuuu"),
])

U_HEAD = spans(14, [
    (37, "UU"),
    (36, "UUUU"),
    (35, "UUUUUUU"),
    (34, "UUUUUUUUUU"),
    (33, "UUUUUUUUUUUU"),
    (33, "UUUUUUnnUUUUU"),
    (33, "UUUUUUnnUUUUUU"),
    (32, "UUUUUUUUUUUUUUU"),
    (32, "UUUUUUUUUUUUUUUU"),
    (32, "UUUUUUUUUUUUUUnU"),
    (31, "UUUUUUUUUoUUUUUU"),
    (31, "UUUUUUUUUUoooooU"),
    (30, "UUUUUUUUUUUUUUU"),
    (30, "UUUUUUUUUuuuu"),
    (29, "UUUUUUUU"),
    (29, "UUUUUUUU"),
    (28, "UUUUUUUU"),
    (28, "UUUUUUUU"),
    (28, "UUUUUUUU"),
])

U_HORN = spans(6, [
    (45, "g"),
    (44, "gg"),
    (44, "Gg"),
    (43, "gG"),
    (42, "ggg"),
    (42, "Ggg"),
    (41, "ggG"),
    (40, "gggg"),
])

# x of the back of the neck, per canvas row from 14
NECK_BACK = [37, 36, 35, 34, 33, 33, 33, 32, 32, 32, 31, 31, 30, 30, 29, 29, 28]


def mane(phase):
    """Rainbow locks falling over the neck, their tips flowing back."""
    rows = []
    for i in range(17):
        edge = NECK_BACK[i]
        band, k = divmod(i, 3)
        band = min(band, 4)
        # each lock is a sawtooth: longest at its lower tip
        length = 2 + k + (1 if band else 0)
        sway = [0, 1, 1, 0][phase] if k == 2 else [0, 0, 1, 0][phase] if k == 1 else 0
        left = edge - length - sway
        rows.append((left, RAINBOW[band] * (edge + 3 - left)))
    return spans(14, rows)


def tail(phase):
    """A big rainbow plume streaming back from the rump."""
    lift = [0, -1, 0, 1][phase]
    wave = [0, 1, 0, -1][phase]
    rows = [
        (9, "rrr"),
        (6, "rrrryy"),
        (4, "rrryyyyy"),
        (3, "rryyyymmm"),
        (2, "yyyymmmcc"),
        (2, "ymmmmccll"),
        (2, "mmmcccll"),
        (2, "mcccll"),
        (3, "ccll"),
        (4, "ll"),
    ]
    # the tip of the plume swishes
    rows = [(x + (wave if i >= 6 else 0), t) for i, (x, t) in enumerate(rows)]
    return spans(26 + lift, rows)


def rider(bob):
    """The screaming hamster, front-facing, sat upright on the back."""
    halves = [2, 3, 4, 5, 5, 6, 6, 7, 7, 7, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 8]
    body = blob(9, halves, cx=18, odd=True, base=False)
    body = paint(body, 12, [
        [(15, "n"), (21, "n")],
        [(15, "n"), (21, "n")],
        [(13, "bb"), (17, "kkk"), (22, "bb")],
    ])
    body = paint(body, 15, [
        [(14, "ooooooooo")],
        [(13, "onttTnttTno")],
        [(13, "onttTnttTno")],
        [(13, "onnnnnnnnno")],
        [(13, "onnnnnnnnno")],
        [(13, "onnkkkkknno")],
        [(14, "onkkkkkno")],
        [(15, "ooooooo")],
        None,
        None,
        [(24, "oo")],
        [(23, "o")],
        [(24, "oo")],
    ])
    return body.moved(0, bob)


def running(stride, lift, bob, phase, ride):
    hf, hn, ff, fn = stride
    lhf, lhn, lff, lfn = lift
    far = [unicorn_leg(15, hf, lhf, "u"), unicorn_leg(30, ff, lff, "u")]
    near = [unicorn_leg(12, hn, lhn, "U").soft(), unicorn_leg(33, fn, lfn, "U").soft()]
    back = [p.moved(0, bob) for p in (tail(phase), U_BODY.soft())]
    front = [p.moved(0, bob) for p in (U_HEAD.soft(), U_HORN, mane(phase))]
    return stack(far + back + [rider(bob + ride)] + near + front)


# --------------------------------------------------------------- asleep ----

def sleeping():
    halves = [5, 8, 10, 11, 12, 13, 14, 14, 15, 15, 16, 16, 16, 16, 17, 17, 17, 17, 16, 15]
    body = blob(26, halves)
    body = paint(body, 31, EYES["closed"][1:])
    body = paint(body, 33, BLUSH)
    body = paint(body, 33, [[(18, "kkkk")], [(19, "kk")]])
    body = paint(body, 35, SMILE)
    return stack([body], ox=5)


def frames():
    run = [
        dict(stride=(-5, -3, 5, 3), lift=(0, 2, 1, 0), bob=0, phase=0, ride=0),
        dict(stride=(-1, 1, 1, -1), lift=(2, 3, 0, 0), bob=-1, phase=1, ride=-1),
        dict(stride=(4, 2, -3, -5), lift=(0, 0, 2, 3), bob=-1, phase=2, ride=0),
        dict(stride=(1, -1, 3, 5), lift=(0, 0, 3, 2), bob=0, phase=3, ride=1),
    ]
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(arms=1),
        "sit_bark": sitting(mouth="scream"),
        "sit_serene": sitting(eyes="closed", arms=1),
        "sit_happy": sitting(eyes="happy", mouth="grin", bob=-1),
        "sleep": sleeping(),
    }
    for i, r in enumerate(run):
        out[f"run{i}"] = running(**r)
    return out


PET = {
    "id": "hamster",
    "name": "Happy Hamster",
    "kind": "hamster",
    "palette": PALETTE,
    "frames": frames(),
}
