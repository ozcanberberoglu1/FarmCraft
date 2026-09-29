# Trees

Built from Poly Haven's film-quality tree models (CC0, public domain: free for commercial
use, no attribution required). `tools/fetch_trees.py` downloads them (into a cache
outside the project: they are 50 MB - 1 GB each) and has Blender turn them into game
trees with `tools/blender/build_trees.py`:

    python3 tools/fetch_trees.py --build
    python3 tools/fetch_trees.py --compose     # the impostor atlas of all trees

then write the import settings and import in Godot (`python3 tools/set_texture_import.py`,
`godot --headless --path . --import`).

Each `<tree>.glb` holds the real trunk and limbs (decimated, three levels of detail) and
the crown as cards (`cards_lod0..2`), each showing a cluster of the model's real twigs and
leaves rendered into `textures/<tree>_leaves.webp` (+ `_nor`, its normal map).
`textures/impostors.webp` (+ `_nor`) has every tree from eight sides for the far forest.
The bark maps in `textures/` are the models' own (resized, WebP).

| Game trees | Model | Source |
|---|---|---|
| fir_a, fir_b, fir_c | Fir Tree 01 | https://polyhaven.com/a/fir_tree_01 |
| pine_a, pine_b, pine_c | Pine Tree 01 | https://polyhaven.com/a/pine_tree_01 |
| broadleaf | Tree Small 02 | https://polyhaven.com/a/tree_small_02 |
| olive | Island Tree 01 | https://polyhaven.com/a/island_tree_01 |
| locust | Jacaranda Tree | https://polyhaven.com/a/jacaranda_tree |
