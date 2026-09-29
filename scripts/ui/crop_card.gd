class_name CropCard
extends GlassPanel
## Beside the crosshair while a planted bed is aimed at: a ring that fills with the
## crop's growth towards the next harvest (its icon inside, stage marks on the track),
## the crop, stage and percent, the game time left and the soil's water. Dry soil
## pauses growth (amber), a ripe crop fills the ring and pulses, a withered one turns
## it red. The numbers come from FarmPlot.growth_info(), read a few times a second
## and only while a planted bed is the player's target; the labels are laid out
## again only when their text changes. Hidden in menus and while driving.

## Seconds between reads of the aimed bed (growth moves in 10-game-minute ticks).
const REFRESH := 0.25
## The aim slips through the gaps between beds: stay up this long before hiding.
const LINGER := 0.3
## Left edge and vertical centre from the screen centre: right of the hold-action ring
## (radius 26), above its label (+44) and the prompt rows (+150).
const OFFSET := Vector2(68, -32)
const STAGE_KEYS := ["CROP_STAGE_SPROUT", "CROP_STAGE_YOUNG", "CROP_STAGE_GROWING", "CROP_STAGE_RIPE"]
const AMBER := Color("f2b64a")
## Under this many hours from withering the water line turns red.
const URGENT_HOURS := 12.0
## The same art as the badges over the beds.
const BADGES := {"ready": "res://art/icons/ui/badge_harvest.svg", "dry": "res://art/icons/ui/badge_water.svg",
	"withered": "res://art/icons/ui/badge_withered.svg"}

## Mipmapped copies of the badges by state (their SVGs import at 128 px without
## mipmaps and would shimmer at ring size).
static var _badges := {}

var ring: GrowthRing
## "growing", "dry", "ready" or "withered"; "" while hidden (tests read it).
var state := ""
var _name: Label
var _stage: Label
var _time_row: HBoxContainer
var _time_icon: TextureRect
var _time: Label
var _hint_icon: TextureRect
var _hint: Label
var _plot: FarmPlot = null
var _wait := 0.0
var _lost := 0.0
var _snap := true
var _key := ""


func _init() -> void:
	super(Vector4(12, 10, 22, 10), 20.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	UiTheme.place(self, Vector2(0.5, 0.5), OFFSET, Vector2.ZERO)
	# Centred on OFFSET.y whatever its height; long languages only grow it rightwards.
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	ring = GrowthRing.new(84.0, 7.0)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ring)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Wide enough that the ticking time doesn't make the card twitch.
	col.custom_minimum_size = Vector2(168, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name = UiTheme.make_label("", UiTheme.heading(23, UiTheme.TEXT, 700, 2))
	col.add_child(_name)
	_stage = UiTheme.make_label("", UiTheme.heading(15, UiTheme.GOLD_SOFT, 700, 2))
	col.add_child(_stage)
	col.add_child(UiTheme.spacer(4))
	_time_row = HBoxContainer.new()
	_time_row.add_theme_constant_override("separation", 7)
	_time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_time_row)
	_time_icon = UiTheme.icon_rect(UiTheme.glyph("clock"), 18, UiTheme.TEXT_MUTED)
	_time_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_time_row.add_child(_time_icon)
	_time = UiTheme.make_label("", UiTheme.heading(21, UiTheme.TEXT, 700, 1))
	_time_row.add_child(_time)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 7)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_row)
	_hint_icon = UiTheme.icon_rect(UiTheme.glyph("drop"), 17, UiTheme.BLUE)
	_hint_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_row.add_child(_hint_icon)
	_hint = UiTheme.make_label("", UiTheme.text(15, UiTheme.BLUE, 600))
	hint_row.add_child(_hint)


## A cast and a few checks a frame; the bed itself is read every REFRESH.
func _process(delta: float) -> void:
	var p := _on_foot_player()
	var plot: FarmPlot = null
	if p != null and is_instance_valid(p.target):
		plot = p.target as FarmPlot
	# Grandpa's beds wait for their goal without a card (FarmPlot.held_back).
	if plot == null or plot.crop == &"" or plot.held_back():
		if visible:
			_lost += delta
			# At once in a menu, while driving or on a bed just harvested or cleared;
			# a moment later when the aim slips off between beds.
			if p == null or plot != null or _lost >= LINGER:
				_hide_card()
		return
	_lost = 0.0
	if not is_instance_valid(_plot) or plot != _plot:
		_plot = plot
		_wait = 0.0
		_snap = true
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	_show(plot.growth_info())


## The player on foot with no menu, title or sleep report open, else null (the aim
## goes stale while driving).
static func _on_foot_player() -> Player:
	if Game.is_ui_open() or not is_instance_valid(Game.player):
		return null
	var p := Game.player as Player
	return p if p != null and p.driving == null else null


func _hide_card() -> void:
	visible = false
	state = ""
	_key = ""
	_plot = null
	_snap = true
	_lost = 0.0
	ring.settle()


