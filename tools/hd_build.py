#!/usr/bin/env python3
"""Builds full-resolution frames for a pet's Large size from original artwork.

    python3 tools/hd_build.py hamster

Reads Resources/HD-src/hamster-idle.png and hamster-ride.png and writes
Resources/HD/hamster/sit.png and run.png. Both folders are git-ignored: the
source art is not ours to publish, so these frames only exist in local builds.
"""
import sys
from pathlib import Path
from PIL import Image, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd_cutout import cutout, complete_right_side, lum  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def drop_grass(im, from_y):
    """Clear saturated grass greens below `from_y`; the pastel mint in the mane stays."""
    px = im.load()
    for y in range(from_y, im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and g > r + 18 and g > b + 8 and lum((r, g, b)) < 205:
                px[x, y] = (0, 0, 0, 0)
    return im


def drop_specks(im, min_size=40):
    """Remove small islands of opaque pixels left behind by the cutout."""
    from collections import deque
    w, h = im.size
    a = im.getchannel("A").load()
    px = im.load()
    seen = set()
    for y0 in range(h):
        for x0 in range(w):
            if not a[x0, y0] or (x0, y0) in seen:
                continue
            comp, q = [], deque([(x0, y0)])
            seen.add((x0, y0))
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (x + dx, y + dy)
                    if 0 <= n[0] < w and 0 <= n[1] < h and a[n] and n not in seen:
                        seen.add(n)
                        q.append(n)
            if len(comp) < min_size:
                for p in comp:
                    px[p] = (0, 0, 0, 0)
    return im


def trim(im):
    return im.crop(im.getchannel("A").getbbox())


def main(pet):
    src, out = ROOT / "Resources" / "HD-src", ROOT / "Resources" / "HD" / pet
    out.mkdir(parents=True, exist_ok=True)
    idle = trim(complete_right_side(src / f"{pet}-idle.png"))
    idle.save(out / "sit.png")
    ride = cutout(src / f"{pet}-ride.png")
    ride = drop_specks(drop_grass(ride, int(ride.height * 0.72)))
    # Kibble's running frames face right; the app mirrors them when the pet faces left.
    ImageOps.mirror(trim(ride)).save(out / "run.png")
    print("wrote", out / "sit.png", idle.size, "and", out / "run.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "hamster")
