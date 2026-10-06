class_name Doghouse
extends PlacedObject
## The farmer's own dog's house (PlaceableTable "doghouse": the construction board cuts
## its kit once he has a dog, for a little wood and a few nails), put up on open farm land
## near the house like the workbench. It goes up on site first, for "build_seconds" real
## seconds of play (half a minute; a night's sleep finishes it): pegs and a line round its
## plot, boards and a sawhorse, and the house taking shape in three stages (the sill and
## posts, the walls, the roof), a sign counting down over it. Finished, it is the dog's
## home (Pet.kennel: the first finished one on the farm): it sleeps in it at night, lying
## just inside the door with its nose out, and waits on its doorstep while the farmer is
## away; the old bed by the farmhouse door is taken away. Its name is on the board over
## the door. Its walls are solid (the door is open to the dog: too narrow for the farmer);
## its roof stops him alone, so the dog's feet find the ground under it.
## Entry fields besides {id, pos, yaw}: stage ("site" / "done"), build_left (real seconds).

const GROUP := &"doghouses"
## Its id in Events.construction_started and Events.building_completed.
const BUILD_ID := &"doghouse"
const STAGES := 3
## A night's sleep (or any skip this long, in game minutes) finishes the construction.
const SKIP_FINISHES := 30.0
## Hammering is heard from this close (metres).
const HEAR_RANGE := 26.0
## In front of the door (m from the front wall): the dog's doorstep, where it turns in and
## where it waits; the middle of the patch it potters about on while the farmer is away.
const DOORSTEP := 0.95
const YARD := 2.6
## The roof's collision layer: the farmer and what he aims at (the animals' layer), not the
## world's (the dog's feet and nose look for the world only).
const ROOF_LAYER := 16

var _house: MeshInstance3D
var _site: MeshInstance3D
var _label: Label3D
var _name: Label3D
var _stage := -1
var _knock := 1.0
var _label_timer := 0.0


