class_name GlassPanel
extends PanelContainer
## Frosted glass container (shaders/ui/glass.gdshader): blurred world behind a dark
## tint, hairline border, soft drop shadow. Children are laid out with `padding`.

const MARGIN := 28.0

static var _shader: Shader
static var _white: Texture2D

var radius := 14.0
var tint := UiTheme.GLASS
var border := UiTheme.BORDER
var accent := Color(UiTheme.GOLD, 0.0)
var shadow := 0.55
var padding := Vector4(24, 20, 24, 22)

var _mat: ShaderMaterial


func _init(p_padding := Vector4(24, 20, 24, 22), p_radius := 14.0) -> void:
	padding = p_padding
	radius = p_radius
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = padding.x
	sb.content_margin_top = padding.y
	sb.content_margin_right = padding.z
	sb.content_margin_bottom = padding.w
	add_theme_stylebox_override("panel", sb)
	if _shader == null:
		_shader = load("res://shaders/ui/glass.gdshader")
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	material = _mat
	resized.connect(_sync)
	_sync()


## Changes the look after creation (e.g. highlight a card).
func set_look(p_tint: Color, p_border: Color, p_accent := Color(0, 0, 0, 0)) -> void:
	tint = p_tint
	border = p_border
	accent = p_accent
	_sync()


func _sync() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("rect_size", size + Vector2(MARGIN, MARGIN) * 2.0)
	_mat.set_shader_parameter("margin", MARGIN)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("border", border)
	_mat.set_shader_parameter("accent", accent)
	_mat.set_shader_parameter("shadow", shadow)
	queue_redraw()


func _draw() -> void:
	if _white:
		draw_texture_rect(_white, Rect2(-Vector2(MARGIN, MARGIN), size + Vector2(MARGIN, MARGIN) * 2.0), false)
