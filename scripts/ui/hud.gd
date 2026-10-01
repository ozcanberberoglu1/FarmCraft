class_name HUD
extends CanvasLayer
## In-game overlay: money, clock and weather, crosshair with the hold-action ring,
## the crop growth card beside it, key-cap interaction prompts, toast notifications,
## the story's waypoint dot, achievement banners, the morning sale badge, the hotbar
## (hidden on a new farm until the first item comes into the bag) with the hunger and
## energy bars beside it, and the countdowns over fish cooking on a campfire; owns every
## menu screen (inventory, shops, construction, animals, pause and settings) and the
## conversations with townspeople. The side story (SideStory: Zeynep, the new
## neighbour) has a card of its own under the goal's and a dot of its own, ringed in
## rose, beside the story's; any other side goal up at the same time (SideStory.goals:
## the wolves, the vet) gets a card and a dot of its own in its colour too.

const MAX_TOASTS := 5
## A prompt line starting with this is a title over the key rows (the aimed object's
## name, e.g. "#Hoe" over "[E] TAKE").
const TITLE_MARK := "#"
## Where the level and goal cards rest under the money (they slide down to make room
## for the sale badge).
const LEVEL_Y := 92.0
const QUEST_Y := 150.0
## Quiet side goals (Zeynep's errands, the mailbox): their hint shows this many seconds
## after the goal comes up or changes, and again closer than SIDE_HINT_NEAR metres to the
## place; their cards are this opaque (under the story's own).
const SIDE_HINT_SECONDS := 20.0
const SIDE_HINT_NEAR := 15.0
const SIDE_QUIET_ALPHA := 0.86
## The toasts' column: its top from the screen's middle and its height, at rest; how far
## under the goal cards it keeps when they reach down past it, and how fast it slides
## there (px/s).
const TOAST_TOP := -120.0
const TOAST_HEIGHT := 360.0
const TOAST_GAP := 14.0
const TOAST_SLIDE := 900.0


## Dot crosshair; a ring shows when something can be interacted with and a gold
## arc fills while a hold action runs.
class Crosshair extends Control:
	var targeting := false
	var progress := -1.0:
		set(value):
			if value != progress:
				progress = value
				queue_redraw()
	var _ring := 0.0

	## Redraws only while the ring grows or fades.
	func _process(delta: float) -> void:
		var ring := move_toward(_ring, 1.0 if targeting else 0.0, delta * 8.0)
		if ring != _ring:
			_ring = ring
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 3.6, Color(0, 0, 0, 0.45))
		draw_circle(c, 2.3, Color(1, 1, 1, 0.95))
		if _ring > 0.01:
			draw_arc(c, 10.0 + 3.0 * (1.0 - _ring), 0.0, TAU, 40, Color(1, 1, 1, 0.75 * _ring), 1.8, true)
		if progress >= 0.0:
			draw_arc(c, 26.0, 0.0, TAU, 64, Color(0, 0, 0, 0.35), 7.0, true)
			draw_arc(c, 26.0, 0.0, TAU, 64, Color(1, 1, 1, 0.16), 5.0, true)
			if progress > 0.0:
				draw_arc(c, 26.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 64, UiTheme.GOLD, 5.0, true)


var hotbar: HotbarUI
var inventory_screen: InventoryScreen
var sleep_screen: SleepScreen
var build_screen: BuildScreen
var shop_screen: ShopScreen
var rancher_screen: RancherScreen
var vet_screen: VetScreen
var animal_panel: AnimalPanel
var pause_menu: PauseMenu
var settings_screen: SettingsScreen
var title_screen: TitleScreen
var storage_screen: StorageScreen
var dealer_screen: DealerScreen
var save_screen: SaveScreen
var crafting_screen: CraftingScreen
var order_screen: OrderScreen
var confirm_dialog: ConfirmDialog
var level_up_screen: LevelUpScreen
var letter_screen: LetterScreen
## Conversations with townspeople at the bottom of the screen (Zeynep).
var dialogue_screen: DialogueScreen
var vehicle_hud: VehicleHUD
## Growth ring and card beside the crosshair while a planted bed is aimed at.
var crop_card: CropCard
## The story's guide dot (Quests.waypoint()), and the side story's (SideStory).
var waypoint: WaypointMarker
var side_waypoint: WaypointMarker
## Top-centre banner for unlocked achievements.
var achievement_toast: AchievementToast
## Hunger and energy at the bottom left (PlayerState.needs).
var needs_bars: NeedsBars
## Countdown rings over fish cooking on a campfire.
var cook_rings: CookRings
## The red of the farmer's wounds at the screen's edges (PlayerState.injury).
var injury_overlay: InjuryOverlay

