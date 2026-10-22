extends SceneTree
## Synthetic device input through the actual scene; not a human playtest.
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)
func key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    root.size = Vector2i(960, 540)
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    scene.settings_path = "user://controls-test-unused.cfg"
    for child in scene.content.get_children():
        if child is Button and child.text == "Credits":
            child.pressed.emit()
            break
    check(scene.state == "credits", "credits menu opens")
    var found_license := false
    for child in scene.content.get_children():
        if child is TextEdit:
            found_license = not child.editable and child.text.contains(Engine.get_license_text()) and child.text.contains("THIRD-PARTY ATTRIBUTIONS")
    check(found_license, "credits include read-only engine license and attribution")
    for child in scene.content.get_children():
        if child is Button and child.text == "Back":
            child.pressed.emit()
            break
    check(scene.state == "menu", "credits back returns to menu")
    # Start via the actual menu button's UI signal.
    for child in scene.content.get_children():
        if child is Button and child.text == "Begin run":
            child.pressed.emit()
            break
    await physics_frame
    check(scene.state == "combat", "menu starts real scene")
    var start: Vector2 = scene.player_pos
    key(KEY_D, true)
    await create_timer(0.08).timeout
    key(KEY_D, false)
    check(scene.player_pos.x > start.x + 5, "D input moves player")
    var mouse := InputEventMouseMotion.new()
    mouse.position = scene.player_pos + Vector2(150, 0)
    mouse.global_position = mouse.position
    root.push_input(mouse, true)
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.position = mouse.position
    click.pressed = true
    Input.parse_input_event(click)
    await create_timer(0.04).timeout
    click.pressed = false
    Input.parse_input_event(click)
    check(scene.cast_id > 0 and scene.mana < 100, "mouse input casts")
    check(scene.aim.x > 0.9, "mouse input aims right")
    key(KEY_SPACE, true)
    await physics_frame
    key(KEY_SPACE, false)
    check(scene.dodge_time > 0 and scene.dodge_cooldown > 0, "space input dodges")
    key(KEY_ESCAPE, true)
    await physics_frame
    key(KEY_ESCAPE, false)
    check(scene.state == "paused", "Escape input pauses")
    var pause_time: float = scene.elapsed
    await create_timer(0.05).timeout
    check(scene.elapsed == pause_time, "paused physics does not advance combat")
    key(KEY_ESCAPE, true)
    await physics_frame
    key(KEY_ESCAPE, false)
    check(scene.state == "combat", "Escape input resumes")
    scene.hp = 12
    scene.hurt_time = 0
    scene.dodge_time = 0
    scene.add_projectile(scene.player_pos - Vector2(20, 0), Vector2.RIGHT, true)
    await create_timer(0.08).timeout
    check(scene.state == "death", "hostile projectile causes real death")
    for child in scene.content.get_children():
        if child is Button and child.text == "Retry this seed":
            child.pressed.emit()
            break
    check(scene.state == "combat" and scene.hp == 100 and scene.encounter_index == 0, "retry UI resets run")
    scene.queue_free()
    await create_timer(0.2).timeout
    print("Controls integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
