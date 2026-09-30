class_name FoodTable
extends PlacedObject
## The food table (Yemek Tezgahı; PlaceableTable kind "food_table", made at the
## workbench, put down with the placement preview): a butcher's table with an end-grain
## board (FoodTableModel).
##
## Holding a fish or game (a caught rabbit: ItemTable cat "game"), E lays it on the board,
## but only with a knife in the bag; without one the farmer is told a knife is needed
## (MSG_FOOD_TABLE_NEED_KNIFE) and keeps it. With the catch on the board and a knife in
## the bag, E cleans it: the knife comes down on it three times (chops, a spatter of
## blood and scales, the view jolting with each blow); a fish's head comes off
## (FoodModels.piece: the body with its cut face, "<fish>_cleaned") and is tipped into the
## offal pail, game is jointed into meat ("rabbit_meat" ×2). What comes of it flies into
## the bag (Events.food_cleaned) and the knife wears a little. Cleaned food cooks on the
## campfire into a meal that fills far more than the whole fish would (ItemTable). F takes
## back what lies on the board. Its FarmState entry keeps "board" (the item lying there)
## and "board_q" (its quality).

const CLEAN_SECONDS := 2.5
## Seconds into the cleaning the knife comes down, and the chop that parts it.
const CHOPS: Array[float] = [0.55, 1.1, 1.65]
const SEVER := 2
## Seconds the knife takes to rise before a chop, and how high it goes (m).
const RISE := 0.42
const LIFT := 0.13
## Game -> [meat item, pieces]; other game gives "<id>_meat" ×2 when there is such an item.
const MEAT := {&"rabbit": [&"rabbit_meat", 2]}
const KNIFE := &"knife"
## The longest the catch is drawn on the board (m).
const MAX_LENGTH := 0.52

var board: StringName = &""
var board_quality := 0
## Seconds into cleaning (-1: not cleaning).
var _t := -1.0
var _next_chop := 0
var _result: Array = []
var _holder: Node3D
var _whole: MeshInstance3D
var _pieces: Array[MeshInstance3D] = []
var _lay := Transform3D.IDENTITY
var _knife: MeshInstance3D
var _knife_base := Transform3D.IDENTITY
var _knife_tip := 0.2


func _setup() -> void:
	add_to_group(&"food_tables")
	_holder = Node3D.new()
	_holder.name = "Board"
	_holder.position = FoodTableModel.BOARD
	add_child(_holder)
	_knife = MeshInstance3D.new()
	_knife.mesh = ItemModels.mesh(KNIFE)
	_knife.layers = 2
	_knife.visible = false
	_knife.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_holder.add_child(_knife)
	# Blade down, its flat across the catch (the cut runs along the knife's plane), turned a
	# little toward the farmer so the blade shows.
	var kb := Basis(Vector3.UP, PI * 0.5 - 0.6) * Basis(Vector3.FORWARD, PI)
	_knife_base = Transform3D(kb, Vector3.ZERO)
	_knife_tip = _knife.mesh.get_aabb().end.y if _knife.mesh else 0.2
	var saved := StringName(String(entry.get("board", "")))
	if saved != &"" and ItemDB.has_item(saved):
		board_quality = int(entry.get("board_q", 0))
		_lay_down(saved, null)


# --- What it takes ----------------------------------------------------------------------

## [item, count] that cleaning `id` gives ([] when it can't be cleaned here): a fish comes
## out headed and gutted, game as joints of meat.
static func result_of(id: StringName) -> Array:
	if FishTable.is_fish(id):
		var c := FoodModels.cleaned_id(id)
		return [c, 1] if c != &"" and ItemDB.has_item(c) else []
	var item := ItemDB.get_item(id)
	if item == null or item.category != "game":
		return []
	if MEAT.has(id) and ItemDB.has_item(MEAT[id][0]):
		return MEAT[id]
	var meat := StringName(String(id) + "_meat")
	return [meat, 2] if ItemDB.has_item(meat) else []


static func cleanable(stack: ItemStack) -> bool:
	return stack != null and stack.item != null and not result_of(stack.item.id).is_empty()