var _root: Control
var _money_label: Label
var _money_pill: GlassPanel
var _level_pill: GlassPanel
var _level_label: Label
var _level_bar: StatBar
var _quest_card: GlassPanel
var _quest_text: Label
var _quest_count: Label
var _quest_chapter: Label
var _quest_note: Label
var _note_left := 0.0
## The side story's goal (SideStory), under the story's own card.
var _side_card: GlassPanel
var _side_text: Label
var _side_hint: Label
var _side_hearts: Label
## Seconds the quiet side goals' hints still show since their goal came up or changed
## (Zeynep's here, the others' in their _goal_cards entry: "hint_left"); near the place
## they show again (SIDE_HINT_NEAR).
var side_hint_left := 0.0
var _side_shown := ""
## The other side goals' cards (SideStory.goals), between the story's and Zeynep's:
## SideGoal -> {"card", "text", "hint", "dot"}.
var _goal_cards := {}
var _clock_card: GlassPanel
var _time_label: Label
var _day_label: Label
var _weather_icon: TextureRect
var _night := false
var _weather_label: Label
var _day_bar: StatBar
var _crosshair: Crosshair
var _prompts: VBoxContainer
var _progress_label: Label
var _toasts: VBoxContainer
var _last_prompt := PackedStringArray()
var _sale_badge: SaleBadge
var _sale_tween: Tween
## Room made under the money for the sale badge: the level and goal cards slide down.
var _sale_room := 0.0:
	set(value):
		_sale_room = value
		if _level_pill:
			_level_pill.position.y = LEVEL_Y + value
		if _quest_card:
			_quest_card.position.y = QUEST_Y + value
## The first item came in while a window was open: the hotbar rises when it closes.
var _reveal_pending := false
## The game minute and day the clock card shows (it is only rebuilt when they change).
var _shown_minute := -1
var _shown_day := -1

static var _prompt_rx := RegEx.create_from_string("^(.+?) \\((.+)\\)$")


func _ready() -> void:
	layer = 10
	add_to_group(&"hud")
	Game.hud = self
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_money()
	_sale_badge = SaleBadge.new()
	_root.add_child(_sale_badge)
	_sale_badge.folding.connect(_close_sale_room)
	_build_level()
	_build_quest()
	_build_side()
	_build_clock()
	# Under the crosshair, the prompts and every menu.
	side_waypoint = WaypointMarker.new()
	side_waypoint.source = SideStory
	side_waypoint.ring_color = SideStory.ROSE
	# Zeynep's errands can wait: a smaller, fainter dot.
	side_waypoint.quiet = true
	_root.add_child(side_waypoint)
	SideStory.goals_changed.connect(_sync_goal_cards)
	waypoint = WaypointMarker.new()
	_root.add_child(waypoint)
	cook_rings = CookRings.new()
	_root.add_child(cook_rings)
	_build_center()
	_build_toasts()
	achievement_toast = AchievementToast.new()
	_root.add_child(achievement_toast)
	hotbar = HotbarUI.new()
	_root.add_child(hotbar)
	hotbar.visible = PlayerState.hotbar_unlocked
	needs_bars = NeedsBars.new()
	_root.add_child(needs_bars)
	needs_bars.visible = PlayerState.hotbar_unlocked
	vehicle_hud = VehicleHUD.new()
	_root.add_child(vehicle_hud)
	title_screen = TitleScreen.new()
	_root.add_child(title_screen)
	inventory_screen = InventoryScreen.new()
	_root.add_child(inventory_screen)
	build_screen = BuildScreen.new()
	_root.add_child(build_screen)
	shop_screen = ShopScreen.new()
	_root.add_child(shop_screen)
	rancher_screen = RancherScreen.new()
	_root.add_child(rancher_screen)
	vet_screen = VetScreen.new()
	_root.add_child(vet_screen)
	animal_panel = AnimalPanel.new()
	_root.add_child(animal_panel)
	storage_screen = StorageScreen.new()
	_root.add_child(storage_screen)
	dealer_screen = DealerScreen.new()
	_root.add_child(dealer_screen)
	pause_menu = PauseMenu.new()
	_root.add_child(pause_menu)
	settings_screen = SettingsScreen.new()
	_root.add_child(settings_screen)
	save_screen = SaveScreen.new()
	_root.add_child(save_screen)
	crafting_screen = CraftingScreen.new()
	_root.add_child(crafting_screen)
	order_screen = OrderScreen.new()
	_root.add_child(order_screen)
	letter_screen = LetterScreen.new()
	_root.add_child(letter_screen)
	dialogue_screen = DialogueScreen.new()
	_root.add_child(dialogue_screen)
	# Over a shop or the order board, where selling and deliveries raise the level.
	level_up_screen = LevelUpScreen.new()
	_root.add_child(level_up_screen)
	Progress.leveled_up.connect(_on_level_up)
	Quests.story_finished.connect(func() -> void:
		if not DebugTools.is_automated():
			letter_screen.open("final"))
	# Last, so it sits over any screen that asks.
	confirm_dialog = ConfirmDialog.new()
	_root.add_child(confirm_dialog)
	sleep_screen = SleepScreen.new()
	add_child(sleep_screen)
	injury_overlay = InjuryOverlay.new()
	add_child(injury_overlay)
	Events.passed_out.connect(func() -> void: sleep_screen.start_sleep(true))
	Weather.weather_changed.connect(func(_k: int) -> void: _refresh_weather())
	_refresh_weather()
	Settings.changed.connect(_refresh_day)
	Events.money_changed.connect(_on_money_changed)
	Events.interaction_prompt_changed.connect(_on_prompt_changed)
	Events.notification_requested.connect(notify)
	Events.action_progress_started.connect(_on_progress_started)
	Events.action_progress_updated.connect(_on_progress_updated)
	Events.action_progress_finished.connect(_on_progress_finished)
	Events.ui_opened.connect(func(_n: StringName) -> void: _sync_hud_visibility())
	Events.ui_closed.connect(func(_n: StringName) -> void:
		_sync_hud_visibility()
		if _reveal_pending:
			_on_hotbar_revealed())
	PlayerState.hotbar_revealed.connect(_on_hotbar_revealed)
	Events.morning_sale.connect(show_sale_badge)
	_on_money_changed(Economy.money, 0)
	# The side goal of a loaded game shows once everything is up.
	_refresh_side.call_deferred()
	_sync_goal_cards.call_deferred()
	# Normal launches open on the title screen; debug and test runs, and a game being
	# loaded or started, go straight in.
	if DebugTools.args.is_empty() and not SaveGame.loading:
		show_title.call_deferred()


