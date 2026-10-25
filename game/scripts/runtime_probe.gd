extends RefCounted
## Bounded combat/render diagnostic shared by editor script and fixed debug export.
## This module deliberately does not preload game.gd, so it can probe older builds.
const SCHEMA_VERSION := 1
const STEP := 1.0 / 60.0
const SEED := 4242
const WARMUP_FRAMES := 60
const DEFAULT_FRAMES := 180
const OUTPUT_PATH := "user://runtime-probe.json"
const Spell = preload("res://scripts/spell_engine.gd")
var entry_mode := "fixed_debug_entry"
var failures := 0
var results: Array = []
var _input_map: Dictionary = {}

static func distribution(samples: Array) -> Dictionary:
    if samples.is_empty():
        return {"p50": null, "p95": null, "p99": null, "max": null}
    var ordered := samples.duplicate()
    ordered.sort()
    # Nearest-rank percentiles, including the largest observation for p100.
    return {"p50": ordered[maxi(0, ceili(ordered.size() * 0.50) - 1)],
        "p95": ordered[maxi(0, ceili(ordered.size() * 0.95) - 1)],
        "p99": ordered[maxi(0, ceili(ordered.size() * 0.99) - 1)], "max": ordered.back()}

static func has_property(object: Object, key: String) -> bool:
    for property in object.get_property_list():
        if str(property.name) == key:
            return true
    return false

func run(game: Node) -> void:
    game.set_physics_process(false)
    game.set_process_input(false)
    game.set_process_unhandled_input(false)
    _isolate_input()
    var frames := DEFAULT_FRAMES
    var write_result := false
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--probe-frames="):
            var value := argument.trim_prefix("--probe-frames=")
            if not value.is_valid_int() or int(value) < 16 or int(value) > 600:
                push_error("Performance probe frames must be an integer from 16 to 600.")
                failures += 1
            else:
                frames = int(value)
        elif argument == "--probe-write":
            write_result = true
    if failures == 0:
        var scenarios: Array = [
            {"id": "forge_wave", "expedition": "forge", "encounter": 5,
                "roster": ["bulwark", "channeler", "lane_archer", "pursuer", "swarm", "swarm", "swarm"],
                "build": ["projectile", "fire", "pierce"]},
            {"id": "max_trigger_build", "expedition": "forge", "encounter": 5,
                "roster": ["bulwark", "channeler", "lane_archer", "pursuer", "swarm", "swarm", "swarm"],
                "build": ["projectile", "pierce", "split", "chain", "explode"]},
            {"id": "warden", "expedition": "forge", "encounter": 6,
                "roster": ["boss"], "build": ["projectile", "fire", "pierce", "chain", "explode"]},
        ]
        # Safe capability check: the baseline has neither property nor Archive.
        if has_property(game, "expedition") and has_property(game, "obstacles"):
            scenarios.append({"id": "archive_archivist", "expedition": "archive", "encounter": 6,
                "roster": ["archivist"], "build": ["projectile", "fire", "pierce", "chain", "explode"]})
        else:
            print("PERF_SKIP ", JSON.stringify({"schema_version": SCHEMA_VERSION,
                "scenario": "archive_archivist", "reason": "Archive capability absent in this runtime"}))
        for scenario in scenarios:
            var result: Dictionary = await _sample(game, scenario, frames)
            results.append(result)
            print("PERF_RESULT ", JSON.stringify(result))
    _release_input()
    if write_result:
        var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
        if output == null:
            push_error("Performance probe could not write its fixed user output: error %d" % FileAccess.get_open_error())
            failures += 1
        else:
            output.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "results": results}, "  "))
            output.flush()
            var error := output.get_error()
            output.close()
            if error != OK:
                push_error("Performance probe output write failed: error %d" % error)
                failures += 1
    if is_instance_valid(game.audio) and not await game.audio.shutdown():
        push_error("Performance probe audio shutdown failed.")
        failures += 1
    _cleanup_settings(game)
    _restore_input()
    print("PERF_COMPLETE ", JSON.stringify({"schema_version": SCHEMA_VERSION, "scenarios": results.size(), "error_count": failures}))
    game.get_tree().quit(1 if failures else 0)

