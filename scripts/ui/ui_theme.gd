class_name UiTheme
extends RefCounted
## FarmCraft's UI design system: palette, typography (Barlow for text, Barlow
## Condensed for titles, numbers and buttons), style boxes and small component
## factories shared by every screen. Windows are frosted glass (GlassPanel).

# --- Palette -----------------------------------------------------------------------------

const TEXT := Color("f4f0e6")
const TEXT_MUTED := Color("abb4a5")
const TEXT_DIM := Color("7c8578")
const TEXT_DARK := Color("17140e")
const GOLD := Color("e9b84e")
const GOLD_SOFT := Color("f7d78e")
const GREEN := Color("84d46f")
const RED := Color("ff6b5b")
const BLUE := Color("70c7ee")
const GLASS := Color(0.043, 0.055, 0.05, 0.8)
const BORDER := Color(1, 1, 1, 0.12)
const LINE := Color(1, 1, 1, 0.08)
const CARD := Color(1, 1, 1, 0.045)
const CARD_HOVER := Color(1, 1, 1, 0.09)
const CARD_ACTIVE := Color(0.91, 0.72, 0.31, 0.13)

# Names used around the codebase (3D signs, older widgets).
const PROMPT := GOLD_SOFT
const NOTIFY := GOLD_SOFT
const ACCENT := GOLD
const OUTLINE := Color(0.02, 0.02, 0.02, 0.85)
const PANEL_BG := GLASS
const SLOT_BG := CARD
const SLOT_BORDER := BORDER

const ICON_DIR := "res://art/icons/ui2/"
## Noto Sans (OFL) draws what Barlow lacks: Cyrillic and Greek, and the CJK scripts.
const NOTO := "res://art/fonts/noto/"
const NOTO_LATIN := "NotoSans-Variable.ttf"
## CJK faces by the locale they suit; the current language's comes first because the
## same Han character is drawn differently in Japanese, Chinese and Korean.
const NOTO_CJK := {"ja": "NotoSansJP-Variable.ttf", "zh_CN": "NotoSansSC-Variable.ttf",
	"zh_TW": "NotoSansTC-Variable.ttf", "ko": "NotoSansKR-Variable.ttf"}

static var _fonts := {}
static var _icons := {}
static var _font_locale := ""


# --- Typography -----------------------------------------------------------------------

## Body text (Barlow): 500 medium, 600 semibold, 700+ bold.
static func font(weight := 600) -> Font:
	var file := "Barlow-Bold.ttf" if weight >= 700 else ("Barlow-SemiBold.ttf" if weight >= 600 else "Barlow-Medium.ttf")
	return _font(file, 0, weight, false)


## Display text (Barlow Condensed) for titles, numbers and buttons; `tracking` adds
## letter spacing in pixels.
static func display(weight := 700, tracking := 1) -> Font:
	return _font("BarlowCondensed-Bold.ttf" if weight >= 700 else "BarlowCondensed-SemiBold.ttf", tracking, weight, true)


## Display text whose CJK characters are drawn the way `locale` writes them (the
## language picker shows every language's name in its own script).
static func display_for(locale: String, weight := 700, tracking := 1) -> Font:
	var key := "for/%s/%d/%d" % [locale, weight, tracking]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = load("res://art/fonts/" + ("BarlowCondensed-Bold.ttf" if weight >= 700 else "BarlowCondensed-SemiBold.ttf"))
		v.spacing_glyph = 0 if NOTO_CJK.has(locale) else tracking
		v.fallbacks = _fallbacks(weight, true, locale)
		_fonts[key] = v
	return _fonts[key]


static func _font(file: String, tracking: int, weight: int, condensed: bool) -> Font:
	var key := "%s/%d" % [file, tracking]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = load("res://art/fonts/" + file)
		# Han and kana are already evenly spaced: no letter spacing there.
		v.spacing_glyph = 0 if is_cjk() else tracking
		v.set_meta("tracking", tracking)
		v.set_meta("weight", weight)
		v.set_meta("condensed", condensed)
		v.fallbacks = _fallbacks(weight, condensed, TranslationServer.get_locale())
		_fonts[key] = v
	return _fonts[key]