func _process(_delta: float) -> void:
	# Grandpa's note waits while a window (the night's report) covers it.
	if _note_left > 0.0 and not Game.is_ui_open():
		_note_left -= _delta
		if _note_left <= 0.0:
			_quest_note.visible = false
	# Catches what no signal reports (getting in or out of a vehicle, the lock set
	# directly); compares with what the hotbar should be, so a locked one stays quiet.
	if hotbar.visible != _hotbar_wanted() and not Game.is_ui_open():
		_sync_hud_visibility()
	# The clock card changes once a game minute; the day bar moves well under a pixel
	# per minute.
	var minute := int(GameClock.minute)
	if minute != _shown_minute:
		_shown_minute = minute
		_time_label.text = GameClock.time_string()
		_day_bar.set_value(fposmod(GameClock.get_hour_float() - 6.0, 24.0) / 20.0 * 100.0, false)
	if GameClock.is_night() != _night:
		_refresh_weather()
	if GameClock.day != _shown_day:
		_refresh_day()
	_update_side_hints(_delta)
	_place_side_cards()
	# The dots riding the screen's left edge keep clear of the goal cards.
	var cards: Array[Rect2] = []
	for card: Control in [_quest_card, _side_card]:
		if card.visible:
			cards.append(Rect2(card.position, card.size))
	for e: Dictionary in _goal_cards.values():
		var gc: Control = e["card"]
		if gc.visible:
			cards.append(Rect2(gc.position, gc.size))
	waypoint.keep_out = cards
	side_waypoint.keep_out = cards
	_place_toasts(cards, _delta)
	# The other side goals' dots also keep clear of the dots on the screen's edge before them
	# (two goals in town would put theirs on top of each other).
	var taken := cards.duplicate()
	for dot: WaypointMarker in [waypoint, side_waypoint]:
		if dot.visible and not dot.on_screen:
			taken.append(dot.screen_rect())
	for e: Dictionary in _goal_cards.values():
		var dot: WaypointMarker = e["dot"]
		dot.keep_out = taken.duplicate()
		if dot.visible and not dot.on_screen:
			taken.append(dot.screen_rect())


## "DAY 3 · SPRING 3" under the time (again when the language changes).
func _refresh_day() -> void:
	_shown_day = GameClock.day
	_day_label.text = "%s  ·  %s %d" % [UiTheme.caps(tr("HUD_DAY") % GameClock.day),
			UiTheme.caps(GameClock.season_name()), GameClock.get_day_of_season()]


