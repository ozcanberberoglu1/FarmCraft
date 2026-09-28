class_name Workbench
extends PlacedObject
## E opens the crafting screen (RecipeTable.CRAFTING): machines, sprinklers and
## fertilizer from the farm's wood, stone, ore and manure.


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_CRAFT")


func interact(_player: Node) -> void:
	Game.hud.open_crafting()
