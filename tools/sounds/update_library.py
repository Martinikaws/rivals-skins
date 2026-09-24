"""Rebuild the sound library in the site (index.html) and the in-game menu
(RivalsSkinGui.lua) from library.json, plus the Kenney sounds once uploaded.

library.json: [{"name": group, "sounds": [[name, id], ...]}, ...]
Kenney sounds (CC0) come from prepared/kenney/sounds.json + sound_ids.json;
their WAVs are copied to the site so it can play them directly.

    python update_library.py [path to RivalsSkinGui.lua]
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.normpath(os.path.join(HERE, "..", ".."))
GUI = sys.argv[1] if len(sys.argv) > 1 else r"C:\matcha\scripts\RivalsSkinGui.lua"
KENNEY = os.path.join(HERE, "prepared", "kenney")


def load_groups():
    groups = json.load(open(os.path.join(HERE, "library.json"), encoding="utf-8"))
    ids_path = os.path.join(HERE, "sound_ids.json")
    ids = json.load(open(ids_path)) if os.path.exists(ids_path) else {}
    kenney = []
    listing = os.path.join(KENNEY, "sounds.json")
    if os.path.exists(listing):
        dest = os.path.join(SITE, "assets", "sounds")
        os.makedirs(dest, exist_ok=True)
        for item in json.load(open(listing, encoding="utf-8")):
            if ids.get(item["key"]):
                shutil.copyfile(os.path.join(KENNEY, item["key"] + ".wav"), os.path.join(dest, item["key"] + ".wav"))
                kenney.append([item["name"], ids[item["key"]], "assets/sounds/%s.wav" % item["key"]])
    if kenney:
        groups = [g for g in groups if g["name"] != "Kenney (CC0)"]
        groups.append({"name": "Kenney (CC0)", "sounds": kenney})
    return groups


def main():
    groups = load_groups()
    seen, total = set(), 0
    for g in groups:
        g["sounds"] = [s for s in g["sounds"] if not (s[1] in seen or seen.add(s[1]))]
        total += len(g["sounds"])

    site = os.path.join(SITE, "index.html")
    html = open(site, encoding="utf-8", newline="").read()
    m = re.search(r"const SOUND_LIBRARY = (\[.*?\]);\n", html)
    html = html[:m.start(1)] + json.dumps(groups, ensure_ascii=False) + html[m.end(1):]
    open(site, "w", encoding="utf-8", newline="").write(html)

    lua = ["local SOUND_LIBRARY = {"]
    for g in groups:
        lua.append('    {name = "%s", sounds = {' % g["name"])
        for s in g["sounds"]:
            lua.append('        {"%s", "%s"},' % (s[0].replace('"', '\\"'), s[1]))
        lua.append("    }},")
    lua.append("}")
    src = open(GUI, encoding="utf-8").read()
    a = src.index("local SOUND_LIBRARY = {")
    b = src.index("\n}\n", a) + 3
    src = src[:a] + "\n".join(lua) + "\n" + src[b:]
    open(GUI, "w", encoding="utf-8").write(src)
    print("%d groups, %d sounds -> site + menu" % (len(groups), total))


if __name__ == "__main__":
    main()
