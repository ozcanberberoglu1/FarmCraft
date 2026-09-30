class_name CargoBed
extends Node3D
## The load in a vehicle's bed, drawn from its cargo Stockpile. Packages from
## CargoModels stand in a grid of slots: two layers on the bed floor, one on top of
## each wheel well. Goods fill the slots front to back in the order they were loaded
## (the first load rides against the cab); each slot carries units_per_slot() units,
## except a crate with a live animal in it, which is one animal and always shows (a
## CrateHen sits in it). New packages drop in one after another. Lives in the model
## frame of the vehicle.

const DROP_TIME := 0.3
const DROP_HEIGHT := 0.4
## Delay between packages that arrive together (e.g. "load the pickup").
const DROP_STAGGER := 0.045

var cargo: Stockpile
var floor_y := 0.0
## Slot transforms, model frame, in fill order.
var slots: Array[Transform3D] = []
## Item ids in the order they first came aboard.
var _order: Array[StringName] = []
## Item id per filled slot.
var _layout: Array[StringName] = []
## Template key -> MultiMeshInstance3D.
var _mmis := {}
## Slot index -> seconds until its drop animation ends.
var _drops := {}
## Live animals riding in crates: slot index -> CrateHen, kept on their crates.
var _hens := {}


func setup(p_cargo: Stockpile, info: Dictionary) -> void:
	cargo = p_cargo
	_make_slots(info)
	cargo.changed.connect(_refresh.bind(true))
	_refresh(false)


## Units a single package stands for, so a full bed fills every slot.
func units_per_slot() -> int:
	return maxi(ceili(float(cargo.capacity) / maxf(slots.size(), 1.0)), 1)


## Ends any drop animation (e.g. after loading a saved game).
func settle() -> void:
	_drops.clear()
	_apply()
	set_process(false)


func package_count() -> int:
	return _layout.size()


## Top of the load (model frame), or the bed floor when empty.
func load_top() -> float:
	var top := floor_y
	for i in _layout.size():
		top = maxf(top, slots[i].origin.y + CargoModels.SIZE.y)
	return top


