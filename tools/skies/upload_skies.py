"""Upload the prepared sky faces to Roblox as Images and record their ids.

Needs two environment variables, set by you in your own terminal:
    ROBLOX_API_KEY   an Open Cloud key with the Assets API, Read + Write
    ROBLOX_USER_ID   your Roblox user id (the number in your profile URL)

    python upload_skies.py              upload every sky not uploaded yet
    python upload_skies.py cloudy-01    upload just that sky (for a test)

Ids land in sky_ids.json next to this file. Faces already in it are
skipped, so a failed run can simply be started again.
"""
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
PREPARED = os.path.join(HERE, "prepared")
IDS = os.path.join(HERE, "sky_ids.json")
API = "https://apis.roblox.com/assets/v1/"
FACES = ["bk", "dn", "ft", "lf", "rt", "up"]


def call(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers=dict(headers or {}, **{"x-api-key": key}))
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        raise RuntimeError("HTTP %d: %s" % (e.code, detail)) from None


def upload(path, name, key, user, asset_type="Image"):
    boundary = uuid.uuid4().hex
    meta = {
        "assetType": asset_type,
        "displayName": name[:50],
        "description": "Rivals skin changer " + ("sky face" if asset_type == "Image" else "sound"),
        "creationContext": {"creator": {"userId": str(user)}},
    }
    with open(path, "rb") as f:
        data = f.read()
    ctype = mimetypes.guess_type(path)[0] or "image/png"
    body = (
        ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % boundary).encode()
        + json.dumps(meta).encode()
        + ("\r\n--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
           % (boundary, os.path.basename(path), ctype)).encode()
        + data
        + ("\r\n--%s--\r\n" % boundary).encode()
    )
    op = call("POST", API + "assets", key, body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            asset = (op.get("response") or {}).get("assetId")
            if not asset:
                raise RuntimeError("upload finished without an id: %s" % json.dumps(op)[:300])
            return str(asset)
        time.sleep(2)
        op = call("GET", API + "operations/" + op_id, key)
    raise RuntimeError("timed out waiting for Roblox to finish " + name)


def main():
    key, user = os.environ.get("ROBLOX_API_KEY"), os.environ.get("ROBLOX_USER_ID")
    if not key or not user:
        print("Set ROBLOX_API_KEY and ROBLOX_USER_ID first (see the top of this file).")
        return 1
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    skies = sys.argv[1:] or sorted(os.listdir(PREPARED))
    for sky in skies:
        ids.setdefault(sky, {})
        for face in FACES:
            if ids[sky].get(face) or not os.path.exists(os.path.join(PREPARED, sky, face + ".png")):
                continue
            try:
                ids[sky][face] = upload(os.path.join(PREPARED, sky, face + ".png"), "sky %s %s" % (sky, face), key, user)
                print("%s %s -> %s" % (sky, face, ids[sky][face]))
            except Exception as e:
                print("%s %s FAILED: %s" % (sky, face, e))
            finally:
                with open(IDS, "w") as f:
                    json.dump(ids, f, indent=2, sort_keys=True)
            time.sleep(0.5)
    missing = [s + "/" + f for s in skies for f in FACES
               if not ids.get(s, {}).get(f) and os.path.exists(os.path.join(PREPARED, s, f + ".png"))]
    print("done: %d skies, %s" % (len(skies), ("missing " + ", ".join(missing)) if missing else "all faces uploaded"))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
