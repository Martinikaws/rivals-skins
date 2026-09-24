"""Import Roblox sky mods (sky512_*.tex packs) from a folder of folders/zips.

These packs replace Roblox's own sky textures, so their faces are already in
Roblox's layout - no cutting or turning, unlike prepare_skies.py. Screenshot
and preview images inside the packs are ignored; the site's preview comes from
each sky's own front face. Identical skies (same pictures under different
names) are kept once.

    python import_tex_packs.py "C:/Users/Martini/Desktop/SKYBOX"

Writes prepared/<name>/{bk,dn,ft,lf,rt,up}.png like prepare_skies.py, then
run check_skies.py, upload_skies.py, publish_skies.py, lighting_from_skies.py.
"""
import hashlib
import io
import os
import re
import sys
import zipfile
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "prepared")
FACES = ["bk", "dn", "ft", "lf", "rt", "up"]
MAX = 1024
FACE_RE = re.compile(r"sky512_(bk|dn|ft|lf|rt|up)\.tex$", re.I)


def slug(name):
    name = re.sub(r"\[.*?\]", "", name)
    name = re.sub(r"(?i)\b(skybox|sky box)\b", "", name)
    name = re.sub(r"(?i)by\w+$", "", name)
    name = re.sub(r"[^A-Za-z0-9]+", "-", name).strip("-").lower()
    return name or "sky"


def pick_faces(entries):
    """entries: {path: bytes-loader}. Returns {face: loader} for one complete set,
    preferring the set inside PlatformContent (what the mod actually installs)."""
    sets = {}
    for path, load in entries.items():
        path = path.replace(os.sep, "/")
        m = FACE_RE.search(path)
        if m:
            folder = path.rsplit("/", 1)[0] if "/" in path else ""
            sets.setdefault(folder, {})[m.group(1).lower()] = load
    full = {k: v for k, v in sets.items() if len(v) == 6}
    if not full:
        return None
    best = sorted(full, key=lambda k: ("platformcontent" not in k.lower(), len(k)))[0]
    return full[best]


def decode(data):
    im = Image.open(io.BytesIO(data))
    im.load()
    return im.convert("RGB")


def fingerprint(faces):
    h = hashlib.sha1()
    for f in ("ft", "up", "lf"):
        h.update(faces[f].resize((16, 16)).tobytes())
    return h.hexdigest()


def main(src, only=None):
    packs = []
    for name in sorted(os.listdir(src)):
        p = os.path.join(src, name)
        if os.path.isdir(p):
            entries = {}
            for dp, _, fs in os.walk(p):
                for fn in fs:
                    full = os.path.join(dp, fn)
                    entries[os.path.relpath(full, p)] = (lambda f=full: open(f, "rb").read())
            packs.append((name, entries))
        elif name.lower().endswith(".zip"):
            z = zipfile.ZipFile(p)
            entries = {n: (lambda n=n, z=z: z.read(n)) for n in z.namelist() if not n.endswith("/")}
            packs.append((name[:-4], entries))

    seen, made, skipped = {}, [], []
    for name, entries in packs:
        if only and name not in only:
            continue
        chosen = pick_faces(entries)
        if not chosen:
            skipped.append((name, "no complete set of six faces"))
            continue
        faces, broken = {}, []
        for f in FACES:
            try:
                faces[f] = decode(chosen[f]())
            except Exception:
                broken.append(f)
        if len(broken) > 1 or (broken and broken[0] != "dn"):
            skipped.append((name, "could not read faces: " + ", ".join(broken)))
            continue
        if broken:
            # Some packs ship an empty bottom (nobody looks straight down); fill it
            # with the colour along the sides' bottom edge so the seam blends in.
            size = faces["ft"].size
            edge = [faces[f].resize((1, 16)).getpixel((0, 15)) for f in ("ft", "bk", "lf", "rt")]
            colour = tuple(sum(c[i] for c in edge) // len(edge) for i in range(3))
            faces["dn"] = Image.new("RGB", size, colour)
        fp = fingerprint(faces)
        if fp in seen:
            skipped.append((name, "same sky as " + seen[fp]))
            continue
        key = slug(name)
        while os.path.exists(os.path.join(OUT, key)) and key not in [m[0] for m in made]:
            key += "-2"
        seen[fp] = key
        folder = os.path.join(OUT, key)
        os.makedirs(folder, exist_ok=True)
        for f, im in faces.items():
            if im.width > MAX:
                im = im.resize((MAX, MAX), Image.LANCZOS)
            im.save(os.path.join(folder, f + ".png"), optimize=True)
        made.append((key, name, faces["ft"].size))

    for key, name, size in made:
        print("new   %-28s from %s %s" % (key, name, size))
    for name, why in skipped:
        print("skip  %-28s %s" % (name, why))
    print("%d new skies, %d skipped" % (len(made), len(skipped)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(r"~\Desktop\SKYBOX"), set(sys.argv[2:]) or None)
