extends Node
## In-game time. `minute` counts minutes since 00:00 of the current day and may run
## past 1440 (up to 02:00 of the next morning) until the player sleeps.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const MINUTES_PER_DAY := 1440
## Every morning starts here: the player wakes at 06:00 (see sleep_to_next_morning).
const DAY_START_MINUTE := 6 * 60
## A new game's first day starts at 13:00: the player arrives at Grandpa's farm with the
## afternoon ahead (Quests slows the first day's clock a little while its story runs: ten
## real minutes from here to nightfall, FIRST_DAY_RATE).
const FIRST_DAY_START_MINUTE := 13 * 60
const PASS_OUT_MINUTE := 26 * 60
const DAYS_PER_SEASON := 10
const TICK_MINUTES := 10.0
const SEASON_KEYS := ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER"]

var day := 1
var minute := float(FIRST_DAY_START_MINUTE)
## Monotonic minutes since the start of the game; used by growth/needs simulations.
var total_minutes := 0.0
var running := true
var time_scale := 1.0
## The test shortcuts' fast-forward (TestKeys: F6 held), on top of time_scale.
var fast_forward := 1.0

var _tick_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	# Time stands still while a menu is open.
	if not running or Game.is_ui_open():
		return
	advance(delta * Settings.game_minutes_per_second() * time_scale * fast_forward)
	if minute >= PASS_OUT_MINUTE:
		running = false
		Events.passed_out.emit()


## Moves time forward by `minutes`, emitting hour and tick signals along the way.
func advance(minutes: float) -> void:
	var prev_hour := get_hour()
	minute += minutes
	total_minutes += minutes
	_tick_accum += minutes
	if _tick_accum >= TICK_MINUTES:
		Events.clock_tick.emit(total_minutes, _tick_accum)
		_tick_accum = 0.0
	var hour := get_hour()
	if hour != prev_hour:
		Events.hour_passed.emit(hour)


## Skips to 06:00 of the next day (used by sleeping). Simulations receive the
## skipped span through `time_skipped` and a final large `clock_tick`.
func sleep_to_next_morning() -> void:
	var target := float(MINUTES_PER_DAY + DAY_START_MINUTE)
	var skipped := maxf(target - minute, 0.0)
	total_minutes += skipped
	var prev_season := get_season()
	day += 1
	minute = float(DAY_START_MINUTE)
	Events.clock_tick.emit(total_minutes, skipped + _tick_accum)
	_tick_accum = 0.0
	Events.time_skipped.emit(skipped)
	if get_season() != prev_season:
		Events.season_changed.emit(get_season())
	Events.day_started.emit(day)


func set_time_of_day(hour_float: float) -> void:
	minute = clampf(hour_float, 0.0, 26.0) * 60.0


func get_hour() -> int:
	return int(minute / 60.0) % 24


func get_minute_of_hour() -> int:
	return int(minute) % 60


## Hour of day as a float in [0, 24).
func get_hour_float() -> float:
	return fmod(minute / 60.0, 24.0)


func time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute_of_hour()]


func is_night() -> bool:
	var h := get_hour_float()
	return h >= 20.0 or h < 5.5


func get_season() -> int:
	return floori((day - 1) / float(DAYS_PER_SEASON)) % 4


func get_day_of_season() -> int:
	return (day - 1) % DAYS_PER_SEASON + 1


func get_year() -> int:
	return floori((day - 1) / float(DAYS_PER_SEASON * 4)) + 1


func season_name(season: int = -1) -> String:
	return tr(SEASON_KEYS[get_season() if season < 0 else season])


func new_game() -> void:
	load_data({})
	running = true


func save_data() -> Dictionary:
	return {"day": day, "minute": minute, "total_minutes": total_minutes}


func load_data(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	# A saved game keeps its time; a new one (no data) starts at 13:00 on day 1.
	minute = float(data.get("minute", FIRST_DAY_START_MINUTE if day == 1 else DAY_START_MINUTE))
	total_minutes = float(data.get("total_minutes", 0.0))
