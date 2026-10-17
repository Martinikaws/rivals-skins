"""Add new RIVALS skins, wraps, finishers and charms to the site, the GUIs'
data and the changer's hotbar icons, from the game's own data.

Inputs (made in Matcha, written to C:\\matcha\\workspace):
  _dec_CosmeticLibrary_new.lua  decompile(ReplicatedStorage.Modules.CosmeticLibrary)
  _dec_ItemLibrary_new.lua      decompile(ReplicatedStorage.Modules.ItemLibrary)
  rivals_wraptextures.txt       one line per PlayerScripts.Assets.WrapTextures
                                folder: "<name>\\t<child>:<image id>,..." (the
                                image id is the Texture's string at +0x1D0)

What it changes (only adds; existing entries are left as they are):
  index.html            OFFICIAL_WEAPON_DATA skins ("Standard" first, rest sorted)
  skin_icon_map.json    src / cdnUrl / assetId / rarity per new skin
  assets/images/*.png   150x150 pictures of the new skins (Roblox thumbnails)
  assets/wraps.js       WRAPS rows [name, rarity index, hidden, layers]
  assets/cosmetics.js   FINISHERS [name, rarity, icon file], CHARMS [name, rarity, picture or ""]
  assets/images/finishers/<id>.png
  ../RivalsSkinChangerFULLMATCHA/main.lua   ITEM_ICONS entries

The GUIs read the site's files, so they pick up the new items by themselves.

Usage: python tools/sync_new_items.py [--dry-run]
"""
import json
import os
import re
import sys
import urllib.request

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGER = os.path.join(os.path.dirname(SITE), "RivalsSkinChangerFULLMATCHA", "main.lua")
WS = r"C:\matcha\workspace"
DRY = "--dry-run" in sys.argv


def read(p):
    return open(p, encoding="utf-8", newline="").read()


def write(p, s):
    if DRY:
        print("  (dry run) would write", os.path.relpath(p, SITE))
        return
    open(p, "w", encoding="utf-8", newline="").write(s)


def unescape(s):
    return s.replace("\\'", "'").replace('\\"', '"')


cos = read(os.path.join(WS, "_dec_CosmeticLibrary_new.lua"))
items = read(os.path.join(WS, "_dec_ItemLibrary_new.lua"))

# The game's lists
game_skins = [(r, unescape(w), unescape(n)) for r, w, n in
              re.findall(r'^v100\("([^"]+)", "([^"]+)", "((?:[^"\\]|\\.)+)"', cos, re.M)
              if not n.startswith("MISSING")]
other = [(t, r, unescape(n), img) for t, r, n, img in
         re.findall(r'^v_u_90\("([^"]+)", "([^"]+)", "((?:[^"\\]|\\.)+)", (nil|"[^"]*")', cos, re.M)
         if not n.startswith("MISSING")]
vm_image = {unescape(n): img for n, img in re.findall(r'^v96\("((?:[^"\\]|\\.)+)", "rbxassetid://(\d+)"', items, re.M)}

# --- Roblox thumbnails -------------------------------------------------------
def thumbnails(ids):
    out = {}
    ids = sorted(set(ids))
    for i in range(0, len(ids), 50):
        chunk = ",".join(ids[i:i + 50])
        url = "https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=150x150&format=Png&isCircular=false" % chunk
        data = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30))
        for d in data.get("data", []):
            if d.get("state") == "Completed" and d.get("imageUrl"):
                out[str(d["targetId"])] = d["imageUrl"]
    return out


def download(url, path):
    if os.path.exists(path):
        return False
    if DRY:
        print("  (dry run) would download", os.path.relpath(path, SITE))
        return True
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read()
    open(path, "wb").write(data)
    return True


def slug(name):
    return re.sub(r"[^a-z0-9]", "-", name.lower())


# --- Skins: index.html + skin_icon_map.json + pictures -----------------------
html_path = os.path.join(SITE, "index.html")
html = read(html_path)
start = html.index("const OFFICIAL_WEAPON_DATA = ") + len("const OFFICIAL_WEAPON_DATA = ")
end = html.index("];", start) + 1
weapons = json.loads(html[start:end])
assert json.dumps(weapons, indent=2, ensure_ascii=False) == html[start:end].replace("\r\n", "\n"), "OFFICIAL_WEAPON_DATA would not round-trip"
by_weapon = {w["name"]: w for w in weapons}

