# Produce and goods models

| Item | Model | Author | License | Source |
|---|---|---|---|---|
| Carrot, potatoes, strawberry, pumpkins | Lowpoly Fruits & Vegetables | Loïc Norgeot (from CC BY scans by the authors listed on the model page) | CC BY 4.0 | https://sketchfab.com/3d-models/lowpoly-fruits-vegetables-d3be8fed96eb48be88b47bbe8d2951e1 |
| Tomato | 4K Tomato Photogrammetry 3D Model - Low poly | Tayfun Özen | CC BY 4.0 | https://sketchfab.com/3d-models/4k-tomato-photogrammetry-3d-model-low-poly-e569c4763db04a32b2bc23361b82b3f0 |
| Eggplant | Eggplant (Game Ready / 2K PBR) | Meerschaum Digital | CC BY 4.0 | https://sketchfab.com/3d-models/eggplant-game-ready-2k-pbr-334a3ab0383f49d1bd34575a36ddf4d6 |
| Cheese | Half Cheese Wheel | Meerschaum Digital | CC BY 4.0 | https://sketchfab.com/3d-models/half-cheese-wheel-53eb788dee544f8c926638a27d7bea5a |
| Egg | Egg | Bandit | CC BY 4.0 | https://sketchfab.com/3d-models/egg-a96f2ce3d1ec429181031e97086d5b1f |
| Yarn | Ball Of Yarn | Mikko Haapoja | CC BY 4.0 | https://sketchfab.com/3d-models/ball-of-yarn-28cf446dd629404c920df2ba64e22dde |
| Pickles | Pickled Cucumbers | epavlenko | CC BY 4.0 | https://sketchfab.com/3d-models/pickled-cucumbers-eb4bd06db59b4c1686b0461051b2a1ca |
| Jam, tomato paste | Preservatives Jam Jar | m31odyr | CC BY 4.0 | https://sketchfab.com/3d-models/preservatives-jam-jar-dc8ea337322f4170855c6162b5c2ffdf |
| Flour, feed and manure sacks | Old burlap bag photo scan | Teilor Andersen | CC BY 4.0 | https://sketchfab.com/3d-models/old-burlap-bag-photo-scan-d52b9c947f994d528e872f71a1cabba1 |
| Hay | Hay bales | Zbrojmistrz | CC BY 4.0 | https://sketchfab.com/3d-models/hay-bales-d6e087f9a2a9416c94918f0503943c17 |
| Milk | Metal Jug | Poly Haven | CC0 | https://polyhaven.com/a/metal_jug |
| Fertilizer | Compost Bag 02 | Poly Haven | CC0 | https://polyhaven.com/a/compost_bag_02 |

Changes: textures scaled to 1024 px; the seven pieces of the fruit & vegetable pack
were cut out of it with `tools/extract_scans.gd` (produce/, the pack's license in
`produce/license_fruits_vegetables_pack.txt`); the yarn is repainted undyed and
without the stick it was scanned on; one bale of the hay pair; tinted sacks and jars
tell flour, feed, manure and tomato paste apart. `GoodsModels` bakes them in item
space, with thinned-out versions for crates and market shelves
(`tools/bake_tools.gd`). Each Sketchfab folder keeps its original `license.txt`;
Poly Haven models are fetched by `tools/fetch_models.py`.
