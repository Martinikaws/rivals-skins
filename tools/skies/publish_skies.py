"""Turn sky_ids.json into everything that lists the uploaded skies:

- assets/skyboxes.json          the site's shared skies
- assets/images/skies/<ft>.png  a preview of each sky's front face
- skies.lua                     SKYBOX_PRESETS entries for the changer

Run after upload_skies.py.
"""
import json
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.normpath(os.path.join(HERE, "..", ".."))
PREPARED = os.path.join(HERE, "prepared")
LUA_ORDER = ["bk", "dn", "ft", "lf", "rt", "up"]  # SKYBOX_FACES order in the changer

CREDITS = {
    "cloudy": "Screaming Brain Studios (CC0)",
    "galaxy": "hackcraft.de (CC-BY)",
}
NAMES = {"galaxy": "Galaxy", "nebula-blue": "Blue Nebula", "nebula-gold": "Gold Nebula"}


def display_name(key):
    if key.startswith("cloudy-"):
        return "Cloudy " + key.split("-")[1]
    return NAMES.get(key, key.replace("-", " ").title())


def main():
    ids = json.load(open(os.path.join(HERE, "sky_ids.json")))
    keys = sorted(ids, key=lambda k: (not k.startswith("cloudy"), k))
    shared, lua = [], []
    thumbs = os.path.join(SITE, "assets", "images", "skies")
    os.makedirs(thumbs, exist_ok=True)
    for key in keys:
        faces = ids[key]
        if any(not faces.get(f) for f in LUA_ORDER):
            print("skipping incomplete", key)
            continue
        name = display_name(key)
        entry = {"name": name, "faces": {f: faces[f] for f in ["ft", "bk", "lf", "rt", "up", "dn"]}}
        credit = next((v for k, v in CREDITS.items() if key.startswith(k)), None)
        if credit:
            entry["by"] = credit
        shared.append(entry)
        src = os.path.join(PREPARED, key, "ft.png")
        if os.path.exists(src):
            Image.open(src).convert("RGB").resize((112, 112), Image.LANCZOS).save(
                os.path.join(thumbs, faces["ft"] + ".png"), optimize=True)
        lua.append('    ["%s"] = {%s},' % (name.lower(), ", ".join('"%s"' % faces[f] for f in LUA_ORDER)))

    path = os.path.join(SITE, "assets", "skyboxes.json")
    data = json.load(open(path)) if os.path.exists(path) else {}
    data["skyboxes"] = shared
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    with open(os.path.join(HERE, "skies.lua"), "w", encoding="utf-8") as f:
        f.write("\n".join(lua) + "\n")
    print("%d skies -> assets/skyboxes.json, previews, skies.lua" % len(shared))


if __name__ == "__main__":
    main()
