class_name Mailbox
extends PlacedObject
## The mailbox by the house (PlaceableTable "mailbox": made at the workbench): letters
## from the town arrive in it (Mail). Its little red flag stands up while a letter waits
## unread; E opens the letter screen (the new letters first, the read ones in a list).

const GROUP := &"mailboxes"
## Seconds the flag takes to swing up or down.
const FLAG_TIME := 0.5

var _flag: Node3D
var _up := false


func _setup() -> void:
	add_to_group(GROUP)
	var pivot := PlaceableModels.MAILBOX_FLAG_PIVOT
	_flag = Node3D.new()
	_flag.name = "Flag"
	_flag.position = pivot
	add_child(_flag)
	var mi := MeshInstance3D.new()
	mi.mesh = PlaceableModels.mesh(item_id, "moving")
	mi.position = -pivot
	_flag.add_child(mi)
	Mail.letters_changed.connect(_sync_flag)
	_sync_flag.call_deferred(true)


## The flag up while a letter waits unread (swung, or set at once when `instant`).
func _sync_flag(instant := false) -> void:
	if not is_inside_tree():
		return
	var up := Mail.unread_count() > 0
	if up == _up and not instant:
		return
	_up = up
	var angle := -PI * 0.5 if up else 0.0
	if instant:
		_flag.rotation.x = angle
		return
	var tw := create_tween()
	tw.tween_property(_flag, "rotation:x", angle, FLAG_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Whether the flag stands up (tests).
func flag_up() -> bool:
	return _up


func interact_title() -> String:
	return display_name()


func interact_prompt(_player: Node) -> String:
	var n := Mail.unread_count()
	if n > 0:
		return tr("ACTION_READ_MAIL") % n
	return tr("ACTION_CHECK_MAIL")


func interact(_player: Node) -> void:
	Audio.play("plank", global_position + Vector3(0, 1.1, 0), -12.0)
	Mail.open_mailbox(self)