func _driving() -> bool:
	return Game.player is Player and (Game.player as Player).driving != null


## Whether the hotbar shows when no menu is open: open (a first item came) and on foot.
func _hotbar_wanted() -> bool:
	return PlayerState.hotbar_unlocked and not _driving()


# --- Building ------------------------------------------------------------------

func _build_money() -> void:
	_money_pill = GlassPanel.new(Vector4(22, 8, 22, 8), 30.0)
	_money_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_pill.position = Vector2(28, 24)
	_root.add_child(_money_pill)
	# "$1,234" on its own: the $ says it is money.
	_money_label = UiTheme.make_label(UiTheme.money(0), UiTheme.heading(36, UiTheme.TEXT, 700, 1))
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_money_pill.add_child(_money_label)


## Farm level under the money: "LEVEL 3" and a thin bar to the next level.
func _build_level() -> void:
	_level_pill = GlassPanel.new(Vector4(16, 8, 18, 10), 16.0)
	_level_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_pill.position = Vector2(28, LEVEL_Y)
	_root.add_child(_level_pill)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_pill.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph("star"), 20, UiTheme.GOLD))
	_level_label = UiTheme.make_label("", UiTheme.heading(18, UiTheme.TEXT, 700, 2))
	row.add_child(_level_label)
	_level_bar = StatBar.new(4.0, UiTheme.GOLD)
	_level_bar.custom_minimum_size = Vector2(150, 4)
	col.add_child(_level_bar)
	Progress.xp_changed.connect(func(_x: int, _l: int) -> void: _refresh_level())
	_refresh_level()


func _refresh_level() -> void:
	_level_label.text = UiTheme.caps(tr("HUD_FARM_LEVEL") % Progress.level)
	_level_bar.max_value = 100.0
	_level_bar.set_value(Progress.fraction() * 100.0, false)


## The current tutorial goal and its progress, under the level.
func _build_quest() -> void:
	_quest_card = GlassPanel.new(Vector4(16, 10, 18, 12), 16.0)
	_quest_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_card.position = Vector2(28, QUEST_Y)
	_root.add_child(_quest_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph("book"), 16, UiTheme.GOLD_SOFT))
	_quest_chapter = UiTheme.make_label("", UiTheme.heading(14, UiTheme.GOLD_SOFT, 700, 3))
	head.add_child(_quest_chapter)
	head.add_child(UiTheme.expand())
	_quest_count = UiTheme.make_label("", UiTheme.heading(16, UiTheme.TEXT_MUTED, 700, 1))
	head.add_child(_quest_count)
	_quest_text = UiTheme.make_label("", UiTheme.text(17, UiTheme.TEXT, 600))
	_quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_text.custom_minimum_size = Vector2(300, 0)
	col.add_child(_quest_text)
	# A new chapter opens with a line from Grandpa's notebook for a while.
	_quest_note = UiTheme.make_label("", UiTheme.text(15, UiTheme.GOLD_SOFT, 500))
	_quest_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_note.custom_minimum_size = Vector2(300, 0)
	_quest_note.visible = false
	col.add_child(_quest_note)
	Quests.tutorial_changed.connect(_refresh_quest)
	Quests.chapter_started.connect(show_chapter_note)
	_refresh_quest()


func _refresh_quest() -> void:
	var g := Quests.current()
	_quest_card.set_meta("active", not g.is_empty())
	if g.is_empty():
		_quest_card.visible = false
		return
	_quest_text.text = Quests.goal_text()
	_quest_count.text = "%d/%d" % [Quests.step_count, int(g["count"])]
	# "0/1" says nothing on a one-step goal (open the door, take the key).
	_quest_count.visible = int(g["count"]) > 1
	_quest_chapter.text = UiTheme.caps("%s · %s" % [tr("HUD_CHAPTER") % (Quests.chapter() + 1), Quests.chapter_title(Quests.chapter())])
	if _crosshair != null:
		_sync_hud_visibility()


