"""Score how well each prepared sky's faces meet at their edges, using the
seams Roblox expects (worked out from its own sky512_*.tex). Lower is better;
a clean sky scores under ~6, a wrong turn or swap scores 20+."""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PREPARED = os.path.join(HERE, "prepared")
# (face, edge, other face, other edge, reversed)
SEAMS = [
    ("ft", "right", "lf", "left", False), ("lf", "right", "bk", "left", False),
    ("bk", "right", "rt", "left", False), ("rt", "right", "ft", "left", False),
    ("up", "right", "ft", "top", True), ("up", "top", "lf", "top", True),
    ("up", "left", "bk", "top", False), ("up", "bottom", "rt", "top", False),
    ("dn", "right", "ft", "bottom", False), ("dn", "bottom", "lf", "bottom", True),
    ("dn", "left", "bk", "bottom", True), ("dn", "top", "rt", "bottom", False),
]


def edge(a, name):
    return {"top": a[0], "bottom": a[-1], "left": a[:, 0], "right": a[:, -1]}[name]


def score(folder):
    f = {n: np.asarray(Image.open(os.path.join(folder, n + ".png")).convert("RGB").resize((128, 128)), dtype=float)
         for n in ["ft", "bk", "lf", "rt", "up", "dn"]}
    out = []
    for a, ea, b, eb, rev in SEAMS:
        x, y = edge(f[a], ea), edge(f[b], eb)
        out.append(np.abs((y[::-1] if rev else y) - x).mean())
    return out


if __name__ == "__main__":
    for sky in sorted(os.listdir(PREPARED)):
        if sky.startswith("rot-test"):
            continue
        s = score(os.path.join(PREPARED, sky))
        worst = max(range(len(s)), key=lambda i: s[i])
        print("%-12s sides %5.1f  top %5.1f  bottom %5.1f  worst %s-%s %.1f" % (
            sky, np.mean(s[:4]), np.mean(s[4:8]), np.mean(s[8:]), SEAMS[worst][0], SEAMS[worst][2], s[worst]))
