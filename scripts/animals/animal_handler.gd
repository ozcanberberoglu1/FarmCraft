class_name AnimalHandler
extends Node
## The farmer's hands for his own animals (a child of the Player).
## G on one of his birds (a hen, the rooster, a chick) picks it up: it is held in both arms
## in front of him, its head low in the middle of the view, alive in them (shifting its
## weight, looking about and blinking, clucking now and then, a wriggle and a flap of the
## wings, beating them a little while he runs). LMB, E (with nothing else to use it on) or
## G again sets it down on the ground in front of him; from there it goes on as usual (back
## into its pen when that is outside it, Animal._settle_where_left).
## G on one of his sheep, cows or horses slips a rope halter over its head: it walks after
## him along the way he went, keeping a couple of metres behind (through pen gates and
## doorways as he did, never over a fence he jumped), a sagging rope from the halter to his
## hand; E or G lets it go where it stands. Pulled too far (it can't follow, or he ran off)
## the halter slips off its head. With his hands full the item in hand is put away;
## leading, he walks at the animal's pace. Never the market's animals or a neighbour's.

## Seconds between a held bird's clucks, and between its wriggles; a wriggle's length.
const CLUCK_EVERY := Vector2(3.5, 9.0)
const WRIGGLE_EVERY := Vector2(3.0, 8.0)
const WRIGGLE_TIME := 0.7
## Where the held bird's head is in the view: across and down per metre of its distance
## (camera space), that distance from the bird's height (metres; nearest and farthest),
## and how far it is turned (radians about the view's up: its head toward the left, its
## right side and face to the farmer).
const HOLD_HEAD := Vector2(0.0, -0.32)
const HOLD_DIST := Vector2(0.28, 0.72)
const HOLD_YAW := 1.05
## Leading: metres of the farmer's way between the points kept; how far behind him the
## animal keeps (its radius on top); his pace on foot and running while he leads (m/s);
## the animal's fastest trot; the rope's reach beyond which it slips off its head (held
## that far SLIP_TIME seconds).
const TRAIL_STEP := 0.35
const LEAD_GAP := 2.0
const LEAD_WALK := 1.45
const LEAD_RUN := 3.0
const LEAD_TOP := 3.4
const ROPE_SLIP := 6.5
const SLIP_TIME := 0.5
## Height over the ground (m) of the line the animal looks along for fences and walls.
const LOOK_HEIGHT := 0.45
## The lead rope: its length, thickness and colour; its end in the farmer's hand (camera
## space).
const ROPE_LEN := 3.4
const ROPE_RADIUS := 0.011
const ROPE_COLOR := Color(0.5, 0.38, 0.24)
const HAND := Vector3(0.2, -0.27, -0.42)
## The halter per species: head length from the head bone to the muzzle, the noseband's
## and the crownpiece's radius (m, full size) and how far the face points down from
## straight ahead with the head up, standing (radians; the sheep's measured on its model).
const HALTER := {
	&"sheep": [0.31, 0.095, 0.115, 0.39],
	&"cow": [0.5, 0.14, 0.18, 0.9],
	&"horse": [0.58, 0.12, 0.16, 1.0],
}
## Seconds after the halter goes on that the face's way is taken again (its head is up by
## then, whatever it was doing).
const FACE_SETTLE := 0.8

var carried: Animal
var led: Animal

var _player: Player
var _rng := RandomNumberGenerator.new()
# Holding: the clock, the bird's head in its own frame and where it goes in the view, the
# sway behind the turning view, the next cluck and wriggle (seconds into one, -1: none).
var _t := 0.0
var _head_local := Vector3.ZERO
var _head_at := Vector3.ZERO
var _sway := Vector2.ZERO
var _last_basis := Basis.IDENTITY
var _cluck := 0.0
var _wriggle_wait := 0.0
var _wriggle_t := -1.0
# Leading: the farmer's way (points on the ground he walked), whether it is cut (he got
# somewhere the animal can't follow), where the animal's present stretch of it began, its
# pace, the next look for a short cut, and how long the rope has been pulled too far.
var _trail: Array[Vector3] = []
var _broken := false
var _from := Vector3.ZERO
var _pace := 0.0
var _shortcut := 0.0
var _slip := 0.0
# The halter's head bone, the face's direction in it (taken again FACE_SETTLE in), the
# species' halter sizes, and the mesh drawing the halter and the rope.
var _head_bone := -1
var _face_local := Vector3.FORWARD
var _face_wait := 0.0
var _halter: Array = []
var _rope: MeshInstance3D
var _rope_mesh: ImmediateMesh