## The side story's goal (SideStory) on a compact card of its own under the story's: one
## line (a heart, the goal, the friendship's hearts), quieter than the story's card, as
## her errands can wait; the hint under it shows for SIDE_HINT_SECONDS when the goal
## comes up or changes, and again near the place.
func _build_side() -> void:
	_side_card = GlassPanel.new(Vector4(12, 6, 14, 7), 12.0)
	_side_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_card.position = Vector2(28, QUEST_Y)
	_side_card.visible = false
	_side_card.modulate.a = SIDE_QUIET_ALPHA
	_root.add_child(_side_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph("heart"), 14, SideStory.ROSE))
	_side_text = UiTheme.make_label("", UiTheme.text(15, UiTheme.TEXT, 600))
	_side_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side_text.custom_minimum_size = Vector2(250, 0)
	head.add_child(_side_text)
	_side_hearts = UiTheme.make_label("", UiTheme.heading(13, SideStory.ROSE, 700, 1))
	head.add_child(_side_hearts)
	_side_hint = UiTheme.make_label("", UiTheme.text(13, UiTheme.TEXT_MUTED, 500))
	_side_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side_hint.custom_minimum_size = Vector2(250, 0)
	col.add_child(_side_hint)
	SideStory.changed.connect(_refresh_side)
	Relations.changed.connect(func(_w: StringName, _l: int, _p: int) -> void: _refresh_side())
	_refresh_side()


func _refresh_side() -> void:
	var text := SideStory.goal_text()
	_side_card.set_meta("active", text != "")
	_side_text.text = text
	if text != _side_shown:
		# A new goal (or a new step of it): its hint shows for a while.
		_side_shown = text
		side_hint_left = SIDE_HINT_SECONDS
	var hint := SideStory.goal_hint()
	_side_hint.text = hint
	_side_hint.visible = hint != "" and (side_hint_left > 0.0 or side_waypoint == null or side_waypoint.near(SIDE_HINT_NEAR))
	var lv := Relations.level(SideStory.WHO)
	_side_hearts.text = "♥ %d/%d" % [lv, Relations.max_level(SideStory.WHO)]
	_side_hearts.visible = SideStory.met
	if _crosshair != null:
		_sync_hud_visibility()
	if _side_card.visible:
		_side_card.reset_size()
		_place_side_cards()


## The quiet side goals' hints: shown for SIDE_HINT_SECONDS after their goal came up or
## changed, then only near the place (the dot closer than SIDE_HINT_NEAR).
func _update_side_hints(delta: float) -> void:
	if _side_card == null:
		return
	side_hint_left = maxf(side_hint_left - delta, 0.0)
	var show := _side_hint.text != "" and (side_hint_left > 0.0 or side_waypoint.near(SIDE_HINT_NEAR))
	if show != _side_hint.visible:
		_side_hint.visible = show
		_side_card.reset_size()
	for g: SideGoal in _goal_cards:
		if not g.quiet:
			continue
		var e: Dictionary = _goal_cards[g]
		e["hint_left"] = maxf(float(e.get("hint_left", 0.0)) - delta, 0.0)
		var hint: Label = e["hint"]
		var on := g.hint != "" and (float(e["hint_left"]) > 0.0 or (e["dot"] as WaypointMarker).near(SIDE_HINT_NEAR))
		if on != hint.visible:
			hint.visible = on
			(e["card"] as Control).reset_size()


## Under the story's goal card (or in its place when there is none): the other side goals'
## cards first (SideStory.goals, in order), then Zeynep's.
func _place_side_cards() -> void:
	var y := QUEST_Y + _sale_room
	if _quest_card.visible:
		y = _quest_card.position.y + _quest_card.size.y + 10.0
	for g: SideGoal in SideStory.goals:
		var e: Dictionary = _goal_cards.get(g, {})
		if e.is_empty() or not (e["card"] as Control).visible:
			continue
		var card: Control = e["card"]
		card.position.y = y
		y += card.size.y + 10.0
	_side_card.position.y = y


## Builds a card and a dot for each side goal newly up (SideStory.goals), and drops those
## of the ones taken down.
func _sync_goal_cards() -> void:
	for g: SideGoal in _goal_cards.keys():
		if SideStory.goals.has(g):
			continue
		var e: Dictionary = _goal_cards[g]
		(e["card"] as Node).queue_free()
		(e["dot"] as Node).queue_free()
		g.changed.disconnect(e["refresh"])
		_goal_cards.erase(g)
	for g: SideGoal in SideStory.goals:
		if not _goal_cards.has(g):
			var e := _build_goal_card(g)
			e["refresh"] = _refresh_goal_card.bind(g)
			g.changed.connect(e["refresh"])
			_goal_cards[g] = e
		_refresh_goal_card(g)


