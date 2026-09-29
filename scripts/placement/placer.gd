class_name Placer
extends Node3D
## Placement preview for the placeable in the player's hand: a see-through copy of the
## model sits where the player looks, snapped to a GRID on the ground and turned with R
## in 45° steps; green where it fits, red where it doesn't. Left click puts it down.
## Machines go on open farm land: not in town, not on the road, not on steep ground and
## not into anything else.
## Building kits (PlaceableTable "building": the coop kit, the workbench) show the finished building on
## its whole plot, further out ("reach"), its door toward the player and turned in 15°
## steps. The plot must be open, level enough farm land clear of buildings, fences,
## vehicles, water, fields, tracks, the yard's fixtures and other plots; where it isn't,
## a red "Can't build here" floats over it. Put down, a building starts as a
## construction site (Events.construction_started).

const REACH := 6.5
const GRID := 0.25
## Buildings: grid, turn step and the most the ground may rise across the plot (m).
const BUILDING_GRID := 0.5
const BUILDING_STEP := PI / 12.0
const MAX_SPAN := 0.6
## Seconds a building's verdict holds while the spot doesn't change.
const RECHECK := 0.25

var active := false
var valid := false
var reason := ""
var _id: StringName = &""
var _info: Dictionary = {}
var _yaw := 0.0
var _ghost: MeshInstance3D
var _ok: StandardMaterial3D
var _bad: StandardMaterial3D
var _ok_building: StandardMaterial3D
var _bad_building: StandardMaterial3D
var _warning: Label3D
var _last_spot := Vector3.INF
var _recheck := 0.0


func _ready() -> void:
	top_level = true
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	_ok = _material(Color(0.35, 1.0, 0.45, 0.42))
	_bad = _material(Color(1.0, 0.3, 0.25, 0.42))
	_ok_building = _building_material(Color(0.35, 1.0, 0.45, 0.4))
	_bad_building = _building_material(Color(1.0, 0.3, 0.25, 0.42))
	_warning = Label3D.new()
	_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warning.font = UiTheme.font(800)
	_warning.font_size = 64
	_warning.pixel_size = 0.004
	_warning.outline_size = 14
	_warning.outline_modulate = Color(0.1, 0.02, 0.0, 0.85)
	_warning.modulate = UiTheme.RED
	_warning.no_depth_test = true
	_warning.fixed_size = false
	_warning.visible = false
	add_child(_warning)
	visible = false


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.no_depth_test = false
	return m


## A building's silhouette: only its outer surfaces show (depth pre-pass), lightly
## shaded so its form reads.
func _building_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.albedo_color = c
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b) * 0.45
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## What the preview shows: a kit's finished building on its plot, else the placeable.
static func ghost_mesh(id: StringName) -> ArrayMesh:
	match String(PlaceableTable.get_info(id).get("kind", "")):
		"coop":
			return ChickenCoop.ghost_mesh()
	return PlaceableModels.mesh(id, "whole")


## Whether the placeable in hand is a building kit.
func is_building() -> bool:
	return active and bool(_info.get("building", false))