## Noto Sans at a matching weight and width, the CJK faces with `locale`'s first, then
## system symbols (arrows, stars) none of them draw.
static func _fallbacks(weight: int, condensed: bool, locale: String) -> Array[Font]:
	var out: Array[Font] = []
	# Axis keys must be numeric OpenType tags: string names are ignored (Godot 4.7),
	# which would leave these variable fonts at their thin default weight.
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	var latin := FontVariation.new()
	latin.base_font = load(NOTO + NOTO_LATIN)
	latin.variation_opentype = {wght: clampi(weight, 100, 900), ts.name_to_tag("wdth"): 75 if condensed else 100}
	out.append(latin)
	var order: Array = NOTO_CJK.keys()
	var own := _cjk_key(locale)
	if own != "":
		order.erase(own)
		order.push_front(own)
	for k: String in order:
		var cjk := FontVariation.new()
		cjk.base_font = load(NOTO + String(NOTO_CJK[k]))
		cjk.variation_opentype = {wght: clampi(weight, 100, 900)}
		out.append(cjk)
	var symbols := SystemFont.new()
	symbols.font_names = PackedStringArray(["Apple Symbols", "Segoe UI Symbol", "Noto Sans Symbols 2", "DejaVu Sans"])
	out.append(symbols)
	return out


static func _cjk_key(locale: String) -> String:
	if locale.begins_with("ja"):
		return "ja"
	if locale.begins_with("ko"):
		return "ko"
	if locale.begins_with("zh"):
		return "zh_TW" if (locale.contains("TW") or locale.contains("HK") or locale.contains("Hant")) else "zh_CN"
	return ""


## True for languages written without spaces or capitals, where wide letter spacing
## and upper-casing don't apply.
static func is_cjk(locale := "") -> bool:
	return _cjk_key(TranslationServer.get_locale() if locale == "" else locale) != ""


## After a language change: reorder the CJK fallbacks of every font in use.
static func refresh_locale() -> void:
	var locale := TranslationServer.get_locale()
	if locale == _font_locale:
		return
	_font_locale = locale
	for key: String in _fonts:
		var v: FontVariation = _fonts[key]
		if v.has_meta("weight"):
			v.fallbacks = _fallbacks(int(v.get_meta("weight")), bool(v.get_meta("condensed")), locale)
			v.spacing_glyph = 0 if is_cjk(locale) else int(v.get_meta("tracking"))


## Body label settings; HUD text over the world gets a soft shadow.
static func text(size: int, color := TEXT, weight := 600, shadow := false) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font(weight)
	ls.font_size = size
	ls.font_color = color
	if shadow:
		_shadow(ls)
	return ls


## Title / number label settings in the condensed display face.
static func heading(size: int, color := TEXT, weight := 700, tracking := 1, shadow := false) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = display(weight, tracking)
	ls.font_size = size
	ls.font_color = color
	if shadow:
		_shadow(ls)
	return ls


static func _shadow(ls: LabelSettings) -> void:
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.55)
	ls.shadow_offset = Vector2(0, 2)


## Older call sites: body text with an optional outline.
static func label_settings(size: int, color := TEXT, weight := 600, outline := 0,
		outline_color := OUTLINE, shadow := false) -> LabelSettings:
	var ls := text(size, color, weight, shadow)
	ls.outline_size = outline
	ls.outline_color = outline_color
	return ls


static func make_label(value: String, settings: LabelSettings) -> Label:
	var l := Label.new()
	l.text = value
	l.label_settings = settings
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Joins list items the way the language does ("A, B" / "A、B").
static func join_list(parts: PackedStringArray) -> String:
	var locale := TranslationServer.get_locale()
	return ("、" if locale.begins_with("zh") or locale.begins_with("ja") else ", ").join(parts)


## Makes a label's text fit `width`: the font shrinks down to `min_size`, and what
## still doesn't fit wraps onto a second line (then ends in "…"). For names in fixed
## tiles, whose length varies a lot between languages.
static func fit_label(l: Label, width: float, min_size := 12) -> void:
	var ls := l.label_settings
	if ls == null or ls.font == null:
		return
	# Letter spacing isn't part of the measured width.
	var tracking := (ls.font as FontVariation).spacing_glyph * l.text.length() if ls.font is FontVariation else 0
	var measure := func(sz: int) -> float: return ls.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + tracking
	var size := ls.font_size
	while size > min_size and float(measure.call(size)) > width:
		size -= 1
	if size != ls.font_size:
		ls = ls.duplicate() as LabelSettings
		ls.font_size = size
		l.label_settings = ls
	if float(measure.call(size)) > width:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# Two lines sit tight.
		if l.label_settings.line_spacing > -3.0:
			ls = l.label_settings.duplicate() as LabelSettings
			ls.line_spacing = -3.0
			l.label_settings = ls
	l.clip_text = true
	# Outside the tree a wrapping label still reports its one-line width as minimum,
	# so it can only be narrowed once it's in: size it when it's ready.
	if l.is_inside_tree():
		l.size = Vector2(width, l.size.y)
	else:
		l.ready.connect(func() -> void: l.size = Vector2(width, l.size.y), CONNECT_ONE_SHOT)


