"""Orange tabby: a ginger cat with bold mackerel stripes and a cream bib.

Sitting is front-facing (drawn as a left half and mirrored, with the tail
wrapped round the front paws as its own part); running and sleeping are a
side view facing right.
"""
from pixelkit import Part, stack, mirrored, flip, BASE_PALETTE

PALETTE = {
    **BASE_PALETTE,
    "O": "F2A35C",   # ginger coat
    "s": "D7843F",   # soft inner line / shade
    "S": "BF6630",   # stripes
    "C": "FCEBD3",   # cream bib, muzzle, paws
    "c": "EBCDAA",   # cream shade
    "k": "F0A2A6",   # inner ear / nose pink
    "g": "A9C75A",   # eyes
}

# ------------------------------------------------------- sitting, front ----
# Left half only (x 0-19); mirrored around x=20, then centred on the canvas.

S_HEAD = [
    "           OO",
    "           OOO",
    "          OOkOO",
    "          OkkkOO",
    "          OkkkOOOOOO",
    "         OOOOOOSOOOS",
    "         OOOOOOOSOOS",
    "        OOOOOOOOOOOS",
    "        OOOOOOOOOOOO",
    "        OOOOOOgggOOO",
    "        OOOOOOgngOOO",
    "       SSOOOOOgngOOO",
    "       OOOOOOOOOOCCk",
    "       SSSOOOOOOCoCo",
    "        OOOOOOOCCCoC",
    "         OOOOOCCCCCC",
    "           OOOCCCCCC",
]
EYES_AT = 20
S_EYES = {
    "blink":  ["              OOO", "              nnn", "              OOO"],
    "serene": ["             nOOn", "             OnnO", "             OOOO"],
    "happy":  ["              OnO", "              nOn", "              OOO"],
}
S_MOUTH_OPEN = [
    "                  pp",
    "                  op",
]

S_BODY = [
    "            OOOCCCCC",
    "            OOOCCCCC",
    "            OOOCCCCC",
    "           OOOOCCCCC",
    "           SSOOCCCCC",
    "           OSOOCCCCC",
    "          OOOOOCCCCC",
    "          OOOOOCCCCC",
    "          OOOOOCCCCC",
    "          OOOOOCCCCC",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOO",
]

S_HAUNCH = [
    "         OOOO",
    "       OOOOOOO",
    "      OOOSSSOO",
    "     OOSOOOOOO",
    "     OSOOOOOOO",
    "     OOOOOOOOO",
    "     OOOOOOOOO",
    "     OOOOOOOOO",
    "     OOOOOOOOO",
    "     OOOOOOOOO",
    "     OOOOOOOOO",
    "     OOOOOOOOO",
    "      OOOOOOOO",
]

S_LEG = [
    "               OOOO",
    "               OOOO",
    "               OOOO",
    "               OOOO",
    "               SSSO",
    "               OOOO",
    "               OOOO",
    "              CCCCC",
    "              CcCcC",
    "              CCCCC",
]

S_TAIL = [
    "           SS",
    "           OO",
    "           OOO                   OO",
    "            OOOOOSSOOOOOSSOOOOOSSOOO",
    "             OOOOSSOOOOOSSOOOOOSSOOO",
]


def sitting(eyes="open", mouth="closed", sway=0, bob=0):
    head = Part(11, S_HEAD)
    if eyes in S_EYES:
        head = head.patched(EYES_AT, S_EYES[eyes])
    if mouth == "open":
        head = head.patched(25, S_MOUTH_OPEN)
    head = Part.from_px({**head.px, **flip(head).px})
    body = mirrored(27, S_BODY)
    haunch_l, haunch_r = Part(33, S_HAUNCH), flip(Part(33, S_HAUNCH))
    legs = mirrored(34, S_LEG)
    tail = Part(41, S_TAIL)
    if sway:
        # the tail tip twitches outward by a pixel
        tail = Part.from_px({((x - sway) if y < 43 and x < 20 else x, y): c for (x, y), c in tail.px.items()})
    return stack([body.soft(), haunch_l.soft(), haunch_r.soft(), legs.soft(), tail.soft(),
                  head.moved(0, bob).soft()], ox=5)


# ------------------------------------------------------------ side view ----

