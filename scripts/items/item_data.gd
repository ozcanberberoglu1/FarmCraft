class_name ItemData
extends Resource
## Static definition of an item type (built by ItemDB from data/item_table.gd).

@export var id: StringName
@export var category := "misc"
@export var max_stack := 99
@export var sell_price := 0
@export var buy_price := 0
@export var max_durability := 0
@export var tool_type: StringName
@export var crop_id: StringName
@export var water_capacity := 0
@export var icon: Texture2D


func display_name() -> String:
	return TranslationServer.translate("ITEM_" + String(id).to_upper())


func description() -> String:
	var key := "DESC_" + String(id).to_upper()
	var text := TranslationServer.translate(key)
	return "" if text == key else text


func category_name() -> String:
	return TranslationServer.translate(ItemTable.CATEGORY_KEYS.get(category, "CAT_MISC"))


func is_tool() -> bool:
	return category == "tool"


func is_stackable() -> bool:
	return max_stack > 1


func has_durability() -> bool:
	return max_durability > 0