## A knife in the bag that still cuts (null: none).
static func knife_stack() -> ItemStack:
	var inv := PlayerState.inventory
	for i in inv.size():
		var st := inv.get_stack(i)
		if st and (st.item.id == KNIFE or st.item.tool_type == KNIFE) and (not st.item.has_durability() or st.durability > 0):
			return st
	return null


func is_cleaning() -> bool:
	return _t >= 0.0


# --- Interaction ------------------------------------------------------------------------

func interact_title() -> String:
	return display_name()


func interact_prompt(_player: Node) -> String:
	if is_cleaning():
		return ""
	if board != &"":
		return tr("ACTION_CLEAN") if knife_stack() != null else ""
	if cleanable(PlayerState.selected_stack()):
		return tr("ACTION_PUT_ON_TABLE")
	return ""


func hint_prompt() -> String:
	if is_cleaning():
		return ""
	if board != &"":
		var line := ItemDB.get_item(board).display_name()
		if knife_stack() == null:
			line += "\n" + tr("MSG_FOOD_TABLE_NEED_KNIFE")
		return line
	if not cleanable(PlayerState.selected_stack()):
		return tr("HINT_FOOD_TABLE")
	return ""


func interact(player: Node) -> void:
	if is_cleaning():
		return
	if board != &"":
		if knife_stack() == null:
			_refuse()
			return
		_start_cleaning(player as Player)
		return
	var stack := PlayerState.selected_stack()
	if not cleanable(stack):
		return
	if knife_stack() == null:
		_refuse()
		return
	var taken := PlayerState.inventory.take_from(PlayerState.selected, 1)
	if taken == null:
		return
	board_quality = taken.quality
	_lay_down(taken.item.id, player as Player)
	_store()


func _refuse() -> void:
	Game.notify(tr("MSG_FOOD_TABLE_NEED_KNIFE"), UiTheme.RED)


func can_pick_up() -> bool:
	return board == &"" and not is_cleaning()


func info_prompt() -> String:
	if is_cleaning():
		return ""
	if board != &"":
		return tr("ACTION_TAKE_BACK")
	return super.info_prompt()


## F: what lies on the board back into the bag; an empty table picked up.
func info_interact(player: Node) -> void:
	if is_cleaning():
		return
	if board == &"":
		super.info_interact(player)
		return
	var id := board
	if PlayerState.inventory.add_item(id, 1, board_quality) > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
		return
	if player is Player and is_instance_valid(_whole):
		(player as Player).show_take(id, _whole.global_transform)
	_clear_board()
	_store()


# --- The catch on the board -------------------------------------------------------------

## `id` laid on its side on the board (flown there from the farmer's hand when `player`).
func _lay_down(id: StringName, player: Player) -> void:
	_clear_board()
	board = id
	var mesh := ItemModels.mesh(id)
	_lay = _lay_transform(mesh)
	_whole = MeshInstance3D.new()
	_whole.mesh = mesh
	_whole.layers = 2
	_whole.transform = _lay
	_holder.add_child(_whole)
	if FishTable.is_fish(id):
		# The pieces the knife will part it into load now, not on the blow.
		FoodModels.piece(id, "body")
		FoodModels.piece(id, "head")
	if player == null or not is_instance_valid(player):
		return
	var cam := player.camera
	var from := _holder.global_transform.affine_inverse() * Transform3D(cam.global_basis, cam.global_position
			- cam.global_basis.z * 0.5 + cam.global_basis.x * 0.2 - cam.global_basis.y * 0.25)
	_whole.transform = Transform3D(from.basis.orthonormalized().scaled(_lay.basis.get_scale()), from.origin)
	var tw := _whole.create_tween()
	tw.tween_property(_whole, "transform", _lay, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var at := _holder.global_position
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		if FishTable.is_fish(id):
			FishingAudio.play("flop", at, -8.0, 1.1)
		else:
			Audio.play("soft", at, -6.0, 0.1, &"Effects", 3.0, 0.8))


