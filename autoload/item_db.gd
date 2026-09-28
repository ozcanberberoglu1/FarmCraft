extends Node
## Registry of all item definitions, built from data/item_table.gd at startup.
## Icons are rendered from the 3D item models by tools/icon_studio (art/icons/items).

const ICON_DIR := "res://art/icons/items/"

var _items: Dictionary = {}
var _placeholder: Texture2D


func _init() -> void:
	for id: StringName in ItemTable.ITEMS:
		var row: Dictionary = ItemTable.ITEMS[id]
		var d := ItemData.new()
		d.id = id
		d.category = row.get("cat", "misc")
		d.max_stack = row.get("stack", 99)
		d.sell_price = row.get("sell", 0)
		d.buy_price = row.get("buy", 0)
		d.max_durability = row.get("dur", 0)
		d.tool_type = row.get("tool", &"")
		d.crop_id = row.get("crop", &"")
		d.water_capacity = row.get("water", 0)
		var icon_path := ICON_DIR + String(id) + ".png"
		d.icon = load(icon_path) if ResourceLoader.exists(icon_path) else _placeholder_icon()
		_items[id] = d


func get_item(id: StringName) -> ItemData:
	return _items.get(id)


func has_item(id: StringName) -> bool:
	return _items.has(id)


func all_ids() -> Array:
	return _items.keys()


func _placeholder_icon() -> Texture2D:
	if _placeholder == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.2, 0.8, 0.6))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder
