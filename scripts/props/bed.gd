@tool
class_name Bed
extends StaticBody3D
## Rustic wooden bed. Interacting after 18:00 ends the day; so does it at any hour once
## the farmer is worn out (Needs.sleepy) or the day's story is done and its next goal
## waits for the morning (Quests.day_work_done), sleeping through to the next morning.
## Local origin = floor center of the bed; the headboard is at -Z.

const FRAME := Color(0.36, 0.3, 0.26)
const MATTRESS := Color("e9e4d8")
const BLANKET := Color("4a6a9a")
const PILLOW := Color("dcdde6")

const WIDTH := 1.1
const LENGTH := 2.1
const SLEEP_FROM_HOUR := 18.0

## Grandpa's old bed in the run-down house: darker frame, a slat gone, a stained,
## sagging mattress and a drab wool blanket. Sleeps just the same.
@export var worn := false


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"beds")
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var mb := MeshBuilder.new()
	var hw := WIDTH * 0.5
	var hl := LENGTH * 0.5
	var wood: StringName = &"wood_old_in" if worn else &"wood_in"
	var frame: Color = FRAME.darkened(0.25) if worn else FRAME
	# Posts: tall at the head, short at the foot.
	for sx: float in [-1.0, 1.0]:
		mb.box_at(wood, Vector3(sx * hw, 0.55, -hl), Vector3(0.1, 1.1, 0.1), frame)
		mb.box_at(wood, Vector3(sx * hw, 0.36, hl), Vector3(0.1, 0.72, 0.1), frame)
		mb.box_at(wood, Vector3(sx * hw, 0.3, 0), Vector3(0.06, 0.16, LENGTH), frame)
	# Headboard and footboard with slats.
	mb.box_at(wood, Vector3(0, 1.02, -hl), Vector3(WIDTH, 0.08, 0.08), frame)
	mb.box_at(wood, Vector3(0, 0.66, hl), Vector3(WIDTH, 0.07, 0.07), frame)
	for i in 6:
		var x := -hw + 0.13 + i * (WIDTH - 0.26) / 5.0
		if not (worn and i == 2):
			mb.box_at(wood, Vector3(x, 0.72, -hl), Vector3(0.08, 0.55, 0.05), frame.lightened(0.08), Vector3.ZERO, true)
		mb.box_at(wood, Vector3(x, 0.5, hl), Vector3(0.08, 0.28, 0.05), frame.lightened(0.08), Vector3.ZERO, true)
	# Bedding.
	if worn:
		# A thin mattress sagging in the middle, a coarse blanket thrown over it.
		for k in 3:
			var z := -0.62 + k * 0.62
			mb.box_at(&"cloth", Vector3(0, 0.43 - (0.03 if k == 1 else 0.0), z), Vector3(WIDTH - 0.12, 0.16, 0.66),
					Color(0.66, 0.62, 0.55).darkened(0.06 * k), Vector3(3.0 * (1 - k), 0, 0))
		mb.box_at(&"cloth", Vector3(-0.05, 0.53, 0.35), Vector3(WIDTH - 0.02, 0.06, 1.3), Color(0.36, 0.33, 0.28), Vector3(0, 5, 2))
		mb.box_at(&"cloth", Vector3(-hw + 0.02, 0.42, 0.38), Vector3(0.03, 0.22, 1.2), Color(0.31, 0.29, 0.25), Vector3(0, 5, -6))
		mb.box_at(&"cloth", Vector3(0.08, 0.56, -0.74), Vector3(0.66, 0.11, 0.38), Color(0.7, 0.67, 0.61), Vector3(6, -9, 0))
	else:
		mb.box_at(&"cloth", Vector3(0, 0.46, 0), Vector3(WIDTH - 0.12, 0.2, LENGTH - 0.12), MATTRESS)
		mb.box_at(&"cloth", Vector3(0, 0.58, 0.28), Vector3(WIDTH - 0.04, 0.07, 1.4), BLANKET)
		for sx: float in [-1.0, 1.0]:
			mb.box_at(&"cloth", Vector3(sx * (hw - 0.01), 0.47, 0.28), Vector3(0.03, 0.25, 1.4), BLANKET.darkened(0.08))
		mb.box_at(&"cloth", Vector3(0, 0.58, 0.97), Vector3(WIDTH - 0.04, 0.24, 0.03), BLANKET.darkened(0.08))
		mb.box_at(&"cloth", Vector3(0, 0.6, -0.72), Vector3(0.72, 0.13, 0.4), PILLOW, Vector3(4, 3, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH + 0.1, 0.7, LENGTH + 0.1)
	cs.shape = box
	cs.position.y = 0.35
	add_child(cs)


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_SLEEP_TIRED") if daytime() and PlayerState.needs.sleepy() else tr("ACTION_SLEEP")


func interact(_player: Node) -> void:
	if not can_sleep_now():
		Game.notify(tr("MSG_SLEEP_NOT_TIRED"))
		return
	Game.hud.sleep_screen.start_sleep()


## Whether the bed takes the farmer now: in the evening and at night, by day when he is
## worn out, and at any hour once the day's story is done (nothing left to wait up for).
static func can_sleep_now() -> bool:
	return not daytime() or PlayerState.needs.sleepy() or Quests.day_work_done()


## The working day (06:00 to 18:00): only a worn-out farmer goes to bed then.
static func daytime() -> bool:
	var hour := GameClock.get_hour_float()
	return hour >= GameClock.DAY_START_MINUTE / 60.0 and hour < SLEEP_FROM_HOUR
