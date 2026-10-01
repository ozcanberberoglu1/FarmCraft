class_name CombatDummy
extends Node3D
## TEST ONLY (tests/ is left out of exported games): a wolf-sized straw target for the
## combat scenario, which measures every hit exactly on it. It is hittable
## (Combat: the "hittable" group and take_hit), its body a box on the animal layer that
## arrows strike and stick in, and it keeps every hit it took. At 0 health it falls over
## and can't be hit any more (like a carcass).

const SIZE := Vector3(0.36, 0.72, 1.05)
const MAX_HEALTH := 100.0

var health := MAX_HEALTH
## Every hit taken: {damage, from, kind}.
var hits: Array[Dictionary] = []
## Combat reads this for the knife's reach.
var hit_radius := 0.3


func _ready() -> void:
	add_to_group(&"hittable")
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	cs.shape = box
	cs.position.y = SIZE.y * 0.5
	body.add_child(cs)
	add_child(body)
	# A bale of straw on two stakes, a sack for a head.
	var mb := MeshBuilder.new()
	mb.box_at(&"straw", Vector3(0, SIZE.y * 0.55, 0), Vector3(SIZE.x, SIZE.y * 0.62, SIZE.z * 0.82), Color(0.82, 0.7, 0.42))
	for z: float in [-0.3, 0.3]:
		mb.box_at(&"wood", Vector3(0, SIZE.y * 0.13, z), Vector3(0.05, SIZE.y * 0.26, 0.05), Color(0.45, 0.33, 0.22))
	mb.box_at(&"cloth", Vector3(0, SIZE.y * 0.78, -SIZE.z * 0.5), Vector3(0.24, 0.22, 0.26), Color(0.62, 0.52, 0.38))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)


func can_be_hit() -> bool:
	return health > 0.0


func hit_center() -> Vector3:
	return global_position + Vector3(0, SIZE.y * 0.55, 0)


func take_hit(damage: float, from: Vector3, kind: StringName) -> void:
	if health <= 0.0:
		return
	hits.append({"damage": damage, "from": from, "kind": kind})
	health = maxf(health - damage, 0.0)
	if health <= 0.0:
		rotation.z = PI * 0.5


func total_damage(kind: StringName = &"") -> float:
	var sum := 0.0
	for h in hits:
		if kind == &"" or h["kind"] == kind:
			sum += float(h["damage"])
	return sum


## Back to full health, standing, no hits.
func reset() -> void:
	health = MAX_HEALTH
	hits.clear()
	rotation = Vector3.ZERO
