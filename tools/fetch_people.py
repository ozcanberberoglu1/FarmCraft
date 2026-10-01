#!/usr/bin/env python3
"""Downloads what Yeşilova's townspeople are built from and has Blender build them
(tools/blender/build_people.py): the MPFB2 add-on (MakeHuman for Blender, from
extensions.blender.org) and the CC0 MakeHuman asset packs (base mesh, skins, eyes,
hair, clothes). No account or login is needed for any of it.

MPFB2 itself is GPL code, but what it makes from the MakeHuman assets is CC0, like the
assets; see art/models/people/CREDITS.md. The add-on is installed into a Blender user
folder inside the cache (BLENDER_USER_RESOURCES), so the user's own Blender setup is
not touched.

Run from the project root:
    python3 tools/fetch_people.py              # download into ~/.cache/farmcraft_people
    python3 tools/fetch_people.py --build      # ... and build art/models/people/*.glb
    python3 tools/fetch_people.py --build --only farmer --preview /tmp/prev
Options: --cache <dir>, --blender <path to the Blender executable>.
Then import in Godot (godot --headless --path . --import).
"""
import hashlib
import os
import subprocess
import sys
import urllib.request
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEFAULT_CACHE = os.path.expanduser("~/.cache/farmcraft_people")
DEFAULT_BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
HEADERS = {"User-Agent": "FarmCraft-people-fetcher/1.0"}

MPFB = ("https://extensions.blender.org/download/sha256:4f0a879d64a39bf646fbf5f53601ac678855da329d650617dca5737548239a87/"
        "add-on-mpfb-v2.0.17.zip", "4f0a879d64a39bf646fbf5f53601ac678855da329d650617dca5737548239a87")
PACK_URL = "https://files.makehumancommunity.org/asset_packs/%s/%s_cc0.zip"
# All CC0 (see each pack's packs/<name>.json for the per-asset authors).
PACKS = ["makehuman_system_assets", "skins01", "skins02", "shirts01", "pants01", "shoes01", "hats01", "bodyparts05"]
# Single assets from the community site that no pack has (CC0): folder -> files. The vet's
# lab coat ("Crude lab coat open (female)" by Joel Palmius,
# http://www.makehumancommunity.org/clothes/crude_lab_coat_open_female.html).
SITE = "http://www.makehumancommunity.org/sites/default/files/clothes/1/"
SINGLES = {"crudelabcoatopen": [SITE + "1798072530/crudelabcoatopen.mhclo", SITE + "1405995134/crudelabcoatopen.obj",
                                SITE + "1282161064/crudelabcoatopen.mhmat", SITE + "216120273/crudelabcoatopen.thumb",
                                SITE + "1939352706/CrudeLabCoatOpenDiffuse.png"]}


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def download(url, path, sha=None):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return
    print("download", url)
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=600) as r, open(path + ".part", "wb") as f:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    if sha:
        h = hashlib.sha256(open(path + ".part", "rb").read()).hexdigest()
        if h != sha:
            raise SystemExit("checksum mismatch for " + url)
    os.replace(path + ".part", path)


def main():
    cache = os.path.abspath(arg("--cache", DEFAULT_CACHE))
    blender = arg("--blender", DEFAULT_BLENDER)
    os.makedirs(os.path.join(cache, "packs"), exist_ok=True)
    mpfb_zip = os.path.join(cache, "mpfb.zip")
    download(MPFB[0], mpfb_zip, MPFB[1])
    data = os.path.join(cache, "packs", "data")
    for pack in PACKS:
        z = os.path.join(cache, "packs", pack + "_cc0.zip")
        download(PACK_URL % (pack, pack), z)
        marker = os.path.join(cache, "packs", "." + pack)
        if not os.path.exists(marker):
            zipfile.ZipFile(z).extractall(data)
            open(marker, "w").close()
    for folder, urls in SINGLES.items():
        os.makedirs(os.path.join(data, "clothes", folder), exist_ok=True)
        for url in urls:
            download(url, os.path.join(data, "clothes", folder, url.rsplit("/", 1)[1]))
    env = dict(os.environ, BLENDER_USER_RESOURCES=os.path.join(cache, "bl_user"))
    home = os.path.join(cache, "bl_user", "extensions", ".user", "user_default", "mpfb")
    if not os.path.isdir(os.path.join(cache, "bl_user", "extensions", "user_default", "mpfb")):
        subprocess.check_call([blender, "-b", "--factory-startup", "--command", "extension", "install-file",
                               "-r", "user_default", "-e", mpfb_zip], env=env)
    # MPFB looks for its assets in <its user folder>/data.
    os.makedirs(home, exist_ok=True)
    link = os.path.join(home, "data")
    if os.path.isdir(link) and not os.path.islink(link):
        os.rmdir(link) if not os.listdir(link) else None
    if not os.path.exists(link):
        os.symlink(data, link)
    if "--build" not in sys.argv:
        return
    cmd = [blender, "-b", "--python", os.path.join(ROOT, "tools", "blender", "build_people.py"), "--",
           "--data", data, "--tmp", os.path.join(cache, "_textures"), "--out", os.path.join(ROOT, "art", "models", "people")]
    for opt in ("--only", "--preview"):
        if arg(opt):
            cmd += [opt, arg(opt)]
    subprocess.check_call(cmd, env=env)


if __name__ == "__main__":
    main()
