"""For a sky whose six images come unlabelled or in an unknown order, find
which image goes on which Roblox face, and how far to turn it, by trying
every arrangement and keeping the one whose edges meet best.

    python solve_faces.py <sky folder>    e.g. prepared/nebula-gold

Rewrites the six faces in place and prints the arrangement it chose.
"""
import itertools
import os
import sys
import numpy as np
from PIL import Image
from check_skies import SEAMS

N = 64


def edges_of(a):
    return {"top": a[0], "bottom": a[-1], "left": a[:, 0], "right": a[:, -1]}


def main(folder):
    names = ["ft", "bk", "lf", "rt", "up", "dn"]
    imgs = [Image.open(os.path.join(folder, n + ".png")).convert("RGB") for n in names]
    small = [np.asarray(im.resize((N, N)), dtype=float) for im in imgs]
    # rotated[i][r] = edges of image i turned r quarter turns counter-clockwise
    rotated = [[edges_of(np.rot90(a, r)) for r in range(4)] for a in small]

    def seam(pa, pb, ea, eb, rev):
        x, y = rotated[pa[0]][pa[1]][ea], rotated[pb[0]][pb[1]][eb]
        return np.abs((y[::-1] if rev else y) - x).mean()

    side_seams = SEAMS[:4]
    ring = []
    for order in itertools.permutations(range(6), 4):
        for rots in itertools.product(range(4), repeat=4):
            pick = dict(zip(["ft", "lf", "bk", "rt"], zip(order, rots)))
            ring.append((sum(seam(pick[a], pick[b], ea, eb, rev) for a, ea, b, eb, rev in side_seams), pick))
    ring.sort(key=lambda t: t[0])

    best = None
    for side_cost, pick in ring[:200]:
        rest = [i for i in range(6) if i not in [p[0] for p in pick.values()]]
        for up_i, dn_i in (rest, rest[::-1]):
            for ru in range(4):
                for rd in range(4):
                    full = dict(pick, up=(up_i, ru), dn=(dn_i, rd))
                    cost = sum(seam(full[a], full[b], ea, eb, rev) for a, ea, b, eb, rev in SEAMS)
                    if best is None or cost < best[0]:
                        best = (cost, full)
    cost, full = best
    for face, (i, r) in full.items():
        out = imgs[i].rotate(90 * r, expand=True) if r else imgs[i]
        out.save(os.path.join(folder, face + ".tmp.png"))
    for face in full:
        os.replace(os.path.join(folder, face + ".tmp.png"), os.path.join(folder, face + ".png"))
    print("%s: mean seam %.1f  %s" % (os.path.basename(folder), cost / len(SEAMS),
          ", ".join("%s<-%s%s" % (f, names[i], (" +%d" % (90 * r)) if r else "") for f, (i, r) in full.items())))


if __name__ == "__main__":
    main(sys.argv[1])
