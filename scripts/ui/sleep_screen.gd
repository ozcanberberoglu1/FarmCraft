class_name SleepScreen
extends CanvasLayer
## Sleep sequence: fade to black, close the day (sales, report), skip to 06:00,
## show the morning report, then fade back in. Once the morning shows, the night's
## shipping-bin income goes out on the bus (Events.morning_sale) and the HUD shows it
## under the money. A night the wolves came has a card of its own (WolfRaids.take_report).
## Fainting from wounds (PlayerState.knock_out) runs the same night: the view sinks to
## the ground as the screen darkens, a line on the black tells how he got home, and the
## morning finds him in his bed, hungry and worn out.

signal _continue

const PASS_OUT_FEE_RATE := 0.1
const PASS_OUT_FEE_MAX := 60
## Fainting: seconds the view takes to sink and the screen to go black, and the line
## shows on the black.
const FAINT_FALL := 1.6
const FAINT_LINE := 3.6

var _black: ColorRect
var _report: VBoxContainer
var _hint: Label
var _busy := false
var _waiting := false
var _blink := 0.0
## The line on the black after fainting.
var _faint_line: Label
## The red the screen goes through as he faints, under the black.
var _faint_red: ColorRect


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color(0.012, 0.016, 0.02)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	_black.visible = false
	add_child(_black)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.add_child(center)
	_report = VBoxContainer.new()
	_report.add_theme_constant_override("separation", 18)
	_report.custom_minimum_size = Vector2(760, 0)
	_report.visible = false
	center.add_child(_report)
	_faint_red = ColorRect.new()
	_faint_red.color = Color(0.32, 0.02, 0.02)
	_faint_red.set_anchors_preset(Control.PRESET_FULL_RECT)
	_faint_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faint_red.modulate.a = 0.0
	_faint_red.visible = false
	add_child(_faint_red)
	move_child(_faint_red, 0)
	_faint_line = UiTheme.paragraph("", 26, UiTheme.TEXT, 820)
	_faint_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faint_line.visible = false
	center.add_child(_faint_line)


func is_busy() -> bool:
	return _busy


## `passed_out`: collapsed at 02:00 (a fee is lost); `knocked_out`: fainted from wounds
## (PlayerState.knock_out).
func start_sleep(passed_out := false, knocked_out := false) -> void:
	if _busy:
		return
	_busy = true
	SaveGame.snapshot()
	Game.push_ui(&"sleep")
	Events.action_progress_finished.emit(false)
	_black.visible = true
	if knocked_out:
		await _faint()
	else:
		await _fade(1.0, 0.9)
	Events.day_ending.emit()
	var fee := 0
	if passed_out:
		fee = mini(int(Economy.money * PASS_OUT_FEE_RATE), PASS_OUT_FEE_MAX)
		if fee > 0:
			Economy.spend(fee, "REPORT_PASS_OUT_FEE")
	var summary := Economy.close_day()
	var shipped := shipping_income(summary)
	GameClock.sleep_to_next_morning()
	if passed_out:
		GameClock.running = not DebugTools.args.has("freeze-time")
	_wake_player()
	# The night's wolf lines are taken before the morning's autosave, so a game loaded
	# from it doesn't tell of them again the next morning.
	var wolves := WolfRaids.take_report()
	var autosaved := SaveGame.save(SaveGame.AUTO)
	_show_report(summary, fee, knocked_out, wolves)
	_waiting = true
	await _continue
	_waiting = false
	_report.visible = false
	await _fade(0.0, 0.8)
	_black.visible = false
	Game.pop_ui(&"sleep")
	Game.notify(tr("MSG_GOOD_MORNING") % GameClock.day)
	if autosaved:
		Game.notify(tr("MSG_AUTOSAVED"), UiTheme.TEXT_MUTED)
	_busy = false
	# Every morning, 0 when the bin was empty (the HUD's badge, the first-sale medal).
	Events.morning_sale.emit(shipped)


