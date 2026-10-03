extends Node
## Carnival nights in Yeşilova: the first on day 5, then one every EVERY_DAYS days (day 9,
## 13...); the fishing contest falls two days off each (FishingContest: 7, 11, 15...).
##
## In the morning of a carnival day Beyza of the Yeşilova Market sends a letter: it opens
## once the player is free (after the night's report, never over another window) and
## only once (letter_day is saved). From 19:30 the town dresses up (TownCarnival: bulbs
## over the street, lanterns, bunting, stalls, a carousel and a Ferris wheel on the green
## behind the market), at 20:00 the fun starts (a banner, fireworks, the fair's music
## while the player is in town) and until 23:00 everything sold in town pays twice its
## price (Economy.carnival_factor: the market counter, a pickup's load sold there, the
## orders on the board; the shipping bin's courier pays the usual price in the morning).
## At 23:00 a note says it's over and the decorations come down.
##
## Automated runs (tests, screenshots) keep ordinary nights unless the run asks for
## carnivals (`--carnival`, or `testing` set by the carnival scenario), so other checks'
## prices and night shots don't depend on the day they happen to land on.

signal began
signal finished

const FIRST_DAY := 5
const EVERY_DAYS := 4
## The town dresses up from here; the fun and the double pay run START..END.
const DRESS_MINUTE := 19 * 60 + 30
const START_MINUTE := 20 * 60
const END_MINUTE := 23 * 60
const PAY_FACTOR := 2.0
## Seconds between the player being free and Beyza's letter opening (a note comes first).
const LETTER_DELAY := 2.2
## The fair is heard (music, crowd) this close to the town square, in metres.
const TOWN_RADIUS := 80.0
## Where the fair stands (the green behind the market): the crowd is loudest here.
const FAIR_CENTER := Vector2(226.0, -20.0)

## The last carnival day whose letter was opened (saved: it never comes twice).
var letter_day := 0
## Today's letter waits for the player to be free.
var letter_pending := false
## Set by the carnival scenario: carnivals happen in this automated run (and with
## `testing_letter`, Beyza's letter opens by itself as in play).
var testing := false
var testing_letter := false

var _letter_wait := LETTER_DELAY
var _letter_noted := false
## The window as last seen: began / finished fire when it changes during play.
var _on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.day_started.connect(_on_day_started)


## Whether day `d` has a carnival night (5, 9, 13...).
static func is_carnival_day(d: int) -> bool:
	return d >= FIRST_DAY and (d - FIRST_DAY) % EVERY_DAYS == 0


## The next carnival day from `d` on (`d` itself when it has one).
static func next_carnival_day(d: int) -> int:
	if d <= FIRST_DAY:
		return FIRST_DAY
	return FIRST_DAY + ceili(float(d - FIRST_DAY) / EVERY_DAYS) * EVERY_DAYS


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("carnival")


## Tonight is a carnival night (whatever the hour).
func is_today() -> bool:
	return enabled() and is_carnival_day(GameClock.day)


## 20:00 to 23:00 of a carnival day: the fun is on and sales in town pay double.
func is_on() -> bool:
	return is_today() and GameClock.minute >= START_MINUTE and GameClock.minute < END_MINUTE


## 19:30 to 23:00 of a carnival day: the town wears its decorations.
func is_dressed() -> bool:
	return is_today() and GameClock.minute >= DRESS_MINUTE and GameClock.minute < END_MINUTE


## What a sale in town pays on top of its price right now (2 during the carnival).
func pay_factor() -> float:
	return PAY_FACTOR if is_on() else 1.0


## How far the player stands from the town square (flat metres); INF without a player.
func town_distance() -> float:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p):
		return INF
	return Vector2(p.global_position.x, p.global_position.z).distance_to(WorldLayout.TOWN_CENTER)


## The fair's music plays: the carnival is on and the player is in town.
func music_on() -> bool:
	return is_on() and town_distance() < TOWN_RADIUS


## How loud the fair's crowd is where the player stands (0..1): full on the fairground,
## a murmur in the street, nothing out of town or on other nights.
func crowd_level() -> float:
	if not is_on():
		return 0.0
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p):
		return 0.0
	var d := Vector2(p.global_position.x, p.global_position.z).distance_to(FAIR_CENTER)
	return clampf(1.0 - (d - 12.0) / 70.0, 0.0, 1.0)


func _process(delta: float) -> void:
	if Game.player == null or not is_instance_valid(Game.player) or SaveGame.loading:
		return
	var on := is_on()
	if on != _on:
		_on = on
		if on:
			began.emit()
			_show_banner()
		else:
			finished.emit()
			if is_today() and GameClock.minute >= END_MINUTE:
				Game.notify(tr("MSG_CARNIVAL_OVER"), UiTheme.GOLD_SOFT)
	_update_letter(delta)


## Beyza's letter opens a moment after the player is free: no window open, no night's
## report, not at the wheel, not while loading. Too late for tonight (after 23:00): it is
## dropped.
func _update_letter(delta: float) -> void:
	if not letter_pending:
		return
	if not is_today() or GameClock.minute >= END_MINUTE:
		letter_pending = false
		return
	# Tests open it themselves (it would stop the clock of every check after it).
	if DebugTools.is_automated() and not testing_letter:
		return
	var hud := Game.hud as HUD
	var player := Game.player as Player
	if hud == null or Game.is_ui_open() or hud.sleep_screen.is_busy() or (player and player.driving != null):
		_letter_wait = LETTER_DELAY
		return
	if not _letter_noted:
		_letter_noted = true
		Game.notify(tr("MSG_CARNIVAL_LETTER"), Color("f59ac8"))
		Audio.ui("notify", -6.0)
	_letter_wait -= delta
	if _letter_wait <= 0.0:
		open_letter()


## Opens Beyza's letter now (and marks it read).
func open_letter() -> void:
	letter_pending = false
	letter_day = GameClock.day
	var hud := Game.hud as HUD
	if hud:
		hud.letter_screen.open("carnival", letter_args())


## The hours in Beyza's letter ({start}, {end}).
static func letter_args() -> Dictionary:
	return {"start": _clock(START_MINUTE), "end": _clock(END_MINUTE)}


static func _clock(minute: int) -> String:
	return "%02d:%02d" % [floori(minute / 60.0), minute % 60]


func _show_banner() -> void:
	var hud := Game.hud as HUD
	if hud == null:
		return
	var banner := CarnivalBanner.new()
	# Over the HUD's own layout (the root every card of the HUD is placed in).
	var parent: Node = hud.get_node_or_null("Root")
	(parent if parent else hud).add_child(banner)
	banner.play(tr("CARNIVAL_BANNER_TITLE"), tr("CARNIVAL_BANNER_TEXT") % _clock(END_MINUTE))
	Audio.ui("confirm", -4.0)


func _on_day_started(d: int) -> void:
	# A night slept through ends the carnival without a note.
	_on = false
	_letter_noted = false
	_letter_wait = LETTER_DELAY
	letter_pending = enabled() and is_carnival_day(d) and letter_day != d


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	return {"letter_day": letter_day}


## After GameClock.load_data: a carnival morning whose letter wasn't read yet brings it.
func load_data(data: Dictionary) -> void:
	letter_day = int(data.get("letter_day", 0))
	_on = false
	_letter_noted = false
	_letter_wait = LETTER_DELAY
	letter_pending = is_today() and letter_day != GameClock.day and GameClock.minute < END_MINUTE
