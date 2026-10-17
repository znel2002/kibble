"""Shared pixel-art toolkit for Kibble pets.

Every pet is a module in tools/pets/ that builds its frames from these helpers
and exposes a PET dict (see CONTRACT below). Parts are fill-only ASCII; each
part gets its own 1px outline and parts are stacked back to front, so where
one part overlaps another a line separates them. `Part.soft()` makes that inner
line a shade instead of the dark outline; the silhouette is always outlined.

Preview and validate a pet while drawing it:

    python3 tools/pixelkit.py preview <pet_id>   # writes docs/pets/<pet_id>.png
"""
from pathlib import Path
import importlib
import sys

ROOT = Path(__file__).resolve().parent.parent
W, H = 50, 48

# Lowest row every pose touches (one row higher is tolerated, e.g. mid-stride).
# Every pose must rest on this row so the pet sits on the usage stage instead of floating above it.
FLOOR = 46

REQUIRED_FRAMES = [
    "sit",          # idle, front-facing, eyes open
    "sit_blink",    # idle with eyes closed for one blink
    "sit_sway",     # idle with a small movement (ears, fur, tail), 1px
    "sit_bark",     # mouth open: barking (dogs) or meowing (cats)
    "sit_serene",   # eyes closed, calm (after howling)
    "sit_happy",    # eyes closed happily + mouth open (being petted)
    "run0", "run1", "run2", "run3",   # side view, facing RIGHT, a looping run cycle
    "sleep",        # side view, facing RIGHT, lying down, eyes closed
]

CONTRACT = """
PET = {
    "id": "shiba",              # matches the module filename
    "name": "Shiba Inu",        # shown in the menu
    "kind": "dog", "cat" or "hamster",  # picks the voice and menu section
    "palette": {"o": "3A3346", ...},   # one-char keys -> RRGGBB; "o" is the outline
    "frames": {name: grid},     # every REQUIRED_FRAMES name; grid = H rows x W chars from stack()
}
"""

# Picks the voice and the menu section: dogs woof, cats meow, hamsters squeak.
KINDS = ("dog", "cat", "hamster")

BASE_PALETTE = {
    "o": "3A3346",   # outline, shared by every pet so they look like one family
    "n": "231E2B",   # eyes / nose
    "p": "E9677F",   # mouth / tongue
}


class Part:
    """Fill pixels keyed by (x, y)."""

    def __init__(self, y0, rows, ring="o"):
        self.ring = ring
        self.px = {}
        for dy, row in enumerate(rows):
            for x, c in enumerate(row):
                if c != " ":
                    self.px[(x, y0 + dy)] = c

    @classmethod
    def from_px(cls, px, ring="o"):
        p = cls(0, [], ring)
        p.px = dict(px)
        return p

    def soft(self, ring="s"):
        """Inner edges drawn in a soft shade instead of the dark outline."""
        return Part.from_px(self.px, ring)

    def moved(self, dx, dy):
        return Part.from_px({(x + dx, y + dy): c for (x, y), c in self.px.items()}, self.ring)

    def with_px(self, **_):
        return self

    def patched(self, y0, rows):
        """Overlay rows on a copy; '_' erases a pixel."""
        px = dict(self.px)
        for dy, row in enumerate(rows):
            for x, c in enumerate(row):
                if c == "_":
                    px.pop((x, y0 + dy), None)
                elif c != " ":
                    px[(x, y0 + dy)] = c
        return Part.from_px(px, self.ring)


def stack(parts, ox=0, oy=0):
    parts = [p.moved(ox, oy) for p in parts]
    canvas = {}
    for part in parts:
        ring = {}
        for (x, y) in part.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                # A soft ring only shades fill that is already there; it never
                # replaces another part's outline, or the silhouette would grow.
                if q not in part.px and (part.ring == "o" or canvas.get(q, "o") != "o"):
                    ring[q] = part.ring
        canvas.update(ring)
        canvas.update({k: v for k, v in part.px.items() if v != "o"})
        canvas.update({k: "o" for k, v in part.px.items() if v == "o"})
    # the silhouette always gets a dark outline
    for (x, y) in [k for k, v in canvas.items() if v != "o"]:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in canvas:
                canvas[q] = "o"
    return [[canvas.get((x, y), " ") for x in range(W)] for y in range(H)]


