extends Node
## Farm experience and level (1-10). Work on the farm earns experience: harvests,
## animal care, sales, artisan goods, crafting, births and delivered orders. Levels
## unlock workbench recipes (RecipeTable) and bigger orders on the town board.

signal xp_changed(xp: int, level: int)
signal leveled_up(level: int)

const MAX_LEVEL := 10
## Total experience needed for each level (index = level).
const THRESHOLDS: Array[int] = [0, 0, 120, 320, 650, 1100, 1700, 2500, 3500, 4800, 6400]
## Experience per finished action.
const ACTION_XP := {"hoe": 1, "plant": 1, "harvest": 3, "chop": 2, "break": 2, "cut": 1, "milk": 3,
	"shear": 4, "brush": 1, "feed": 1, "fertilize": 1, "muck": 1}

var xp := 0
var level := 1


func _ready() -> void:
	Events.action_done.connect(func(id: String, _t: Node) -> void: add(int(ACTION_XP.get(id, 0))))
	Events.item_sold.connect(func(_id: StringName, _n: int, gold: int) -> void: add(gold / 20))
	Events.product_made.connect(func(_id: StringName, n: int) -> void: add(4 * n))
	Events.crafted.connect(func(_id: StringName, _n: int) -> void: add(5))
	Events.placed.connect(func(_id: StringName) -> void: add(2))
	Events.animal_born.connect(func(_s: StringName) -> void: add(15))
	Events.order_delivered.connect(func(_id: StringName, _n: int, reward: int) -> void: add(20 + reward / 25))


func add(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= THRESHOLDS[level + 1]:
		level += 1
		leveled_up.emit(level)
		Game.notify(tr("MSG_LEVEL_UP") % level, UiTheme.GOLD)
		Audio.ui("notify", -4.0)
	xp_changed.emit(xp, level)


## 0..1 of the way to the next level (1 at the top level).
func fraction() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	var lo := THRESHOLDS[level]
	var hi := THRESHOLDS[level + 1]
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)


func xp_to_next() -> int:
	return 0 if level >= MAX_LEVEL else THRESHOLDS[level + 1] - xp


func new_game() -> void:
	xp = 0
	level = 1
	xp_changed.emit(xp, level)


func save_data() -> Dictionary:
	return {"xp": xp, "level": level}


func load_data(d: Dictionary) -> void:
	xp = int(d.get("xp", 0))
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp_changed.emit(xp, level)