## A side goal's card (its glyph and "TITLE · SIDE GOAL" in its colour over the goal and
## its hint) and its dot, ringed in its colour, beside the others. A quiet one (an errand
## that can wait) is compact like Zeynep's: one line, the glyph and the goal, its hint
## for a while; its dot smaller and fainter.
func _build_goal_card(g: SideGoal) -> Dictionary:
	var card := GlassPanel.new(Vector4(12, 6, 14, 7) if g.quiet else Vector4(16, 10, 18, 12), 12.0 if g.quiet else 16.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(28, QUEST_Y)
	card.visible = false
	if g.quiet:
		card.modulate.a = SIDE_QUIET_ALPHA
	_root.add_child(card)
	_root.move_child(card, _side_card.get_index())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2 if g.quiet else 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph(g.glyph), 14 if g.quiet else 16, g.color))
	var title := UiTheme.make_label("", UiTheme.heading(14, g.color, 700, 3))
	head.add_child(title)
	title.visible = not g.quiet
	var text := UiTheme.make_label("", UiTheme.text(15 if g.quiet else 17, UiTheme.TEXT, 600))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(250 if g.quiet else 300, 0)
	if g.quiet:
		head.add_child(text)
	else:
		col.add_child(text)
	var hint := UiTheme.make_label("", UiTheme.text(13 if g.quiet else 15, UiTheme.TEXT_MUTED, 500))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(250 if g.quiet else 300, 0)
	col.add_child(hint)
	# Under the crosshair, the prompts and every menu, like the other dots.
	var dot := WaypointMarker.new()
	dot.source = g
	dot.ring_color = g.color
	dot.quiet = g.quiet
	_root.add_child(dot)
	_root.move_child(dot, side_waypoint.get_index() + 1)
	return {"card": card, "title": title, "text": text, "hint": hint, "dot": dot}


func _refresh_goal_card(g: SideGoal) -> void:
	var e: Dictionary = _goal_cards.get(g, {})
	if e.is_empty():
		return
	var card: GlassPanel = e["card"]
	card.set_meta("active", g.text != "")
	(e["title"] as Label).text = UiTheme.caps(tr("HUD_SIDE_GOAL") % g.title)
	var text: Label = e["text"]
	if g.quiet and text.text != g.text:
		e["hint_left"] = SIDE_HINT_SECONDS
	text.text = g.text
	var hint: Label = e["hint"]
	hint.text = g.hint
	hint.visible = g.hint != "" and (not g.quiet or float(e.get("hint_left", 0.0)) > 0.0
			or (e["dot"] as WaypointMarker).near(SIDE_HINT_NEAR))
	if _crosshair != null:
		_sync_hud_visibility()
	if card.visible:
		card.reset_size()
		_place_side_cards()


## Grandpa's line for chapter `index` under the goal, for a while.
func show_chapter_note(index: int) -> void:
	_quest_note.text = "“%s”" % Quests.chapter_note(index)
	_quest_note.visible = true
	_note_left = 18.0


func _on_level_up(level: int) -> void:
	if DebugTools.is_automated() or SaveGame.loading:
		return
	level_up_screen.open(level)


func _build_clock() -> void:
	var card := GlassPanel.new(Vector4(16, 10, 20, 12), 18.0)
	_clock_card = card
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.offset_left = -28
	card.offset_right = -28
	card.offset_top = 24
	_root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var weather := VBoxContainer.new()
	weather.add_theme_constant_override("separation", 0)
	weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(weather)
	_weather_icon = UiTheme.icon_rect(null, 50)
	weather.add_child(_weather_icon)
	_weather_label = UiTheme.make_label("", UiTheme.heading(14, UiTheme.TEXT_MUTED, 700, 1))
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather.add_child(_weather_label)
	var sep := ColorRect.new()
	sep.color = UiTheme.LINE
	sep.custom_minimum_size = Vector2(1, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -6)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	_time_label = UiTheme.make_label("", UiTheme.heading(52, UiTheme.TEXT, 700, 1))
	texts.add_child(_time_label)
	_day_label = UiTheme.make_label("", UiTheme.heading(17, UiTheme.GOLD_SOFT, 700, 2))
	texts.add_child(_day_label)
	_day_bar = StatBar.new(4.0, Color(UiTheme.GOLD, 0.9))
	_day_bar.custom_minimum_size = Vector2(0, 4)
	col.add_child(_day_bar)


