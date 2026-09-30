# Fishing models

| Model | Source | Licence |
|---|---|---|
| The pond's fish (rudd, crucian carp, perch, carp, tench, rainbow trout, zander, pike, wels catfish, roach, bleak, gudgeon, bream, chub, barbel, eel, grass carp, silver carp, brown trout, sturgeon), their grilled variants, the crayfish, the rods (standard, cane pole, carbon spinning rod, carp rod) and the float, the market's bait (maggot tin, sweetcorn tin, cheese cubes, minnow bucket, spinner lure) | Modelled and textured for FarmCraft by `tools/blender/make_fishing.py` | Project's own |
| Old rubber boot | *Rubber Boots*, Poly Haven, https://polyhaven.com/a/rubber_boots | CC0 |

Changes: one boot of the pair, with the model's "dirty" texture set, stood on its sole.
`tools/fetch_fishing.py` downloads the boot and runs the Blender script, which writes
`<name>.gltf` / `.bin` here and the textures to `textures/`.
