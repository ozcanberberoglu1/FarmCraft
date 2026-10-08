class_name DogBowl
extends StaticBody3D
## The farmer's own dog's food bowl: a red enamel bowl on the ground by its doghouse's
## door (until one stands, by its bed at the farmhouse). Pet puts it there, keeps it with
## the dog's home and owns what is in it (Pet.bowl_meals, saved): this is only how it looks
## and what the farmer does at it. Looked at, it tells how full it is the way the troughs
## do ("Dog food: 75% · 3 meals": hint_prompt), and to the eye: kibble heaped in it by the
## meal. With a sack of dog food in the bag E pours one in (Pet.fill_bowl: Pet.SACK_MEALS
## meals, when there is room for a whole sack). The dog eats from it by itself (PetDog
## &"eat"). Too low to stand in anyone's way: only the farmer's look finds it.

const RADIUS := 0.15
const HEIGHT := 0.07
## The layer the farmer's look finds (not the world's: nobody trips on it, and the dog's
## feet and nose never feel it).
const LOOK_LAYER := 4

var _fill: MeshInstance3D
var _shown := -1


func _init() -> void:
	name = "PetBowl"


func _ready() -> void:
	collision_layer = LOOK_LAYER
	collision_mask = 0
	add_to_group(&"interactable")
	var mb := MeshBuilder.new()
	var enamel := Color(0.6, 0.13, 0.1)
	# Wider at the foot than at the rim (it does not tip), a pale rim, dark inside.
	mb.cylinder(&"metal", Transform3D.IDENTITY, RADIUS, RADIUS * 0.84, HEIGHT, 20, enamel)
	mb.ring(&"metal", Transform3D(Basis(), Vector3(0, HEIGHT - 0.004, 0)), RADIUS * 0.86, RADIUS * 0.74, 0.008, 20, Color(0.86, 0.84, 0.78))
	mb.disc(&"galv", Transform3D(Basis(), Vector3(0, HEIGHT + 0.0015, 0)), RADIUS * 0.75, 20, Color(0.2, 0.2, 0.21))
	var mi := MeshInstance3D.new()
	mi.name = "Bowl"
	mi.mesh = mb.build()
	mi.visibility_range_end = 60.0
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	# The kibble: a low heap of brown pellets, scaled by the meals in it.
	var fb := MeshBuilder.new()
	var brown := Color(0.42, 0.26, 0.13)
	var r := RADIUS * 0.72
	fb.sphere(&"veg_rough", Transform3D.IDENTITY, Vector3(r, 0.034, r), 14, 5, brown)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 44:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.9
		var y := 0.034 * sqrt(maxf(1.0 - pow(d / r, 2.0), 0.0))
		var s := rng.randf_range(0.011, 0.016)
		fb.sphere(&"veg_rough", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * d, y, sin(a) * d)), Vector3(s, s * 0.7, s * 0.85), 5, 3,
				brown.lightened(rng.randf_range(-0.12, 0.16)))
	_fill = MeshInstance3D.new()
	_fill.name = "Kibble"
	_fill.mesh = fb.build()
	_fill.position.y = HEIGHT
	_fill.visibility_range_end = 40.0
	_fill.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_fill)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS + 0.05
	shape.height = HEIGHT + 0.08
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	refresh()


## Shows what is in it now (Pet.bowl_meals): no kibble, a thin layer, a heap.
func refresh() -> void:
	if _fill == null or _shown == Pet.bowl_meals:
		return
	_shown = Pet.bowl_meals
	var k := clampf(float(Pet.bowl_meals) / float(Pet.BOWL_MEALS), 0.0, 1.0)
	_fill.visible = k > 0.0
	_fill.scale = Vector3(lerpf(0.8, 1.0, k), lerpf(0.3, 1.25, k), lerpf(0.8, 1.0, k))
	_fill.reset_physics_interpolation()


## Whether kibble is drawn in it (tests).
func shows_food() -> bool:
	return _fill != null and _fill.visible


## How high the kibble stands (m over the rim; tests).
func food_height() -> float:
	return 0.034 * _fill.scale.y if shows_food() else 0.0


# --- The farmer at it ---------------------------------------------------------------------------

func interact_title() -> String:
	return tr("PET_BOWL")


## E: a sack of dog food from the bag into it (when there is room for a whole sack).
func interact_prompt(_player: Node) -> String:
	return tr("ACTION_FILL_BOWL") if Pet.can_fill_bowl() else ""


func interact(_player: Node) -> void:
	Pet.fill_bowl()


## How full it is, as a plain line under the prompt; empty and no food in the bag: where
## dog food comes from; food in the bag and no room for a sack: that it will do for now.
func hint_prompt() -> String:
	var has_food := PlayerState.inventory.has_item(Pet.FOOD)
	if Pet.bowl_meals <= 0:
		if has_food:
			return tr("PET_BOWL_EMPTY")
		return "%s · %s" % [tr("PET_BOWL_EMPTY"), tr("HINT_BOWL_MARKET") % UiTheme.money(Economy.buy_price(Pet.FOOD))]
	var level := Pet.bowl_text()
	if has_food and not Pet.bowl_has_room():
		return "%s · %s" % [level, tr("HINT_BOWL_ENOUGH")]
	return level
