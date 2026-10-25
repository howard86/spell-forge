extends SceneTree
## Isolated InputMap tests; never reads or writes the player's settings.
const Bindings = preload("res://scripts/input_bindings.gd")
const Navigation = preload("res://scripts/menu_navigation.gd")
var fixture_path := "user://bindings-test-%d.cfg" % Time.get_ticks_usec()
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func button(code: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	return event

func write_config(entries: Variant, version: Variant = 1) -> void:
	var config := ConfigFile.new()
	config.set_value("bindings", "version", version)
	config.set_value("bindings", "overrides", entries)
	config.save(fixture_path)

func test_bindings() -> void:
	var original := Bindings._snapshot()
	var helper := Bindings.new()
	helper.path = fixture_path
	if FileAccess.file_exists(fixture_path):
		DirAccess.remove_absolute(fixture_path)
	check(helper.load_bindings(), "Missing isolated config installs controller defaults")
	for action in Bindings.ACTIONS + Bindings.AIM_ACTIONS:
		check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Defaults exist: " + action)
	var installed := Bindings._snapshot()
	helper.install_defaults()
	check(Bindings._snapshot() == installed, "Installing defaults is idempotent")
	for action in original:
		for event in original[action].events:
			check(InputMap.action_has_event(action, event), "Existing keyboard/mouse default preserved")
	var movement_axis := InputEventJoypadMotion.new()
	movement_axis.axis = JOY_AXIS_LEFT_X
	movement_axis.axis_value = -1
	check(InputMap.event_is_action(movement_axis, "move_left"), "Synthetic left stick mapping")
	var aim_axis := InputEventJoypadMotion.new()
	aim_axis.axis = JOY_AXIS_RIGHT_Y
	aim_axis.axis_value = 1
	check(InputMap.event_is_action(aim_axis, "aim_down"), "Synthetic right stick mapping")
	var aim_right := InputEventJoypadMotion.new()
	aim_right.axis = JOY_AXIS_RIGHT_X
	aim_right.axis_value = 0.8
	Input.parse_input_event(aim_right)
	Input.flush_buffered_events()
	check(Bindings.controller_aim().x > 0.5, "Synthetic right-stick aim reaches helper")
	var aim_release := aim_right.duplicate()
	aim_release.axis_value = 0.0
	Input.parse_input_event(aim_release)
	Input.flush_buffered_events()
	check(Bindings.controller_aim() == Vector2.ZERO, "Released aim returns neutral")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1
	check(InputMap.event_is_action(trigger, "cast") and InputMap.event_is_action(button(JOY_BUTTON_RIGHT_SHOULDER), "cast"), "Trigger and shoulder cast defaults")
	check(InputMap.event_is_action(button(JOY_BUTTON_A), "dodge") and InputMap.event_is_action(button(JOY_BUTTON_START), "pause"), "Face dodge and Start pause defaults")
	check(helper.rebind("move_left", key(KEY_J)), "Keyboard remap accepted")
	check(not InputMap.action_has_event("move_left", key(KEY_A)) and InputMap.action_has_event("move_left", key(KEY_J)), "Keyboard family replaced")
	check(InputMap.event_is_action(movement_axis, "move_left"), "Remap preserves controller movement")
	check(not helper.rebind("move_right", key(KEY_J)) and helper.notice.contains("move left"), "Conflict rejected with clear notice")
	var modified := key(KEY_J)
	modified.ctrl_pressed = true
	check(not helper.rebind("cast", modified), "Modified key conflicts rejected because gameplay ignores extra modifiers")
	check(not helper.rebind("move_left", key(KEY_ESCAPE)), "Escape remains reserved")
	check(not helper.rebind("cast", button(JOY_BUTTON_START)), "Start cannot be stolen from pause")
	check(helper.rebind("pause", key(KEY_P)), "Pause alternate accepted")
	var escape := key(KEY_ESCAPE)
	escape.keycode = KEY_ESCAPE
	check(InputMap.event_is_action(escape, "pause") and InputMap.event_is_action(button(JOY_BUTTON_START), "pause"), "Pause retains Escape and Start")
	check(helper.rebind("dodge", button(JOY_BUTTON_X)), "Controller button remap accepted")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	check(helper.rebind("cast", mouse), "Mouse remap accepted")
	check(helper.save_bindings(), "Save isolated primitive configuration")
	var stored := FileAccess.get_file_as_string(fixture_path)
	check(not stored.contains("Object(") and stored.contains("overrides"), "Persistence contains primitives")
	var expected := Bindings._snapshot()
	helper.reset_defaults()
	check(InputMap.action_has_event("move_left", key(KEY_A)) and not InputMap.action_has_event("move_left", key(KEY_J)), "Reset restores exact project keyboard defaults")
	var restored := Bindings.new()
	restored.path = fixture_path
	check(restored.load_bindings(), "Load bindings round trip")
	# Resource identity differs after decode, so compare labels for stable primitive meaning.
	for action in expected:
		var labels := PackedStringArray()
		for event in expected[action].events:
			labels.append(event.as_text())
		check(Bindings.action_label(action) == " / ".join(labels), "Round-trip action " + action)
	var before_invalid := Bindings._snapshot()
	for value in [
		{"unknown/key": {"type": "key", "code": KEY_J}},
		{"cast/button": {"type": "button", "code": 9999}},
		{"cast/button": {"type": "button", "code": -1}},
		{"cast/button": {"type": "button", "code": 2.5}},
		{"cast/button": {"type": "axis", "code": 2}},
		{"cast/button": {"type": "button", "code": 2, "extra": true}},
		{"cast/key": {"type": "key", "code": 999999999, "physical": true, "alt": false, "shift": false, "ctrl": false, "meta": false}},
		[],
	]:
		write_config(value)
		check(not restored.load_bindings() and Bindings._snapshot() == before_invalid, "Malformed config fails without InputMap mutation")
	var conflict: Dictionary = {"move_left/key": Bindings._encode(key(KEY_D))}
	write_config(conflict)
	check(not restored.load_bindings() and Bindings._snapshot() == before_invalid, "Loaded cross-action conflict rolls back entire InputMap")
	write_config({}, 2)
	check(not restored.load_bindings(), "Unknown schema fails closed")
	write_config({}, 1.0)
	check(not restored.load_bindings(), "Non-integer schema rejected")
	var invalid_source := FileAccess.open(fixture_path, FileAccess.WRITE)
	invalid_source.store_string("[bindings]\nversion=1\noverrides=Object (RefCounted)\n")
	invalid_source.close()
	check(not restored.load_bindings() and Bindings._snapshot() == before_invalid, "Object syntax rejected before parsing")
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string("x".repeat(Bindings.MAX_FILE_BYTES + 1))
	file.close()
	check(not restored.load_bindings(), "Oversized file rejected")
	for action in ["unknown", "ui_cancel", "aim_left"]:
		check(not Bindings.validate_event(action, key(KEY_J)), "Only gameplay actions may be rebound")
	var echo := key(KEY_J)
	echo.echo = true
	check(not Bindings.validate_event("cast", echo), "Echo rejected")
	check(not Bindings.validate_event("cast", movement_axis) and not Bindings.validate_event("cast", InputEventMouseMotion.new()), "Unsupported motion captures rejected")
	check(Bindings.action_label("unknown") == "Unbound", "Missing action label safe")
	helper.path = fixture_path + "/missing-parent/bindings.cfg"
	check(not helper.save_bindings() and not helper.notice.is_empty(), "Save failure reported")
	Bindings._restore(original)
	check(Bindings._snapshot() == original, "All tested actions and deadzones restored exactly")
	DirAccess.remove_absolute(fixture_path)

func test_navigation() -> void:
	var detached := Control.new()
	Navigation.focus_first(detached)
	Navigation.ensure_focus(detached)
	Navigation.connect_focus_neighbors(detached)
	detached.free()
	var menu := VBoxContainer.new()
	root.add_child(menu)
	var first := Button.new()
	first.text = "First"
	menu.add_child(first)
	var hidden := Button.new()
	menu.add_child(hidden)
	hidden.hide()
	var disabled := Button.new()
	disabled.disabled = true
	menu.add_child(disabled)
	var holder := VBoxContainer.new()
	menu.add_child(holder)
	var nested_hidden := Button.new()
	holder.add_child(nested_hidden)
	holder.hide()
	var last := LineEdit.new()
	menu.add_child(last)
	Navigation.connect_focus_neighbors(menu)
	Navigation.connect_focus_neighbors(menu)
	Navigation.focus_first(menu)
	check(root.gui_get_focus_owner() == first, "Initial focus selects first visible enabled control")
	check(first.get_node(first.focus_next) == last and last.get_node(last.focus_next) == first, "Focus wraps and skips hidden/disabled descendants")
	check(first.get_node(first.focus_neighbor_bottom) == last, "Arrow focus path deterministic")
	last.grab_focus()
	Navigation.ensure_focus(menu)
	check(root.gui_get_focus_owner() == last, "Valid editor focus retained")
	last.text = "abc"
	last.caret_column = 0
	var right := key(KEY_RIGHT)
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right, true)
	check(last.caret_column == 1 and root.gui_get_focus_owner() == last, "Text editing consumes arrow without stealing focus")
	last.hide()
	Navigation.ensure_focus(menu)
	check(root.gui_get_focus_owner() == first, "Lost or hidden focus repaired")
	first.disabled = true
	Navigation.ensure_focus(menu)
	check(root.gui_get_focus_owner() == null, "Invalid focus released when no eligible controls remain")
	menu.free()
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(160, 80)
	root.add_child(scroll)
	var items := VBoxContainer.new()
	scroll.add_child(items)
	var final_button: Button
	for i in 8:
		final_button = Button.new()
		final_button.custom_minimum_size = Vector2(100, 40)
		items.add_child(final_button)
	await process_frame
	await process_frame
	Navigation.connect_focus_neighbors(scroll)
	final_button.grab_focus()
	check(scroll.scroll_vertical > 0, "Focus automatically reveals control inside scroll container")
	scroll.free()
	check(true, "Detached and freed menu lifecycle needs no deferred callbacks")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(fixture_path.get_base_dir())
	test_bindings()
	await test_navigation()
	print("Bindings/navigation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