## Wrapped paragraph of body text.
static func paragraph(value: String, size := 18, color := TEXT_MUTED, width := 400.0) -> Label:
	var l := make_label(value, text(size, color, 500))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## Condensed upper-case title label.
static func title(value: String, size := 34, color := TEXT, tracking := 2) -> Label:
	return make_label(caps(value), heading(size, color, 700, tracking))


## Upper case for display in the current language (Turkish i -> İ, ı -> I).
static func caps(value: String) -> String:
	var ts := TextServerManager.get_primary_interface()
	return ts.string_to_upper(value, TranslationServer.get_locale())


## 75 -> "%75" in Turkish, "75 %" in French and German, "75%" elsewhere.
static func percent(value: int) -> String:
	var locale := TranslationServer.get_locale()
	if locale.begins_with("tr"):
		return "%%%d" % value
	if locale.begins_with("fr") or locale.begins_with("de"):
		return "%d %%" % value
	return "%d%%" % value


## 12345 -> "12.345" / "12,345" / "12 345": the thousands separator of the language.
static func money(amount: int) -> String:
	var locale := TranslationServer.get_locale().get_slice("_", 0)
	var sep := "."
	if locale in ["en", "ja", "ko", "zh"]:
		sep = ","
	elif locale in ["fr", "ru", "pl"]:
		sep = " "
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = sep + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if amount < 0 else "") + s + out


## A local date and time the way the language writes it.
static func date_time(unix: float) -> String:
	if unix <= 0.0:
		return ""
	var local := int(unix) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	var time := "%02d:%02d" % [d["hour"], d["minute"]]
	var locale := TranslationServer.get_locale()
	if locale == "en":
		return "%02d/%02d/%04d  %s" % [d["month"], d["day"], d["year"], time]
	if is_cjk(locale):
		return "%04d/%02d/%02d  %s" % [d["year"], d["month"], d["day"], time]
	if locale.begins_with("fr") or locale.begins_with("es") or locale.begins_with("it") or locale.begins_with("pt"):
		return "%02d/%02d/%04d  %s" % [d["day"], d["month"], d["year"], time]
	return "%02d.%02d.%04d  %s" % [d["day"], d["month"], d["year"], time]


# --- Icons ------------------------------------------------------------------------------

static func icon(path: String) -> Texture2D:
	if not _icons.has(path):
		_icons[path] = load(path) as Texture2D
	return _icons[path]


## One of the UI line icons in art/icons/ui2 by name ("coin", "backpack" ...).
static func glyph(icon_name: String) -> Texture2D:
	return icon(ICON_DIR + icon_name + ".svg")