func _ready() -> void:
	_player = get_parent() as Player
	_rng.randomize()
	Events.day_ending.connect(_on_day_ending)


## Hands full: a bird in the arms or an animal on the halter.
func busy() -> bool:
	return carried != null or led != null


## The farmer's top pace (m/s) while he leads an animal (INF otherwise).
func pace_cap(sprinting: bool) -> float:
	if led == null:
		return INF
	return LEAD_RUN if sprinting else LEAD_WALK


## The line offering G on `target` ("" when there is nothing to take hold of).
func offer_line(target: Object) -> String:
	if busy() or not is_instance_valid(target) or not target is Animal or _player.riding or _player.driving:
		return ""
	var a := target as Animal
	if a.can_carry():
		return "G (%s)" % tr("ACTION_HOLD_ANIMAL")
	if a.can_lead():
		return "G (%s)" % tr("ACTION_HALTER")
	return ""


## The lines while the hands are full: how to set the bird down or let the animal go (E
## when nothing else takes it, `e_free`).
func busy_lines(e_free: bool) -> PackedStringArray:
	var lines := PackedStringArray()
	if carried:
		lines.append("%s (%s)" % [tr("KEY_LMB"), tr("ACTION_SET_DOWN")])
	elif led:
		lines.append("%s (%s)" % [tr("KEY_E") if e_free else "G", tr("ACTION_LET_GO")])
	return lines


## G: sets down or lets go what is in hand, else takes hold of `target`.
func handle_pressed(target: Object) -> void:
	if busy():
		let_go()
		return
	if not is_instance_valid(target) or not target is Animal or _player.riding or _player.driving:
		return
	var a := target as Animal
	if a.can_carry():
		pick_up(a)
	elif a.can_lead():
		lead(a)


## Sets the bird down or takes the halter off, whichever is in hand.
func let_go() -> void:
	if carried:
		set_down()
	elif led:
		release()


## Animal `a` left the farmer's keeping some other way (teleported home overnight, or
## `freeing`: sold, taken to the vet, killed): his hands are empty again.
static func lost(a: Animal, freeing := false) -> void:
	var p := Game.player as Player
	if p == null or not is_instance_valid(p) or p.handler == null:
		return
	var h := p.handler
	if h.carried == a:
		if freeing:
			h._clear_carry()
		else:
			h.set_down()
	elif h.led == a:
		if freeing:
			h._clear_lead()
		else:
			h.release()


# --- Carrying -----------------------------------------------------------------------------

func pick_up(a: Animal) -> void:
	if busy() or not a.can_carry():
		return
	a.pick_up()
	carried = a
	_player.held.set_stowed(true)
	# Its head in its own frame (it faces -Z, its feet at the origin), from its body's size.
	var size := a.body_size()
	_head_local = Vector3(0.0, size.y * 0.84, -size.z * 0.36)
	var d := clampf(size.y * 1.35 + 0.06, HOLD_DIST.x, HOLD_DIST.y)
	_head_at = Vector3(HOLD_HEAD.x * d, HOLD_HEAD.y * d, -d)
	_sway = Vector2(0.0, -0.3)
	_last_basis = _player.camera.global_basis
	_cluck = _rng.randf_range(1.5, 3.0)
	_wriggle_wait = _rng.randf_range(WRIGGLE_EVERY.x, WRIGGLE_EVERY.y)
	# Snatched up: a squawk and a flap.
	_wriggle_t = 0.0
	_voice(a, -6.0)
	a.rig.held = 1.0
	_pose_carried(0.0)


