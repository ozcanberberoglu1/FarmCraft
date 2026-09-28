class_name Stockpile
extends RefCounted
## Bulk storage counted in units rather than slots (farm warehouse, pickup bed):
## item id + quality -> count, up to `capacity` units in total. A crated animal is
## one unit.

signal changed

var capacity := 100
## "id|quality" -> count
var items := {}


func _init(p_capacity := 100) -> void:
	capacity = p_capacity


static func key_of(id: StringName, quality: int) -> String:
	return "%s|%d" % [id, quality]


func total() -> int:
	var n := 0
	for k: String in items:
		n += int(items[k])
	return n


func space() -> int:
	return maxi(capacity - total(), 0)


func count(id: StringName, quality := -1) -> int:
	var n := 0
	for k: String in items:
		var parts := k.split("|")
		if StringName(parts[0]) == id and (quality < 0 or int(parts[1]) == quality):
			n += int(items[k])
	return n


## Adds up to `amount`; returns how many fitted.
func add(id: StringName, amount: int, quality := 0) -> int:
	var n := mini(amount, space())
	if n <= 0:
		return 0
	var k := key_of(id, quality)
	items[k] = int(items.get(k, 0)) + n
	changed.emit()
	return n


## Removes up to `amount`; returns how many were taken.
func take(id: StringName, amount: int, quality := 0) -> int:
	var k := key_of(id, quality)
	var n := mini(amount, int(items.get(k, 0)))
	if n <= 0:
		return 0
	items[k] = int(items[k]) - n
	if int(items[k]) <= 0:
		items.erase(k)
	changed.emit()
	return n


## [{id, quality, count}] sorted by item category and name.
func entries() -> Array:
	var out := []
	for k: String in items:
		var parts := k.split("|")
		out.append({"id": StringName(parts[0]), "quality": int(parts[1]), "count": int(items[k])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia := ItemDB.get_item(a["id"])
		var ib := ItemDB.get_item(b["id"])
		if ia.category != ib.category:
			return ia.category < ib.category
		if ia.id != ib.id:
			return ia.display_name() < ib.display_name()
		return a["quality"] > b["quality"])
	return out


## Whether `item` can be kept in bulk storage: not tools with wear, cans or keys
## (crated animals can wait here).
static func can_store(item: ItemData) -> bool:
	return item != null and not item.has_durability() and item.water_capacity <= 0 and item.category != "key"


## Moves as much of a bag slot into the stockpile as fits.
func store_stack(inv: Inventory, index: int) -> int:
	var s := inv.get_stack(index)
	if s == null or not can_store(s.item):
		return 0
	var n := add(s.item.id, s.count, s.quality)
	if n > 0:
		inv.take_from(index, n)
	return n


## Moves up to `amount` into the bag; returns how many moved.
func withdraw_to(inv: Inventory, id: StringName, quality: int, amount: int) -> int:
	var n := mini(amount, count(id, quality))
	if n <= 0:
		return 0
	var left := inv.add_item(id, n, quality)
	var moved := n - left
	if moved > 0:
		take(id, moved, quality)
	return moved


## Moves up to `amount` to another stockpile.
func transfer_to(other: Stockpile, id: StringName, quality: int, amount: int) -> int:
	var n := mini(amount, mini(count(id, quality), other.space()))
	if n <= 0:
		return 0
	take(id, n, quality)
	other.add(id, n, quality)
	return n


func to_dict() -> Dictionary:
	return {"capacity": capacity, "items": items.duplicate()}


func from_dict(d: Dictionary) -> void:
	capacity = int(d.get("capacity", capacity))
	items = (d.get("items", {}) as Dictionary).duplicate()
	changed.emit()
