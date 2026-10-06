class_name InputSetup
extends RefCounted
## Registers all gameplay input actions at startup (physical key positions, so WASD
## works on any keyboard layout).


static func register_actions() -> void:
	_key(&"move_forward", KEY_W)
	_key(&"move_back", KEY_S)
	_key(&"move_left", KEY_A)
	_key(&"move_right", KEY_D)
	_key(&"sprint", KEY_SHIFT)
	_key(&"jump", KEY_SPACE)
	_key(&"interact", KEY_E)
	_key(&"animal_info", KEY_F)
	_key(&"inventory", KEY_TAB)
	_key(&"inventory", KEY_I)
	_key(&"drop", KEY_Q)
	_key(&"rotate", KEY_R)
	_key(&"pause", KEY_ESCAPE)
	_key(&"debug_overlay", KEY_F3)
	_key(&"screenshot", KEY_F12)
	# Test shortcuts (TestKeys, while Settings.test_shortcuts is on).
	_key(&"test_time_fast", KEY_F6)
	_key(&"test_skip_night", KEY_F7)
	_key(&"test_plus_hour", KEY_F8)
	_key(&"vehicle_camera", KEY_V)
	_key(&"vehicle_lights", KEY_L)
	# The car radio (CarRadio): on and off, the next station.
	_key(&"radio_toggle", KEY_R)
	_key(&"radio_next", KEY_T)
	# Whistling for the farmer's own dog (Pet).
	_key(&"whistle", KEY_H)
	# Taking hold of an animal: a bird into the arms, a halter on a big one (AnimalHandler).
	_key(&"handle", KEY_G)
	_mouse(&"use", MOUSE_BUTTON_LEFT)
	_mouse(&"secondary", MOUSE_BUTTON_RIGHT)
	_mouse(&"hotbar_prev", MOUSE_BUTTON_WHEEL_UP)
	_mouse(&"hotbar_next", MOUSE_BUTTON_WHEEL_DOWN)
	for i in 8:
		_key(StringName("hotbar_%d" % (i + 1)), (KEY_1 + i) as Key)


static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _key(action: StringName, keycode: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


static func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