func _sample(game: Node, scenario: Dictionary, frames: int) -> Dictionary:
    game.start_run(SEED)
    if has_property(game, "expedition"):
        game.set("expedition", scenario.expedition)
        if has_property(game, "route"):
            game.set("route", "reflector" if scenario.expedition == "archive" else "open")
    game.encounter_index = scenario.encounter
    # Obtain candidate terrain/boss presentation through the real encounter entry.
    game.start_encounter()
    game.enemies.clear()
    game.pending_spawns.clear()
    game.encounter_waves.clear()
    game.next_wave = 0
    game.projectiles.clear()
    game.effects.clear()
    game.hazards.clear()
    game.delayed_blasts.clear()
    game.casts.clear()
    game.components = scenario.build.duplicate()
    game.owned = scenario.build.duplicate()
    game.compiled = Spell.compile(game.components)
    var errors := 0
    if not game.compiled.get("valid", false):
        errors += 1
    for index in scenario.roster.size():
        var position := Vector2(610 + (index % 3) * 36, 255 + (index / 3) * 38)
        game.spawn_enemy(scenario.roster[index], position, 0.15 + index * 0.08)
    # Sustained fixture only: invulnerable targets/player, otherwise authored attacks,
    # movement, spell costs/cooldowns, collision, update methods and rendering.
    for enemy in game.enemies:
        enemy.hp = 1000000000.0
        enemy.max_hp = 1000000000.0
        if enemy.kind in ["boss", "archivist"]:
            enemy.phase = 2
    var simulation: Array = []
    var wall: Array = []
    var peaks := {"projectiles": 0, "enemies": 0, "effects": 0, "hazards": 0, "delayed_blasts": 0,
        "static_memory_bytes": 0.0, "engine_peak_static_memory_bytes": 0.0,
        "render_objects": 0.0, "render_primitives": 0.0, "render_draw_calls": 0.0}
    var counts := {"ticks": 0, "cast_attempts": 0, "successful_casts": 0, "failed_casts": 0,
        "mana_limited_ticks": 0, "capacity_limited_ticks": 0, "projectile_observations": 0,
        "warmup_successful_casts": 0, "warmup_target_hp_loss": 0.0, "target_hp_loss": 0.0, "wall_frames_over_budget": 0, "simulation_ticks_over_budget": 0}
    var rendered := DisplayServer.get_name() != "headless"
    var previous := Time.get_ticks_usec()
    for tick in WARMUP_FRAMES + frames:
        var measured := tick >= WARMUP_FRAMES
        _drive(game, tick)
        if game.state != "combat" or game.enemies.size() != scenario.roster.size():
            errors += 1
        game.hurt_time = 3600.0
        # Explicit cast calls preserve real costs/cooldowns and expose denial counts.
        if game.cooldown <= 0:
            if measured:
                counts.cast_attempts += 1
                if game.mana < float(game.compiled.mana_cost): counts.mana_limited_ticks += 1
                if game.projectiles.size() >= 160: counts.capacity_limited_ticks += 1
            var cast_before := int(game.cast_id)
            var success: bool = game.cast_spell()
            if success and int(game.cast_id) != cast_before + 1:
                errors += 1
            if measured:
                if success: counts.successful_casts += 1
                else: counts.failed_casts += 1
            elif success:
                counts.warmup_successful_casts += 1
        var target_hp_before := _target_hp(game)
        var start := Time.get_ticks_usec()
        game.simulate(STEP)
        var duration := Time.get_ticks_usec() - start
        if not measured:
            counts.warmup_target_hp_loss += maxf(0.0, target_hp_before - _target_hp(game))
        game.visual_time += STEP
        game.update_hud()
        game.queue_redraw()
        if measured:
            simulation.append(float(duration) / 1000.0)
            counts.target_hp_loss += maxf(0.0, target_hp_before - _target_hp(game))
            if float(duration) / 1000.0 > STEP * 1000.0: counts.simulation_ticks_over_budget += 1
            counts.ticks += 1
            counts.projectile_observations += game.projectiles.size()
            _observe(game, peaks)
        await game.get_tree().process_frame
        if rendered:
            await RenderingServer.frame_post_draw
        var now := Time.get_ticks_usec()
        if measured:
            wall.append(float(now - previous) / 1000.0)
            if float(now - previous) / 1000.0 > STEP * 1000.0: counts.wall_frames_over_budget += 1
            _observe_render(peaks)
        previous = now
    if counts.successful_casts == 0 or counts.projectile_observations == 0 or counts.ticks != frames or int(peaks.projectiles) > 160 or counts.target_hp_loss + counts.warmup_target_hp_loss <= 0.0:
        errors += 1
    failures += errors
    return {"schema_version": SCHEMA_VERSION, "scenario": scenario.id,
        "sample_count": frames, "warmup_count": WARMUP_FRAMES, "seed": SEED,
        "build": scenario.build, "expedition": scenario.expedition, "encounter": scenario.encounter,
        "mode": entry_mode, "environment": _environment(game), "rendered": rendered,
        "rendered_frames_observed": frames if rendered else 0, "headless_is_graphical_acceptance": false, "fixed_simulation_step_ms": STEP * 1000.0,
        "target_frame_budget_ms": 1000.0 / 60.0,
        "wall_frame_interval_ms": distribution(wall), "simulation_ms": distribution(simulation),
        "metric_definitions": {"percentile": "nearest rank", "wall_frame_interval_ms": "between successive completed frame observations; includes probe/input/HUD, scheduling and rendering when rendered",
            "simulation_ms": "Time.get_ticks_usec around simulate(1/60) only; explicit casting and HUD excluded",
            "memory": "Godot Performance static memory monitors, not process RSS; engine peak spans earlier scenarios too",
            "error_count": "probe invariants; engine script errors must also be checked in the log"},
        "fixture": {"player_invulnerable": true, "targets_invulnerable": true, "boss_phase": 2,
            "automatic_waves_disabled": true, "projectile_cap": 160, "mana_and_cooldowns": "authored",
            "authored_encounter_enemy_total_bound": 14, "projectile_contact_candidate_bound_per_tick": 2240},
        "counts": counts, "peaks": peaks, "error_count": errors}