new_skins = [(r, w, n) for r, w, n in game_skins if w in by_weapon and n not in by_weapon[w]["skins"]]
unknown_weapons = sorted({w for _, w, _ in game_skins if w not in by_weapon})
print("new skins:", len(new_skins), [n for _, _, n in new_skins])
if unknown_weapons:
    print("WEAPONS NOT ON THE SITE (add them by hand):", unknown_weapons)
for r, w, n in new_skins:
    lst = by_weapon[w]["skins"]
    rest = lst[1:]
    keep_sorted = rest == sorted(rest)
    rest.append(n)
    if keep_sorted:
        rest.sort()
    by_weapon[w]["skins"] = [lst[0]] + rest
if new_skins:
    nl = "\r\n" if "\r\n" in html[start:end] else "\n"
    html = html[:start] + json.dumps(weapons, indent=2, ensure_ascii=False).replace("\n", nl) + html[end:]
    write(html_path, html)

map_path = os.path.join(SITE, "skin_icon_map.json")
icon_map_raw = read(map_path)
icon_map = json.loads(icon_map_raw)
need = [(r, w, n) for r, w, n in game_skins if w in icon_map and n not in icon_map[w]] + \
       [(r, w, n) for r, w, n in new_skins if w not in icon_map]
thumbs = thumbnails([vm_image[n] for _, _, n in need if n in vm_image])
added_map = 0
for r, w, n in need:
    aid = vm_image.get(n)
    if not aid:
        print("  no ItemLibrary image for", n)
        continue
    src = "assets/images/%s.png" % slug(n)
    icon_map.setdefault(w, {})[n] = {"src": src, "cdnUrl": thumbs.get(aid, ""), "assetId": aid, "rarity": r}
    added_map += 1
    if thumbs.get(aid):
        download(thumbs[aid], os.path.join(SITE, src))
    else:
        print("  no thumbnail yet for", n, aid)
if added_map:
    nl = "\r\n" if "\r\n" in icon_map_raw else "\n"
    write(map_path, json.dumps(icon_map, indent=2, ensure_ascii=False).replace("\n", nl) + ("\n" if icon_map_raw.endswith("\n") else ""))
print("skin_icon_map entries added:", added_map)

# --- Wraps: assets/wraps.js --------------------------------------------------
wraps_path = os.path.join(SITE, "assets", "wraps.js")
wraps_js = read(wraps_path)
m = re.search(r"window\.WRAPS=(\[.*\]);", wraps_js, re.S)
wraps = json.loads(m.group(1))
assert json.dumps(wraps, separators=(",", ":"), ensure_ascii=False) == m.group(1), "WRAPS would not round-trip"
rar = [r[0] for r in json.loads(re.search(r"window\.WRAP_RARITIES=(\[.*?\]);", wraps_js, re.S).group(1))]
have = {w[0] for w in wraps}

tex = {}
tex_path = os.path.join(WS, "rivals_wraptextures.txt")
if os.path.exists(tex_path):
    for line in read(tex_path).splitlines():
        if "\t" in line:
            name, rest = line.split("\t", 1)
            ids = [x.split(":")[-1] for x in rest.split(",") if x]
            tex[name] = next((i for i in ids if i), "")


def call_at(src, i):
    depth = 0
    for j in range(i, len(src)):
        c = src[j]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return src[i:j + 1]


def split_top(s):
    parts, depth, cur = [], 0, ""
    for c in s:
        if c in "({[":
            depth += 1
        if c in ")}]":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += c
    if cur.strip():
        parts.append(cur.strip())
    return parts


def color_hex(expr):
    m = re.match(r"Color3\.fromRGB\((\d+),\s*(\d+),\s*(\d+)\)", expr or "")
    return "#%02x%02x%02x" % tuple(int(x) for x in m.groups()) if m else "#ffffff"


