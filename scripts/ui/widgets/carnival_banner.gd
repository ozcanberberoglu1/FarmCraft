class_name CarnivalBanner
extends Control
## The sweet note when a carnival night begins (Carnival): a glass card under the top of
## the screen, "the carnival has begun!" in gold over a line on the double pay, a festive
## rim that shimmers from pink to gold, and a shower of confetti. It floats in, stays a
## while and slowly fades away, then frees itself.

const TOP := 150.0
const WIDTH := 760.0
const HOLD := 6.0
const FADE_OUT := 3.2
const CONFETTI := 70
const COLORS: Array[Color] = [Color("ff5d8f"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"),
	Color("f78c3b"), Color("c77dff"), Color("fff3b0")]
const PINK := Color("ff7eb6")

var _card: GlassPanel
var _box: Control
## Confetti pieces: [x, y, speed, sway phase, spin, size, color index].
var _bits: Array = []
var _age := 0.0
var _life := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Offsets too: in the tree already, anchors alone would keep the empty rect it has.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.place(_box, Vector2(0.5, 0.0), Vector2(-WIDTH * 0.5, TOP), Vector2(WIDTH, 150))
	add_child(_box)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(center)
	_card = GlassPanel.new(Vector4(34, 18, 34, 20), 22.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_card)


## Shows `title` over `line`, then fades away.
func play(title: String, line: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph("sparkles"), 40, PINK))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var kicker := UiTheme.make_label(UiTheme.caps(tr("CARNIVAL_BANNER_KICKER")), UiTheme.heading(15, PINK, 700, 4))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	var head := UiTheme.make_label(title, UiTheme.heading(36, UiTheme.GOLD_SOFT, 700, 1, true))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var sub := UiTheme.make_label(line, UiTheme.text(18, UiTheme.TEXT, 500))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph("sparkles"), 40, UiTheme.GOLD))
	_rim(0.0)
	var w := get_viewport_rect().size.x
	for i in CONFETTI:
		_bits.append([randf_range(w * 0.5 - WIDTH * 0.75, w * 0.5 + WIDTH * 0.75), randf_range(-260.0, TOP - 20.0),
				randf_range(60.0, 130.0), randf() * TAU, randf_range(-5.0, 5.0), randf_range(5.0, 10.0), randi() % COLORS.size()])
	modulate.a = 0.0
	_box.position.y += 24.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_box, "position:y", _box.position.y - 24.0, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(HOLD)
	tw.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_box, "position:y", _box.position.y - 44.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
	_life = 1.1 + HOLD + FADE_OUT


## The card's rim shimmers between pink and gold.
func _rim(t: float) -> void:
	var c := PINK.lerp(UiTheme.GOLD, 0.5 + 0.5 * sin(t * 2.2))
	_card.set_look(UiTheme.GLASS, Color(c, 0.85), Color(c, 0.42))


func _process(delta: float) -> void:
	_age += delta
	# A window opened meanwhile (a shop, the bag) hides it; it fades on underneath.
	visible = not Game.is_ui_open()
	if _card:
		_rim(_age)
	for b: Array in _bits:
		b[1] += b[2] * delta
		b[3] += delta * 2.0
	queue_redraw()


func _draw() -> void:
	# Confetti rains for the first seconds, thinning out as the note settles.
	var keep := 1.0 - smoothstep(3.0, 6.5, _age)
	if keep <= 0.0:
		return
	for b: Array in _bits:
		var y: float = b[1]
		if y < -20.0 or y > TOP + 260.0:
			continue
		var x: float = b[0] + sin(b[3]) * 14.0
		var s: float = b[5]
		var col: Color = COLORS[int(b[6])]
		col.a = keep * clampf(1.0 - (y - TOP) / 260.0, 0.0, 1.0)
		draw_set_transform(Vector2(x, y), b[4] * _age, Vector2(1.0, 0.45 + 0.55 * absf(sin(b[3] * 1.3))))
		draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), col)
	draw_set_transform(Vector2.ZERO)


## The pink "×2" pill beside a price while a carnival night pays double (shop, orders).
static func badge(size := 15, with_icon := true) -> PanelContainer:
	var c := UiTheme.chip("×2", PINK, "sparkles" if with_icon else "", size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


## A festive strip over a sell list while the carnival pays double: `text` beside the pill.
static func strip(text: String, width: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.glow_box(Color(PINK.r, PINK.g, PINK.b, 0.12), 12, Color(PINK, 0.7), Color(PINK, 0.25), 8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(width, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(badge(17))
	var l := UiTheme.make_label(text, UiTheme.heading(18, Color("ffd6e8"), 700, 0))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	return p