## What the shipping bin earned in the day `summary` (Economy.close_day) closed.
static func shipping_income(summary: Dictionary) -> int:
	return int((summary.get("lines", {}) as Dictionary).get("REPORT_SHIPPING", 0))


## Dismisses the report (also used by automated tests).
func confirm() -> void:
	if _waiting:
		_continue.emit()


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()
		confirm()


func _process(delta: float) -> void:
	if _waiting and _hint:
		_blink += delta
		_hint.modulate.a = 0.5 + 0.5 * sin(_blink * 3.0)


## He faints: the view sinks to the ground as the screen reddens and goes black (a
## heartbeat, the thud of the fall), then a line on the black says how he got home.
func _faint() -> void:
	var player := Game.player as Player
	if player:
		player.collapse(FAINT_FALL)
	CombatSfx.play("heartbeat", null, -4.0, 0.0)
	get_tree().create_timer(FAINT_FALL * 0.8).timeout.connect(func() -> void: CombatSfx.play("fall", null, -3.0, 0.03))
	_faint_red.visible = true
	var red := create_tween()
	red.tween_property(_faint_red, "modulate:a", 0.55, FAINT_FALL * 0.5)
	_black.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(FAINT_FALL * 0.35)
	tw.tween_property(_black, "modulate:a", 1.0, FAINT_FALL * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_faint_red.visible = false
	_faint_red.modulate.a = 0.0
	_faint_line.text = tr("MSG_KNOCKED_OUT_WOLVES" if GameClock.is_night() else "MSG_KNOCKED_OUT")
	_faint_line.visible = true
	_faint_line.modulate.a = 0.0
	var line := create_tween()
	line.tween_property(_faint_line, "modulate:a", 1.0, 0.6)
	line.tween_interval(FAINT_LINE)
	line.tween_property(_faint_line, "modulate:a", 0.0, 0.6)
	await line.finished
	_faint_line.visible = false


func _fade(to: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", to, seconds)
	await tw.finished


func _wake_player() -> void:
	var bed := get_tree().get_first_node_in_group(&"beds") as Node3D
	var player := Game.player as Player
	if bed == null or player == null:
		return
	player.end_collapse()
	player.global_position = bed.global_position + Vector3(-1.25, 0.05, 0.4)
	player.velocity = Vector3.ZERO
	player.look_at_yaw_pitch(PI * 0.5, deg_to_rad(-8.0))


## A dotted line for each of `lines` in `box` (the wolves' card), in `color`.
func _note_rows(box: VBoxContainer, lines: PackedStringArray, color: Color) -> void:
	for note in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UiTheme.box(color, 4))
		row.add_child(dot)
		row.add_child(UiTheme.paragraph(note, 18, color.lerp(Color.WHITE, 0.55), 660))
		box.add_child(row)


func _card(min_size := Vector2(0, 0)) -> Array:
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(1, 1, 1, 0.05), 16, 1, Color(1, 1, 1, 0.09))
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = min_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	return [card, box]


