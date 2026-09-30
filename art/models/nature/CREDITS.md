# Nature models

All from Poly Haven (CC0, public domain), fetched by `tools/fetch_models.py`. The
game draws the simplified pieces `tools/bake_nature.gd` saves to `baked/` (re-run it
after re-fetching); see `NatureModels.SCANS`.

| Use | Model | Source |
|---|---|---|
| Breakable field rocks, forest-floor stones | Rock Moss Set 01 | https://polyhaven.com/a/rock_moss_set_01 |
| Breakable field and quarry rocks, forest-floor stones | Rock Moss Set 02 | https://polyhaven.com/a/rock_moss_set_02 |
| Breakable field and quarry rocks | Boulder 01 | https://polyhaven.com/a/boulder_01 |
| Breakable quarry rocks | Rock 09 | https://polyhaven.com/a/rock_09 |
| Ferns at the forest edges | Fern 02 | https://polyhaven.com/a/fern_02 |
| Nettles at the forest edges | Nettle Plant | https://polyhaven.com/a/nettle_plant |
| Fallen branches | Dry Branches Medium 01 | https://polyhaven.com/a/dry_branches_medium_01 |
| Stumps in the woods | Tree Stump 01 | https://polyhaven.com/a/tree_stump_01 |
| Fallen trunks in the woods | Dead Tree Trunk | https://polyhaven.com/a/dead_tree_trunk |
| Wild berry bushes: raspberry and blackberry canes | Shrub 01 | https://polyhaven.com/a/shrub_01 |
| Wild berry bushes: dog rose (rosehips) | Shrub 02 | https://polyhaven.com/a/shrub_02 |
| Wild berry bushes: blueberry twigs | Shrub 04 | https://polyhaven.com/a/shrub_04 |

The campfire's ring of stones (scripts/camp/campfire_model.gd) is cut from Boulder 01 and Rock 09 too.

The wild berry bushes (scripts/resources/berry_models.gd) are mounds of twigs cut from the
shrub scans, fetched by `tools/fetch_wild.py` and baked with their berries by
`tools/bake_berries.gd` into `baked/berry_*.res`.
