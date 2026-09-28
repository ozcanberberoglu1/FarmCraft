class_name ItemStack
extends RefCounted
## A quantity of one item type in an inventory slot, with per-instance state
## (durability, quality, watering-can water level...).

enum Quality { NORMAL, SILVER, GOLD }

var item: ItemData
var count := 1
var durability := -1
var quality := Quality.NORMAL
var water := 0
## Tool upgrade (workbench): 0 plain, 1 reinforced, 2 steel. Faster work, longer life.
var upgrade := 0

const MAX_UPGRADE := 2


static func create(item_id: StringName, amount := 1, item_quality := Quality.NORMAL) -> ItemStack:
	var data := ItemDB.get_item(item_id)
	if data == null:
		push_error("Unknown item '%s'" % item_id)
		return null
	var s := ItemStack.new()
	s.item = data
	s.count = clampi(amount, 1, data.max_stack)
	s.quality = item_quality
	if data.has_durability():
		s.durability = data.max_durability
	s.water = data.water_capacity
	return s


func id() -> StringName:
	return item.id


func space_left() -> int:
	return item.max_stack - count


func can_merge(other: ItemStack) -> bool:
	return other != null and other.item == item and item.is_stackable() and other.quality == quality


func copy() -> ItemStack:
	var s := ItemStack.new()
	s.item = item
	s.count = count
	s.durability = durability
	s.quality = quality
	s.water = water
	s.upgrade = upgrade
	return s


## Durability when new or repaired: each upgrade adds half again.
func max_durability() -> int:
	return roundi(item.max_durability * (1.0 + 0.5 * upgrade))


## How much quicker work goes with this tool (each upgrade takes a fifth off).
func speed_factor() -> float:
	return 1.0 - 0.2 * upgrade


## The name with its upgrade ("Hoe +1").
func display_name() -> String:
	return item.display_name() + (" +%d" % upgrade if upgrade > 0 else "")


func durability_ratio() -> float:
	if not item.has_durability():
		return -1.0
	return clampf(float(durability) / max_durability(), 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"id": String(item.id), "count": count, "durability": durability, "quality": quality, "water": water,
		"upgrade": upgrade}


static func from_dict(d: Dictionary) -> ItemStack:
	var s := create(StringName(d.get("id", "")), int(d.get("count", 1)), int(d.get("quality", 0)))
	if s:
		s.durability = int(d.get("durability", s.durability))
		s.water = int(d.get("water", s.water))
		s.upgrade = int(d.get("upgrade", 0))
	return s