## Down on the ground in front of the farmer (at his feet when a wall is right there),
## facing away from him.
func set_down() -> void:
	var a := carried
	if a == null:
		return
	_clear_carry()
	if not is_instance_valid(a) or not a.is_inside_tree():
		return
	var fwd := -_player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var feet := _player.global_position
	var spot := feet + fwd * (0.7 + a.radius())
	var space := _player.get_world_3d().direct_space_state
	var chest := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 0.9, 0), spot + Vector3(0, 0.3, 0), 1)
	if not space.intersect_ray(chest).is_empty():
		spot = feet + fwd * 0.2
	if a.housing.in_pen(spot):
		# Its own pen, coop floor or ramp.
		spot.y = a.housing.ground_height(spot)
	else:
		var down := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 1.2, 0), spot - Vector3(0, 2.5, 0), 1)
		var hit := space.intersect_ray(down)
		spot.y = (hit["position"] as Vector3).y if not hit.is_empty() else TerrainData.height(spot.x, spot.z)
	a.put_down(spot, atan2(-fwd.x, -fwd.z))
	_voice(a, -10.0)


func _clear_carry() -> void:
	carried = null
	_wriggle_t = -1.0
	_restore_hands()


## The bird in the arms this frame: in front of the view (after it, as the item in hand:
## lagging the turn, bobbing with the steps, breathing), shifting its weight, now and then
## a wriggle, its wings going a little while he runs; posed on the spot, legs tucked up.
func _pose_carried(delta: float) -> void:
	var a := carried
	var cam := _player.camera
	_t += delta
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var on_floor := _player.is_on_floor()
	var run := smoothstep(4.8, 6.6, speed) if on_floor else 0.8
	_wriggle_wait -= delta
	if _wriggle_wait <= 0.0 and _wriggle_t < 0.0:
		_wriggle_wait = _rng.randf_range(WRIGGLE_EVERY.x, WRIGGLE_EVERY.y)
		_wriggle_t = 0.0
	var wr := 0.0
	if _wriggle_t >= 0.0:
		_wriggle_t += delta
		var u := _wriggle_t / WRIGGLE_TIME
		wr = sin(PI * clampf(u, 0.0, 1.0))
		if u >= 1.0:
			_wriggle_t = -1.0
	_cluck -= delta
	if _cluck <= 0.0:
		_cluck = _rng.randf_range(CLUCK_EVERY.x, CLUCK_EVERY.y)
		if not a.in_faint():
			_voice(a, -12.0)
	var out := a.in_faint()
	# Unsteady beats while he runs, a flurry in a wriggle (none out cold).
	var beat := run * (0.55 + 0.45 * sin(_t * 2.9)) + wr * 0.7
	a.rig.flutter = move_toward(a.rig.flutter, 0.0 if out else clampf(beat, 0.0, 1.0), delta * 5.0)
	a.rig.held = 1.0
	if not out:
		a.rig.fluff = wr * 0.5
	var basis_now := cam.global_basis
	var turn := (_last_basis.inverse() * basis_now).get_euler()
	_last_basis = basis_now
	_sway += Vector2(-turn.y, turn.x) * 0.5
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	_sway = _sway.clamp(Vector2(-0.07, -0.35), Vector2(0.07, 0.07))
	var bob := sin(_t * 9.0) * 0.014 * clampf(speed / 4.0, 0.0, 1.5) if on_floor else 0.0
	var breath := sin(_t * 2.4) * 0.003
	var off := Vector3(_sway.x, _sway.y + bob + breath, 0.0)
	# Shifting about in the arms; a wriggle turns it this way and that.
	var shift := sin(_t * 0.6 + float(a.data.id)) * 0.08 + sin(_t * 1.7) * 0.03
	var w := maxf(_wriggle_t, 0.0)
	var yaw := HOLD_YAW + shift + sin(w * 19.0) * 0.15 * wr
	var roll := sin(w * 23.0 + 1.0) * 0.07 * wr + sin(_t * 1.1) * 0.025
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.06 + run * 0.06) * Basis(Vector3.BACK, roll)
	var origin := _head_at - b * _head_local + off
	a.global_transform = cam.global_transform * Transform3D(b, origin)
	a.rig.animate(delta, 0.0, AnimalRig.Mode.IDLE)


