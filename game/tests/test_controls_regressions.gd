extends SceneTree
## Review regressions through real game controls and synthetic device events.
const Game = preload("res://scripts/game.gd")
const Bindings = preload("res://scripts/input_bindings.gd")
const Entry = preload("res://scripts/text_entry.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func settle() -> void:
    for i in 8:
        await process_frame
func forge_button(game: Node, component: String, action: String) -> Button:
    var controls: Array[Control] = []
    game.Navigation._collect(game.content, controls)
    for control in controls:
        var identity: Dictionary = control.get_meta("forge_focus", {})
        if identity.get("component") == component and identity.get("action") == action:
            return control
    return null
func check_forge_fonts(node: Node) -> void:
    if node is Button and node.has_meta("forge_focus"):
        check(node.get_theme_font_size("font_size") >= 19, "large forge scales enabled and disabled slot/action/owned text")
    for child in node.get_children():
        check_forge_fonts(child)
func preview_bounds(preview: Control, description: String) -> void:
    check(preview.large_text and preview.custom_minimum_size.y >= 150, description + " reserves large preview height")
    check(preview.report_label.get_theme_font_size("font_size") >= 19 and preview.picker.get_theme_font_size("font_size") >= 19, description + " scales measurements and scenario picker")
    check(preview.report_label.position.y + preview.report_label.size.y < 115 and preview.report_label.get_minimum_size().y <= preview.report_label.size.y, description + " wrapped report fits above animation")
    check(preview.point(Vector2(480, 300)).y + 20 <= preview.size.y, description + " animation fits below report")
func pad(code: JoyButton) -> void:
    for down in [true, false]:
        var event := InputEventJoypadButton.new()
        event.button_index = code
        event.pressed = down
        root.push_input(event, true)
func dodge_distance(game: Node, strength: float, moving: bool) -> float:
    for action in ["aim_right", "move_right"]:
        Input.action_release(action)
    game.dodge_time = 0
    game.dodge_cooldown = 0
    game.player_pos = Vector2(400, 300)
    Input.action_press("move_right" if moving else "aim_right", strength)
    game.simulate(0.01)
    if not moving:
        check(is_equal_approx(game.aim.length(), 1), "partial/full stick aim is a unit direction")
        Input.action_release("aim_right")
        game.simulate(0.01)
        check(is_equal_approx(game.aim.length(), 1), "released aim retains unit direction")
    else:
        check(game.movement_direction().length() < 1 if strength < 1 else is_equal_approx(game.movement_direction().length(), 1), "movement retains analog strength")
    var start: Vector2 = game.player_pos
    var event := InputEventAction.new()
    event.action = "dodge"
    event.pressed = true
    game._unhandled_input(event)
    check(is_equal_approx(game.dodge_direction.length(), 1), "dodge direction normalized")
    for i in 10:
        game.simulate(0.01)
    Input.action_release("move_right")
    check(game.dodge_cooldown > 0, "dodge consumes cooldown")
    return start.distance_to(game.player_pos)
func run() -> void:
    root.size = Vector2i(960, 540)
    var original := Bindings._snapshot()
    var game := Game.new()
    game.settings_path = "user://controls-regression-%d.cfg" % Time.get_ticks_usec()
    game.profile_enabled = false
    root.add_child(game)
    game.set_physics_process(false)
    game.start_run(4242)
    game.obstacles = []
    game.enemies.clear()
    game.pending_spawns = [{"remaining": 99999.0, "duration": 99999.0, "kind": "runner", "position": Vector2(800, 400)}]
    game.suppress_combat = false
    var aimed_partial := dodge_distance(game, 0.5, false)
    var aimed_full := dodge_distance(game, 1, false)
    var moving_partial := dodge_distance(game, 0.5, true)
    var moving_full := dodge_distance(game, 1, true)
    check(is_equal_approx(aimed_partial, aimed_full) and is_equal_approx(aimed_partial, 65), "stationary partial/released/full aim dodges travel equally")
    check(is_equal_approx(moving_partial, moving_full) and is_equal_approx(moving_partial, 65), "partial/full movement dodges travel equally")
    game.state = "reward"
    game.selected_reward = true
    game.owned = ["projectile", "fire", "pierce", "split", "frost"]
    game.components = game.owned.duplicate()
    game.draft = game.components.duplicate()
    game.show_reward()
    await settle()
    var move := forge_button(game, "frost", "left")
    move.grab_focus()
    move.pressed.emit()
    await settle()
    check(root.gui_get_focus_owner() == forge_button(game, "frost", "left") and game.draft[3] == "frost", "reorder focus follows Frost rather than first matching arrow")
    root.gui_get_focus_owner().pressed.emit()
    await settle()
    check(game.draft[2] == "frost" and root.gui_get_focus_owner() == forge_button(game, "frost", "left"), "repeated reorder edits same component")
    root.gui_get_focus_owner().pressed.emit()
    await settle()
    check(game.draft[1] == "frost" and root.gui_get_focus_owner() == forge_button(game, "frost", "inspect"), "boundary reorder falls back to same component inspection")
    var remove := forge_button(game, "pierce", "remove")
    remove.grab_focus()
    remove.pressed.emit()
    await settle()
    check(not game.draft.has("pierce") and root.gui_get_focus_owner() == forge_button(game, "split", "remove"), "removal focuses adjacent component's Remove")
    root.gui_get_focus_owner().pressed.emit()
    await settle()
    check(not game.draft.has("split") and root.gui_get_focus_owner() == forge_button(game, "fire", "remove"), "last-slot removal falls back to preceding component")
    var modified := InputEventKey.new()
    modified.physical_keycode = KEY_K
    modified.ctrl_pressed = true
    modified.alt_pressed = true
    modified.shift_pressed = true
    modified.meta_pressed = true
    check(game.bindings.rebind("dodge", modified), "modified keyboard binding accepted")
    game.controller_device = false
    var hint: String = game.control_hint("dodge")
    check(hint == OS.get_keycode_string(modified.get_physical_keycode_with_modifiers()) and hint != "K", "HUD hint includes every required key modifier")
    var wheel := InputEventMouseButton.new()
    for code in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
        wheel.button_index = code
        check(not game.bindings.rebind("cast", wheel) and game.bindings.notice.contains("cannot be held"), "transient wheel binding rejected with clear notice")
        check(Bindings._decode("cast", {"type": "mouse", "code": code}) == null, "persisted wheel binding rejected")
    for mode in ["seed", "recipe", "share"]:
        var entry := Entry.new()
        entry.setup("", mode)
        root.add_child(entry)
        await settle()
        var keys: Array = entry.keys.get_children()
        keys[0].grab_focus()
        pad(JOY_BUTTON_DPAD_DOWN)
        check(root.gui_get_focus_owner() == keys[12], mode + " Down moves one visual row from Done")
        keys[0].grab_focus()
        pad(JOY_BUTTON_DPAD_RIGHT)
        check(root.gui_get_focus_owner() == keys[1], mode + " Right moves one column from Done")
        keys[13].grab_focus()
        pad(JOY_BUTTON_DPAD_UP)
        check(root.gui_get_focus_owner() == keys[1], mode + " middle-column Up retains column")
        check(keys[11].get_node(keys[11].focus_next) == keys[12] and keys[12].get_node(keys[12].focus_previous) == keys[11], mode + " Tab keeps sequential row traversal")
        keys[-1].grab_focus()
        pad(JOY_BUTTON_DPAD_DOWN)
        check(root.gui_get_focus_owner() == keys[-1], mode + " incomplete final row stays on a valid key")
        entry.free()
    game.settings.large_text = true
    game.owned = ["projectile", "fire", "pierce", "split", "frost", "bounce", "wall_charge", "explode", "delayed_blast", "chain", "cooldown"]
    game.components = ["projectile", "bounce", "wall_charge", "explode", "delayed_blast"]
    game.draft = game.components.duplicate()
    game.show_reward()
    await settle()
    check(game.panel.get_global_rect().end.x <= 960 and game.panel.get_global_rect().end.y <= 540, "large forge panel fits viewport")
    check(game.content.size.x <= game.menu_scroll.size.x, "large forge has no horizontal overflow")
    check_forge_fonts(game.content)
    var controls: Array[Control] = []
    game.Navigation._collect(game.content, controls)
    for control in controls:
        control.grab_focus()
        await settle()
        var rect := control.get_global_rect()
        var visible := rect.intersection(game.menu_scroll.get_global_rect())
        check(rect.size.is_equal_approx(visible.size), "large forge focused control fully visible: " + str(control.name))
    var preview = game.content.get_node("SpellPreview")
    preview_bounds(preview, "forge")
    game.journey.inspect_reward("fire")
    await settle()
    var inspection_preview: Control
    for child in game.content.get_children():
        if child.get_script() == preload("res://scripts/spell_preview.gd"):
            inspection_preview = child
    check(inspection_preview != null, "reward inspection exposes shared preview")
    if inspection_preview != null:
        preview_bounds(inspection_preview, "reward inspection")
    game.journey.show_practice()
    var lab = load("res://scripts/spell_lab.gd").new()
    lab.open(game)
    await settle()
    preview_bounds(lab.preview, "spell lab")
    lab.close()
    await settle()
    Bindings._restore(original)
    await game.audio.shutdown()
    game.queue_free()
    await settle()
    print("Controls review regressions: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