func _make_slots(info: Dictionary) -> void:
	var rows: Array = info.get("bed_rows", [])
	var cols: Array = info.get("bed_cols", [])
	floor_y = float(info.get("bed_floor", 0.7))
	var top := float(info.get("bed_top", 1.2))
	var wells: Array = info.get("wheel_wells", [])
	var h := CargoModels.SIZE.y
	# Middle columns first so a light load sits along the centre line.
	var col_order := range(cols.size() - 1)
	col_order.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(cols[a]) + float(cols[a + 1])) < absf(float(cols[b]) + float(cols[b + 1])))
	var layers: Array = [[], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for r in rows.size() - 1:
		var x_a := float(rows[r])
		var x_b := float(rows[r + 1])
		for c: int in col_order:
			var z_a := float(cols[c])
			var z_b := float(cols[c + 1])
			var base := floor_y
			for w: AABB in wells:
				if minf(x_a, x_b) < w.end.x and maxf(x_a, x_b) > w.position.x and minf(z_a, z_b) < w.end.z and maxf(z_a, z_b) > w.position.z:
					base = maxf(base, w.end.y)
			var slack := Vector2(maxf(absf(x_a - x_b) - CargoModels.SIZE.x, 0.0), maxf(absf(z_a - z_b) - CargoModels.SIZE.z, 0.0)) * 0.45
			var count := mini(int(floor((top + 0.04 - base) / h)), layers.size())
			for l in count:
				var pos := Vector3((x_a + x_b) * 0.5 + rng.randf_range(-slack.x, slack.x), base + l * h,
						(z_a + z_b) * 0.5 + rng.randf_range(-slack.y, slack.y))
				var yaw := rng.randf_range(-0.035, 0.035) + (PI if rng.randf() < 0.5 else 0.0)
				(layers[l] as Array).append(Transform3D(Basis(Vector3.UP, yaw), pos))
	slots.clear()
	for layer: Array in layers:
		for xf: Transform3D in layer:
			slots.append(xf)


func _refresh(animate: bool) -> void:
	var counts := {}
	for e: Dictionary in cargo.entries():
		counts[e["id"]] = int(counts.get(e["id"], 0)) + int(e["count"])
	var order: Array[StringName] = []
	for id in _order:
		if counts.has(id):
			order.append(id)
	for id: StringName in counts:
		if id not in order:
			order.append(id)
	_order = order
	var per := units_per_slot()
	var want := {}
	var total := 0
	for id in _order:
		want[id] = ceili(float(counts[id]) / CargoModels.units_per_package(id, per))
		total += int(want[id])
	# Too many kinds for the slots: the biggest loads give way (a live crate never does).
	while total > slots.size():
		var big := &""
		for id in _order:
			if not CargoModels.is_live(id) and int(want[id]) > 0 and (big == &"" or int(want[id]) > int(want[big])):
				big = id
		if big == &"":
			break
		want[big] = int(want[big]) - 1
		total -= 1
	var layout: Array[StringName] = []
	for id in _order:
		for i in int(want[id]):
			if layout.size() < slots.size():
				layout.append(id)
	var arriving := 0
	for i in layout.size():
		if animate and (i >= _layout.size() or _layout[i] != layout[i]):
			_drops[i] = DROP_TIME + arriving * DROP_STAGGER
			arriving += 1
	for i in _drops.keys():
		if int(i) >= layout.size():
			_drops.erase(i)
	_layout = layout
	_apply()
	set_process(not _drops.is_empty())


func _process(delta: float) -> void:
	for i in _drops.keys():
		_drops[i] = float(_drops[i]) - delta
		if float(_drops[i]) <= 0.0:
			_drops.erase(i)
	_apply()
	if _drops.is_empty():
		set_process(false)


## Pushes the slot transforms into one MultiMesh per package look.
func _apply() -> void:
	var groups := {}
	for i in _layout.size():
		var xf := slots[i]
		if _drops.has(i):
			var left := float(_drops[i])
			if left > DROP_TIME:
				continue
			xf.origin.y += _drop_offset(1.0 - left / DROP_TIME)
		var key := "%s:%d" % [_layout[i], i % 2]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
	for key: String in _mmis:
		if not groups.has(key):
			(_mmis[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key: String in groups:
		var list: Array = groups[key]
		var mm := _mmi(key).multimesh
		if mm.instance_count != list.size():
			mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
	_sync_hens()


## A CrateHen in every live crate on show, moved with its crate as it drops in.
func _sync_hens() -> void:
	var live := {}
	for i in _layout.size():
		if CargoModels.is_live(_layout[i]) and not (_drops.has(i) and float(_drops[i]) > DROP_TIME):
			live[i] = true
	for i: int in _hens.keys():
		if not live.has(i):
			(_hens[i] as Node).queue_free()
			_hens.erase(i)
	for i: int in live:
		if not _hens.has(i):
			var hen := CrateHen.new()
			hen.name = "Hen%d" % i
			hen.variant = i
			hen.species = AnimalTable.species_of_crate(_layout[i])
			add_child(hen)
			_hens[i] = hen
		var xf := slots[i]
		if _drops.has(i):
			xf.origin.y += _drop_offset(1.0 - float(_drops[i]) / DROP_TIME)
		(_hens[i] as Node3D).transform = xf


## Live animals on show in the bed (one CrateHen per crate).
func live_count() -> int:
	return _hens.size()


## Falls in, then settles with a small bounce.
static func _drop_offset(t: float) -> float:
	if t < 0.78:
		var f := t / 0.78
		return DROP_HEIGHT * (1.0 - f * f)
	return 0.025 * sin((t - 0.78) / 0.22 * PI)


func _mmi(key: String) -> MultiMeshInstance3D:
	if _mmis.has(key):
		return _mmis[key]
	var parts := key.split(":")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = CargoModels.mesh(StringName(parts[0]), int(parts[1]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Load_" + key.replace(":", "_")
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Rides on the truck: kept out of SDFGI and the rain-blocker heightfield.
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.layers = 2
	mmi.visibility_range_end = 160.0
	add_child(mmi)
	_mmis[key] = mmi
	return mmi