R_TORSO = Part(29, [
    "              OOSSOOOOSSOOOOSSOOOO",
    "            OOOOSSOOOOSSOOOOSSOOOO",
    "           OOOOOSSOOOOSSOOOOSSOOOOO",
    "          OOOOOOOSOOOOOSOOOOOSOOOOO",
    "          OOOOOOOOOOOOOOOOOOOOOOOOO",
    "          OOOOOOOOOOOOOOOOOOOOOOOOO",
    "          OOOOOOOOOOOOOOOOOOOOOOOOO",
    "           OOOOOOOOOOCCCCCCCCCOOOO",
    "             OOOOOOOCCCCCCCCCCOO",
])
R_HEAD = Part(21, [
    "                                   O    O",
    "                                  OkO  OOO",
    "                                 OkkOOOOOOO",
    "                                OOOOOOOOOOOO",
    "                                OOOOOOOgnOOO",
    "                               OOOOOOOOgnOOOO",
    "                               OOOOOOOOOOOOCCk",
    "                               OOOOOOOOOOOCCC",
    "                                OOOOOOOOCCC",
    "                                 OOOOOOCC",
])
R_TAIL = Part(17, [
    "       SSO",
    "      OO",
    "      OO",
    "      SS",
    "      OO",
    "      OO",
    "       OO",
    "       SS",
    "        OO",
    "        OO",
    "         SS",
    "         OO",
    "          OO",
    "           OO",
])


def leg(xtop, dx, lift, fill, paw, thigh=False, ytop=35, ybot=45):
    """A slim leg from inside the body down to a paw.

    dx shifts the paw forward/back (stride); lift raises it off the floor;
    a hind leg gets a fuller thigh where it leaves the body."""
    px = {}
    bottom = ybot - lift
    span = bottom - ytop
    for y in range(ytop, bottom):
        x = round(xtop + dx * (y - ytop) / max(span, 1))
        extra = (2 if y < ytop + 3 else 1 if y < ytop + 5 else 0) if thigh else 0
        for i in range(-extra // 2, 3 + extra - extra // 2):
            px[(x + i, y)] = fill
    fx = round(xtop + dx)
    for i in range(4):
        px[(fx + i, bottom)] = paw
    return Part.from_px(px)


def running(stride=(0, 0, 0, 0), lift=(0, 0, 0, 0), bob=0):
    """stride/lift: (hind_far, hind_near, fore_far, fore_near)."""
    hf, hn, ff, fn = stride
    lhf, lhn, lff, lfn = lift
    far = [leg(16, hf, lhf, "s", "c", thigh=True), leg(28, ff, lff, "s", "c")]
    near = [leg(12, hn, lhn, "O", "C", thigh=True), leg(32, fn, lfn, "O", "C")]
    # legs go first with hard outlines so near and far stay distinct; the
    # torso then covers their tops with a soft line
    up = [R_TAIL, R_TORSO.soft(), R_HEAD.soft()]
    up = [p.moved(0, bob) for p in up]
    return stack(far + near + up)


L_BODY = Part(30, [
    "                 OOOSSOOOOSSO",
    "              OSOOOOSSOOOOSSOOOO",
    "            OOOSSOOOOSSOOOOSSOOOOO",
    "           OOOOOSOOOOOSOOOOOSOOOOOO",
    "          OOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "         OOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "          OOOOOOOOOOOOOOOOOOOOOOOOOO",
])
L_THIGH = Part(36, [
    "             OOOOO",
    "           OOOOOOOO",
    "          OOOOOOOOOO",
    "          OOOOOOOOOOO",
    "          OOOOOOOOOOO",
    "          OOOOOOOOOOO",
    "          OOOOOOOOOOO",
])
L_PAW = Part(42, [
    "                                    CCCCC",
    "                                   CCcCcCC",
])
L_TAIL = Part(43, [
    "",
    "         OOOOOOSSOOOOOSSOOOOOSSOOOOSSOO",
    "          OOOOOSSOOOOOSSOOOOOSSOOOOSSO",
])


def sleeping():
    head = R_HEAD.patched(25, ["                                       OO",
                               "                                      nnn"])
    # chin tucked down flat onto the paw
    head = head.patched(30, ["                                 OOOOOOCCCC"]).moved(-3, 11)
    # one front paw peeks out under the chin
    return stack([L_BODY.soft(), L_THIGH.soft(), L_PAW.soft(), L_TAIL.soft(), head.soft()])


def frames():
    run = [
        # a gallop: stretch, land on the fore paws, gather, push off
        dict(stride=(-5, -3, 5, 3), lift=(0, 2, 1, 0), bob=0),
        dict(stride=(-1, 1, 1, -1), lift=(2, 3, 0, 0), bob=-1),
        dict(stride=(4, 2, -3, -5), lift=(0, 0, 2, 3), bob=-1),
        dict(stride=(1, -1, 3, 5), lift=(0, 0, 3, 2), bob=0),
    ]
    out = {
        "sit": sitting(),
        "sit_blink": sitting(eyes="blink"),
        "sit_sway": sitting(sway=1),
        "sit_bark": sitting(mouth="open", bob=-1),
        "sit_serene": sitting(eyes="serene"),
        "sit_happy": sitting(eyes="happy", mouth="open", bob=-1),
        "sleep": sleeping(),
    }
    for i, r in enumerate(run):
        out[f"run{i}"] = running(**r)
    return out


PET = {
    "id": "tabby",
    "name": "Orange Tabby",
    "kind": "cat",
    "palette": PALETTE,
    "frames": frames(),
}
