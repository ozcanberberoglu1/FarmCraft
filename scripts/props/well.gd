@tool
class_name Well
extends StaticBody3D
## Stone well with a small roof, crank and bucket. Refills the watering can (phase 3).

const STONE := Color(0.5, 0.5, 0.49)
const WOOD := Color(0.44, 0.42, 0.4)
const ROOF := Color(0.5, 0.48, 0.47)


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var mb := MeshBuilder.new()
	mb.ring(&"stone", Transform3D.IDENTITY, 0.85, 0.62, 0.85, 20, STONE, 0.0, 3)
	mb.ring(&"stone", Transform3D(Basis(), Vector3(0, 0.85, 0)), 0.9, 0.58, 0.1, 14, STONE.lightened(0.06), 0.0, 5)
	mb.cylinder(&"water_still", Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.62, 0.62, 0.3, 14, Color("27485a"), true, true)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(sx * 0.72, 1.05, 0), Vector3(0.12, 2.1, 0.12), WOOD, Vector3.ZERO, true)
	mb.cylinder_between(&"wood", Vector3(-0.78, 1.55, 0), Vector3(0.9, 1.55, 0), 0.06, 0.06, 8, WOOD.lightened(0.1))
	mb.box_at(&"wood", Vector3(0.95, 1.45, 0), Vector3(0.05, 0.25, 0.05), WOOD)
	mb.cylinder_between(&"wood", Vector3(0.95, 1.33, 0), Vector3(1.1, 1.33, 0), 0.025, 0.025, 6, WOOD)
	mb.cylinder_between(&"cloth", Vector3(0.0, 1.55, 0), Vector3(0.0, 1.12, 0), 0.012, 0.012, 4, Color("c9b48a"))
	var bucket := Transform3D(Basis(), Vector3(0, 0.9, 0))
	mb.cylinder(&"wood", bucket, 0.13, 0.16, 0.22, 10, Color(0.5, 0.44, 0.38))
	mb.ring(&"metal", bucket * Transform3D(Basis(), Vector3(0, 0.15, 0)), 0.162, 0.145, 0.03, 10, Color("4a4a4a"))
	mb.prism(&"roof", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2.08, 0)), 1.25, 0.55, 1.85, ROOF)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.92
	shape.height = 1.0
	cs.shape = shape
	cs.position.y = 0.5
	add_child(cs)


func use_prompt(_player: Node, stack: ItemStack) -> String:
	return WaterSource.use_prompt(stack)


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return WaterSource.use_action(stack)


func can_start(_action: Dictionary, stack: ItemStack) -> String:
	return WaterSource.can_start(stack)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	WaterSource.refill(stack)
