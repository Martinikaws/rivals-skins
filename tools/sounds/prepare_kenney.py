"""Pick hit/headshot/kill-friendly sounds from the Kenney packs (CC0) and write
them as trimmed, levelled 16-bit mono WAVs, ready for upload_sounds.py and for
the site's play buttons.

    python prepare_kenney.py
"""
import io
import json
import os
import re
import zipfile

import miniaudio
import numpy as np
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
PACKS = os.path.join(HERE, "packs")
OUT = os.path.join(HERE, "prepared", "kenney")
RATE = 44100

# (pack, file-name pattern, display name). The first file matching the
# pattern (sorted) is used, e.g. impactPunch_heavy_000.
PICKS = [
    ("impact-sounds", r"impactPunch_heavy_000", "Punch heavy"),
    ("impact-sounds", r"impactPunch_medium_000", "Punch"),
    ("impact-sounds", r"impactMetal_light_000", "Metal tap"),
    ("impact-sounds", r"impactMetal_heavy_000", "Metal clang"),
    ("impact-sounds", r"impactGlass_light_000", "Glass tap"),
    ("impact-sounds", r"impactGlass_heavy_000", "Glass smash"),
    ("impact-sounds", r"impactBell_heavy_000", "Bell hit"),
    ("impact-sounds", r"impactPlate_light_000", "Plate tap"),
    ("impact-sounds", r"impactTin_medium_000", "Tin hit"),
    ("impact-sounds", r"impactSoft_heavy_000", "Soft thud"),
    ("interface-sounds", r"click_001", "Click"),
    ("interface-sounds", r"tick_001", "Tick"),
    ("interface-sounds", r"confirmation_001", "Confirm"),
    ("interface-sounds", r"glass_001", "Glass ding"),
    ("interface-sounds", r"pluck_001", "Pluck"),
    ("interface-sounds", r"bong_001", "Bong"),
    ("interface-sounds", r"drop_001", "Drop"),
    ("interface-sounds", r"glitch_001", "Glitch"),
    ("digital-audio", r"zap1", "Zap"),
    ("digital-audio", r"zapTwoTone\b", "Zap two-tone"),
    ("digital-audio", r"pepSound1", "Pep"),
    ("digital-audio", r"highUp", "High up"),
    ("digital-audio", r"phaserUp1", "Phaser up"),
    ("digital-audio", r"powerUp1", "Power up"),
    ("digital-audio", r"threeTone1", "Three-tone"),
    ("sci-fi-sounds", r"laserSmall_000", "Small laser"),
    ("sci-fi-sounds", r"laserRetro_000", "Retro laser"),
    ("sci-fi-sounds", r"explosionCrunch_000", "Explosion crunch"),
]


def clean(samples):
    """Trim leading/trailing silence and level the peak to -1 dBFS."""
    a = np.asarray(samples, dtype=np.float32)
    loud = np.nonzero(np.abs(a) > 0.01)[0]
    if len(loud):
        a = a[max(0, loud[0] - 44):loud[-1] + 441]
    peak = float(np.abs(a).max()) or 1.0
    a = a * (0.891 / peak)
    fade = min(len(a), 441)
    a[-fade:] *= np.linspace(1, 0, fade)
    return (a * 32767).astype(np.int16)


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def main():
    os.makedirs(OUT, exist_ok=True)
    listing = []
    for pack, pattern, name in PICKS:
        z = zipfile.ZipFile(os.path.join(PACKS, "kenney_%s.zip" % pack))
        files = sorted(n for n in z.namelist() if re.search(r"\.(ogg|wav|mp3)$", n, re.I)
                       and re.search(pattern, n.rsplit("/", 1)[-1], re.I) and "preview" not in n.lower())
        if not files:
            print("missing", pack, pattern)
            continue
        d = miniaudio.decode(z.read(files[0]), output_format=miniaudio.SampleFormat.FLOAT32,
                             nchannels=1, sample_rate=RATE)
        pcm = clean(np.frombuffer(d.samples, dtype=np.float32))
        key = "kenney-" + slug(name)
        wavfile.write(os.path.join(OUT, key + ".wav"), RATE, pcm)
        listing.append({"key": key, "name": name, "source": "Kenney %s (CC0)" % pack.replace("-", " "),
                        "file": files[0].rsplit("/", 1)[-1], "seconds": round(len(pcm) / RATE, 2)})
        print("%-26s %5.2fs  from %s" % (name, len(pcm) / RATE, files[0].rsplit("/", 1)[-1]))
    with open(os.path.join(OUT, "sounds.json"), "w", encoding="utf-8") as f:
        json.dump(listing, f, indent=2)
    print("%d sounds -> %s" % (len(listing), OUT))


if __name__ == "__main__":
    main()
