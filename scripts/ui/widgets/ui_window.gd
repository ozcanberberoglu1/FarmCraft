class_name UiWindow
extends GlassPanel
## Standard window: a header (icon badge, title, subtitle, widgets on the right and
## a close button) above a body. The close button emits `close_requested`.

signal close_requested

var header_right: HBoxContainer
var body: VBoxContainer
var _title: Label
var _subtitle: Label
var _badge: PanelContainer
var _badge_icon: TextureRect


func _init(title := "", icon_name := "", subtitle := "") -> void:
	super(Vector4(30, 22, 30, 28), 16.0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	_badge = PanelContainer.new()
	var sb := UiTheme.box(Color(UiTheme.GOLD, 0.15), 30, 1, Color(UiTheme.GOLD, 0.45))
	sb.set_content_margin_all(11)
	_badge.add_theme_stylebox_override("panel", sb)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_icon = UiTheme.icon_rect(null, 28, UiTheme.GOLD_SOFT)
	_badge.add_child(_badge_icon)
	header.add_child(_badge)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(titles)
	_title = UiTheme.title("", 36)
	titles.add_child(_title)
	_subtitle = UiTheme.make_label("", UiTheme.text(16, UiTheme.TEXT_MUTED, 500))
	titles.add_child(_subtitle)
	header.add_child(UiTheme.expand())
	header_right = HBoxContainer.new()
	header_right.add_theme_constant_override("separation", 12)
	header_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(header_right)
	var close := IconButton.new("close", 42)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	root.add_child(UiTheme.separator())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	set_heading(title, icon_name, subtitle)


func set_heading(title: String, icon_name := "", subtitle := "") -> void:
	_title.text = UiTheme.caps(title)
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_badge.visible = icon_name != ""
	if icon_name != "":
		_badge_icon.texture = UiTheme.glyph(icon_name)


## A money pill for the header (returns the label to update).
func add_money_pill() -> Label:
	var pill := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.25), 22, 1, Color(UiTheme.GOLD, 0.3))
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.price(Economy.money, 26)
	pill.add_child(row)
	header_right.add_child(pill)
	return row.get_child(0) as Label
