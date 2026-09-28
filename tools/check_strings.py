#!/usr/bin/env python3
"""Checks localization/strings.csv (the only source of the game's text, 13 languages):
every language has every key, and each translation keeps the English arguments
(%d, %s, %02d) in the same number and order (the game fills them by position); a
literal %% may move (Turkish writes the percent sign first).

Run from the project root:  python3 tools/check_strings.py
Exit code 1 when something is wrong. Empty cells fall back to English in the game.
New text: add a row with en and tr, then translate the other columns (see
docs/LOCALIZATION.md).
"""
import csv
import re
import sys

PATH = "localization/strings.csv"
PH = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[dsfx%]")


def args(text):
    """The positional arguments; a literal %% may sit anywhere ("%75" in Turkish)."""
    return [p for p in PH.findall(text) if p != "%%"]


def main():
    rows = list(csv.reader(open(PATH, newline="", encoding="utf-8")))
    header, body = rows[0], rows[1:]
    langs = header[1:]
    bad = []
    missing = {lang: [] for lang in langs}
    seen = set()
    for r in body:
        key = r[0]
        if key in seen:
            bad.append(f"duplicate key {key}")
        seen.add(key)
        en = r[1]
        for i, lang in enumerate(langs):
            v = r[i + 1] if i + 1 < len(r) else ""
            if v == "":
                missing[lang].append(key)
            elif args(v) != args(en):
                bad.append(f"{lang} {key}: placeholders {args(v)} != {args(en)}")
    print(f"{len(body)} keys, {len(langs)} languages")
    for lang, keys in missing.items():
        if keys:
            print(f"  {lang}: {len(keys)} untranslated: {', '.join(keys[:8])}{' ...' if len(keys) > 8 else ''}")
    for b in bad:
        print("  ERROR", b)
    sys.exit(1 if bad or any(missing.values()) else 0)


if __name__ == "__main__":
    main()
