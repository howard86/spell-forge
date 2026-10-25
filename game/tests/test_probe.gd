extends SceneTree
## Isolated regressions for probe input and live cast/hazard bounds.
const Probe = preload("res://scripts/runtime_probe.gd")
const Bindings = preload("res://scripts/input_bindings.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)

func snapshot_input() -> Dictionary:
    var snapshot := {}
    for action in InputMap.get_actions():
        snapshot[action] = {"events": InputMap.action_get_events(action),
            "deadzone": InputMap.action_get_deadzone(action)}
    return snapshot

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.settings_path = "user://runtime-probe-regression-%d.cfg" % Time.get_ticks_usec()
    game.profile_enabled = false
    root.add_child(game)
    game.set_physics_process(false)
    game.set_process_input(false)
    game.set_process_unhandled_input(false)
    game.start_run(42)
    for invalid in [game.Spell.compile([]), {}]:
        game.compiled = invalid
        game.mana = 100
        game.cooldown = 0
        var before: Array = [game.mana, game.cooldown, game.cast_id, game.casts.duplicate(true), game.projectiles.duplicate(true)]
        check(not game.cast_spell(), "invalid compilation denies a live cast")
        check(before == [game.mana, game.cooldown, game.cast_id, game.casts, game.projectiles], "invalid cast preserves resources, IDs, casts and projectiles")
    check(game.report.snapshot().cast_denials.invalid == 1, "invalid cast is reported with normal denial throttling")
    game.compiled = game.Spell.compile(["projectile"])
    check(game.cast_spell() and game.cast_id == 1 and game.projectiles.size() == 1 and game.mana == 92, "valid compilation still spends and creates one live cast")

    game.hazards.clear()
    for index in 63:
        game.hazards.append({"position": Vector2(300, 300), "radius": 38.0, "progress": 0.0, "life": 1.2, "source": "hazard"})
    var mark := {"attack_kind": "mark", "attack_target": Vector2(320, 320)}
    game.enemy_attack(mark)
    check(game.hazards.size() == 64 and game.hazards.back().position == mark.attack_target and game.hazards.back().life == 1.2, "channeler mark fills the last slot with its authored target and lifetime")
    var full: Array = game.hazards.duplicate(true)
    game.enemy_attack(mark)
    game.queue_archive_marks([Vector2(350, 350)])
    check(game.hazards == full, "channeler and Archivist both preserve the shared full hazard cap")

    var original := snapshot_input()
    var probe := Probe.new()
    for action in ["aim_right", "move_left", "cast", "dodge"]:
        Input.action_press(action)
    probe._isolate_input()
    var empty := true
    var released := true
    for action in InputMap.get_actions():
        empty = empty and InputMap.action_get_events(action).is_empty()
        released = released and not Input.is_action_pressed(action)
    check(empty and released, "probe removes physical event mappings and preexisting held actions")
    var key := InputEventKey.new()
    key.physical_keycode = KEY_D
    key.pressed = true
    var stick := InputEventJoypadMotion.new()
    stick.axis = JOY_AXIS_RIGHT_X
    stick.axis_value = 1.0
    Input.parse_input_event(key.duplicate())
    Input.parse_input_event(stick.duplicate())
    Input.flush_buffered_events()
    check(not Input.is_action_pressed("move_right") and Bindings.controller_aim() == Vector2.ZERO, "live keyboard and stick events cannot drive isolated actions")
    game.start_run(42)
    probe._drive(game, 0)
    var expected: Vector2 = game.aim
    game.simulate(0)
    check(Input.is_action_pressed("move_up") and game.movement_direction() == Vector2.UP, "scripted action_press still drives the deterministic patrol")
    check(game.aim.is_equal_approx(expected), "simulate preserves probe aim despite synthetic physical stick input")
    probe._release_input()
    check(game.movement_direction() == Vector2.ZERO and Bindings.controller_aim() == Vector2.ZERO, "probe releases movement and all aim actions")
    key.pressed = false
    stick.axis_value = 0
    Input.parse_input_event(key.duplicate())
    Input.parse_input_event(stick.duplicate())
    Input.flush_buffered_events()
    probe._restore_input()
    check(snapshot_input() == original, "probe restores every original event and deadzone")
    check(not Input.is_action_pressed("move_up"), "probe restoration leaves no scripted held movement")
    Input.parse_input_event(stick.duplicate())
    stick.axis_value = 0.8
    Input.parse_input_event(stick.duplicate())
    Input.flush_buffered_events()
    check(Bindings.controller_aim().x > 0.5, "restored mappings accept physical input again")
    stick.axis_value = 0
    Input.parse_input_event(stick.duplicate())
    Input.flush_buffered_events()

    # The same module is copied into older builds without aim action mappings.
    for action in Bindings.AIM_ACTIONS:
        InputMap.erase_action(action)
    var legacy := snapshot_input()
    probe._isolate_input()
    probe._release_input()
    Input.action_press("move_right")
    check(Input.is_action_pressed("move_right"), "legacy action map still accepts scripted movement")
    probe._restore_input()
    check(snapshot_input() == legacy and not Input.is_action_pressed("move_right"), "legacy input maps restore without inventing controller actions")
    for action in Bindings.AIM_ACTIONS:
        InputMap.add_action(action, original[action].deadzone)
        for event in original[action].events:
            InputMap.action_add_event(action, event)
    check(snapshot_input() == original, "test restores the complete input map after legacy coverage")
    check(await game.audio.shutdown(), "probe regression audio shuts down")
    probe._cleanup_settings(game)
    game.queue_free()
    await process_frame
    print("Probe integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
