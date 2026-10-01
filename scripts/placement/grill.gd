class_name Grill
extends Campfire
## A charcoal grill bought at the town market (PlaceableTable kind "grill"): "grill", a
## Turkish steel mangal with six places on its grate, and "big_grill", a long barbecue
## grill with twelve (GrillModel). It goes down outdoors like the campfire and is lit,
## fuelled, cooked on and put out the same way (Campfire): E lights the charcoal it comes
## with (five hours), wood in hand adds an hour and rekindles a burnt-out bed, food
## browns for COOK_SECONDS and flies into the bag.
##
## The food lies on the grate in rows of places (GrillModel.place_at). A giant (trophy)
## fish, too big for a campfire, takes two places side by side in a row and grills into
## "<id>_cooked", a meal that fills far more than a whole fish. Doused with the can, the
## coals go out but the grill stays; F picks it up when it is cold (unlit or burnt out)
## and nothing is on it.

## How tall the charcoal's flames are next to a campfire's.
const FLAME_SIZE := 0.2


func _init() -> void:
	burnt_key = "MSG_GRILL_BURNT_DOWN"


func _slot_count() -> int:
	var l := GrillModel.look(item_id)
	return int(l["cols"]) * int(l["rows"])


## A giant fish takes two places.
func _span_of(id: StringName) -> int:
	return 2 if FishTable.is_trophy(id) else 1


func _takes(_id: StringName) -> bool:
	return true


## Places side by side in one row only.
func _span_fits(slot: int, span: int) -> bool:
	if span > 1 and slot % int(GrillModel.look(item_id)["cols"]) + span > int(GrillModel.look(item_id)["cols"]):
		return false
	return super._span_fits(slot, span)


# --- Model ------------------------------------------------------------------------------

func _build() -> void:
	var l := GrillModel.look(item_id)
	var bed := GrillModel.bed_y(item_id)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = GrillModel.body_mesh(item_id)
	add_child(body)
	# The ash floor and the lumps over it: the campfire's bed and logs (Campfire._refresh
	# chars, lights and sinks them).
	_bed = MeshInstance3D.new()
	_bed.mesh = GrillModel.ash_mesh(item_id)
	_bed.layers = 2
	_bed.position.y = bed
	add_child(_bed)
	_logs = MeshInstance3D.new()
	_logs.mesh = GrillModel.coals_mesh(item_id)
	_logs.layers = 2
	_logs.position.y = bed
	add_child(_logs)
	var phase := randf()
	for mi: MeshInstance3D in [_bed, _logs]:
		mi.set_instance_shader_parameter("phase", phase)
	_fx = CampfireFx.new()
	_fx.position.y = bed + 0.02
	add_child(_fx)
	var size: Vector2 = l["size"]
	_fx.spread(size * 0.5 * 0.82, FLAME_SIZE)
	_sizzle = CampSfx.loop("sizzle_loop", self, -80.0, 2.2)
	_sizzle.position = Vector3(0, float(l["grate_y"]) + 0.05, 0)


# --- Cooking ----------------------------------------------------------------------------

## The food laid on the grate over its place (flown there from the farmer's hand).
func _put_on_spit(slot: int, id: StringName, left: float, player: Player = null) -> void:
	var span := _span_of(id)
	var node := Node3D.new()
	node.position = GrillModel.place_at(item_id, slot, span)
	add_child(node)
	var fish := Campfire.food_mesh(id)
	fish.transform = _lay_span(fish.mesh, span)
	node.add_child(fish)
	var steam := Campfire.food_steam()
	steam.position = fish.transform.origin + Vector3(0, 0.03, 0)
	steam.emission_sphere_radius = 0.06 * span
	node.add_child(steam)
	steam.emitting = true
	_spits[slot] = {"id": id, "left": left, "done_t": 0.0, "node": node, "fish": fish,
		"overlay": fish.material_overlay, "steam": steam, "span": span}
	for k in range(1, span):
		_spits[slot + k] = {"link": slot}
	if player != null and is_instance_valid(player):
		Campfire._fly_in(fish, node, player)
		var at := node.global_position
		Audio.play("soft", at, -12.0, 0.1, &"Effects", 2.0)
		get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				CampSfx.play("fire_pop", at, -10.0, 0.2, 2.0, 1.3))


func _lay(mesh: Mesh, slot: int) -> Transform3D:
	return _lay_span(mesh, int(_spits[slot].get("span", 1)))


## The food's model lying on the bars: its longest side along the grill, its thinnest
## upright (a fish on its side), as long as `span` places (a little less), resting on
## the grate.
func _lay_span(mesh: Mesh, span: int) -> Transform3D:
	var cell := GrillModel.cell_size(item_id)
	if mesh == null:
		return Transform3D()
	var box := mesh.get_aabb()
	var ext := box.size
	var order := [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return ext[a] > ext[b])
	var axes: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	axes[order[0]] = Vector3.RIGHT
	axes[order[1]] = Vector3.BACK
	axes[order[2]] = Vector3.UP
	var basis := Basis(axes[0], axes[1], axes[2])
	if basis.determinant() < 0.0:
		axes[order[1]] = Vector3.FORWARD
		basis = Basis(axes[0], axes[1], axes[2])
	var length := cell.x * float(span) * 0.9
	var s := clampf(length / maxf(ext[order[0]], 0.001), 0.2, 4.0)
	# Never wider than its place across the grill.
	s = minf(s, cell.y * 0.92 / maxf(ext[order[1]], 0.001))
	basis = basis.scaled(Vector3.ONE * s)
	return Transform3D(basis, Vector3(0, ext[order[2]] * s * 0.5 + 0.002, 0) - basis * box.get_center())


# --- Fire -------------------------------------------------------------------------------

func light() -> void:
	super.light()
	_fx.steaming = false


func add_wood() -> void:
	super.add_wood()
	if state == "lit":
		_fx.steaming = false


## Water on the coals: out in a cloud of steam; the grill stays, cold, its food back
## in the bag.
func douse() -> void:
	if not is_burning():
		return
	state = "ash"
	burn_left = 0.0
	embers_left = 0.0
	_char = maxf(_char, 0.5)
	_give_back_spits()
	_fx.douse()
	var at := global_position + Vector3(0, GrillModel.bed_y(item_id) + 0.1, 0)
	CampSfx.play("douse", at, 0.0, 0.04, 4.0)
	Fx.water_splash(at)
	_store()
	Events.campfire_out.emit(self)
	Game.notify(tr("MSG_CAMPFIRE_DOUSED"), UiTheme.TEXT_MUTED)


# --- Picking up -------------------------------------------------------------------------

func can_pick_up() -> bool:
	return (state == "laid" or state == "ash") and cook_status().is_empty()


## F: a cold grill back into the bag (its ash tipped out).
func info_prompt() -> String:
	return tr("ACTION_PICK_UP") if can_pick_up() else ""


func info_interact(_player: Node) -> void:
	if not can_pick_up():
		return
	if PlayerState.give(item_id, 1) > 0:
		return
	Audio.play("plank", global_position + Vector3(0, 0.4, 0), -6.0)
	if state == "ash":
		Fx.dust_cloud(global_position + Vector3(0, 0.15, 0), Vector2(0.5, 0.5))
	FarmState.remove_placed(entry)
	queue_free()

