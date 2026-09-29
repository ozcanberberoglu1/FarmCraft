# Localization

All game text lives in `localization/strings.csv` (Godot imports it into one
`.translation` per language). Columns: `keys`, then 13 languages:
`en, tr, de, es, fr, it, pt_BR, ru, pl, ja, ko, zh_CN, zh_TW`.
English is the fallback: an empty cell shows the English text.

Check the file after any change:

    python3 tools/check_strings.py

It reports untranslated cells, duplicate keys and translations whose `%d`/`%s`/`%02d`
arguments differ from the English (the game fills them by position, so their number
and order must match; a literal `%%` may move, e.g. Turkish `%75`).

## Adding text

1. Add a row with the key, English and Turkish; translate the other columns.
2. Keep the conventions the existing translations use: one term per concept (dollar,
   bag, warehouse, pickup bed, trough...), informal "you", short upper-case-friendly
   button labels, `ACTION_*` as short prompt verbs, `QUEST_*` as imperative goals.
   Proper names stay as they are: FarmCraft, Yeşilova, Ova Petrol, author names.
3. Russian and Polish: avoid gendered past tense for "you" and phrasings that need
   a plural form per number ("Units: %d" rather than "%d units").
4. Run `tools/check_strings.py` and reimport (`godot --headless --path . --import`).

## Fonts and formatting

- Barlow / Barlow Condensed draw Latin text; Noto Sans (OFL, `art/fonts/noto/`) is
  their fallback for Cyrillic and the CJK scripts, with the current language's CJK
  face first (Japanese, Korean and Chinese draw some shared characters differently).
  Variable-font axes must be set with numeric OpenType tags (`name_to_tag("wght")`),
  string names are ignored.
- `UiTheme.caps()` upper-cases per language (Turkish i → İ); CJK text gets no letter
  spacing; `UiTheme.money()`, `percent()`, `date_time()` and `join_list()` follow the
  language's separators; `UiTheme.fit_label()` shrinks or wraps names in fixed tiles.
- The game starts in the system language (Settings.detect_language); the language
  can be switched in Settings → General, which rebuilds the scene in place.
- Screenshots and tests can force a language: `-- --lang=ja`.
