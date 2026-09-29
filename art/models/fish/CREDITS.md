# Fishing models

| Model | Source | Licence |
|---|---|---|
| The pond's fish (rudd, crucian carp, perch, carp, tench, trout, zander, pike, wels catfish), their grilled variants, the crayfish, the fishing rod and its float | Modelled and textured for FarmCraft by `tools/blender/make_fishing.py` | Project's own |
| Old rubber boot | *Rubber Boots*, Poly Haven, https://polyhaven.com/a/rubber_boots | CC0 |

Changes: one boot of the pair, with the model's "dirty" texture set, stood on its sole.
`tools/fetch_fishing.py` downloads the boot and runs the Blender script, which writes
`<name>.gltf` / `.bin` here and the textures to `textures/`.
