#!/usr/bin/env python3
"""Downloads the game's sounds and music into art/audio/.

Run from the project root:  python3 tools/fetch_audio.py
Sources (see art/audio/CREDITS.md):
  - Kenney (kenney.nl), CC0: footsteps, impacts, doors, cloth, UI sounds.
  - Mixkit (mixkit.co), Mixkit free license (free for commercial use in games, no
    attribution needed, files may not be redistributed on their own): animals, ambience,
    weather, vehicle, tool actions, coins and music.
  - The carnival night's band organ, crowd and fireworks: CC0 recordings from Freesound,
    cut by tools/build_carnival_audio.py (run at the end too; needs numpy and soundfile).
  - The recorded farm-work sounds (axe, pickaxe, hoe, scythe, harvest, planting, watering,
    felled trees, split boulders) are cut and mixed from public-domain / CC0 recordings
    (Wikimedia Commons, OpenGameArt, Freesound) and Mixkit recordings by
    tools/build_foley.py, which this script runs at the end (it needs numpy, scipy and
    soundfile). None of the sounds needs attribution or share-alike.
Files already present are skipped.
"""
import io
import os
import shutil
import urllib.request
import zipfile

ROOT = os.path.join(os.path.dirname(__file__), "..", "art", "audio")
HEADERS = {"User-Agent": "Mozilla/5.0 (FarmCraft audio fetcher)"}

# Mixkit sound effects: output path (under art/audio) -> sound id.
MIXKIT_SFX = {
    # Animals
    "sfx/animals/cow_moo_1.mp3": 1747,
    "sfx/animals/cow_moo_2.mp3": 1744,
    "sfx/animals/cow_moo_3.mp3": 1748,
    "sfx/animals/cow_moo_barn.mp3": 1751,
    "sfx/animals/cow_eat.mp3": 1767,
    "sfx/animals/cow_breath.mp3": 1746,
    "sfx/animals/sheep_baa_1.mp3": 1741,
    "sfx/animals/sheep_baa_2.mp3": 1760,
    "sfx/animals/sheep_baa_3.mp3": 1771,
    "sfx/animals/lamb_baa.mp3": 1764,
    "sfx/animals/hen_cluck_1.mp3": 1772,
    "sfx/animals/hen_cluck_2.mp3": 1766,
    "sfx/animals/rooster_1.mp3": 2470,
    "sfx/animals/rooster_2.mp3": 2462,
    "sfx/animals/horse_neigh.mp3": 1762,
    "sfx/animals/horse_snort.mp3": 80,
    "sfx/animals/horse_snore.mp3": 75,
    "sfx/animals/horse_walk_dirt.mp3": 78,
    "sfx/animals/horse_gallop_dirt.mp3": 77,
    "sfx/animals/horse_trot_road.mp3": 81,
    # Ambience and weather
    "ambience/farm_day.mp3": 1221,
    "ambience/night_crickets.mp3": 1789,
    "ambience/wind.mp3": 2658,
    "ambience/rain_light.mp3": 1253,
    "ambience/rain_heavy.mp3": 2400,
    "ambience/barn.mp3": 1754,
    "ambience/coop.mp3": 1756,
    "sfx/weather/thunder_1.mp3": 1298,
    "sfx/weather/thunder_2.mp3": 1278,
    "sfx/weather/thunder_3.mp3": 1297,
    # Vehicle
    "sfx/vehicle/engine_loop.mp3": 1553,
    "sfx/vehicle/engine_start.mp3": 1566,
    "sfx/vehicle/door_slam.mp3": 1564,
    # Tools and farm work
    "sfx/tools/dig_1.mp3": 1915,
    "sfx/tools/dig_2.mp3": 1917,
    "sfx/tools/dig_3.mp3": 1916,
    "sfx/tools/shovel_stab.mp3": 1918,
    "sfx/tools/shears_snip.mp3": 2378,
    "sfx/tools/swoosh.mp3": 2605,
    "sfx/tools/grass_cut.mp3": 1920,
    "sfx/tools/grass_heavy.mp3": 1922,
    "sfx/tools/milk_squirt.mp3": 1302,
    "sfx/tools/water_splash.mp3": 1311,
    "sfx/tools/water_fill.mp3": 1819,
    # Money
    "sfx/money/coins_clink.mp3": 1993,
    "sfx/money/coins_handle.mp3": 1939,
    "sfx/money/money_bag.mp3": 1989,
}

