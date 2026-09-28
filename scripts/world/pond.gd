@tool
class_name Pond
extends Node3D
## Water surface for the pond plus an invisible ring that keeps the player on shore.
## The water body is interactable so the watering can can be refilled here (phase 3).


func _ready() -> void:
	add_to_group(&"interactable")
	for c in get_children():
		c.queue_free()
	position = Vector3(WorldLayout.POND_CENTER.x, WorldLayout.WATER_LEVEL, WorldLayout.POND_CENTER.y)
	var r := WorldLayout.POND_RADIUS
	var plane := PlaneMesh.new()
	plane.size = Vector2(r * 2.8, r * 2.8)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var body := StaticBody3D.new()
	body.name = "ShoreWall"
	body.collision_layer = 1
	body.collision_mask = 0
	var segments := 28
	var wall_r := r - 0.9
	for i in segments:
		var ang := TAU * (i + 0.5) / segments
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * wall_r / segments + 0.4, 4.0, 0.4)
		cs.shape = box
		cs.position = Vector3(cos(ang) * wall_r, 1.0, sin(ang) * wall_r)
		cs.rotation.y = -ang + PI * 0.5
		body.add_child(cs)
	add_child(body)

	# Water surface the player can aim at to refill the watering can.
	var surface := StaticBody3D.new()
	surface.name = "WaterSurface"
	surface.collision_layer = 4
	surface.collision_mask = 0
	var scs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r + 0.3
	cyl.height = 0.2
	scs.shape = cyl
	surface.add_child(scs)
	add_child(surface)


func use_prompt(_player: Node, stack: ItemStack) -> String:
	return WaterSource.use_prompt(stack)


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return WaterSource.use_action(stack)


func can_start(_action: Dictionary, stack: ItemStack) -> String:
	return WaterSource.can_start(stack)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	WaterSource.refill(stack)
