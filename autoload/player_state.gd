extends Node
## The player's persistent state: inventory (first 8 slots = hotbar), the selected
## hotbar slot, whether the hotbar and inventory have opened yet, and the farmer's
## hunger and energy (needs; scripts/camp/needs.gd): they run down with the game clock,
## eating and sleeping fill them, and a need running low brings a message. Wounds (a
## wolf's bites: hurt) fill the injury meter, which heals slowly once nothing has hurt
## him for a while; a full meter knocks him out until the next morning.

signal selected_changed(slot: int)
## The first item came into the bag of a new farm: the hotbar and inventory open (the
## HUD plays the reveal).
signal hotbar_revealed
## A wound landed (hurt): `amount` of injury, from a blow at `from` (the HUD's red
## vignette and splash, the player's flinch and grunt).
signal hurt_taken(amount: float, from: Vector3)

const INVENTORY_SIZE := 36
const HOTBAR_SIZE := 8
## The injury meter's top: he faints there.
const INJURY_MAX := 100.0
## Seconds without a wound before the meter starts to go down, and how fast it goes then
## (points per second: ten a minute).
const INJURY_CALM := 10.0
const INJURY_HEAL := 10.0 / 60.0

var inventory := Inventory.new(INVENTORY_SIZE)
var selected := 0
## A new farm starts with an empty bag and no hotbar or inventory (Tab does nothing);
## both open for good with the first item that comes into the bag, however it comes
## (Grandpa's table, a pickup, a chest). Saved; saves from before the lock come open.
var hotbar_unlocked := true
## Hunger and energy (0..100 each). Automated runs keep them still (tests set frozen).
var needs := Needs.new()
## Fish landed since the last trophy (Angler; FishTable.pity owes a giant after a long run).
var fish_since_trophy := 0
## Wounds, 0..INJURY_MAX: a full meter knocks the farmer out (knock_out). Not saved: a
## loaded game starts unhurt.
var injury := 0.0
## Fainted from his wounds, until the next morning.
var knocked_out := false
## Seconds since the last wound (healing starts after INJURY_CALM).
var _calm := 0.0


func _ready() -> void:
	inventory.changed.connect(_on_inventory_changed)
	Events.clock_tick.connect(func(_total: float, minutes: float) -> void: needs.tick(minutes))
	Events.day_ending.connect(needs.fall_asleep)
	Events.passed_out.connect(needs.pass_out)
	Events.time_skipped.connect(func(_minutes: float) -> void:
		needs.wake()
		_heal_all())
	Events.player_knocked_out.connect(needs.knock_out)
	needs.warned.connect(_on_need_warned)
	new_game()
	# Tests and screenshot runs skip the story: they start with Grandpa's kit in the bag
	# and the hotbar open. Deferred: DebugTools reads the command line after this runs.
	_start_automated.call_deferred()


func _start_automated() -> void:
	if DebugTools.is_automated():
		needs.frozen = true
		give_starter_kit()


func new_game() -> void:
	# Locked before the bag is emptied, so its `changed` finds nothing to open it with.
	hotbar_unlocked = false
	# Keep the same Inventory object so UI connections stay valid.
	inventory.from_array([])
	select(0)
	needs.reset()
	fish_since_trophy = 0
	_heal_all()


## Grandpa's old kit straight into the bag, in hotbar order (automated runs; in the
## story the house table hands the same things out one by one). Opens the hotbar.
func give_starter_kit() -> void:
	for entry in ItemTable.STARTING_ITEMS:
		inventory.add_item(entry[0], entry[1])
	# Open even if the kit list comes up empty: tests always have their hotbar.
	unlock_hotbar()
	select(selected)


## Opens the hotbar and inventory now, even with an empty bag (tests, the story).
func unlock_hotbar() -> void:
	if hotbar_unlocked:
		return
	hotbar_unlocked = true
	hotbar_revealed.emit()