new_wraps = []
for m2 in re.finditer(r'^v122\("([^"]+)", "((?:[^"\\]|\\.)+)"', cos, re.M):
    rarity, name = m2.group(1), unescape(m2.group(2))
    if name in have or name.startswith("MISSING") or rarity not in rar:
        continue
    args = split_top(call_at(cos, m2.start())[len("v122("):-1])
    layers = []
    for g in args[2:5]:
        if g in ("nil", ""):
            continue
        f = split_top(g.strip()[1:-1])
        f += ["nil"] * (6 - len(f))
        mat = f[0]
        if mat.startswith('"'):
            mat = "v:" + mat.strip('"')
        elif mat.startswith("Enum.Material."):
            mat = mat[len("Enum.Material."):]
        else:
            mat = "SmoothPlastic"
        transp = float(f[2]) if re.match(r"^[\d.]+$", f[2]) else 0.0
        texname = f[4].strip('"') if f[4].startswith('"') else ""
        tid = int(tex.get(texname) or 0) if texname else 0
        if texname and not tid:
            print("  wrap", name, "texture", texname, "has no image id (dump rivals_wraptextures.txt)")
        layers.append([mat, color_hex(f[1]), transp, tid])
    hidden = 1 if len(args) > 5 and args[5].strip() == "true" else 0
    new_wraps.append([name, rar.index(rarity), hidden, layers])
print("new wraps:", [w[0] for w in new_wraps])
if new_wraps:
    wraps += new_wraps
    wraps.sort(key=lambda r: (r[1], r[0].lower()))
    write(wraps_path, wraps_js[:m.start(1)] + json.dumps(wraps, separators=(",", ":"), ensure_ascii=False) + wraps_js[m.end(1):])

# --- Finishers and charms: assets/cosmetics.js --------------------------------
cos_path = os.path.join(SITE, "assets", "cosmetics.js")
cos_js = read(cos_path)
changed = False
fin_icons = {}
for kind, var in (("Finisher", "FINISHERS"), ("Charm", "CHARMS")):
    mm = re.search(r"window\." + var + r"=(\[.*?\]);", cos_js, re.S)
    rows = json.loads(mm.group(1))
    assert json.dumps(rows, separators=(",", ":"), ensure_ascii=False) == mm.group(1), var + " would not round-trip"
    have = {r[0] for r in rows}
    add = []
    for t, r, n, img in other:
        if t != kind or n in have:
            continue
        pic = ""
        aid = re.search(r"(\d+)", img or "")
        if kind == "Finisher" and aid:
            pic = aid.group(1) + ".png"
            fin_icons[aid.group(1)] = pic
        add.append([n, r, pic])
    print("new %s:" % var.lower(), [a[0] for a in add])
    if add:
        rows += add
        rows.sort(key=lambda r: r[0].lower())
        cos_js = cos_js[:mm.start(1)] + json.dumps(rows, separators=(",", ":"), ensure_ascii=False) + cos_js[mm.end(1):]
        changed = True
if changed:
    write(cos_path, cos_js)
if fin_icons:
    th = thumbnails(list(fin_icons))
    for aid, fn in fin_icons.items():
        if th.get(aid):
            download(th[aid], os.path.join(SITE, "assets", "images", "finishers", fn))
        else:
            print("  no thumbnail for finisher icon", aid)

# --- Changer: ITEM_ICONS hotbar icons ----------------------------------------
if os.path.exists(CHANGER):
    lua = read(CHANGER)
    nl = "\r\n" if "\r\n" in lua else "\n"
    lua = lua.replace("\r\n", "\n")
    a = lua.index("local ITEM_ICONS = {\n")
    b = lua.index("\n}\n", a)
    block = lua[a:b]
    added = []
    for r, w, n in game_skins:
        aid = vm_image.get(n)
        hdr = '    ["%s"] = {\n' % w
        if not aid or hdr not in block:
            continue
        ws = block.index(hdr) + len(hdr)
        we = block.index("\n    },", ws)
        lines = block[ws:we].split("\n")
        keys = [re.match(r'\s*\["(.*)"\]', l).group(1) for l in lines if re.match(r'\s*\["(.*)"\]', l)]
        if n in keys:
            continue
        entry = '        ["%s"] = "rbxassetid://%s",' % (n.replace('"', '\\"'), aid)
        pos = len(lines)
        for i, k in enumerate(keys):
            if k != "Standard" and k.lower() > n.lower():
                pos = i
                break
        lines.insert(pos, entry)
        block = block[:ws] + "\n".join(lines) + block[we:]
        added.append(n)
    print("ITEM_ICONS added:", added)
    if added:
        lua = lua[:a] + block + lua[b:]
        write(CHANGER, lua.replace("\n", nl))