func _build_center() -> void:
	_crosshair = Crosshair.new()
	UiTheme.place(_crosshair, Vector2(0.5, 0.5), Vector2(-40, -40), Vector2(80, 80))
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	_progress_label = UiTheme.make_label("", UiTheme.heading(24, UiTheme.TEXT, 700, 2, true))
	UiTheme.place(_progress_label, Vector2(0.5, 0.5), Vector2(-300, 44), Vector2(600, 32))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.visible = false
	_root.add_child(_progress_label)
	_prompts = VBoxContainer.new()
	_prompts.add_theme_constant_override("separation", 8)
	_prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompts.alignment = BoxContainer.ALIGNMENT_BEGIN
	UiTheme.place(_prompts, Vector2(0.5, 0.5), Vector2(-400, 150), Vector2(800, 150))
	_root.add_child(_prompts)
	# Right of the crosshair, clear of the hold ring, its label and the prompts. It
	# shows and hides itself (aimed bed, menus, driving); the menus draw over it.
	crop_card = CropCard.new()
	_root.add_child(crop_card)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.place(_toasts, Vector2(0, 0.5), Vector2(28, TOAST_TOP), Vector2(560, TOAST_HEIGHT))
	_root.add_child(_toasts)


## The toasts' column keeps clear of the goal `cards` (three or more of them, say the
## story's, the wolves', the vet's and Zeynep's, reach down past its usual top): it
## slides down under them, and when that leaves too little room over the needs bars the
## oldest toasts go early.
func _place_toasts(cards: Array[Rect2], delta: float) -> void:
	var mid := _root.size.y * 0.5
	var top := mid + TOAST_TOP
	for r in cards:
		top = maxf(top, r.end.y + TOAST_GAP)
	var want := top - mid
	if not is_equal_approx(_toasts.offset_top, want):
		_toasts.offset_top = move_toward(_toasts.offset_top, want, delta * TOAST_SLIDE)
		_toasts.offset_bottom = _toasts.offset_top + TOAST_HEIGHT
	if _toasts.get_child_count() < 2:
		return
	var floor_y := _root.size.y - 22.0
	if needs_bars and needs_bars.visible:
		floor_y = needs_bars.position.y
	var room := floor_y - TOAST_GAP - (mid + _toasts.offset_top)
	while _toasts.get_child_count() > 1 and _toasts_height() > room:
		_toasts.get_child(0).free()


## The toasts' height as they stack now.
func _toasts_height() -> float:
	var h := 0.0
	for c: Control in _toasts.get_children():
		h += c.get_combined_minimum_size().y
	return h + 8.0 * maxf(_toasts.get_child_count() - 1, 0)


func _refresh_weather() -> void:
	_night = GameClock.is_night()
	_weather_icon.texture = Weather.icon(-1, _night)
	_weather_label.text = UiTheme.caps(Weather.kind_name(-1, _night))


## Gameplay HUD pieces hide while a full-screen menu is open.
func _sync_hud_visibility() -> void:
	var menu := Game.is_ui_open()
	var driving := _driving()
	_crosshair.visible = not menu and not driving
	_prompts.visible = not menu
	hotbar.visible = not menu and _hotbar_wanted()
	if needs_bars:
		# The needs come with the bag (a new farm's first minutes show neither).
		needs_bars.visible = not menu and PlayerState.hotbar_unlocked and not title_screen.visible
	if cook_rings:
		cook_rings.visible = not menu and not driving
	var title := title_screen.visible
	_money_pill.visible = not title
	_clock_card.visible = not title
	if _level_pill:
		_level_pill.visible = not title
	if _quest_card:
		_quest_card.visible = not title and not menu and bool(_quest_card.get_meta("active", false))
	if _side_card:
		_side_card.visible = not title and not menu and bool(_side_card.get_meta("active", false))
	for e: Dictionary in _goal_cards.values():
		var gc: Control = e["card"]
		gc.visible = not title and not menu and bool(gc.get_meta("active", false))
	if title:
		# Nothing of the last game lingers over the title (their tweens end on their own).
		if _sale_badge:
			_sale_badge.visible = false
		if achievement_toast:
			achievement_toast.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_ui_open():
		return
	if event.is_action_pressed("inventory"):
		# A new farm has no bag to open until the first item comes in.
		if PlayerState.hotbar_unlocked:
			inventory_screen.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		pause_menu.show_screen()
		get_viewport().set_input_as_handled()


func open_build_board(focus: StringName = &"") -> void:
	build_screen.open(focus)


func open_shop(shop: Dictionary) -> void:
	shop_screen.open(shop)


func open_rancher() -> void:
	rancher_screen.open()


## The vet clinic in town (its counter, Dr. Selin).
func open_vet() -> void:
	vet_screen.open()


func open_animal_panel(a: AnimalData) -> void:
	animal_panel.open(a)


func open_settings() -> void:
	settings_screen.show_screen()


## Warehouse / pickup bed transfers; `vehicle` null = opened at the warehouse.
func open_storage(vehicle: Vehicle) -> void:
	storage_screen.open(vehicle)


func open_dealer(vehicle: Vehicle) -> void:
	dealer_screen.open(vehicle)