## The model lying on its side on the board, its middle over the board's, no longer than
## MAX_LENGTH.
static func _lay_transform(mesh: Mesh) -> Transform3D:
	if mesh == null:
		return Transform3D.IDENTITY
	var box := mesh.get_aabb()
	var b := Basis()
	if box.size.z > box.size.x:
		b = Basis(Vector3.UP, PI * 0.5)
	# Along X on its flank, the back toward the farmer.
	b = Basis(Vector3.RIGHT, PI * 0.5) * b
	var length := maxf(box.size.x, box.size.z)
	b = b.scaled(Vector3.ONE * minf(1.0, MAX_LENGTH / maxf(length, 0.001)))
	var tb := Transform3D(b, Vector3.ZERO) * box
	return Transform3D(b, Vector3(-tb.get_center().x, -tb.position.y + 0.002, -tb.get_center().z))


func _clear_board() -> void:
	board = &""
	board_quality = 0
	if is_instance_valid(_whole):
		_whole.queue_free()
	_whole = null
	for p in _pieces:
		if is_instance_valid(p):
			p.queue_free()
	_pieces.clear()


# --- Cleaning ---------------------------------------------------------------------------

func _start_cleaning(player: Player) -> void:
	_result = result_of(board)
	if _result.is_empty():
		return
	_t = 0.0
	_next_chop = 0
	_knife.visible = true
	_pose_knife()
	CampSfx.play("slice", _holder.global_position, -10.0, 0.06, 3.0)
	Events.action_progress_started.emit(tr("PROGRESS_CLEANING"), CLEAN_SECONDS)
	if player:
		player.kick_view(Vector4(0.6, 0.0, 0.0, -0.01))


func _process(delta: float) -> void:
	if _t < 0.0 or Game.is_paused():
		return
	_t += delta
	Events.action_progress_updated.emit(clampf(_t / CLEAN_SECONDS, 0.0, 1.0))
	while _next_chop < CHOPS.size() and _t >= CHOPS[_next_chop]:
		_chop(_next_chop)
		_next_chop += 1
	_pose_knife()
	if _t >= CLEAN_SECONDS:
		_finish()


## Where along the catch (board space, x) chop `i` lands: a fish's three at the neck,
## game jointed at three places along it.
func _chop_x(i: int) -> float:
	if FishTable.is_fish(board) and is_instance_valid(_whole):
		var box := _whole.mesh.get_aabb()
		var cut := box.end.x - box.size.x * float(FoodModels.HEAD_CUT.get(board, 0.2))
		return (_lay * Vector3(cut, 0.0, 0.0)).x
	var half := 0.1
	if is_instance_valid(_whole):
		half = (_lay * _whole.mesh.get_aabb()).size.x * 0.28
	return [-half, half, 0.0][clampi(i, 0, 2)]


## The knife over the board: rising before each chop, coming down fast onto the catch,
## resting in the cut a moment; drawn off and gone at the end.
func _pose_knife() -> void:
	if _t < 0.0:
		_knife.visible = false
		return
	var i := clampi(_next_chop, 0, CHOPS.size() - 1)
	var tc: float = CHOPS[i]
	var h := 0.0
	var start_h := 0.32 if i == 0 else 0.0
	if _next_chop >= CHOPS.size():
		# After the last chop: it rests, then is drawn up and away.
		var k := clampf((_t - CHOPS[-1] - 0.15) / 0.4, 0.0, 1.0)
		h = 0.35 * k * k
		_knife.visible = k < 1.0
	elif _t < tc - 0.08:
		var u := clampf((_t - (tc - RISE)) / (RISE - 0.08), 0.0, 1.0)
		h = lerpf(start_h, LIFT, u * u * (3.0 - 2.0 * u)) if u > 0.0 else start_h
	else:
		var u := clampf((_t - (tc - 0.08)) / 0.08, 0.0, 1.0)
		h = LIFT * (1.0 - u * u)
	var x := _chop_x(mini(_next_chop, CHOPS.size() - 1)) if _next_chop < CHOPS.size() else _chop_x(CHOPS.size() - 1)
	# Tipped back a little as it rises (the wrist cocks).
	var tilt := Basis(Vector3.RIGHT, -0.5 * h)
	_knife.transform = Transform3D(tilt * _knife_base.basis, Vector3(x, _knife_tip + h - 0.01, 0.02))


