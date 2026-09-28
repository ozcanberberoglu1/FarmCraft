class_name Inventory
extends RefCounted
## Fixed-size list of slots holding ItemStacks (null = empty).

signal changed

var slots: Array[ItemStack] = []
## What a container takes: called with the ItemData, true = it may go in (unset = all).
## A hen in its crate stays with the player; the shipping bin only takes what sells.
var accepts := Callable()


func _init(size: int) -> void:
	slots.resize(size)


## True when `stack` may go into this inventory (see accepts).
func allows(stack: ItemStack) -> bool:
	return stack == null or not accepts.is_valid() or bool(accepts.call(stack.item))


func size() -> int:
	return slots.size()


func get_stack(index: int) -> ItemStack:
	return slots[index] if index >= 0 and index < slots.size() else null


func set_stack(index: int, stack: ItemStack) -> void:
	slots[index] = stack if stack == null or stack.count > 0 else null
	changed.emit()


func is_empty_slot(index: int) -> bool:
	return slots[index] == null


## Adds `stack` (merging into matching stacks first). Returns how many items did
## not fit. The passed stack is not modified.
func add_stack(stack: ItemStack, first := 0, last := -1) -> int:
	if stack == null:
		return 0
	if not allows(stack):
		return stack.count
	var end := slots.size() if last < 0 else last
	var left := stack.count
	if stack.item.is_stackable():
		for i in range(first, end):
			var s := slots[i]
			if s != null and s.can_merge(stack) and s.space_left() > 0:
				var moved := mini(left, s.space_left())
				s.count += moved
				left -= moved
				if left == 0:
					changed.emit()
					return 0
	for i in range(first, end):
		if slots[i] == null:
			var placed := stack.copy()
			placed.count = mini(left, stack.item.max_stack)
			slots[i] = placed
			left -= placed.count
			if left == 0:
				break
	changed.emit()
	return left


func add_item(item_id: StringName, amount := 1, quality := ItemStack.Quality.NORMAL) -> int:
	var remaining := amount
	while remaining > 0:
		var s := ItemStack.create(item_id, remaining, quality)
		if s == null:
			return remaining
		var chunk := s.count
		var left := add_stack(s)
		remaining -= chunk - left
		if left > 0:
			return remaining
	return 0


func count_item(item_id: StringName) -> int:
	var total := 0
	for s in slots:
		if s != null and s.item.id == item_id:
			total += s.count
	return total


func has_item(item_id: StringName, amount := 1) -> bool:
	return count_item(item_id) >= amount


## Removes `amount` items of a type (any quality, lowest quality first). Returns
## false and changes nothing if there are not enough.
func remove_item(item_id: StringName, amount := 1) -> bool:
	if count_item(item_id) < amount:
		return false
	var left := amount
	for q in [ItemStack.Quality.NORMAL, ItemStack.Quality.SILVER, ItemStack.Quality.GOLD]:
		for i in slots.size():
			var s := slots[i]
			if s == null or s.item.id != item_id or s.quality != q:
				continue
			var taken := mini(left, s.count)
			s.count -= taken
			left -= taken
			if s.count == 0:
				slots[i] = null
			if left == 0:
				changed.emit()
				return true
	changed.emit()
	return true


## Removes up to `amount` from one slot and returns them as a new stack.
func take_from(index: int, amount: int) -> ItemStack:
	var s := slots[index]
	if s == null or amount <= 0:
		return null
	var taken := s.copy()
	taken.count = mini(amount, s.count)
	s.count -= taken.count
	if s.count == 0:
		slots[index] = null
	changed.emit()
	return taken


func first_empty(first := 0, last := -1) -> int:
	var end := slots.size() if last < 0 else last
	for i in range(first, end):
		if slots[i] == null:
			return i
	return -1


## Moves/merges/swaps the stack at `from_index` of `from_inv` onto `to_index` here.
static func transfer(from_inv: Inventory, from_index: int, to_inv: Inventory, to_index: int) -> void:
	if from_inv == to_inv and from_index == to_index:
		return
	var src := from_inv.slots[from_index]
	if src == null:
		return
	var dst := to_inv.slots[to_index]
	# Both ways: a swap puts the other stack into the source inventory.
	if not to_inv.allows(src) or not from_inv.allows(dst):
		return
	if dst != null and dst.can_merge(src):
		var moved := mini(src.count, dst.space_left())
		dst.count += moved
		src.count -= moved
		if src.count == 0:
			from_inv.slots[from_index] = null
	else:
		to_inv.slots[to_index] = src
		from_inv.slots[from_index] = dst
	from_inv.changed.emit()
	if to_inv != from_inv:
		to_inv.changed.emit()


## Splits half of a stack into the first empty slot. Returns the new slot or -1.
func split_half(index: int) -> int:
	var s := slots[index]
	if s == null or s.count < 2:
		return -1
	var target := first_empty()
	if target < 0:
		return -1
	var half := s.count >> 1
	var part := s.copy()
	part.count = half
	s.count -= half
	slots[target] = part
	changed.emit()
	return target


func to_array() -> Array:
	var out := []
	for s in slots:
		out.append(s.to_dict() if s else null)
	return out


func from_array(data: Array) -> void:
	for i in slots.size():
		slots[i] = ItemStack.from_dict(data[i]) if i < data.size() and data[i] is Dictionary else null
	changed.emit()