## "save" or "load".
func open_saves(mode: String) -> void:
	save_screen.open(mode)


func open_crafting() -> void:
	crafting_screen.open()


func open_orders() -> void:
	order_screen.open()


func show_title() -> void:
	title_screen.show_title()
	_sync_hud_visibility()


## The first item on a new farm: the hotbar rises in (after any open window closes).
func _on_hotbar_revealed() -> void:
	if Game.is_ui_open() or SaveGame.loading:
		_reveal_pending = not SaveGame.loading
		return
	_reveal_pending = false
	_sync_hud_visibility()
	if hotbar.visible and not DebugTools.is_automated():
		hotbar.reveal()
		Audio.ui("open", -8.0)
		notify(tr("MSG_BAG_OPEN"), UiTheme.GREEN)


## What the shipping bin fetched overnight, under the money for a while (the level and
## goal cards slide down to make room). Nothing for 0.
func show_sale_badge(gold: int) -> void:
	if gold <= 0:
		return
	_sale_badge.position = Vector2(28.0, _money_pill.position.y + _money_pill.size.y + 10.0)
	_tween_sale_room(_sale_badge.show_amount(gold) + 10.0, SaleBadge.FADE_IN + 0.1)


func _close_sale_room() -> void:
	_tween_sale_room(0.0, SaleBadge.FADE_OUT)


func _tween_sale_room(to: float, seconds: float) -> void:
	if _sale_tween and _sale_tween.is_valid():
		_sale_tween.kill()
	_sale_tween = create_tween()
	_sale_tween.tween_property(self, "_sale_room", to, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Opens the inventory next to a container such as a chest.
func open_container(container: Inventory, title: String, on_close := Callable()) -> void:
	inventory_screen.open(container, title, on_close)


# --- Updates -------------------------------------------------------------------

func _on_money_changed(amount: int, delta: int) -> void:
	_money_label.text = UiTheme.money(amount)
	if delta == 0 or not is_inside_tree():
		return
	var pop := UiTheme.make_label(("+" if delta > 0 else "−") + UiTheme.money(absi(delta)),
			UiTheme.heading(26, UiTheme.GREEN if delta > 0 else UiTheme.RED, 700, 1, true))
	pop.position = _money_pill.position + Vector2(24, _money_pill.size.y + 4 + _sale_room)
	_root.add_child(pop)
	var tw := pop.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "position:y", pop.position.y - 26, 1.2)
	tw.tween_property(pop, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.chain().tween_callback(pop.queue_free)


func _on_prompt_changed(lines: PackedStringArray) -> void:
	if lines == _last_prompt:
		return
	_last_prompt = lines
	for c in _prompts.get_children():
		c.queue_free()
	_crosshair.targeting = not lines.is_empty()
	for line in lines:
		if line.begins_with(TITLE_MARK):
			var t := UiTheme.make_label(UiTheme.caps(line.substr(TITLE_MARK.length())), UiTheme.heading(18, UiTheme.GOLD_SOFT, 700, 3, true))
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_prompts.add_child(t)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := _prompt_rx.search(line)
		var action := line
		if m:
			var key := m.get_string(1)
			action = m.get_string(2)
			var cap := "LMB" if key == tr("KEY_LMB") else ("RMB" if key == tr("KEY_RMB") else key)
			row.add_child(UiTheme.keycap(cap, 20))
		var l := UiTheme.make_label(UiTheme.caps(action), UiTheme.heading(24, UiTheme.TEXT, 700, 2, true))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		_prompts.add_child(row)


func notify(message: String, color := UiTheme.NOTIFY) -> void:
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color(0.03, 0.04, 0.035, 0.72), 10, 0)
	sb.border_width_left = 4
	sb.border_color = color
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	toast.add_theme_stylebox_override("panel", sb)
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := UiTheme.make_label(message, UiTheme.heading(24, color.lerp(Color.WHITE, 0.25), 700, 1))
	toast.add_child(l)
	_toasts.add_child(toast)
	while _toasts.get_child_count() > MAX_TOASTS:
		_toasts.get_child(0).free()
	toast.modulate.a = 0.0
	var tw := toast.create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.8)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)


func _on_progress_started(label: String, _duration: float) -> void:
	_progress_label.text = UiTheme.caps(label)
	_progress_label.visible = true
	_crosshair.progress = 0.0


func _on_progress_updated(ratio: float) -> void:
	_crosshair.progress = ratio


func _on_progress_finished(_completed: bool) -> void:
	_progress_label.visible = false
	_crosshair.progress = -1.0
