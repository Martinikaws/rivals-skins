"""Make a lighting preset for each uploaded sky from the sky's own colours.

Sky colour (the top and the upper half of the sides) tints the outdoor
light, the horizon band tints the ambient light and the fog, and how bright
the sky is sets brightness and exposure. Writes lighting.lua (entries for
LIGHTING_PRESETS in the changer), named like the skies.
"""
import os
import numpy as np
from PIL import Image
from publish_skies import display_name

HERE = os.path.dirname(os.path.abspath(__file__))
PREPARED = os.path.join(HERE, "prepared")


def load(sky, face):
    return np.asarray(Image.open(os.path.join(PREPARED, sky, face + ".png")).convert("RGB").resize((64, 64)), dtype=float) / 255


def hexc(rgb):
    rgb = np.clip(rgb, 0, 1)
    return "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in rgb)


def luminance(rgb):
    return float(0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2])


def scaled(rgb, target):
    """Same hue as rgb, at luminance target, and not fully saturated."""
    lum = max(luminance(rgb), 1e-3)
    tinted = rgb * (target / lum)
    grey = np.array([target, target, target])
    return 0.65 * tinted + 0.35 * grey


def preset(sky):
    sides = [load(sky, f) for f in ("ft", "bk", "lf", "rt")]
    upper = np.concatenate([s[:24].reshape(-1, 3) for s in sides] + [load(sky, "up").reshape(-1, 3)])
    band = np.concatenate([s[26:38].reshape(-1, 3) for s in sides])
    sky_col, horizon = upper.mean(0), band.mean(0)
    lum = luminance(sky_col)
    # Bright day skies land near Roblox's defaults; dark space skies go dim.
    brightness = round(float(np.clip(0.4 + 3.2 * lum, 0.4, 3)), 2)
    exposure = round(float(np.clip((lum - 0.42) * 1.6, -1.1, 0.3)), 2)
    outdoor = scaled(sky_col, float(np.clip(0.18 + 0.6 * lum, 0.12, 0.55)))
    ambient = scaled(horizon, float(np.clip(0.08 + 0.35 * lum, 0.05, 0.32)))
    return {
        "brightness": brightness, "exposure": exposure, "diffuse": 1, "specular": 1,
        "ambient": hexc(ambient), "outdoor": hexc(outdoor), "fogcolor": hexc(horizon),
    }, lum


def main():
    lines = []
    for sky in sorted(os.listdir(PREPARED), key=lambda k: (not k.startswith("cloudy"), k)):
        p, lum = preset(sky)
        body = ", ".join('%s = %s' % (k, ('"%s"' % v) if isinstance(v, str) else v)
                         for k, v in p.items())
        lines.append('    ["%s"] = {%s},' % (display_name(sky).lower(), body))
        print("%-12s sky lum %.2f  %s" % (sky, lum, body))
    with open(os.path.join(HERE, "lighting.lua"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