## A cluck (a rooster's lower, a chick's cheep) from the bird in the arms.
func _voice(a: Animal, volume_db: float) -> void:
	var at := a.global_transform * _head_local
	if a.data.is_chick():
		Audio.play("chick", at, volume_db + 2.0, 0.12, &"Effects", 3.0, _rng.randf_range(0.95, 1.12))
	else:
		Audio.play("chicken", at, volume_db, 0.06, &"Effects", 4.0, 0.82 if a.data.species == &"rooster" else 1.0)


# --- Leading ------------------------------------------------------------------------------

func lead(a: Animal) -> void:
	if busy() or not a.can_lead():
		return
	a.begin_lead()
	led = a
	_player.held.set_stowed(true)
	var me := _player.global_position
	_from = a.global_position
	_trail.clear()
	_trail.append(me)
	# Not through the fence it stands behind: it follows once he comes round to it.
	_broken = not _clear(a.global_position, me)
	_pace = 0.0
	_slip = 0.0
	_shortcut = 0.0
	_setup_halter(a)
	Audio.animal_voice(a.data.species, a.data.adult, a.global_position, -9.0)
	Audio.play("soft", a.global_position + Vector3(0, 1.0, 0), -14.0, 0.1, &"Effects", 3.0, 1.3)


## The halter off where it stands (`slipped`: it slipped off, the farmer is told).
func release(slipped := false) -> void:
	var a := led
	if a == null:
		return
	_clear_lead()
	if not is_instance_valid(a) or not a.is_inside_tree():
		return
	a.end_lead()
	if slipped:
		Game.notify(tr("MSG_HALTER_SLIPPED") % a.data.name, Color(1.0, 0.75, 0.4))


func _clear_lead() -> void:
	led = null
	_trail.clear()
	_head_bone = -1
	if is_instance_valid(_rope):
		_rope.queue_free()
	_rope = null
	_rope_mesh = null
	_restore_hands()


## One tick of the lead: the farmer's way grows behind him; the animal walks along it to
## keep its distance (his pace, a little more to catch up, a trot at most), cutting a corner
## where nothing stands in between; pulled too far, the halter slips off.
func _lead_tick(delta: float) -> void:
	var a := led
	var me := _player.global_position
	if _broken:
		# Back where it was cut (or round to it): it can follow again.
		if _flat(me, _trail.back()) < 0.8 and absf(me.y - _trail.back().y) < 0.6:
			_broken = false
	elif _player.is_on_floor() and _flat(me, _trail.back()) > TRAIL_STEP:
		# Only from the ground: a jump over a fence leaves a gap it can't cross.
		if _clear(_trail.back(), me):
			_trail.append(me)
		else:
			_broken = true
	_shortcut -= delta
	if _shortcut <= 0.0:
		_shortcut = 0.3
		_try_shortcut()
	var pos := a.global_position
	var left := _flat(pos, _trail[0])
	for i in _trail.size() - 1:
		left += _flat(_trail[i], _trail[i + 1])
	if not _broken:
		left += _flat(_trail.back(), me)
	var excess := left - (LEAD_GAP + a.radius())
	var his := Vector2(_player.velocity.x, _player.velocity.z).length()
	var want := 0.0
	if excess > 0.0:
		want = clampf(his * smoothstep(0.0, 0.5, excess) + excess * 0.9, 0.0, LEAD_TOP)
		if a.data.injured():
			want *= Animal.INJURED_PACE
	_pace = move_toward(_pace, want, delta * (2.5 if want > _pace else 4.0))
	var step := _pace * delta
	var p := pos
	while step > 0.0001:
		var to: Vector3 = _trail[0]
		var d := _flat(p, to)
		if d <= step:
			p = to
			step -= d
			if _trail.size() == 1:
				break
			_from = to
			_trail.pop_front()
		else:
			var dir := Vector3(to.x - p.x, 0.0, to.z - p.z) / d
			p += dir * step
			var span := _flat(_from, to)
			var u := 1.0 - _flat(p, to) / span if span > 0.001 else 1.0
			p.y = lerpf(_from.y, to.y, clampf(u, 0.0, 1.0))
			step = 0.0
	a.lead_step(p, (p - pos).length() / maxf(delta, 0.0001), delta)
	# The rope can't reach any further: off it slips.
	if _flat(p, me) > ROPE_SLIP + a.radius():
		_slip += delta
		if _slip >= SLIP_TIME:
			release(true)
	else:
		_slip = 0.0


