"""Upload the prepared Kenney sounds to Roblox as Audio and record their ids.

Same environment variables as tools/skies/upload_skies.py:
    ROBLOX_API_KEY   Open Cloud key with the Assets API, Read + Write
    ROBLOX_USER_ID   your Roblox user id

    python upload_sounds.py

Ids land in sound_ids.json; sounds already in it are skipped, so a failed run
can be started again. Uploaded audio is private: to make it play in Rivals,
open each one on create.roblox.com and switch on "Distribute on Creator Store"
(the upload API can't do that part).
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skies"))
from upload_skies import upload  # noqa: E402  same multipart upload, different asset type

HERE = os.path.dirname(os.path.abspath(__file__))
PREPARED = os.path.join(HERE, "prepared", "kenney")
IDS = os.path.join(HERE, "sound_ids.json")


def main():
    key, user = os.environ.get("ROBLOX_API_KEY"), os.environ.get("ROBLOX_USER_ID")
    if not key or not user:
        print("Set ROBLOX_API_KEY and ROBLOX_USER_ID first (see the top of this file).")
        return 1
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    listing = json.load(open(os.path.join(PREPARED, "sounds.json"), encoding="utf-8"))
    for item in listing:
        if ids.get(item["key"]):
            continue
        path = os.path.join(PREPARED, item["key"] + ".wav")
        try:
            ids[item["key"]] = upload(path, item["name"], key, user, asset_type="Audio")
            print("%s -> %s" % (item["name"], ids[item["key"]]))
        except Exception as e:
            print("%s FAILED: %s" % (item["name"], e))
        finally:
            with open(IDS, "w") as f:
                json.dump(ids, f, indent=2, sort_keys=True)
        time.sleep(0.5)
    missing = [i["name"] for i in listing if not ids.get(i["key"])]
    print("done: %s" % (("missing " + ", ".join(missing)) if missing else "all %d uploaded" % len(listing)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