def mirrored(y0, rows, both=True):
    half = Part(y0, rows)
    px = dict(half.px)
    if both:
        px.update({(39 - x, y): c for (x, y), c in half.px.items()})
    return Part.from_px(px)


def flip(part):
    return Part.from_px({(39 - x, y): c for (x, y), c in part.px.items()}, part.ring)



# ---------------------------------------------------------------- checks ----

def load(pet_id):
    sys.path.insert(0, str(ROOT / "tools"))
    return importlib.import_module(f"pets.{pet_id}").PET


def validate(pet):
    """Problems with a PET dict, as a list of strings (empty means fine)."""
    errs = []
    for k in ("id", "name", "kind", "palette", "frames"):
        if k not in pet:
            errs.append(f"missing key {k!r}")
    if errs:
        return errs
    if pet["kind"] not in KINDS:
        errs.append(f"kind must be one of {KINDS}")
    pal = pet["palette"]
    if pal.get("o") != BASE_PALETTE["o"]:
        errs.append("palette['o'] must be the shared outline 3A3346")
    for name in REQUIRED_FRAMES:
        g = pet["frames"].get(name)
        if g is None:
            errs.append(f"missing frame {name}")
            continue
        if len(g) != H or any(len(r) != W for r in g):
            errs.append(f"{name}: must be {H} rows x {W} cols")
            continue
        used = {c for r in g for c in r if c != " "}
        if used - set(pal):
            errs.append(f"{name}: chars {sorted(used - set(pal))} not in palette")
        rows = [y for y, r in enumerate(g) if any(c != " " for c in r)]
        if not rows:
            errs.append(f"{name}: empty")
            continue
        if max(rows) not in (FLOOR - 1, FLOOR):
            errs.append(f"{name}: lowest pixel is row {max(rows)}, must rest on row {FLOOR} (or {FLOOR - 1})")
        edge = [g[0][x] for x in range(W)] + [g[H - 1][x] for x in range(W)] + [g[y][0] for y in range(H)] + [g[y][W - 1] for y in range(H)]
        if any(c not in (" ", "o") for c in edge):
            errs.append(f"{name}: fill pixels on the canvas edge, so the drawing is clipped; move it inward")
    return errs


# --------------------------------------------------------------- preview ----

def rgba(palette, c):
    h = palette[c]
    return tuple(int(h[k:k + 2], 16) for k in (0, 2, 4)) + (255,)


def paint(img, grid, palette, ox, oy, scale):
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c != " ":
                img.paste(rgba(palette, c), (ox + x * scale, oy + y * scale, ox + (x + 1) * scale, oy + (y + 1) * scale))


def render_sheet(pet, path, scale=6):
    """All frames at 6x on a light and a dark band, plus sit/run/sleep at real
    widget size (2x) so you can judge how it reads small."""
    from PIL import Image
    names = REQUIRED_FRAMES
    gap, cols = 10, 6
    rows = (len(names) + cols - 1) // cols
    cw, ch = W * scale + gap, H * scale + gap
    small = 2
    strip_h = H * small + 20
    img = Image.new("RGBA", (cols * cw + gap, rows * ch + gap + 2 * strip_h), (0, 0, 0, 255))
    img.paste((84, 102, 132, 255), (0, 0, img.width, rows * ch + gap))
    for i, name in enumerate(names):
        paint(img, pet["frames"][name], pet["palette"], gap + (i % cols) * cw, gap + (i // cols) * ch, scale)
    y0 = rows * ch + gap
    for band, bg in enumerate([(242, 242, 245, 255), (32, 32, 36, 255)]):
        by = y0 + band * strip_h
        img.paste(bg, (0, by, img.width, by + strip_h))
        for i, name in enumerate(["sit", "sit_bark", "sit_happy", "run0", "run2", "sleep"]):
            paint(img, pet["frames"][name], pet["palette"], gap + i * (W * small + 30), by + 10, small)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "preview":
        pet = load(sys.argv[2])
        errs = validate(pet)
        out = ROOT / "docs" / "pets" / f"{pet['id']}.png"
        if not errs or all("missing" not in e for e in errs):
            render_sheet(pet, out)
            print("wrote", out)
        print("OK" if not errs else "PROBLEMS:\n  " + "\n  ".join(errs))
        sys.exit(1 if errs else 0)
    print(__doc__)