## Called by the player every physics frame.
func update(player: Player) -> void:
	var stack := PlayerState.selected_stack()
	var id: StringName = stack.item.id if stack and PlaceableTable.is_placeable(stack.item.id) else &""
	active = id != &"" and not Game.is_ui_open() and player.driving == null and player.riding == null
	visible = active
	if not active:
		_id = &""
		return
	if id != _id:
		_id = id
		_info = PlaceableTable.get_info(id)
		_ghost.mesh = ghost_mesh(id)
		_last_spot = Vector3.INF
		if bool(_info.get("building", false)):
			# Door toward the farmer.
			_yaw = wrapf(snappedf(player.rotation.y, BUILDING_STEP), -PI, PI)
	var building := bool(_info.get("building", false))
	var reach := float(_info.get("reach", REACH))
	var cam := player.camera
	var from := cam.global_position
	var fwd := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * reach, 1)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3
	if hit.is_empty():
		p = from + fwd * (minf(reach * 0.6, 8.0) if building else 3.0)
	else:
		p = hit["position"]
	if building:
		# The plot's near edge where the farmer looks.
		var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var b := Basis(Vector3.UP, _yaw)
		var size: Vector3 = _info["size"]
		p += flat * (absf(flat.dot(b.x)) * size.x * 0.5 + absf(flat.dot(b.z)) * size.z * 0.5)
	var grid := BUILDING_GRID if building else GRID
	p.x = snappedf(p.x, grid)
	p.z = snappedf(p.z, grid)
	p.y = TerrainData.height(p.x, p.z)
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), p)
	# A building's checks sample its whole plot: only again when it moves (or now and then).
	var spot := Vector3(p.x, _yaw, p.z)
	_recheck -= get_physics_process_delta_time()
	if not building or spot != _last_spot or _recheck <= 0.0:
		_last_spot = spot
		_recheck = RECHECK
		reason = _check(player, p)
		valid = reason == ""
	if building:
		_ghost.material_override = _ok_building if valid else _bad_building
		_warning.visible = not valid
		if not valid:
			var size: Vector3 = _info["size"]
			# A heading without its full stop over the reason.
			var head := tr("MSG_CANT_BUILD_HERE").trim_suffix(".").trim_suffix("。")
			var text := "%s\n%s" % [UiTheme.caps(head), tr(reason)]
			if _warning.text != text:
				_warning.text = text
			_warning.position = Vector3(0, size.y + 1.6, 0)
	else:
		_ghost.material_override = _ok if valid else _bad
		_warning.visible = false


func rotate_step() -> void:
	_yaw = wrapf(_yaw + (BUILDING_STEP if bool(_info.get("building", false)) else PI * 0.25), -PI, PI)


## "" where it fits, else why not (a translation key).
func _check(player: Player, p: Vector3) -> String:
	var size: Vector3 = _info["size"]
	var building := bool(_info.get("building", false))
	var xf := Transform3D(Basis(Vector3.UP, _yaw), p)
	var spots: Array[Vector3] = [p]
	if building:
		# The corners and the middle of each side too.
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
			spots.append(xf * Vector3(s.x * size.x * 0.5, 0.0, s.y * size.z * 0.5))
	for s in spots:
		if WorldLayout.playable_distance(s.x, s.z) < 1.0 \
				or Vector2(s.x, s.z).distance_to(WorldLayout.TOWN_CENTER) < WorldLayout.TOWN_BOUNDARY_RADIUS + 8.0 \
				or WorldLayout.distance_to_road(s.x, s.z) < 5.0:
			return "MSG_BUILD_FARM_ONLY" if building else "MSG_PLACE_FARM_ONLY"
	if TerrainData.normal_at(p.x, p.z).y < 0.93:
		return "MSG_PLACE_FLAT"
	if building:
		var r := _plot_reason(player, xf, size)
		if r != "":
			return r
	elif in_building_plot(p):
		# A coop's yard is its hens' (they would walk through a machine).
		return "MSG_PLACE_BLOCKED"
	if String(_info.get("kind", "")) == "campfire":
		# A fire burns out of doors, on open ground: never inside or under a roof, on a
		# field or a track, or by the water (Campfire).
		if indoors(p):
			return "MSG_PLACE_INDOORS"
		var why := Campfire.placement_reason(player, p)
		if why != "":
			return why
	var shape := BoxShape3D.new()
	var fill := 0.97 if building else 0.94
	shape.size = Vector3(size.x * fill, size.y * 0.85, size.z * fill)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(Vector3.UP, _yaw), p + Vector3(0, size.y * 0.5 + 0.12, 0))
	q.collision_mask = 1 | 4 | 16
	var exclude: Array[RID] = [player.get_rid()]
	for path in ["Terrain/Collision", "Road/Collision"]:
		var body := Game.world.get_node_or_null(path) as CollisionObject3D if Game.world else null
		if body:
			exclude.append(body.get_rid())
	q.exclude = exclude
	# A plot can hold dozens of grass clumps: take enough hits that a fence post or a
	# tree among them is not left out.
	for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(q, 64 if building else 1):
		# Tall grass is cleared when a building goes up.
		if building and hit["collider"] is GrassPatch:
			continue
		return "MSG_PLACE_BLOCKED"
	return ""


