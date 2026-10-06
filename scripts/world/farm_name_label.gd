class_name FarmNameLabel
extends Label3D
## The farm's name painted on something (the shipping bin's label, the pickup's door): a
## small line of capitals that follows the name as the farmer changes it on the board
## (FarmIdentity.LISTENERS), sized to fit `fit_width` metres.

## The widest the line may be (m), and its letters' size at most.
var fit_width := 0.6
var max_size := 18


func _ready() -> void:
	add_to_group(FarmIdentity.LISTENERS)
	font = UiTheme.display(700, 1)
	outline_size = 0
	shaded = true
	double_sided = false
	alpha_cut = Label3D.ALPHA_CUT_DISCARD
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	visibility_range_end = 30.0
	_write()


func farm_identity_changed(what: StringName) -> void:
	if what == &"name":
		_write()


func _write() -> void:
	var t := UiTheme.caps(FarmIdentity.farm_name())
	var size := max_size
	while size > 8 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * pixel_size > fit_width:
		size -= 1
	font_size = size
	text = t