static func icon_rect(tex: Texture2D, size := 24.0, color := Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## TextureRect scaled to `size` at `pos` (older call sites).
static func make_icon(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var r := icon_rect(icon(path), size.x)
	r.custom_minimum_size = size
	r.position = pos
	r.size = size
	return r


## Small icon + text row (costs, stats).
static func icon_row(tex: Texture2D, value: String, color := TEXT, size := 20, icon_size := 26) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect(tex, icon_size))
	var l := make_label(value, heading(size, color, 700, 0))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


## Coin + amount in gold.
static func price(amount: int, size := 22, icon_size := 24, color := GOLD_SOFT) -> HBoxContainer:
	return icon_row(glyph("coin"), money(amount), color, size, icon_size)


# --- Boxes ------------------------------------------------------------------------------

static func box(bg: Color, radius := 10, border := 0, border_color := BORDER, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if pad > 0:
		sb.set_content_margin_all(pad)
	return sb


## A box with a coloured glow around it (selection, focus).
static func glow_box(bg: Color, radius: int, border_color: Color, glow: Color, glow_size := 10) -> StyleBoxFlat:
	var sb := box(bg, radius, 2, border_color)
	sb.shadow_color = glow
	sb.shadow_size = glow_size
	return sb


## Older call sites.
static func flat_box(bg: Color, radius := 8, border := 0, border_color := Color.TRANSPARENT, shadow := 0) -> StyleBoxFlat:
	var sb := box(bg, radius, border, border_color)
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_offset = Vector2(0, 3)
	return sb


static func window_style() -> StyleBoxFlat:
	var sb := box(GLASS, 14, 1, BORDER)
	sb.set_content_margin_all(24)
	return sb


## Anchors `c` to a point of its parent (0..1 on each axis) and offsets it from there.
static func place(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


# --- Components ---------------------------------------------------------------------------

## kind: "primary" (gold), "secondary" (glass), "success", "danger", "ghost".
static func button(label: String, kind := "primary", min_size := Vector2(180, 50), icon_name := "", font_size := 21) -> UiButton:
	var b := UiButton.new()
	b.setup(label, kind, min_size, icon_name, font_size)
	return b


## Older call sites: picks a kind from the colour they asked for.
static func make_button(label: String, min_size := Vector2(160, 48), color := ACCENT, font_size := 22) -> Button:
	var kind := "primary"
	if color.is_equal_approx(ACCENT):
		kind = "primary"
	elif color.g > color.r * 1.2 and color.g > color.b:
		kind = "success"
	elif color.r > color.g * 1.5:
		kind = "danger"
	else:
		kind = "secondary"
	return button(label, kind, min_size, "", font_size)


## Thin divider line.
static func separator() -> Control:
	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Small upper-case section title with a rule running to the right.
static func section(label: String, icon_name := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_name != "":
		row.add_child(icon_rect(glyph(icon_name), 18, TEXT_MUTED))
	var l := make_label(caps(label), heading(17, TEXT_MUTED, 700, 2))
	row.add_child(l)
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	return row


## Rounded pill with an optional icon: status tags, categories.
static func chip(label: String, color := TEXT_MUTED, icon_name := "", size := 16) -> PanelContainer:
	var c := PanelContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := box(Color(color.r, color.g, color.b, 0.14), 20, 1, Color(color.r, color.g, color.b, 0.35))
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	c.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(row)
	if icon_name != "":
		row.add_child(icon_rect(glyph(icon_name), size - 1, color))
	var l := make_label(caps(label), heading(size, color, 700, 1))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return c


## A keyboard key or mouse button drawn as a key cap.
static func keycap(key: String, size := 20) -> PanelContainer:
	var c := PanelContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := box(Color(0.96, 0.95, 0.9, 0.95), 6)
	sb.border_width_bottom = 3
	sb.border_color = Color(0.62, 0.6, 0.55)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	c.add_theme_stylebox_override("panel", sb)
	c.custom_minimum_size = Vector2(size + 12, size + 10)
	if key == "LMB" or key == "RMB":
		var r := icon_rect(glyph("mouse_left"), size, TEXT_DARK)
		r.flip_h = key == "RMB"
		c.add_child(r)
	else:
		var l := make_label(caps(key), heading(size, TEXT_DARK, 700, 0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
	return c


## Full-screen blurred, darkened backdrop for menus.
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Passes to the screen behind it, so items dragged out of a window can be dropped.
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ui/backdrop.gdshader")
	r.material = m
	return r


## The FARMCRAFT word mark with its tagline.
static func logo(size := 96) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word := HBoxContainer.new()
	word.add_theme_constant_override("separation", 0)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.add_child(make_label("FARM", heading(size, TEXT, 700, int(size * 0.04), true)))
	word.add_child(make_label("CRAFT", heading(size, GOLD, 700, int(size * 0.04), true)))
	box.add_child(word)
	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", 14)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rule := ColorRect.new()
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(size * 0.6, 3)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(rule)
	tag.add_child(make_label(caps(TranslationServer.translate("UI_TAGLINE")), heading(int(size * 0.22), TEXT_MUTED, 700, int(size * 0.07), true)))
	box.add_child(tag)
	return box


## Fades and scales a control in (window open).
static func appear(c: Control, seconds := 0.2) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(0.965, 0.965)
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, seconds)
	tw.tween_property(c, "scale", Vector2.ONE, seconds)


## Separator for older call sites that expect a Control with padding.
static func spacer(height := 8.0) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


static func expand() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