## The morning report: the day closed (`summary`, Economy.close_day), the fee for passing
## out, a faint, the night's `wolves` lines (WolfRaids.take_report), the animals' notes,
## the weather.
func _show_report(summary: Dictionary, fee: int, knocked_out := false, wolves := PackedStringArray()) -> void:
	for c in _report.get_children():
		c.queue_free()
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", -6)
	_report.add_child(head)
	var sun := UiTheme.icon_rect(UiTheme.glyph("sun"), 46, UiTheme.GOLD)
	head.add_child(sun)
	var title := UiTheme.make_label(UiTheme.caps(tr("HUD_DAY") % GameClock.day), UiTheme.heading(92, UiTheme.TEXT, 700, 4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var sub := UiTheme.make_label(UiTheme.caps(tr("REPORT_SEASON_DAY") % [GameClock.season_name(), GameClock.get_day_of_season()]),
			UiTheme.heading(22, UiTheme.GOLD_SOFT, 700, 4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(sub)
	if GameClock.get_day_of_season() == 1 and GameClock.day > 1:
		var season := UiTheme.chip(tr("MSG_SEASON_START") % GameClock.season_name(), UiTheme.GOLD, "sparkles", 18)
		season.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_report.add_child(season)
	if fee > 0:
		var po := UiTheme.chip(tr("MSG_PASSED_OUT") % UiTheme.money(fee), UiTheme.RED, "info", 17)
		po.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_report.add_child(po)
	if knocked_out:
		var ko := UiTheme.chip(tr("REPORT_KNOCKED_OUT"), UiTheme.RED, "info", 17)
		ko.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_report.add_child(ko)
	_report.add_child(UiTheme.section(tr("REPORT_YESTERDAY"), "calendar"))
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 14)
	_report.add_child(money_row)
	var income: int = summary.get("income", 0)
	var expenses: int = summary.get("expenses", 0)
	var net := income - expenses
	for spec: Array in [[tr("REPORT_INCOME"), "+" + UiTheme.money(income), UiTheme.GREEN, "arrow_up"],
			[tr("REPORT_EXPENSES"), "−" + UiTheme.money(expenses), UiTheme.RED, "arrow_down"],
			[tr("REPORT_NET"), ("+" if net >= 0 else "−") + UiTheme.money(absi(net)), UiTheme.GOLD_SOFT, ""]]:
		var c := _card(Vector2(0, 110))
		money_row.add_child(c[0])
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		if spec[3] != "":
			top.add_child(UiTheme.icon_rect(UiTheme.glyph(spec[3]), 18, spec[2]))
		top.add_child(UiTheme.make_label(UiTheme.caps(String(spec[0])), UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 2)))
		c[1].add_child(top)
		c[1].add_child(UiTheme.make_label(spec[1], UiTheme.heading(44, spec[2], 700, 1)))
	var shipped := shipping_income(summary)
	if shipped > 0:
		var chip := UiTheme.chip(tr("REPORT_SHIPPED") % UiTheme.money(shipped), UiTheme.GREEN, "", 17)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_report.add_child(chip)
	if not wolves.is_empty():
		_report.add_child(UiTheme.section(tr("REPORT_WOLVES"), "moon"))
		var wc := _card()
		_report.add_child(wc[0])
		_note_rows(wc[1], wolves.slice(0, 5), WolfRaids.AMBER)
	# Every hurt animal's time left (and a death from wounds, one healed) shows, the
	# everyday lines in the room left (Animals.take_report_lines).
	var notes := Animals.take_report_lines(5)
	if not notes.is_empty():
		_report.add_child(UiTheme.section(tr("REPORT_ANIMALS"), "paw"))
		var c := _card()
		_report.add_child(c[0])
		for note in notes:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var dot := PanelContainer.new()
			dot.custom_minimum_size = Vector2(8, 8)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.add_theme_stylebox_override("panel", UiTheme.box(Color("ffb38a"), 4))
			row.add_child(dot)
			row.add_child(UiTheme.paragraph(note, 18, Color("ffd2bb"), 660))
			c[1].add_child(row)
	_report.add_child(UiTheme.section(tr("REPORT_WEATHER"), "sun"))
	var weather_row := HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 14)
	_report.add_child(weather_row)
	for spec: Array in [[tr("REPORT_TODAY"), Weather.today], [tr("REPORT_TOMORROW"), Weather.forecast]]:
		var c := _card()
		weather_row.add_child(c[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		c[1].add_child(row)
		row.add_child(UiTheme.icon_rect(Weather.icon(spec[1]), 56))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(col)
		col.add_child(UiTheme.make_label(UiTheme.caps(String(spec[0])), UiTheme.heading(16, UiTheme.TEXT_MUTED, 700, 2)))
		col.add_child(UiTheme.make_label(UiTheme.caps(Weather.kind_name(spec[1])), UiTheme.heading(30, UiTheme.TEXT, 700, 1)))
	_report.add_child(UiTheme.spacer(4))
	_hint = UiTheme.make_label(UiTheme.caps(tr("REPORT_CONTINUE")), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 3))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report.add_child(_hint)
	_report.visible = true
	UiTheme.appear(_report, 0.35)
