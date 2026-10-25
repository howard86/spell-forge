extends RefCounted
## Bounded gameplay remaps. UI navigation actions always retain Godot defaults.
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "cast", "dodge", "pause"]
const AIM_ACTIONS := ["aim_left", "aim_right", "aim_up", "aim_down"]
const MAX_FILE_BYTES := 16384
const MAX_OVERRIDES := 21 # One event per action and input family.
const SPECIAL_KEYS := [KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER,
	KEY_INSERT, KEY_DELETE, KEY_PAUSE, KEY_PRINT, KEY_HOME, KEY_END, KEY_LEFT, KEY_UP,
	KEY_RIGHT, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK,
	KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10,
	KEY_F11, KEY_F12, KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_PERIOD,
	KEY_KP_ADD, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6,
	KEY_KP_7, KEY_KP_8, KEY_KP_9]

var path: String = "user://bindings.cfg"
var notice: String = ""
var _overrides: Dictionary = {}

static func _append(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	_append(action, event)

static func _button(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	_append(action, event)

func install_defaults() -> void:
	# Append only: never reset an existing keyboard, mouse, or user remap.
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis("cast", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button("cast", JOY_BUTTON_RIGHT_SHOULDER)
	_button("dodge", JOY_BUTTON_A)
	_button("pause", JOY_BUTTON_START)

static func _family(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key"
	if event is InputEventMouseButton:
		return "mouse"
	if event is InputEventJoypadButton:
		return "button"
	return ""

static func validate_event(action: String, event: InputEvent) -> bool:
	if action not in ACTIONS or event == null:
		return false
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return not event.echo and code != KEY_ESCAPE and ((code >= KEY_SPACE and code <= KEY_ASCIITILDE) or code in SPECIAL_KEYS)
	if event is InputEventMouseButton:
		return event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2] and not event.double_click and not event.canceled and not (event.alt_pressed or event.shift_pressed or event.ctrl_pressed or event.meta_pressed)
	if event is InputEventJoypadButton:
		return event.button_index >= JOY_BUTTON_A and event.button_index <= JOY_BUTTON_TOUCHPAD and (event.button_index != JOY_BUTTON_START or action == "pause")
	return false

static func _encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": int(event.physical_keycode if event.physical_keycode else event.keycode),
			"physical": event.physical_keycode != 0, "alt": event.alt_pressed, "shift": event.shift_pressed,
			"ctrl": event.ctrl_pressed, "meta": event.meta_pressed}
	if event is InputEventMouseButton:
		return {"type": "mouse", "code": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"type": "button", "code": int(event.button_index)}
	return {}

static func _decode(action: String, value: Variant) -> InputEvent:
	if not value is Dictionary or not value.get("type") is String or not value.get("code") is int:
		return null
	var event: InputEvent
	if value.type == "key":
		if value.size() != 7:
			return null
		for flag in ["physical", "alt", "shift", "ctrl", "meta"]:
			if not value.get(flag) is bool:
				return null
		event = InputEventKey.new()
		if value.physical:
			event.physical_keycode = value.code
		else:
			event.keycode = value.code
		event.alt_pressed = value.alt
		event.shift_pressed = value.shift
		event.ctrl_pressed = value.ctrl
		event.meta_pressed = value.meta
	elif value.type in ["mouse", "button"] and value.size() == 2:
		if value.type == "mouse":
			event = InputEventMouseButton.new()
		else:
			event = InputEventJoypadButton.new()
			event.device = -1
		event.button_index = value.code
	else:
		return null
	return event if validate_event(action, event) else null

static func _same_binding(a: InputEvent, b: InputEvent) -> bool:
	if _family(a) != _family(b) or _family(a).is_empty():
		return false
	var left := _encode(a)
	var right := _encode(b)
	# Logical/physical spellings of the same key must not hide a conflict.
	for field in ["physical", "alt", "shift", "ctrl", "meta"]:
		left.erase(field)
		right.erase(field)
	return left == right

static func _protected(action: String, event: InputEvent) -> bool:
	return action == "pause" and ((event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START))

static func _apply(action: String, event: InputEvent) -> void:
	for old in InputMap.action_get_events(action):
		if _family(old) == _family(event) and not _protected(action, old):
			InputMap.action_erase_event(action, old)
	_append(action, event)

func rebind(action: String, event: InputEvent) -> bool:
	notice = ""
	if not validate_event(action, event):
		notice = "Mouse wheel cannot be held. Choose a key or mouse/controller button." if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] else "Unsupported binding. Escape is reserved for Back and Pause; Start is reserved for Pause."
		return false
	for other in ACTIONS:
		if other == action:
			continue
		for old in InputMap.action_get_events(other):
			if _same_binding(old, event):
				notice = "Binding already used by %s. Choose a different input." % other.replace("_", " ")
				return false
	var normalized := _decode(action, _encode(event))
	_apply(action, normalized)
	_overrides[action + "/" + _family(event)] = _encode(normalized)
	return true

func reset_defaults() -> void:
	for action in ACTIONS + AIM_ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		if ProjectSettings.has_setting("input/" + action):
			var configured: Dictionary = ProjectSettings.get_setting("input/" + action)
			InputMap.add_action(action, float(configured.get("deadzone", 0.2)))
			for event in configured.get("events", []):
				InputMap.action_add_event(action, event.duplicate())
	_overrides.clear()
	install_defaults()
	notice = "Bindings reset. Save to keep these defaults."

func _valid_path() -> bool:
	return not path.is_empty() and path.length() <= 1024 and not path.contains("..") and (path.begins_with("user://") or path.is_absolute_path())

func save_bindings() -> bool:
	notice = ""
	if not _valid_path():
		notice = "Invalid bindings file path."
		return false
	var config := ConfigFile.new()
	config.set_value("bindings", "version", 1)
	config.set_value("bindings", "overrides", _overrides.duplicate(true))
	var result := config.save(path)
	if result != OK:
		notice = "Could not save bindings (%s)." % error_string(result)
	return result == OK

func load_bindings() -> bool:
	notice = ""
	if not _valid_path():
		notice = "Invalid bindings file path."
		return false
	if not FileAccess.file_exists(path):
		install_defaults()
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		notice = "Bindings file is unreadable or too large."
		return false
	var source := file.get_as_text()
	file.close()
	# ConfigFile supports Variant syntax; object construction is never accepted.
	var object_pattern := RegEx.new()
	object_pattern.compile("\\b(Object|Resource)\\s*\\(")
	if object_pattern.search(source) != null:
		notice = "Bindings must contain primitive values only."
		return false
	var config := ConfigFile.new()
	if config.parse(source) != OK or config.get_sections() != PackedStringArray(["bindings"]) or config.get_section_keys("bindings").size() != 2 or not config.get_value("bindings", "version") is int or config.get_value("bindings", "version") != 1:
		notice = "Unsupported or malformed bindings file."
		return false
	var entries: Variant = config.get_value("bindings", "overrides")
	if not entries is Dictionary or entries.size() > MAX_OVERRIDES:
		notice = "Invalid bindings entries."
		return false
	var pending: Dictionary = {}
	for id in entries:
		if not id is String or id.get_slice_count("/") != 2:
			notice = "Unknown bindings entry."
			return false
		var action: String = id.get_slice("/", 0)
		var event := _decode(action, entries[id])
		if event == null or id.get_slice("/", 1) != _family(event):
			notice = "Unsupported bindings entry: %s." % id
			return false
		pending[id] = event
	# Validate the final map transactionally: no partial load on a conflict.
	var snapshot := _snapshot()
	var previous_overrides := _overrides.duplicate(true)
	reset_defaults()
	for id in pending:
		_apply(id.get_slice("/", 0), pending[id])
	for i in ACTIONS.size():
		for j in range(i + 1, ACTIONS.size()):
			for a in InputMap.action_get_events(ACTIONS[i]):
				for b in InputMap.action_get_events(ACTIONS[j]):
					if _same_binding(a, b):
						_restore(snapshot)
						_overrides = previous_overrides
						notice = "Conflicting bindings; no changes loaded."
						return false
	_overrides = entries.duplicate(true)
	notice = ""
	return true

static func _snapshot() -> Dictionary:
	var result: Dictionary = {}
	for action in ACTIONS + AIM_ACTIONS:
		if InputMap.has_action(action):
			result[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action)}
	return result

static func _restore(snapshot: Dictionary) -> void:
	for action in ACTIONS + AIM_ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		if snapshot.has(action):
			InputMap.add_action(action, snapshot[action].deadzone)
			for event in snapshot[action].events:
				InputMap.action_add_event(action, event)

static func action_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "Unbound"
	var labels := PackedStringArray()
	for event in InputMap.action_get_events(action):
		labels.append(event.as_text())
	return " / ".join(labels) if not labels.is_empty() else "Unbound"

static func controller_aim() -> Vector2:
	for action in AIM_ACTIONS:
		if not InputMap.has_action(action):
			return Vector2.ZERO
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.2)
