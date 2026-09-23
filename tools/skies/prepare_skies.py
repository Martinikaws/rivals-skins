"""Cut the downloaded skybox packs into Roblox sky faces.

Writes prepared/<sky>/{bk,dn,ft,lf,rt,up}.png, each at most 1024px (the
largest image Roblox keeps). Run upload_skies.py afterwards.

Roblox's sides run ft -> lf -> bk -> rt when turning right, so its lf/rt
are the pack's +x/-x, and its up and dn are turned a quarter each way.
Derived from the edges of Roblox's own sky (sky512_*.tex); check_skies.py
verifies every cut sky the same way.
"""
import os
import sys
import zipfile
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "prepared")
DOWNLOADS = os.path.expanduser(r"~\Downloads")
MAX = 1024

# Roblox face -> (source face, rotation in degrees counter-clockwise)
ORIENT = {"ft": ("+z", 0), "bk": ("-z", 0), "lf": ("+x", 0), "rt": ("-x", 0), "up": ("+y", 90), "dn": ("-y", 270)}


def save(faces, name):
    folder = os.path.join(OUT, name)
    os.makedirs(folder, exist_ok=True)
    for face, (src, rot) in ORIENT.items():
        im = faces[src].convert("RGB")
        if rot:
            im = im.rotate(rot, expand=True)
        if im.width > MAX:
            im = im.resize((MAX, MAX), Image.LANCZOS)
        im.save(os.path.join(folder, face + ".png"), optimize=True)


def cross_faces(im):
    """Horizontal cross, 4x3 cells: top row up, middle row left/front/right/back, bottom row down."""
    s = im.width // 4
    cell = lambda cx, cy: im.crop((cx * s, cy * s, cx * s + s, cy * s + s))
    return {"+y": cell(1, 0), "-x": cell(0, 1), "+z": cell(1, 1), "+x": cell(2, 1), "-z": cell(3, 1), "-y": cell(1, 2)}


def main():
    done = 0
    with zipfile.ZipFile(os.path.join(DOWNLOADS, "sbs_-_cloudy_skyboxes_-_cubemap.zip")) as z:
        for n in sorted(z.namelist()):
            if n.lower().endswith(".png"):
                num = n.split("Sky_")[1][:2]
                with z.open(n) as f:
                    save(cross_faces(Image.open(f)), "cloudy-" + num)
                done += 1
    with zipfile.ZipFile(os.path.join(DOWNLOADS, "galaxy_20101014.zip")) as z:
        faces = {}
        for key in ["+x", "-x", "+y", "-y", "+z", "-z"]:
            with z.open("galaxy/galaxy" + key.upper() + ".tga") as f:
                faces[key] = Image.open(f).copy()
        save(faces, "galaxy")
        done += 1
    # skybox1/2 are numbered 1-6 in +x, -x, +y, -y, +z, -z order (space-3d export).
    with zipfile.ZipFile(os.path.join(DOWNLOADS, "skybox.zip")) as z:
        for sky, label in (("skybox1", "nebula-blue"), ("skybox2", "nebula-gold")):
            faces = {}
            for i, key in enumerate(["+x", "-x", "+y", "-y", "+z", "-z"], start=1):
                with z.open("%s/%d.png" % (sky, i)) as f:
                    faces[key] = Image.open(f).copy()
            save(faces, label)
            done += 1
    print("prepared %d skies in %s" % (done, OUT))


if __name__ == "__main__":
    sys.exit(main())