func _chop(i: int) -> void:
	var at := _holder.global_transform * Vector3(_chop_x(i), 0.02, 0.0)
	var fish := FishTable.is_fish(board)
	CampSfx.play("chop", at, -3.0, 0.08, 3.0)
	if not fish:
		CampSfx.play("meat_hit", at, -6.0, 0.08, 3.0)
	_burst(at, Color(0.32, 0.02, 0.02), 7, 0.004, 0.9)
	if fish:
		_burst(at, Color(0.78, 0.8, 0.82), 5, 0.003, 1.2)
	var player := Game.player as Player
	if player and player.global_position.distance_to(global_position) < 4.0:
		player.kick_view(Vector4(-0.9, 0.0, 0.3, -0.006))
	if i == SEVER:
		_part(at)


## The blow that parts it: a fish's head off and tipped into the pail, game in joints.
func _part(at: Vector3) -> void:
	if not is_instance_valid(_whole):
		return
	var id := board
	_whole.visible = false
	if FishTable.is_fish(id):
		var body := MeshInstance3D.new()
		body.mesh = FoodModels.piece(id, "body")
		body.layers = 2
		body.transform = _lay
		_holder.add_child(body)
		_pieces.append(body)
		var head := MeshInstance3D.new()
		head.mesh = FoodModels.piece(id, "head")
		head.layers = 2
		head.transform = _lay
		_holder.add_child(head)
		# The head slides off the board and drops into the offal pail.
		var pail := _holder.transform.affine_inverse() * FoodTableModel.PAIL
		var off := _lay.translated(Vector3(0.05, 0.0, 0.0))
		var over := Transform3D(_lay.basis, Vector3(pail.x, 0.12, pail.z))
		var into := Transform3D(_lay.basis.rotated(Vector3.FORWARD, 1.2), pail + Vector3(0, 0.02, 0))
		var tw := head.create_tween()
		tw.tween_property(head, "transform", off, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(head, "transform", over, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(head, "transform", into, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(head):
				Audio.play("soft", head.global_position, -10.0, 0.1, &"Effects", 2.0, 0.7)
				head.queue_free())
	else:
		var meat: StringName = _result[0]
		var n := int(_result[1])
		var m := ItemModels.mesh(meat)
		for k in n:
			var piece := MeshInstance3D.new()
			piece.mesh = m
			piece.layers = 2
			var z := (float(k) - (n - 1) * 0.5) * 0.13
			var turn := Basis(Vector3.UP, (0.25 if k % 2 == 0 else PI - 0.25))
			var rest := Transform3D(turn, Vector3(0.0, -m.get_aabb().position.y + 0.002, z))
			piece.transform = rest.translated(Vector3(0, 0.05, 0))
			_holder.add_child(piece)
			_pieces.append(piece)
			var tw := piece.create_tween()
			tw.tween_property(piece, "transform", rest, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_burst(at, Color(0.4, 0.04, 0.03), 10, 0.005, 1.1)


## Cleaned: what came of it flies into the bag, the knife wears, the board is clear.
func _finish() -> void:
	_t = -1.0
	_knife.visible = false
	var id: StringName = _result[0]
	var count := int(_result[1])
	var player := Game.player as Player
	var left := PlayerState.give(id, count)
	if left > 0:
		Pickup.spawn(ItemStack.create(id, left), global_position + Vector3(0, 1.1, 0), Vector3(0, 1.2, 0))
	if player and not _pieces.is_empty() and is_instance_valid(_pieces[0]):
		var p := _pieces[0]
		var from := p.global_transform
		if FishTable.is_fish(board):
			# The item's model is centred on what is left of the fish, turned end for end.
			from = from * Transform3D(Basis(Vector3.UP, PI), p.mesh.get_aabb().get_center())
		player.show_take(id, from)
	var knife := knife_stack()
	if knife and knife.item.has_durability():
		if player:
			player.wear_tool(knife)
		else:
			knife.durability = maxi(knife.durability - 1, 0)
	Audio.play("soft", _holder.global_position, -12.0, 0.1, &"Effects", 2.0)
	Events.action_progress_finished.emit(true)
	Events.food_cleaned.emit(id)
	_clear_board()
	_store()


## A spatter off the blow: `amount` droplets of `color` (blood, loose scales).
func _burst(at: Vector3, color: Color, amount: int, size: float, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.95
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.25
	m.material = mat
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


func _store() -> void:
	entry["board"] = String(board)
	entry["board_q"] = board_quality
