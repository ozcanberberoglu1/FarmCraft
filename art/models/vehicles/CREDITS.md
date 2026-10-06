# Vehicle model credits

Models downloaded from Sketchfab under Creative Commons Attribution 4.0
(https://creativecommons.org/licenses/by/4.0/). Changes: re-pivoted wheels, re-shaded
(game shaders for paint, trim, wheels and glass; rust textures from Poly Haven, CC0),
Turkish number plates added (plates/, drawn by tools/make_vehicle_plates.py with the
game's Barlow Condensed font, SIL OFL), driven by the game's vehicle physics.

## pickup_90

"Lightbody '90 MD Pickup - Low poly model"
(https://sketchfab.com/3d-models/lightbody-90-md-pickup-low-poly-model-3b3ac59245c44872b06ad85673be9643)
by Daniel Zhabotinsky (https://sketchfab.com/DanielZhabotinsky), CC-BY-4.0.

## Modelled parts (pickup_90/hd_parts.glb)

The pickup's tyres (all-terrain tread, sidewall serrations and lettering), steel rims
with lug nuts and hub caps, brake discs and drums, and its steering wheel are modelled
for this game by tools/build_pickup_hd.py (Blender, headless) and replace the model's
own low-poly wheels and steering wheel. The sidewall lettering is cut from Barlow
Condensed Bold (art/fonts, SIL Open Font License 1.1). No outside assets.

## The pickup's other bodies (pickup_90/canopy.glb, stake.glb, box.glb)

The fibreglass canopy, the stake-bed deck and the aluminium box body that go on the
Lightbody '90 chassis (the game hides the steel bed where they replace it) are modelled
for this game by tools/blender/build_pickup_variants.py (Blender, headless). No outside
assets; the deck's planks are drawn with Poly Haven's "Weathered Brown Planks" (CC0,
art/textures/weathered_brown_planks).

## Estate, four-by-four, light truck and tractor (wagon/, offroad/, truck/, tractor/)

The "Atmaca 1600" estate, the "Kaya 88" four-by-four, the "Yayla 35" dropside truck and
the "Tarla 45" tractor are fictional vehicles modelled for this game from primitives by
tools/blender/build_wagon.py, build_offroad.py, build_truck.py and build_tractor.py
(shared kit: tools/blender/vehicle_kit.py). Their road wheels are the pickup's modelled
wheel (tools/build_pickup_hd.py) fitted to each tyre size; the tractor's bar-lug and
ribbed tyres, rims and lettering are modelled in build_tractor.py (lettering in Barlow
Condensed Bold, SIL Open Font License 1.1). No outside assets; Turkish number plates
by tools/make_vehicle_plates.py.

## The pickup's cab (pickup_90/interior.glb) and the cabs' textures (art/textures/cab)

The pickup's cab interior (dashboard with its instruments, vents, radio and heater
panel, steering column, seats, door cards, console, pedals, matting, headliner, sun
visors, mirror, seat belts and the trim round them) is modelled for this game by
tools/blender/build_pickup_interior.py with the shared cab kit tools/blender/cab_kit.py
(Blender, headless) and replaces the downloaded model's low-poly cab. The grain sets of
every cab (moulded plastic, vinyl, woven cloth, ribbed rubber, perforated headliner) and
the sheet of printed faces (dials, radio, heater panel, speaker grille, gear pattern,
visor label) are drawn by tools/make_cab_textures.py (noise, weaves and line drawing;
lettering in Barlow Condensed Bold, art/fonts, SIL Open Font License 1.1). No outside assets.
