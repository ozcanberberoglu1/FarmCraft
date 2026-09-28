class_name Machine
extends PlacedObject
## Turns goods into artisan products over time (RecipeTable.PROCESSING). E with an
## input in hand puts in what one batch takes; E again once it is done takes the
## product. Timing follows the game clock, so a batch carries on through the night.
## While busy some machines show it: the quern's stone turns, the kettle steams over a
## glowing stove. A finished batch shows its product floating above the machine.
##
## entry: out (product being made, "" when idle), qty, quality, ready_at (game minutes)

var _badge: Sprite3D
## Resting height of the product badge (it bobs around it).
var _badge_y := 0.0
var _steam: CPUParticles3D
var _glow: OmniLight3D
var _time := 0.0


func _setup() -> void:
	_badge = Sprite3D.new()
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.pixel_size = 0.0022
	_badge.no_depth_test = true
	_badge.render_priority = 5
	_badge.visible = false
	# Small clutter: kept out of the rain height map (layer 2) and out of GI. It bobs
	# from _process, so it is not interpolated between physics ticks.
	_badge.layers = 2
	_badge.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_badge.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_badge)
	if item_id == &"jam_kettle":
		_steam = CPUParticles3D.new()
		_steam.amount = 26
		_steam.lifetime = 2.6
		_steam.position = Vector3(0, 1.1, 0)
		_steam.direction = Vector3.UP
		_steam.spread = 18.0
		_steam.initial_velocity_min = 0.25
		_steam.initial_velocity_max = 0.45
		_steam.gravity = Vector3(0, 0.05, 0)
		_steam.scale_amount_min = 0.6
		_steam.scale_amount_max = 1.4
		var quad := QuadMesh.new()
		quad.size = Vector2(0.28, 0.28)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = _puff_texture()
		quad.material = mat
		_steam.mesh = quad
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.0))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		ramp.add_point(0.2, Color(0.55, 0.55, 0.55, 0.3))
		_steam.color_ramp = ramp
		_steam.emitting = false
		_steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_steam.layers = 2
		_steam.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_steam)
		# Hidden while the stove is cold, so an unlit light costs nothing.
		_glow = OmniLight3D.new()
		_glow.position = Vector3(0, 0.3, 0.32)
		_glow.light_color = Color(1.0, 0.55, 0.2)
		_glow.omni_range = 2.2
		_glow.light_energy = 0.0
		_glow.visible = false
		add_child(_glow)
	_refresh()


## A soft round puff for the steam (radial fade to transparent).
static func _puff_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func is_busy() -> bool:
	return String(entry.get("out", "")) != ""


func is_done() -> bool:
	return is_busy() and GameClock.total_minutes >= float(entry.get("ready_at", 0.0))


func can_pick_up() -> bool:
	return not is_busy()


## The recipe for what the player holds, or {}.
func _recipe_in_hand() -> Dictionary:
	var s := PlayerState.selected_stack()
	return RecipeTable.recipe_for(item_id, s.item.id) if s else {}


func interact_prompt(_player: Node) -> String:
	if is_done():
		return tr("ACTION_MACHINE_TAKE") % ItemDB.get_item(StringName(entry["out"])).display_name()
	if is_busy():
		return ""
	var r := _recipe_in_hand()
	if r.is_empty():
		return ""
	var input: StringName = (r["in"] as Dictionary).keys()[0]
	return tr("ACTION_MACHINE_PUT") % [ItemDB.get_item(input).display_name(), int(r["in"][input])]


func info_prompt() -> String:
	if is_busy() and not is_done():
		var left := maxf(float(entry["ready_at"]) - GameClock.total_minutes, 0.0) / 60.0
		return tr("INFO_MACHINE_WORKING") % [ItemDB.get_item(StringName(entry["out"])).display_name(), ceili(left)]
	if not is_busy():
		return tr("ACTION_PICK_UP")
	return ""


func interact(_player: Node) -> void:
	if is_done():
		_take()
	elif not is_busy():
		_load()


func _load() -> void:
	var r := _recipe_in_hand()
	if r.is_empty():
		# Tell the player what goes in.
		var inputs := PackedStringArray()
		for rec: Dictionary in RecipeTable.processing(item_id):
			for id: StringName in rec["in"]:
				inputs.append("%s ×%d" % [ItemDB.get_item(id).display_name(), int(rec["in"][id])])
		Game.notify(tr("MSG_MACHINE_TAKES") % [display_name(), UiTheme.join_list(inputs)], UiTheme.TEXT_MUTED)
		return
	var input: StringName = (r["in"] as Dictionary).keys()[0]
	var need := int(r["in"][input])
	if PlayerState.inventory.count_item(input) < need:
		Game.notify(tr("MSG_MACHINE_NEED_MORE") % [ItemDB.get_item(input).display_name(), need], UiTheme.RED)
		return
	var quality := PlayerState.selected_stack().quality
	PlayerState.inventory.remove_item(input, need)
	entry["out"] = String(r["out"])
	entry["qty"] = 1
	entry["quality"] = quality
	entry["ready_at"] = GameClock.total_minutes + float(r["hours"]) * 60.0
	Audio.action_done("fill_feed" if item_id != &"jam_kettle" else "medicine", global_position + Vector3(0, 0.8, 0))
	Events.machine_started.emit(item_id)
	_refresh()


func _take() -> void:
	var out := StringName(entry["out"])
	var qty := int(entry.get("qty", 1))
	var left := PlayerState.inventory.add_item(out, qty, int(entry.get("quality", 0)))
	if left > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), UiTheme.RED)
		if left == qty:
			return
	Game.notify("+%dx %s" % [qty - left, ItemDB.get_item(out).display_name()])
	Audio.play("soft", global_position + Vector3(0, 0.8, 0), -6.0)
	Events.product_made.emit(out, qty - left)
	entry["out"] = ""
	entry["qty"] = 0
	_refresh()


## Shows the machine's state; _process only runs while it works or shows its product.
func _refresh() -> void:
	var done := is_done()
	_badge.visible = done
	if done:
		_badge.texture = ItemDB.get_item(StringName(entry["out"])).icon
		_badge_y = float(PlaceableTable.get_info(item_id)["size"].y) + 0.35
		_badge.position.y = _badge_y
	var working := is_busy() and not done
	if _steam:
		_steam.emitting = working
	if _glow:
		_glow.visible = working
	set_process(working or done)


func _process(delta: float) -> void:
	_time += delta
	var working := is_busy() and not is_done()
	if _badge.visible:
		_badge.position.y = _badge_y + sin(_time * 2.4) * 0.05
	elif is_done():
		_refresh()
	if _moving and working:
		_moving.rotation.y += delta * 1.1
	if _glow and working:
		_glow.light_energy = 1.4 + sin(_time * 11.0) * 0.25 + sin(_time * 6.3) * 0.2
