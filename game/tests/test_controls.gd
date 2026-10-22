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
func wait_physics_frames(count: int) -> void:
    # physics_frame fires before node callbacks. The final process_frame lets
    # the last requested physics tick finish before assertions inspect state.
    for frame in count:
        await physics_frame
    await process_frame

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
    await wait_physics_frames(1)
    check(scene.state == "combat", "menu starts real scene")
    var start: Vector2 = scene.player_pos
    var movement_start_time: float = scene.elapsed
    key(KEY_D, true)
    var movement_key_pressed := Input.is_key_pressed(KEY_D)
    await wait_physics_frames(4)
    key(KEY_D, false)
    check(scene.player_pos.x > start.x + 5,
        "D input moves player (start=%s end=%s simulated_seconds=%.4f key_pressed=%s state=%s)" %
        [start, scene.player_pos, scene.elapsed - movement_start_time, movement_key_pressed, scene.state])
    var mouse := InputEventMouseMotion.new()
    mouse.position = scene.player_pos + Vector2(150, 0)
    mouse.global_position = mouse.position
    root.push_input(mouse, true)
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.position = mouse.position
    click.pressed = true
    Input.parse_input_event(click)
    await wait_physics_frames(2)
    click.pressed = false
    Input.parse_input_event(click)
    check(scene.cast_id > 0 and scene.mana < 100, "mouse input casts")
    check(scene.aim.x > 0.9, "mouse input aims right")
    key(KEY_SPACE, true)
    await wait_physics_frames(1)
    key(KEY_SPACE, false)
    check(scene.dodge_time > 0 and scene.dodge_cooldown > 0, "space input dodges")
    key(KEY_ESCAPE, true)
    await wait_physics_frames(1)
    key(KEY_ESCAPE, false)
    check(scene.state == "paused", "Escape input pauses")
    var pause_time: float = scene.elapsed
    await wait_physics_frames(3)
    check(scene.elapsed == pause_time, "paused physics does not advance combat")
    key(KEY_ESCAPE, true)
    await wait_physics_frames(1)
    key(KEY_ESCAPE, false)
    check(scene.state == "combat", "Escape input resumes")
    scene.hp = 12
    scene.hurt_time = 0
    scene.dodge_time = 0
    scene.add_projectile(scene.player_pos - Vector2(20, 0), Vector2.RIGHT, true)
    await wait_physics_frames(4)
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
