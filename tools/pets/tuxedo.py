"""Tuxedo cat: black coat, white bib, white muzzle blaze and white spats.

Sitting is front-facing (drawn as a left half and mirrored); running and
sleeping are a side view facing right.
"""
from pixelkit import Part, stack, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "K": "50566B",   # coat: deep cool charcoal, kept lighter than the outline
    "s": "42465A",   # soft inner line on the coat
    "k": "474C60",   # far limbs
    "h": "687088",   # coat sheen
    "W": "F6F3EC",   # white markings
    "w": "D9D4CD",   # white shade, far paws
    "u": "D9D4CD",   # soft inner line on white
    "e": "8E7080",   # inner ear
    "r": "E3919F",   # nose
    "Y": "CDE35C",   # iris, yellow-green
    "v": "9C9AAB",   # whiskers
}
RINGS = {"s", "u"}


def R(x0, y0, rows):
    """A part from rows that start at column x0."""
    return Part(y0, rows).moved(x0, 0)


def sym(part):
    """Mirror a left half (x 0-19) around x=20 into one part."""
    return Part.from_px({**part.px, **{(39 - x, y): c for (x, y), c in part.px.items()}}, part.ring)


def build(parts, ox=0, oy=0, extra=None):
    """stack(), then tidy: a soft line that landed on an earlier part's outline
    (rather than on its fill) goes back to outline, so the silhouette never grows.
    `extra` paints pixels into empty space afterwards (whiskers)."""
    g = stack(parts, ox, oy)
    fill = {(x + ox, y + oy) for p in parts for (x, y), c in p.px.items() if c != "o"}
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x] in RINGS and (x, y) not in fill:
                g[y][x] = "o"
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x] == "o" and not any((x + dx, y + dy) in fill for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = " "
    for (x, y), c in (extra or {}).items():
        if g[y][x] == " ":
            g[y][x] = c
    return g


# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred with ox=5.

S_HEAD = [               # y0 = 11
    "         K",
    "         KK",
    "        KeKK",
    "        KeeKK",
    "        KeeeKKKKKKKK",   # 15
    "        KKKKKKKKKKKK",
    "        KKKKKKKKKKKK",
    "       KKKKKKKKKKKKW",
    "       KKKKKYYYKKKKW",   # 19
    "       KKKKKYYnYKKKW",
    "       KKKKKKYnYKKWW",
    "       KKKKKKKKKKWWW",
    "      KKKKKKKKKKWWrr",
    "      KKKKKKKKKWWWWr",   # 24
    "       KKKKKKKWWWWWw",
    "        KKKKKWWWWwwW",
    "         KKKWWWWWWWW",
    "            WWWWWWWW",   # bib
    "            WWWWWWWW",
    "             WWWWWWW",   # 30
    "             WWWWWWW",
    "              WWWWWW",
    "              WWWWWW",
    "                WWWW",
    "                  WW",   # 35
]
EYES = {                 # rows 19-21
    "closed": [
        "       KKKKKKKKKKKKW",
        "       KKKKKnnnnKKKW",
        "       KKKKKKKKKKKWW",
    ],
    "serene": [
        "       KKKKKKKKKKKKW",
        "       KKKKKnKKnKKKW",
        "       KKKKKKnnKKKWW",
    ],
    "happy": [
        "       KKKKKKnnKKKKW",
        "       KKKKKnKKnKKKW",
        "       KKKKKKKKKKKWW",
    ],
}
MOUTH_OPEN = [           # rows 25-27
    "       KKKKKKKWWWWWw",
    "        KKKKKWWWWWpp",
    "         KKKWWWWWWWp",
]

S_BODY = R(0, 26, [
    "          KKKKKKKKKK",
    "          KKKKKKKKKK",
    "          KKKKKKKKKK",
    "          KKKKKKKKKK",
    "         KKKKKKKKKKK",   # 30
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",   # 35
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",   # 40
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",
    "         KKKKKKKKKKK",   # 45
])

S_HAUNCH = R(0, 36, [
    "        KKK",
    "       KhhKKK",
    "      KhKKKKKK",
    "      KKKKKKKKK",
    "      KKKKKKKKK",         # 40
    "      KKKKKKKKK",
    "      KKKKKKKKK",
    "      KKKKKKKKK",
    "      KKKKKKKKK",
    "      KKKKKKKKK",         # 45
])

S_LEG = R(0, 34, [
    "               KKK",
    "               KKKK",
    "               KKKKK",
    "               KKKKK",
    "               KKKKK",
    "               KKKKK",
    "               KKKKK",   # 40
    "               KKKKK",
    "               WWWWW",
    "              WWWWWW",
    "              WWWWWW",
    "              WWwWWW",   # 45
])

S_TAIL = [               # pre-offset coords, y0 = 39
    "                                  hK",
    "                                  hKK",
    "                                   hK",
    "                          hh       hK",
    "                          KK     hhKK",
    "                          KhhhhhhhKK",
    "                           KKKKKKKK",      # 45
]
TAIL_TWITCH = [          # tip curls a pixel further out
    "                         hh",
    "                         KK_",
]

WHISKERS = {(x + 6, y): "v" for x, y in [
    (3, 23), (2, 23), (1, 22),
    (3, 25), (2, 25), (1, 26),
]}
WHISKERS.update({(49 - x, y): c for (x, y), c in list(WHISKERS.items())})


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    head = R(0, 11, S_HEAD)
    if eyes in EYES:
        head = head.patched(19, EYES[eyes])
    if mouth == "open":
        head = head.patched(25, MOUTH_OPEN)
    head = sym(head).soft()
    body = sym(S_BODY)
    haunches = [S_HAUNCH.soft(), flip(S_HAUNCH).soft()]
    legs = sym(S_LEG)
    legs = legs.patched(35, [" " * 20 + "s"] * 7 + [" " * 20 + "u"] * 4).soft()
    tail = Part(39, S_TAIL)
    if sway:
        tail = tail.patched(41, TAIL_TWITCH)
    up = [p.moved(0, bob) for p in (body, head)]
    whiskers = {(x, y + bob): c for (x, y), c in WHISKERS.items()}
    return build([up[0]] + haunches + [tail.soft(), up[1], legs], ox=5, extra=whiskers)


# ------------------------------------------------------------ side view ----

def limb(pts, fill, paw, width=3, paw_rows=2):
    """A thick polyline from hip to paw; the bottom rows are the white paw."""
    px = {}
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            if abs(y1 - y0) >= abs(x1 - x0):
                for j in range(width):
                    px[(x - width // 2 + j, y)] = fill
            else:
                for j in range(width):
                    px[(x, y - width // 2 + j)] = fill
    fx, fy = pts[-1]
    for (x, y) in list(px):
        if y > fy - paw_rows:
            px[(x, y)] = paw
    px[(fx + width // 2 + 1, fy)] = paw
    return Part.from_px(px)


RUN_BODY = R(0, 25, [
    "                 KKKKKKKKKK",
    "              KKKKKhhhhhKKKKK",
    "             KKKKKKKKKKKKKKKKKKK",
    "            KKKKKKKKKKKKKKKKKKKKKK",
    "           KKKKKKKKKKKKKKKKKKKKKKKK",
    "           KKKKKKKKKKKKKKKKKKKKKKKW",      # 30
    "           KKKKKKKKKKKKKKKKKKKKKKWW",
    "           KKKKKKKKKKKKKKKKKKKKKWWW",
    "            KKKKKKKKKKKKKKKKKKKWWWW",
    "              KKKKKK  wWWWWWWWWWW",
])
RUN_THIGH = R(0, 27, [
    "            KhhK",
    "           KhKKKKK",
    "           KKKKKKKK",
    "           KKKKKKKKK",                     # 30
    "           KKKKKKKKK",
    "            KKKKKKKK",
    "             KKKKKKK",
    "              KKKKK",
])

RUN_HEAD = R(0, 15, [
    "                                  K",
    "                                 KK   K",
    "                                KeK  KK",
    "                               KKeKKKeK",
    "                              KKKKKKKKKK",
    "                             KKKKKKKKKKKK",     # 20
    "                             KKKKKKKKYYKKK",
    "                             KKKKKKKKYnKKKW",
    "                             KKKKKKKKKKKWWWr",
    "                            KKKKKKKKKKWWWWW",
    "                             KKKKKKKKWWWWW",    # 25
    "                              KKKKKKWWWW",
    "                               KKKKWWWW",
    "                                 WWWW",
])
RUN_WHISKERS = {(45, 23): "v", (46, 23): "v", (45, 25): "v", (46, 26): "v"}

RUN_TAIL = R(0, 15, [
    "        KK",
    "       KK",
    "      KK",
    "      KK",
    "      KK",
    "      KK",          # 20
    "      KK",
    "      KK",
    "       KK",
    "        KK",
    "         KK",       # 25
    "          KKK",
    "           KKK",
])

# (near fore, far fore, near hind, far hind): hip -> joint -> paw
RUN_POSES = [
    ([(31, 31), (35, 38), (38, 41)], [(29, 31), (31, 39), (33, 45)],
     [(15, 33), (12, 39), (9, 42)], [(18, 32), (15, 39), (13, 45)], 0),
    ([(31, 31), (31, 39), (30, 45)], [(29, 31), (27, 38), (25, 42)],
     [(15, 33), (17, 38), (20, 42)], [(18, 32), (17, 39), (17, 45)], -1),
    ([(31, 31), (29, 38), (26, 43)], [(29, 31), (28, 39), (27, 45)],
     [(15, 33), (18, 39), (21, 45)], [(18, 32), (21, 38), (23, 42)], 0),
    ([(31, 31), (34, 37), (37, 40)], [(29, 31), (31, 38), (33, 42)],
     [(15, 33), (14, 40), (13, 45)], [(18, 32), (16, 38), (12, 43)], -1),
]


def runner(nf, ff, nh, fh, bob):
    far = [limb(fh, "k", "w"), limb(ff, "k", "w")]
    near = [limb(nh, "K", "W").soft(), limb(nf, "K", "W").soft()]
    up = [RUN_TAIL, RUN_BODY.soft(), RUN_THIGH.soft(), RUN_HEAD.soft()]
    up = [p.moved(0, bob) for p in up]
    whiskers = {(x, y + bob): c for (x, y), c in RUN_WHISKERS.items()}
    return build(far + near + up, extra=whiskers)


def lying():
    body = R(0, 29, [
        "                  KKKKKKKK",
        "               KKKKhhhhhhKKKK",
        "             KKKhhhKKKKKKKKKKKK",
        "           KKKhhKKKKKKKKKKKKKKKK",
        "          KKhhKKKKKKKKKKKKKKKKKKK",
        "         KKhKKKKKKKKKKKKKKKKKKKKKK",
        "         KKhKKKKKKKKKKKKKKKKKKKKKK",
        "        KKKKKKKKKKKKKKKKKKKKKKKKKK",
        "        KKKKKKKKKKKKKKKKKKKKKKKKKK",
        "        KKKKKKKKKKKKKKKKKKKKKKKKKK",
        "        KKKKKKKKKKKKKKKKKKKKKKKKKK",
        "        KKKKKKKKKKKKKKKKKKKKKKKKKK",
        "        KKKKKKKKKKKKKKKKKKKKKKKKKK",
        "         KKKKKKKKKKKKKKKKKKKKKKKKK",
        "         KKKKKKKKKKKKKKKKKKKKKKKKK",
        "          KKKKKKKKKKKKKKKKKKKKKKKK",
        "            KKKKKKKKKKKKKKKKKKKKK",
    ])
    head = R(0, 26, [
        "                               K     K",
        "                              KK    KK",
        "                             KeK   KeK",
        "                            KKeKKKKKeKK",
        "                           KKKKKKKKKKKKK",     # 30
        "                           KKKKKKKKKKKKKK",
        "                           KKKKKKKKKKKKKK",
        "                           KKKKKKKKKKKKKKW",
        "                           KKKKKKnKKKKKWWW",
        "                           KKKKKKKnnKKWWWWr",  # 35
        "                           KKKKKKKKKKKWWWWW",
        "                            KKKKKKKKKWWWWWW",
        "                             KKKKKKKWWWWWW",
        "                              KKKKKWWWWWW",
        "                                 WWWWWWW",     # 40
    ])
    paws = R(0, 42, [
        "                               WWWWWWWWW",
        "                              WWWWWWWWWWW",
        "                              WWWWWWWWwWW",
        "                               WWWWWWWWW",
    ])
    tail = R(0, 40, [
        "          hK",
        "         hKK",
        "         hKKK",
        "          KKKKhhhhKKKKKKKKKKK",
        "           KKKKKKKKKKKKKKKKKKKK",
        "             KKKKKKKKKKKKKKKKK",
    ])
    whiskers = {(44, 35): "v", (45, 35): "v", (44, 37): "v", (45, 38): "v"}
    return build([body, tail.soft(), paws.soft("u"), head.soft()], extra=whiskers)


def frames():
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="closed"),
        "sit_sway": sitting(sway=1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="serene"),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": lying(),
    }
    for i, pose in enumerate(RUN_POSES):
        out[f"run{i}"] = runner(*pose)
    return out


PET = {
    "id": "tuxedo",
    "name": "Tuxedo Cat",
    "kind": "cat",
    "palette": PALETTE,
    "frames": frames(),
}
