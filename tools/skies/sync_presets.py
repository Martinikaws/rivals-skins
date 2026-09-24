"""After upload_skies.py: refresh everything that lists the uploaded skies.

Runs publish_skies.py (site list + previews + skies.lua) and
lighting_from_skies.py (lighting.lua), then writes both into the changer's
SKYBOX_PRESETS / LIGHTING_PRESETS and rebuilds the menu's sky groups. Menu
dropdowns can't scroll, so groups hold at most 13 skies.

    python sync_presets.py [changer.lua] [menu.lua]
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CHANGER = sys.argv[1] if len(sys.argv) > 1 else r"C:\matcha\scripts\RivalsSkinSwapper.lua"
MENU = sys.argv[2] if len(sys.argv) > 2 else r"C:\matcha\scripts\RivalsSkinGui.lua"
GROUP_MAX = 13
SPACE = ["galaxy", "blue nebula", "gold nebula"]


def between(src, start, end):
    a = src.index(start) + len(start)
    return a, src.index(end, a)


def main():
    for script in ("publish_skies.py", "lighting_from_skies.py"):
        subprocess.run([sys.executable, os.path.join(HERE, script)], check=True, cwd=HERE)
    skies = open(os.path.join(HERE, "skies.lua"), encoding="utf-8").read().rstrip("\n")
    lighting = open(os.path.join(HERE, "lighting.lua"), encoding="utf-8").read().rstrip("\n")
    names = [line.split('"')[1] for line in skies.splitlines()]

    src = open(CHANGER, encoding="utf-8").read()
    a, b = between(src, "    -- Uploaded skybox packs (tools/skies in the site repo), bk, dn, ft, lf, rt, up.\n",
                   '\n    ["classic"]')
    src = src[:a] + skies + src[b:]
    a, b = between(src, "    -- One per uploaded sky, from its colours (tools/skies/lighting_from_skies.py).\n"
                        '    -- "Preset=match" picks the one named like the current skybox.\n', "\n}")
    src = src[:a] + lighting + src[b:]
    open(CHANGER, "w", encoding="utf-8").write(src)

    cloudy = [n for n in names if n.startswith("cloudy ")]
    rest = sorted(n for n in names if not n.startswith("cloudy ") and n not in SPACE)
    groups = ['    {name = "Off", skies = {}},',
              '    {name = "Game skies", skies = {"blue", "space", "graveyard", "sudden death", "station", "westown", "black", "gray", "classic"}},']
    # 1-12 and 13-25, as the menu always had them.
    for part in (cloudy[:12], cloudy[12:]):
        if not part:
            continue
        groups.append('    {name = "Cloudy %d-%d", skies = {%s}},' % (
            int(part[0].split()[1]), int(part[-1].split()[1]), ", ".join('"%s"' % n for n in part)))
    groups.append('    {name = "Space", skies = {%s}},' % ", ".join('"%s"' % n for n in SPACE if n in names))
    for i in range(0, len(rest), GROUP_MAX):
        part = rest[i:i + GROUP_MAX]
        groups.append('    {name = "More %s-%s", skies = {%s}},' % (
            part[0][0].upper(), part[-1][0].upper(), ", ".join('"%s"' % n for n in part)))
    menu = open(MENU, encoding="utf-8").read()
    a, b = between(menu, "local SKY_GROUPS = {\n", "\n}")
    menu = menu[:a] + "\n".join(groups) + menu[b:]
    open(MENU, "w", encoding="utf-8").write(menu)
    print("%d uploaded skies in the changer and %d menu groups" % (len(names), len(groups)))


if __name__ == "__main__":
    main()
