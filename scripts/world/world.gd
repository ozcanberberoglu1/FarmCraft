extends Node3D
## Root of the farm world; registers itself so gameplay systems can find it.

@onready var grass: GrassField = $Grass
@onready var farm: Farm = $Farm


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		Game.world = self


## Removes meadow grass under a new structure (world XZ rect).
func block_grass(rect: Rect2) -> void:
	$Grass.block(rect)