## Straight on to a point further along its way when nothing stands in between (within a
## few metres; one look at a time).
func _try_shortcut() -> void:
	if _trail.size() < 2:
		return
	var pos := led.global_position
	for i in range(_trail.size() - 1, 0, -1):
		if _flat(pos, _trail[i]) > 5.0:
			continue
		if _clear(pos, _trail[i]):
			_from = pos
			_trail = _trail.slice(i)
		return


## Nothing solid (a fence, a wall) on the way from `a` to `b`, looked along LOOK_HEIGHT over
## the ground (gates are open to it).
func _clear(a: Vector3, b: Vector3) -> bool:
	var up := Vector3(0, LOOK_HEIGHT, 0)
	var q := PhysicsRayQueryParameters3D.create(a + up, b + up, 1)
	return _player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The halter's sizes and the face's direction in the head bone (from the model's rest
## pose, so it follows the head as it moves), and the mesh that draws it with the rope.
func _setup_halter(a: Animal) -> void:
	_halter = HALTER.get(a.data.species, HALTER[&"sheep"])
	_head_bone = a.rig._bone("head")
	_take_face(a)
	_face_wait = FACE_SETTLE
	_rope_mesh = ImmediateMesh.new()
	_rope = MeshInstance3D.new()
	_rope.name = "LeadRope"
	_rope.mesh = _rope_mesh
	_rope.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_rope.layers = 2
	_rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROPE_COLOR
	mat.roughness = 0.92
	_rope.material_override = mat
	add_child(_rope)


## The face's way in the head bone, from the head as it is now: straight ahead and down
## by the species' angle (FACE_SETTLE after the halter goes on the head is up, so it holds
## as the head moves from then on).
func _take_face(a: Animal) -> void:
	if _head_bone < 0:
		return
	var sk := a.rig.skeleton
	var head := (sk.global_transform * sk.get_bone_global_pose(_head_bone)).basis
	var down := float(_halter[3])
	var ahead := -a.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	_face_local = head.inverse() * (ahead * cos(down) + Vector3.DOWN * sin(down))


## The halter on the head (crownpiece behind the ears, noseband round the muzzle, a cheek
## strap each side) and the rope sagging from under the jaw to the farmer's hand.
func _draw_lead() -> void:
	var a := led
	if _rope_mesh == null:
		return
	var s := a.rig.scale.x
	var poll := a.global_transform * Vector3(0, 1.0, -0.6)
	var face := -a.global_basis.z
	if _head_bone >= 0:
		var sk := a.rig.skeleton
		var hx := sk.global_transform * sk.get_bone_global_pose(_head_bone)
		poll = hx.origin
		face = (hx.basis * _face_local).normalized()
	var side := a.global_basis.x.normalized()
	side = (side - face * face.dot(side)).normalized()
	var below := side.cross(face).normalized()
	if below.dot(Vector3.DOWN) < 0.0:
		below = -below
	var head_len := float(_halter[0]) * s
	var r_nose := float(_halter[1]) * s
	var r_crown := float(_halter[2]) * s
	var nose := poll + face * head_len * 0.74
	var crown := poll + face * head_len * 0.06
	_rope_mesh.clear_surfaces()
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var nose_ring := _ring(nose, side, below, r_nose, r_nose * 1.15)
	var crown_ring := _ring(crown, side, below, r_crown, r_crown * 1.1)
	_tube(nose_ring, ROPE_RADIUS * 0.9)
	_tube(crown_ring, ROPE_RADIUS * 0.9)
	for k: float in [-1.0, 1.0]:
		var strap: Array[Vector3] = [crown + side * r_crown * k, nose + side * r_nose * k]
		_tube(strap, ROPE_RADIUS * 0.8)
	var chin := nose + below * r_nose * 1.15
	var hand := _player.camera.global_transform * HAND
	var pts: Array[Vector3] = []
	var dist := chin.distance_to(hand)
	var sag := clampf(0.06 + maxf(ROPE_LEN - dist, 0.0) * 0.45, 0.04, 0.9)
	var n := 24
	for i in n + 1:
		var u := float(i) / n
		var q := chin.lerp(hand, u) - Vector3(0, sag * 4.0 * u * (1.0 - u), 0)
		q.y = maxf(q.y, TerrainData.height(q.x, q.z) + 0.02)
		pts.append(q)
	_tube(pts, ROPE_RADIUS)
	_rope_mesh.surface_end()


## A closed loop of points round `c` (radii along `x` and `y`).
static func _ring(c: Vector3, x: Vector3, y: Vector3, rx: float, ry: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 15:
		var t := TAU * float(i) / 14.0
		out.append(c + x * cos(t) * rx + y * sin(t) * ry)
	return out


## A rope of radius `r` along `pts` into the open surface (five sides).
func _tube(pts: Array[Vector3], r: float) -> void:
	var sides := 5
	var rings: Array = []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
		var nx := t.cross(ref).normalized()
		var ny := t.cross(nx).normalized()
		var ring: Array[Vector3] = []
		for k in sides:
			var ang := TAU * float(k) / sides
			ring.append(nx * cos(ang) + ny * sin(ang))
		rings.append(ring)
	for i in pts.size() - 1:
		var ra: Array[Vector3] = rings[i]
		var rb: Array[Vector3] = rings[i + 1]
		for k in sides:
			var k2 := (k + 1) % sides
			for v: Array in [[ra[k], pts[i]], [rb[k], pts[i + 1]], [rb[k2], pts[i + 1]],
					[ra[k], pts[i]], [rb[k2], pts[i + 1]], [ra[k2], pts[i]]]:
				var nrm: Vector3 = v[0]
				_rope_mesh.surface_set_normal(nrm)
				_rope_mesh.surface_add_vertex((v[1] as Vector3) + nrm * r)


# --- Every frame --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if carried:
		if is_instance_valid(carried):
			_pose_carried(delta)
		else:
			_clear_carry()
	if led:
		if is_instance_valid(led):
			if _face_wait > 0.0:
				_face_wait -= delta
				if _face_wait <= 0.0:
					_take_face(led)
			_draw_lead()
		else:
			_clear_lead()


func _physics_process(delta: float) -> void:
	if led:
		if is_instance_valid(led):
			_lead_tick(delta)
		else:
			_clear_lead()


## The item in hand back out (unless riding or driving put it away).
func _restore_hands() -> void:
	if is_instance_valid(_player) and not busy():
		_player.held.set_stowed(_player.riding != null or _player.driving != null)


## Off to bed: the bird and the animal on the halter go home for the night (Animals puts
## them in their housing).
func _on_day_ending() -> void:
	var a := carried if carried else led
	if a == null or not is_instance_valid(a):
		return
	let_go()
	if is_instance_valid(a) and a.is_inside_tree() and a.housing:
		a.data.away = false
		a.teleport_home(a.housing.has_shelter() and a.housing.can_pass())