func _drive(game: Node, tick: int) -> void:
    var nearest: Vector2 = game.player_pos + Vector2.RIGHT * 100
    var distance := INF
    for enemy in game.enemies:
        var candidate: float = game.player_pos.distance_squared_to(enemy.position)
        if candidate < distance:
            nearest = enemy.position
            distance = candidate
    game.cursor_position = nearest
    game.aim = (nearest - game.player_pos).normalized()
    # Deterministic square patrol; no mouse/device input is used.
    _release_input()
    Input.action_press(["move_up", "move_right", "move_down", "move_left"][(tick / 60) % 4])

func _observe(game: Node, peaks: Dictionary) -> void:
    for key in ["projectiles", "enemies", "effects", "hazards", "delayed_blasts"]:
        peaks[key] = maxi(int(peaks[key]), game.get(key).size())
    peaks.static_memory_bytes = maxf(peaks.static_memory_bytes, Performance.get_monitor(Performance.MEMORY_STATIC))
    peaks.engine_peak_static_memory_bytes = maxf(peaks.engine_peak_static_memory_bytes, Performance.get_monitor(Performance.MEMORY_STATIC_MAX))

func _observe_render(peaks: Dictionary) -> void:
    peaks.render_objects = maxf(peaks.render_objects, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
    peaks.render_primitives = maxf(peaks.render_primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    peaks.render_draw_calls = maxf(peaks.render_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _target_hp(game: Node) -> float:
    var total := 0.0
    for enemy in game.enemies:
        total += float(enemy.hp)
    return total

func _environment(game: Node) -> Dictionary:
    return {"godot": Engine.get_version_info().string, "debug_build": OS.is_debug_build(),
        "editor_binary": OS.has_feature("editor"), "os": OS.get_name(), "processor": OS.get_processor_name(),
        "processor_count": OS.get_processor_count(), "display_server": DisplayServer.get_name(),
        "render_driver": RenderingServer.get_current_rendering_driver_name(),
        "render_method": RenderingServer.get_current_rendering_method(), "max_fps": Engine.max_fps,
        "vsync_mode": DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1,
        "viewport_size": [game.get_viewport().get_visible_rect().size.x, game.get_viewport().get_visible_rect().size.y],
        "render_target_size": [game.get_viewport().get_texture().get_size().x, game.get_viewport().get_texture().get_size().y],
        "window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y] if DisplayServer.get_name() != "headless" else null}

func _release_input() -> void:
    for action in ["cast", "dodge", "pause", "move_up", "move_right", "move_down", "move_left",
            "aim_up", "aim_right", "aim_down", "aim_left", "ui_accept"]:
        # Older builds have no controller aim actions.
        if InputMap.has_action(action):
            Input.action_release(action)

func _isolate_input() -> void:
    # Polling Input (not just node callbacks) must be independent of live devices.
    # Keep actions themselves so deterministic action_press still drives the game.
    for action in InputMap.get_actions():
        _input_map[action] = {"events": InputMap.action_get_events(action),
            "deadzone": InputMap.action_get_deadzone(action)}
        Input.action_release(action)
        InputMap.action_erase_events(action)

func _restore_input() -> void:
    _release_input()
    for action in _input_map:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        Input.action_release(action)
        InputMap.action_erase_events(action)
        InputMap.action_set_deadzone(action, _input_map[action].deadzone)
        for event in _input_map[action].events:
            InputMap.action_add_event(action, event)
    _input_map.clear()

func _cleanup_settings(game: Node) -> void:
    # Never remove arbitrary user paths; only our timestamped isolated fixtures.
    for key in ["settings_path", "profile_path", "bindings_path"]:
        if not has_property(game, key):
            continue
        var path := str(game.get(key))
        if not path.begins_with("user://runtime-probe-"):
            continue
        for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