func _show(info: Dictionary) -> void:
	if info.is_empty():
		_hide_card()
		return
	var kind := String(info["state"])
	state = kind
	var crop_id: StringName = info["crop"]
	var item := ItemDB.get_item(StringName(CropTable.get_crop(crop_id).get("item", crop_id)))
	var regrow := bool(info["regrow"])
	var ratio := 1.0 if kind == "ready" else float(info["ratio"])
	var wet := float(info["wet_hours"])
	var stage_text := tr(String(STAGE_KEYS[clampi(int(info["stage"]), 0, 3)]))
	if regrow and kind != "ready":
		stage_text = tr("CROP_STAGE_REGROW")
	var ring_col := UiTheme.GREEN
	var icon_col := Color.WHITE
	var glow := Color(0, 0, 0, 0)
	var time_glyph := "clock"
	var time_text := time_left_text(float(info["hours_left"]))
	var time_col := UiTheme.TEXT
	var hint_glyph := "drop"
	var hint_text := tr("CROP_WET_FOR") % ceili(wet)
	var hint_col := UiTheme.BLUE
	if bool(info["rewater"]):
		# Wet now, but dry again before it is ripe.
		hint_text = tr("CROP_WATER_AGAIN") % ceili(wet)
		hint_col = AMBER
	match kind:
		"ready":
			glow = Color(UiTheme.GREEN, 0.16)
			time_glyph = "check"
			time_text = tr("CROP_READY")
			time_col = UiTheme.GREEN
			hint_glyph = "wheat"
			hint_text = tr("CROP_HARVEST_HINT")
			hint_col = UiTheme.GOLD_SOFT
		"dry":
			var left := float(info["wither_in"])
			ring_col = AMBER
			glow = Color(AMBER, 0.12)
			time_text = tr("CROP_PAUSED")
			time_col = AMBER
			hint_text = tr("CROP_NEEDS_WATER") % ceili(left)
			hint_col = UiTheme.RED if left < URGENT_HOURS else AMBER
		"withered":
			ring_col = UiTheme.RED
			icon_col = Color(0.64, 0.5, 0.38, 0.85)
			glow = Color(UiTheme.RED, 0.12)
			stage_text = tr("CROP_STAGE_WITHERED")
			time_text = ""
			hint_glyph = "trash"
			hint_text = tr("CROP_CLEAR_HINT")
			hint_col = UiTheme.RED
	var stage_line := stage_text
	if kind != "withered":
		# Rounded down, so it only reads 100 once the crop is ripe.
		var pct := 100 if kind == "ready" else mini(floori(ratio * 100.0), 99)
		stage_line = "%s · %s" % [stage_text, UiTheme.percent(pct)]
		if int(info["fertility"]) > 0:
			stage_line += " · " + tr("CROP_FERTILIZED")
	ring.set_state(ratio, ring_col, _snap or not visible)
	ring.set_look(item.icon if item else null, _badge(kind), icon_col, kind == "ready", 1 if regrow else 3)
	_snap = false
	var key := "%s|%s|%s|%s|%s|%s" % [kind, crop_id, stage_line, time_text, hint_text, hint_col.to_html()]
	if key != _key:
		_key = key
		_name.text = UiTheme.caps(item.display_name()) if item else ""
		_stage.text = UiTheme.caps(stage_line)
		_time_row.visible = time_text != ""
		_time_icon.texture = UiTheme.glyph(time_glyph)
		_time_icon.modulate = UiTheme.TEXT_MUTED if time_col == UiTheme.TEXT else time_col
		_time.text = time_text
		_time.label_settings.font_color = time_col
		_hint_icon.texture = UiTheme.glyph(hint_glyph)
		_hint_icon.modulate = hint_col
		_hint.text = hint_text
		_hint.label_settings.font_color = hint_col
		# A faint glow of the state's colour on the glass's inner edge.
		set_look(tint, border, glow)
	if not visible:
		visible = true
		UiTheme.appear(self, 0.14)
		# The new text is measured only at the end of the frame: scale about the size
		# the card is about to take.
		pivot_offset = get_combined_minimum_size() * 0.5


## The time row: "~3h 20m left" ("~3 sa 20 dk kaldı").
static func time_left_text(hours: float) -> String:
	return _t("CROP_TIME_LEFT") % format_hours(hours)


## Game time, rounded up to the clock's 10-minute ticks (growth moves in those
## steps): "~1d 6h" from a day up, "~3h 20m", "~3h", "~40 min".
static func format_hours(hours: float) -> String:
	var minutes := maxi(ceili(hours * 6.0 - 0.001) * 10, 10)
	if minutes >= 1440:
		var days := floori(minutes / 1440.0)
		var day_hours := floori((minutes % 1440) / 60.0)
		if day_hours == 0:
			return _t("CROP_TIME_D") % days
		return _t("CROP_TIME_DH") % [days, day_hours]
	var whole := floori(minutes / 60.0)
	var rest := minutes % 60
	if whole == 0:
		return _t("CROP_TIME_M") % rest
	if rest == 0:
		return _t("CROP_TIME_H") % whole
	return _t("CROP_TIME_HM") % [whole, rest]


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func _badge(kind: String) -> Texture2D:
	if not BADGES.has(kind):
		return null
	if not _badges.has(kind):
		var tex := UiTheme.icon(String(BADGES[kind]))
		var img: Image = null
		if tex != null:
			img = tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
		_badges[kind] = tex
	return _badges[kind]
