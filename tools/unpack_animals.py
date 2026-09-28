#!/usr/bin/env python3
"""Unpacks the downloaded Sketchfab animal zips (glTF format) into
art/models/animals/source/<species>/ and writes the CC-BY credits.

Each zip is recognised by the model id in its license.txt, so the file names do
not matter. Usage: python3 tools/unpack_animals.py [folder with the zips ...]
(default: art/models/animals/source/)
"""
import pathlib
import re
import shutil
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEST = ROOT / "art/models/animals/source"

MODELS = {
    "4fe2c9d43532498081a30f1794758954": "cow",
    "a6f860e43e364619bccb174a1ac7d0c9": "horse",
    "08b05ae799d947f1a68c49b2d661eb53": "sheep",
    "4ab19d3a675343959815ae770f8b178e": "chicken",
}


def species_of(z: zipfile.ZipFile):
    for name in z.namelist():
        if name.lower().endswith("license.txt"):
            text = z.read(name).decode("utf-8", "replace")
            for uid, species in MODELS.items():
                if uid in text:
                    return species, text
    return None, ""


def main() -> None:
    folders = [pathlib.Path(a).expanduser() for a in sys.argv[1:]] or [DEST]
    credits = {}
    credits_file = DEST / "CREDITS.md"
    for folder in folders:
        for path in sorted(folder.glob("*.zip")):
            with zipfile.ZipFile(path) as z:
                species, license_text = species_of(z)
                if species is None:
                    print(f"skip {path.name}: not one of the expected models")
                    continue
                out = DEST / species
                if out.exists():
                    shutil.rmtree(out)
                out.mkdir(parents=True)
                z.extractall(out)
                credits[species] = license_text.strip()
                print(f"{path.name} -> {out.relative_to(ROOT)}")
    # Credits for everything unpacked so far, not just this run.
    for lic in sorted(DEST.glob("*/license.txt")):
        credits[lic.parent.name] = lic.read_text(encoding="utf-8", errors="replace").strip()
    if credits:
        lines = ["# Animal model credits", "",
                 "Photo-textured animal models downloaded from Sketchfab under Creative Commons",
                 "Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/). Changes: rescaled,",
                 "re-oriented, re-shaded (coat colour variants, wetness, shearing) and animated in game.",
                 ""]
        for species in sorted(credits):
            lines += [f"## {species}", "", "```", credits[species], "```", ""]
        credits_file.write_text("\n".join(lines), encoding="utf-8")
        print(f"wrote {credits_file.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
