#!/usr/bin/env python3
"""Step 1 of the HD pipeline: cut a line-art character out of its background.

Background = everything reachable from the given seed edges without crossing a
dark outline pixel. Writes an RGBA cutout for inspection.
"""
import sys
from collections import deque
from PIL import Image


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def cutout(path, seeds=("top", "left", "right", "bottom"), dark=120, grow=1, seal_bottom=0):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    wall = [[lum(px[x, y]) < dark for x in range(w)] for y in range(h)]
    # thicken walls a little so 1px gaps in the line art don't leak
    for _ in range(grow):
        new = [row[:] for row in wall]
        for y in range(h):
            for x in range(w):
                if wall[y][x]:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            new[ny][nx] = True
        wall = new
    # A character cropped by the bottom of the picture has an open outline
    # there; wall off the last rows so the fill can't slip underneath it.
    for y in range(h - seal_bottom, h):
        wall[y] = [True] * w
    bg = [[False] * w for _ in range(h)]
    q = deque()
    starts = []
    if "top" in seeds: starts += [(x, 0) for x in range(w)]
    if "bottom" in seeds: starts += [(x, h - 1) for x in range(w)]
    if "left" in seeds: starts += [(0, y) for y in range(h)]
    if "right" in seeds: starts += [(w - 1, y) for y in range(h)]
    for x, y in starts:
        if not wall[y][x] and not bg[y][x]:
            bg[y][x] = True
            q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx] and not wall[ny][nx]:
                bg[ny][nx] = True
                q.append((nx, ny))
    out = Image.new("RGBA", (w, h))
    o = out.load()
    for y in range(h):
        for x in range(w):
            if not bg[y][x]:
                o[x, y] = px[x, y] + (255,)
    return out


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    seeds = sys.argv[3].split(",") if len(sys.argv) > 3 else ("top", "left", "right", "bottom")
    cutout(src, seeds).save(dst)


def silhouette_from_outline(path, dark=150):
    """For a blob whose outline is cropped by the picture: keep the largest
    connected outline, fill between its left and right edge on every row, and
    continue each edge along its own slope where the drawing stops."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    darkm = [[lum(px[x, y]) < dark for x in range(w)] for y in range(h)]
    # connected components (8-way) of dark pixels; the outline is the tallest
    seen = [[False] * w for _ in range(h)]
    best = None
    for y0 in range(h):
        for x0 in range(w):
            if not darkm[y0][x0] or seen[y0][x0]:
                continue
            comp, q = [], deque([(x0, y0)])
            seen[y0][x0] = True
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and darkm[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
            ys = [p[1] for p in comp]
            if best is None or max(ys) - min(ys) > best[0]:
                best = (max(ys) - min(ys), comp)
    rows = {}
    for x, y in best[1]:
        lo, hi = rows.get(y, (x, x))
        rows[y] = (min(lo, x), max(hi, x))
    top = min(rows)
    mid = w / 2

    def edge(side):
        pts = {y: (v[0] if side == "l" else v[1]) for y, v in rows.items()}
        # only points that are really on this side of the blob
        pts = {y: x for y, x in pts.items() if (x < mid) == (side == "l") or y < top + 25}
        ys = sorted(pts)
        last = ys[-1]
        tail = [y for y in ys if y > last - 30]
        slope = (pts[tail[-1]] - pts[tail[0]]) / max(1, tail[-1] - tail[0])
        out = {}
        prev = None
        for y in range(top, h):
            if y in pts:
                prev = pts[y]
            elif y > last:
                prev = pts[last] + slope * (y - last)
            out[y] = prev
        return out

    left, right = edge("l"), edge("r")
    out = Image.new("RGBA", (w, h))
    o = out.load()
    for y in range(top, h):
        if left[y] is None or right[y] is None:
            continue
        for x in range(max(0, int(left[y])), min(w, int(right[y]) + 1)):
            o[x, y] = px[x, y] + (255,)
    return out


def complete_right_side(path, dark=150, line=2):
    """The idle picture is cropped on the right, so the right-hand outline stops
    early. Below that point, rebuild the right edge as a mirror of the left one
    around the body's midline, fill it with the body's white, and draw a
    matching outline, so the silhouette is whole."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    sil = silhouette_from_outline(path, dark)
    a = sil.getchannel("A").load()
    darkm = lambda x, y: lum(px[x, y]) < dark
    rows = {}
    for y in range(h):
        xs = [x for x in range(w) if a[x, y]]
        if xs:
            rows[y] = (xs[0], xs[-1])
    top = min(rows)
    # Where the real right outline ends: the last row with ink near the right edge.
    right_end = max(y for y, (l, r) in rows.items() if any(darkm(x, y) for x in range(max(l, r - 4), min(w, r + 2))))
    mids = [(rows[y][0] + rows[y][1]) / 2 for y in range(max(top, right_end - 40), right_end + 1) if y in rows]
    mid = sum(mids) / len(mids)
    edge = {}
    for y, (l, r) in rows.items():
        edge[y] = r if y <= right_end else round(2 * mid - l)
    # keep the join smooth: never step inward by more than 1px per row
    for y in sorted(edge):
        if y > right_end and y - 1 in edge:
            edge[y] = max(edge[y], edge[y - 1] - 1) if edge[y] < edge[y - 1] else min(edge[y], edge[y - 1] + 2)
    W = max(max(edge.values()) + line + 2, w)
    out = Image.new("RGBA", (W, h))
    o = out.load()
    src = sil.load()
    whites = sorted(src[x, y][:3] for y in range(top, h, 3) for x in range(0, w, 3) if src[x, y][3] and lum(src[x, y]) > 235)
    body = whites[len(whites) // 2] + (255,)
    ink = (34, 34, 34, 255)
    for y, (l, r) in rows.items():
        for x in range(l, edge[y] + 1):
            o[x, y] = src[x, y] if x < w and src[x, y][3] else body
        if y > right_end:
            for x in range(edge[y] + 1, edge[y] + 1 + line):
                o[x, y] = ink
    return out
