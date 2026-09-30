class_name Needs
extends RefCounted
## The farmer's hunger and energy, 0..100 each (PlayerState.needs; the HUD's bars show
## them). Hunger falls through the day and a little overnight; eating (Eating, RMB with
## food in hand) fills it back up. Energy is the sleep bar: it runs down while awake
## (a whole day, 06:00 to 02:00, empties it) and sleeping in the bed fills it again;
## passing out at 02:00 only restores part of it. Consequences are gentle, never fatal:
## hungry or tired only brings a message; starving or exhausted means no running and
## slower work (work_factor), and starving tires the farmer faster.

signal changed
## A need crossed into a lower state: &"hungry", &"starving", &"tired" or &"exhausted".
signal warned(kind: StringName)

const MAX := 100.0
## Hunger lost per game hour awake, and asleep.
const HUNGER_PER_HOUR := 2.6
const HUNGER_ASLEEP_PER_HOUR := 1.0
## A night's sleep never leaves the farmer below this much hunger (nobody wakes starving).
const HUNGER_NIGHT_FLOOR := 12.0
## Energy lost per game hour awake: 06:00 to 02:00 is 20 hours.
const ENERGY_PER_HOUR := 5.0
## Starving tires the farmer this much faster.
const STARVING_TIRE := 1.5
## Energy after passing out at 02:00 instead of going to bed.
const PASSED_OUT_ENERGY := 45.0
## Thresholds: hungry / tired bring a message, starving / exhausted slow the farmer down.
const HUNGRY := 25.0
const STARVING := 0.5
const TIRED := 20.0
const EXHAUSTED := 5.0
## Under this much energy the farmer may go to bed at any hour (Bed): the night then
## runs as usual, to the next morning.
const SLEEPY := 35.0
## Points over a threshold before its message can show again.
const REARM := 8.0

var hunger := MAX
var energy := MAX
## Needs stand still (automated runs, until a test lets them run).
var frozen := false
var _asleep := false
var _passed_out := false
## Warnings already given, until the need recovers past the threshold again.
var _warned := {}


func reset() -> void:
	hunger = MAX
	energy = MAX
	_asleep = false
	_passed_out = false
	_warned.clear()
	changed.emit()


## `minutes` of game time went by (Events.clock_tick; the night's skip comes as one big
## tick while asleep).
func tick(minutes: float) -> void:
	if frozen or minutes <= 0.0:
		return
	var hours := minutes / 60.0
	if _asleep:
		var floor_at := minf(hunger, HUNGER_NIGHT_FLOOR)
		hunger = maxf(hunger - HUNGER_ASLEEP_PER_HOUR * hours, floor_at)
	else:
		energy = maxf(energy - ENERGY_PER_HOUR * hours * (STARVING_TIRE if starving() else 1.0), 0.0)
		hunger = maxf(hunger - HUNGER_PER_HOUR * hours, 0.0)
	changed.emit()
	_check_warnings()


## Food eaten: `points` of hunger back.
func eat(points: float) -> void:
	hunger = minf(hunger + points, MAX)
	_rearm()
	changed.emit()


## Going to bed (Events.day_ending): the night counts as sleep.
func fall_asleep() -> void:
	_asleep = true


## Collapsing at 02:00 (Events.passed_out): the night only restores part of the energy.
func pass_out() -> void:
	_passed_out = true
	_asleep = true


## The morning after (Events.time_skipped).
func wake() -> void:
	if frozen:
		_asleep = false
		_passed_out = false
		return
	energy = PASSED_OUT_ENERGY if _passed_out else MAX
	_asleep = false
	_passed_out = false
	_rearm()
	changed.emit()


func hungry() -> bool:
	return hunger < HUNGRY


func starving() -> bool:
	return hunger < STARVING


func tired() -> bool:
	return energy < TIRED


func exhausted() -> bool:
	return energy < EXHAUSTED


## Worn out enough to sleep in the daytime.
func sleepy() -> bool:
	return energy < SLEEPY


## Whether the farmer has the strength to run.
func can_sprint() -> bool:
	return not starving() and not exhausted()


## How much longer work takes (1 = normal): starving or exhausted slow the hands.
func work_factor() -> float:
	var f := 1.0
	if starving():
		f += 0.25
	if exhausted():
		f += 0.25
	return f


func _check_warnings() -> void:
	for kind: StringName in [&"starving", &"hungry", &"exhausted", &"tired"]:
		var low := false
		match kind:
			&"hungry":
				low = hungry() and not starving()
			&"starving":
				low = starving()
			&"tired":
				low = tired() and not exhausted()
			&"exhausted":
				low = exhausted()
		if low and not _warned.has(kind):
			_warned[kind] = true
			warned.emit(kind)
	_rearm()


## A warning shows again once its need has come back up past the threshold.
func _rearm() -> void:
	if hunger > HUNGRY + REARM:
		_warned.erase(&"hungry")
	if hunger > STARVING + REARM:
		_warned.erase(&"starving")
	if energy > TIRED + REARM:
		_warned.erase(&"tired")
	if energy > EXHAUSTED + REARM:
		_warned.erase(&"exhausted")


func save_data() -> Dictionary:
	return {"hunger": hunger, "energy": energy}


## Saves from before the needs start full.
func load_data(d: Dictionary) -> void:
	hunger = clampf(float(d.get("hunger", MAX)), 0.0, MAX)
	energy = clampf(float(d.get("energy", MAX)), 0.0, MAX)
	_asleep = false
	_passed_out = false
	_warned.clear()
	# Already low when loaded: no message about it straight away.
	if hungry():
		_warned[&"hungry"] = true
	if starving():
		_warned[&"starving"] = true
	if tired():
		_warned[&"tired"] = true
	if exhausted():
		_warned[&"exhausted"] = true
	changed.emit()