## A building's plot, sampled every metre: no water, nothing the farm keeps for its
## fields, buildings, tracks and yard fixtures, not too uneven, not over another plot
## and not on top of the farmer.
func _plot_reason(player: Player, xf: Transform3D, size: Vector3) -> String:
	var lo := INF
	var hi := -INF
	var nx := maxi(ceili(size.x), 1)
	var nz := maxi(ceili(size.z), 1)
	for ix in nx + 1:
		for iz in nz + 1:
			var w := xf * Vector3((float(ix) / nx - 0.5) * size.x, 0.0, (float(iz) / nz - 0.5) * size.z)
			if WorldLayout.distance_to_pond(w.x, w.z) < WorldLayout.POND_RADIUS + 2.0 or TerrainData.is_underwater(w.x, w.z, 0.3):
				return "MSG_PLACE_WATER"
			if reserved(w.x, w.z):
				return "MSG_PLACE_RESERVED"
			var h := TerrainData.height(w.x, w.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	if hi - lo > MAX_SPAN:
		return "MSG_PLACE_FLAT"
	# Other plots have no fence to bump into: keep off them.
	var half := Vector2(size.x, size.z) * 0.5
	for e: Dictionary in FarmState.placed:
		var other := PlaceableTable.get_info(StringName(e["id"]))
		if not bool(other.get("building", false)):
			continue
		var osize: Vector3 = other["size"]
		var opos: Vector3 = e["pos"]
		var oxf := Transform3D(Basis(Vector3.UP, float(e.get("yaw", 0.0))), opos)
		if _plots_overlap(xf, half, oxf, Vector2(osize.x, osize.z) * 0.5):
			return "MSG_PLACE_BLOCKED"
	var l := xf.affine_inverse() * player.global_position
	if absf(l.x) < half.x + 0.4 and absf(l.z) < half.y + 0.4:
		return "MSG_PLACE_TOO_CLOSE"
	return ""


## Whether `p` lies on the plot of a building put up from a kit (a coop and its yard).
static func in_building_plot(p: Vector3) -> bool:
	for e: Dictionary in FarmState.placed:
		var info := PlaceableTable.get_info(StringName(e["id"]))
		if not bool(info.get("building", false)):
			continue
		var size: Vector3 = info["size"]
		var pos: Vector3 = e["pos"]
		var l := Transform3D(Basis(Vector3.UP, float(e.get("yaw", 0.0))), pos).affine_inverse() * p
		if absf(l.x) < size.x * 0.5 and absf(l.z) < size.z * 0.5:
			return true
	return false


## Whether `p` is inside one of the farm's buildings: the house (as big as it is now),
## the warehouse, the barn and Grandpa's coop where they stand.
static func indoors(p: Vector3) -> bool:
	var pt := Vector2(p.x, p.z)
	if WorldLayout.house_rect(FarmState.house_level()).grow(0.3).has_point(pt) or WorldLayout.WAREHOUSE_RECT.has_point(pt):
		return true
	if FarmState.barn_level() > 0 and WorldLayout.BARN_BUILDING.has_point(pt):
		return true
	return FarmState.coop_level() > 0 and WorldLayout.COOP_BUILDING.has_point(pt)


## Whether two turned rects (centre and yaw in their transforms, half sizes) overlap
## (separating axes).
static func _plots_overlap(a: Transform3D, ha: Vector2, b: Transform3D, hb: Vector2) -> bool:
	var d := b.origin - a.origin
	var axes: Array[Vector3] = [a.basis.x, a.basis.z, b.basis.x, b.basis.z]
	for axis in axes:
		var ax := Vector3(axis.x, 0.0, axis.z).normalized()
		var ra := ha.x * absf(a.basis.x.dot(ax)) + ha.y * absf(a.basis.z.dot(ax))
		var rb := hb.x * absf(b.basis.x.dot(ax)) + hb.y * absf(b.basis.z.dot(ax))
		if absf(Vector3(d.x, 0.0, d.z).dot(ax)) > ra + rb:
			return false
	return true


## Ground the farm keeps for other things: the garden lots (bought or not), the barn's
## paddock, Grandpa's run where it stands, the house as big as it can grow, the
## warehouse and its apron, the quarry, the dirt tracks and the yard's fixtures (the
## truck's spot, the well, the shipping bin, the board, the dung heap).
static func reserved(x: float, z: float) -> bool:
	var pt := Vector2(x, z)
	for lot_id: StringName in WorldLayout.FIELD_LOTS:
		var lot: Rect2 = WorldLayout.FIELD_LOTS[lot_id]["rect"]
		if lot.grow(1.0).has_point(pt):
			return true
	if WorldLayout.BARN_PEN.grow(1.0).has_point(pt) or WorldLayout.QUARRY_RECT.has_point(pt):
		return true
	if FarmState.coop_level() > 0 and WorldLayout.COOP_PEN.grow(1.0).has_point(pt):
		return true
	if WorldLayout.house_rect(3).grow(1.5).has_point(pt) or WorldLayout.WAREHOUSE_RECT.grow(2.0).has_point(pt):
		return true
	for r: Rect2 in WorldLayout.NO_GRASS_RECTS:
		if r.has_point(pt):
			return true
	if pt.distance_to(WorldLayout.FARM_TRUCK_SPOT) < 4.5 or pt.distance_to(WorldLayout.MANURE_HEAP) < 3.0:
		return true
	for fixture: Vector3 in [WorldLayout.WELL_POS, WorldLayout.SHIPPING_BIN_POS, WorldLayout.BOARD_POS]:
		if pt.distance_to(Vector2(fixture.x, fixture.z)) < 2.5:
			return true
	return TerrainData.path_at(x, z) > 0.3


## Puts the held item down here. Returns true when placed.
func place() -> bool:
	if not active:
		return false
	var building := bool(_info.get("building", false))
	var player := get_parent() as Player
	if building and player:
		# The verdict may be up to RECHECK old: the farmer may have stepped onto the plot.
		reason = _check(player, global_position)
		valid = reason == ""
	if not valid:
		var msg := tr(reason)
		if building:
			msg = "%s %s" % [tr("MSG_CANT_BUILD_HERE"), msg]
		Game.notify(msg, UiTheme.RED)
		return false
	var e := FarmState.add_placed(_id, global_position, _yaw)
	if building:
		# It goes up as a construction site first.
		e["stage"] = "site"
		e["build_left"] = PlaceableTable.build_seconds(_id)
	var node := Game.world.farm.spawn_placed(e) as PlacedObject
	var id := _id
	PlayerState.inventory.remove_item(_id, 1)
	Events.placed.emit(id)
	if building:
		var size: Vector3 = _info["size"]
		Audio.play("plank", global_position + Vector3(0, 0.5, 0), 0.0)
		Audio.play("wood_hit", global_position + Vector3(0, 0.5, 0), -4.0)
		Fx.dust_cloud(global_position + Vector3(0, 0.4, 0), Vector2(size.x, size.z) * 0.4)
		var what := tr(String(_info["name_key"])) if _info.has("name_key") else ItemDB.get_item(id).display_name()
		Game.notify(tr("MSG_CONSTRUCTION_STARTED") % [what, maxi(ceili(float(e["build_left"]) / 60.0), 1)], UiTheme.GREEN)
		Events.construction_started.emit(StringName(_info.get("build_id", id)), node)
	else:
		Audio.play("plank", global_position + Vector3(0, 0.3, 0), -4.0)
		Fx.dirt_burst(global_position + Vector3(0, 0.05, 0), 0.7)
	return true