# Mixkit music: output path -> track id.
MIXKIT_MUSIC = {
    "music/day_relaxing_country.mp3": 23,
    "music/day_relaxing_in_nature.mp3": 522,
    "music/day_wind_leaves.mp3": 617,
    "music/day_the_long_road.mp3": 52,
    "music/night_relaxation.mp3": 749,
    # The fair's tunes on a carnival night in town (Carnival).
    "music/carnival_kidding_around.mp3": 9,
    "music/carnival_fun_and_games.mp3": 6,
}

# Kenney packs: zip url -> {file in zip (basename): output path}.
KENNEY = {
    "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip": {
        **{f"footstep_grass_00{i}.ogg": f"sfx/steps/grass_{i}.ogg" for i in range(5)},
        **{f"footstep_concrete_00{i}.ogg": f"sfx/steps/concrete_{i}.ogg" for i in range(5)},
        **{f"footstep_wood_00{i}.ogg": f"sfx/steps/wood_{i}.ogg" for i in range(5)},
        **{f"footstep_snow_00{i}.ogg": f"sfx/steps/gravel_{i}.ogg" for i in range(5)},
        **{f"impactWood_heavy_00{i}.ogg": f"sfx/tools/wood_hit_{i}.ogg" for i in range(5)},
        **{f"impactPlank_medium_00{i}.ogg": f"sfx/misc/plank_{i}.ogg" for i in range(5)},
        **{f"impactMetal_light_00{i}.ogg": f"sfx/misc/metal_{i}.ogg" for i in range(5)},
        **{f"impactSoft_medium_00{i}.ogg": f"sfx/misc/soft_{i}.ogg" for i in range(5)},
        "License.txt": "kenney_impact_license.txt",
    },
    "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip": {
        "doorOpen_1.ogg": "sfx/misc/door_open.ogg",
        "doorClose_1.ogg": "sfx/misc/door_close.ogg",
        "cloth1.ogg": "sfx/tools/brush_1.ogg",
        "cloth2.ogg": "sfx/tools/brush_2.ogg",
        "cloth3.ogg": "sfx/tools/brush_3.ogg",
        "metalPot1.ogg": "sfx/misc/pot_1.ogg",
        "metalPot2.ogg": "sfx/misc/pot_2.ogg",
        "handleCoins.ogg": "sfx/money/coins_small.ogg",
        "creak1.ogg": "sfx/misc/creak.ogg",
        "License.txt": "kenney_rpg_license.txt",
    },
    "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip": {
        "click_001.ogg": "sfx/ui/click.ogg",
        "select_001.ogg": "sfx/ui/hover.ogg",
        "open_001.ogg": "sfx/ui/open.ogg",
        "close_001.ogg": "sfx/ui/close.ogg",
        "confirmation_001.ogg": "sfx/ui/confirm.ogg",
        "error_004.ogg": "sfx/ui/error.ogg",
        "toggle_001.ogg": "sfx/ui/toggle.ogg",
        "drop_002.ogg": "sfx/ui/drop.ogg",
        "maximize_006.ogg": "sfx/ui/notify.ogg",
        "License.txt": "kenney_interface_license.txt",
    },
}


def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def save(rel, data):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return len(data)


def main():
    total = 0
    for rel, sid in MIXKIT_SFX.items():
        if not os.path.exists(os.path.join(ROOT, rel)):
            total += save(rel, fetch(f"https://assets.mixkit.co/active_storage/sfx/{sid}/{sid}-preview.mp3"))
    for rel, tid in MIXKIT_MUSIC.items():
        if not os.path.exists(os.path.join(ROOT, rel)):
            total += save(rel, fetch(f"https://assets.mixkit.co/music/{tid}/{tid}.mp3"))
    for url, files in KENNEY.items():
        if all(os.path.exists(os.path.join(ROOT, rel)) for rel in files.values()):
            continue
        z = zipfile.ZipFile(io.BytesIO(fetch(url)))
        names = {os.path.basename(n): n for n in z.namelist() if not n.endswith("/")}
        for base, rel in files.items():
            if base not in names:
                print(f"missing in {os.path.basename(url)}: {base}")
                continue
            total += save(rel, z.read(names[base]))
    print(f"downloaded {total / 1e6:.1f} MB")
    import build_foley
    try:
        build_foley.build()
    except ImportError as e:
        print(f"skipped the farm-work sounds ({e}): pip install numpy scipy soundfile, then run tools/build_foley.py")
    try:
        import build_carnival_audio
        build_carnival_audio.build()
    except ImportError as e:
        print(f"skipped the carnival sounds ({e}): pip install numpy soundfile, then run tools/build_carnival_audio.py")


if __name__ == "__main__":
    main()