func _setup() -> void:
	add_to_group(GROUP)
	# Ones put down by tests or debug shots stand finished.
	if not entry.has("stage"):
		entry["stage"] = "done"
	var w := PlaceableModels.DOGHOUSE_W
	var d := PlaceableModels.DOGHOUSE_D
	var eh := PlaceableModels.DOGHOUSE_EAVES
	var t := 0.06
	var door := PlaceableModels.DOGHOUSE_DOOR.x
	# The walls: the sides, the back, the front either side of the door.
	var side := (w - door) * 0.5
	for wall: Array in [
			[Vector3(-(w - t) * 0.5, eh * 0.5, 0), Vector3(t, eh, d)], [Vector3((w - t) * 0.5, eh * 0.5, 0), Vector3(t, eh, d)],
			[Vector3(0, eh * 0.5, -(d - t) * 0.5), Vector3(w, eh, t)],
			[Vector3(-(door + side) * 0.5, eh * 0.5, (d - t) * 0.5), Vector3(side, eh, t)],
			[Vector3((door + side) * 0.5, eh * 0.5, (d - t) * 0.5), Vector3(side, eh, t)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		cs.shape = box
		cs.position = wall[0]
		add_child(cs)
	var roof := StaticBody3D.new()
	roof.name = "Roof"
	roof.collision_layer = ROOF_LAYER
	roof.collision_mask = 0
	var rs := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	var rise := PlaceableModels.DOGHOUSE_RIDGE - eh
	rbox.size = Vector3(w + 0.2, rise + 0.06, d + 0.2)
	rs.shape = rbox
	rs.position = Vector3(0, eh + rbox.size.y * 0.5, 0.03)
	roof.add_child(rs)
	add_child(roof)
	_house = MeshInstance3D.new()
	_house.name = "Body"
	add_child(_house)
	if is_built():
		_show_finished()
	else:
		_start_site()
	set_process(not is_built())
	Events.time_skipped.connect(_on_time_skipped)
	Pet.adopted.connect(_on_adopted)


func _exit_tree() -> void:
	Pet.kennel_gone(self)


## Finished (not a construction site any more).
func is_built() -> bool:
	return String(entry.get("stage", "done")) == "done"


## Real seconds the whole construction takes.
func build_seconds() -> float:
	return PlaceableTable.build_seconds(item_id)


## Real seconds of play until it is finished (0 once it is).
func seconds_left() -> float:
	return 0.0 if is_built() else maxf(float(entry.get("build_left", build_seconds())), 0.0)


## 0..1 of the construction done.
func progress() -> float:
	return 1.0 - seconds_left() / maxf(build_seconds(), 0.001)


# --- The dog's places (Pet, PetDog) ----------------------------------------------------------

## A point on the house's long axis `z` metres in front of its middle, on the ground.
func _on_axis(z: float) -> Vector3:
	var p := global_transform * Vector3(0, 0, z)
	return Vector3(p.x, TerrainData.height(p.x, p.z), p.z)


## Where a dog of `dog_size` (against Karamel's) lies: just inside the door, its nose out.
func sleep_point(dog_size: float) -> Vector3:
	return _on_axis(PlaceableModels.DOGHOUSE_D * 0.5 - 0.5 * clampf(dog_size, 0.4, 1.0) - 0.02)


## Its doorstep: in front of the door, where it turns to go in.
func porch_point() -> Vector3:
	return _on_axis(PlaceableModels.DOGHOUSE_D * 0.5 + DOORSTEP)


## The middle of the patch in front of the house it keeps to while the farmer is away.
func yard_point() -> Vector3:
	return _on_axis(PlaceableModels.DOGHOUSE_D * 0.5 + YARD)


## Whether `p` is in the doorway or inside (the way in is straight ahead from there).
func in_doorway(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < PlaceableModels.DOGHOUSE_DOOR.x * 0.5 and absf(l.z) < PlaceableModels.DOGHOUSE_D * 0.5 + 0.45


# --- Construction ---------------------------------------------------------------------

func _start_site() -> void:
	if not entry.has("build_left"):
		entry["build_left"] = build_seconds()
	_site = MeshInstance3D.new()
	_site.name = "Site"
	_site.mesh = Workbench._site_mesh(PlaceableTable.get_info(item_id).get("size", Vector3(1.6, 1.2, 1.8)))
	add_child(_site)
	_label = Label3D.new()
	_label.name = "Countdown"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UiTheme.font(800)
	_label.font_size = 64
	_label.pixel_size = 0.0032
	_label.outline_size = 14
	_label.outline_modulate = Color(0.08, 0.06, 0.04, 0.85)
	_label.modulate = Color(1.0, 0.84, 0.42)
	_label.line_spacing = -8.0
	_label.position = Vector3(0, 1.85, 0)
	_label.visibility_range_end = 50.0
	_label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_label.layers = 2
	add_child(_label)
	_knock = randf_range(0.4, 1.0)
	_set_progress(progress())


func _process(delta: float) -> void:
	if is_built():
		set_process(false)
		return
	# Real time of play: on while the bag or a shop is open, not in the pause menu.
	if Game.is_paused():
		return
	var left := maxf(seconds_left() - delta, 0.0)
	entry["build_left"] = left
	if left <= 0.0:
		finish()
		return
	_set_progress(progress())
	_label_timer -= delta
	if _label_timer <= 0.0:
		_update_label()
	_work_sounds(delta)


func _set_progress(ratio: float) -> void:
	var stage := clampi(int(ratio * STAGES), 0, STAGES - 1)
	if stage == _stage:
		return
	var first := _stage < 0
	_stage = stage
	_house.mesh = PlaceableModels.doghouse_stage(stage)
	if not first and is_inside_tree():
		# The next part of the house goes on.
		Fx.dust_cloud(global_position + Vector3(0, 0.5, 0), Vector2(0.6, 0.7))
		Audio.play("plank", global_position + Vector3(0, 0.6, 0), -3.0)
	_update_label()


func _update_label() -> void:
	_label_timer = 0.5
	if _label:
		_label.text = "%s\n%s" % [UiTheme.caps(tr("SIGN_CONSTRUCTION")), tr("CROP_TIME_LEFT") % ConstructionSite.clock_text(seconds_left())]


## Hammer blows and boards knocked together, while near.
func _work_sounds(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_squared_to(global_position) > HEAR_RANGE * HEAR_RANGE:
		return
	_knock -= delta
	if _knock > 0.0:
		return
	_knock = randf_range(0.45, 1.6)
	var at := global_transform * Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.9), randf_range(-0.5, 0.5))
	if randf() < 0.75:
		Audio.play("wood_hit", at, randf_range(-11.0, -7.0), 0.12)
	else:
		Audio.play("plank", at, -9.0)


## Finishes the construction now: the site makes way for the house in a cloud of sawdust
## (sleeping through it, tests and debug call it too).
func finish() -> void:
	if is_built():
		return
	entry["stage"] = "done"
	entry["build_left"] = 0.0
	set_process(false)
	for n: Node in [_site, _label]:
		if n:
			n.queue_free()
	_site = null
	_label = null
	_show_finished()
	if is_inside_tree():
		Fx.dust_cloud(global_position + Vector3(0, 0.5, 0), Vector2(0.8, 0.9))
		Audio.play("plank", global_position + Vector3(0, 0.6, 0), 0.0)
		Audio.play("wood_hit", global_position + Vector3(0, 0.8, 0), -3.0)
	Game.notify(tr("MSG_BUILT") % tr("ITEM_DOGHOUSE"), Color(0.55, 1.0, 0.45))
	Events.building_completed.emit(BUILD_ID, self)


func _show_finished() -> void:
	_house.mesh = PlaceableModels.mesh(item_id, "body")
	_name = Label3D.new()
	_name.name = "NameBoard"
	_name.font = UiTheme.font(800)
	_name.font_size = 48
	_name.pixel_size = 0.0011
	_name.outline_size = 0
	_name.modulate = Color(0.2, 0.12, 0.07)
	_name.shaded = true
	_name.double_sided = false
	_name.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_name.position = Vector3(0, PlaceableModels.DOGHOUSE_DOOR.y + 0.14, PlaceableModels.DOGHOUSE_D * 0.5 + 0.022)
	_name.visibility_range_end = 25.0
	_name.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_name)
	_write_name()


## The dog's name on the board over the door (as long as fits it).
func _write_name() -> void:
	if _name:
		_name.text = UiTheme.caps(Pet.dog_name.left(10)) if Pet.has_dog() else ""


func _on_adopted(_dog_name: String) -> void:
	_write_name()


func _on_time_skipped(minutes: float) -> void:
	if not is_built() and minutes >= SKIP_FINISHES:
		finish()


# --- Prompts ------------------------------------------------------------------------------

func interact_title() -> String:
	return display_name()


## The countdown over the site, as a plain prompt line.
func hint_prompt() -> String:
	if is_built():
		return ""
	return "%s · %s" % [tr("SIGN_CONSTRUCTION"), tr("CROP_TIME_LEFT") % ConstructionSite.clock_text(seconds_left())]