func _on_inventory_changed() -> void:
	if hotbar_unlocked:
		return
	for i in HOTBAR_SIZE:
		if inventory.slots[i] != null:
			# The first thing in the bag goes straight into the hand.
			select(i)
			unlock_hotbar()
			return
	for s in inventory.slots:
		if s != null:
			unlock_hotbar()
			return


func select(slot: int) -> void:
	selected = wrapi(slot, 0, HOTBAR_SIZE)
	selected_changed.emit(selected)


func selected_stack() -> ItemStack:
	return inventory.get_stack(selected)


## Adds items and shows a pickup notification. Returns the amount that didn't fit.
func give(item_id: StringName, amount := 1, notify := true) -> int:
	var left := inventory.add_item(item_id, amount)
	var added := amount - left
	if notify and added > 0:
		Game.notify("+%dx %s" % [added, ItemDB.get_item(item_id).display_name()])
	if left > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
	return left


# --- Wounds --------------------------------------------------------------------------

## A wound of `amount` (0..INJURY_MAX) from a blow at `from` (a wolf's bite): the meter
## fills, the screen and the view react (hurt_taken), and a full meter knocks him out.
## Nothing hurts him once he is down, asleep, on the title screen or while the game is
## paused (the pause menu, the settings).
func hurt(amount: float, from: Vector3) -> void:
	if knocked_out or amount <= 0.0 or Game.is_paused() or Game.player == null or not is_instance_valid(Game.player):
		return
	var hud := Game.hud as HUD
	if hud == null or hud.sleep_screen.is_busy() or hud.title_screen.visible:
		return
	injury = minf(injury + amount, INJURY_MAX)
	_calm = 0.0
	hurt_taken.emit(amount, from)
	if injury >= INJURY_MAX:
		knock_out()


## He faints: Events.player_knocked_out, then the night runs as if he slept, and he wakes
## in his bed the next morning, hungry and worn out (SleepScreen.start_sleep).
func knock_out() -> void:
	if knocked_out:
		return
	knocked_out = true
	injury = INJURY_MAX
	Events.player_knocked_out.emit()
	var hud := Game.hud as HUD
	if hud:
		hud.sleep_screen.start_sleep(false, true)


## The meter heals once nothing has hurt him for INJURY_CALM seconds (paused while the
## game is).
func _process(delta: float) -> void:
	if injury <= 0.0 or knocked_out or Game.is_paused():
		return
	_calm += delta
	if _calm >= INJURY_CALM:
		injury = maxf(injury - INJURY_HEAL * delta, 0.0)


## Every wound gone (a new morning, a new or loaded game).
func _heal_all() -> void:
	injury = 0.0
	knocked_out = false
	_calm = 0.0


## A need ran low: a word about it (the farmer yawns when tired).
func _on_need_warned(kind: StringName) -> void:
	var msg: String = {&"hungry": "MSG_HUNGRY", &"starving": "MSG_STARVING", &"tired": "MSG_TIRED",
			&"exhausted": "MSG_EXHAUSTED"}.get(kind, "")
	if msg == "":
		return
	var urgent := kind == &"starving" or kind == &"exhausted"
	Game.notify(tr(msg), UiTheme.RED if urgent else UiTheme.GOLD_SOFT)
	if kind == &"tired" or kind == &"exhausted":
		CampSfx.play("yawn", null, -9.0, 0.04)


func save_data() -> Dictionary:
	return {"inventory": inventory.to_array(), "selected": selected, "hotbar": hotbar_unlocked,
		"needs": needs.save_data(), "fish_dry": fish_since_trophy}


func load_data(data: Dictionary) -> void:
	# Saves from before the lock have no "hotbar": their hotbar was always there. Set
	# before the bag, so a locked save that holds items opens itself.
	hotbar_unlocked = bool(data.get("hotbar", true))
	inventory.from_array(data.get("inventory", []))
	select(int(data.get("selected", 0)))
	needs.load_data(data.get("needs", {}))
	fish_since_trophy = int(data.get("fish_dry", 0))
	_heal_all()
