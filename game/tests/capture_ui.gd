extends SceneTree
## Run with a real display: --script res://tests/capture_ui.gd -- /absolute/output-dir
var game: Node
var destination := "/private/tmp/spellforge-ui-captures"
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func capture(name: String) -> void:
    game.queue_redraw()
    for i in 5:
        await process_frame
    await RenderingServer.frame_post_draw
    var result := root.get_texture().get_image().save_png(destination.path_join(name + ".png"))
    if result != OK:
        push_error("Capture failed: " + name)
        failures += 1
    print("UI capture: ", name, " -> ", result)
func run() -> void:
    var args := OS.get_cmdline_user_args()
    if not args.is_empty():
        destination = args[0]
    var directory_error := DirAccess.make_dir_recursive_absolute(destination)
    if directory_error != OK or not DirAccess.dir_exists_absolute(destination):
        push_error("Capture output directory unavailable: %s (mkdir error %d)" % [destination, directory_error])
        quit(1)
        return
    root.size = Vector2i(1280, 720) if args.size() > 1 and args[1] == "1280x720" else Vector2i(960, 540)
    var scene = load("res://scenes/main.tscn").instantiate()
    scene.settings_path = "user://ui-capture-%d.cfg" % Time.get_ticks_usec()
    root.add_child(scene)
    game = scene
    scene.set_physics_process(false)
    scene.settings.shake = false
    await capture("menu")
    scene.journey.show_practice()
    await capture("practice")
    var lab = load("res://scripts/spell_lab.gd").new()
    lab.open(scene)
    await capture("spell-lab")
    lab.close()
    await process_frame
    scene.journey.leave_practice()
    scene.journey.show_tutorial()
    await capture("tutorial")
    scene.journey.show_workshop()
    await capture("workshop")
    scene.journey.show_sharing()
    await capture("sharing")
    scene.start_run(4242)
    scene.update_hud()
    await capture("combat")
    scene.encounter_index = 6
    scene.start_encounter()
    scene.enemies[0].hp = 440
    scene.update_enemies(0)
    scene.mana = 0
    scene.cast_spell()
    scene.update_hud()
    await capture("boss-low-mana")
    scene.player_pos = Vector2(480, 450)
    scene.enemies.clear()
    for i in 5:
        scene.spawn_enemy(["pursuer", "bulwark", "archer", "channeler", "boss"][i], Vector2(160 + i * 160, 300), 1)
        scene.enemies[-1].telegraph = 0.6
        scene.enemies[-1].aim = Vector2.UP.rotated(i * 0.5)
        scene.enemies[-1].burn = scene.Spell.refresh_burn({}, 4, 0)
    scene.hazards = [{"position": Vector2(660, 405), "radius": 38, "progress": 0.5, "life": 1.2}]
    scene.message = "Charge arrow · armor arc · shot line · casting sigil"
    scene.message_time = 3
    scene.resource_notice_time = 0
    scene.update_hud()
    await capture("enemy-cues")
    scene.encounter_index = 3
    scene.state = "reward"
    scene.owned = ["projectile", "fire", "pierce", "split", "bounce", "chain", "explode", "cooldown"]
    scene.components = ["projectile", "fire", "pierce", "split", "bounce"]
    scene.draft = scene.components.duplicate()
    scene.offers = ["chain", "explode", "cooldown"]
    scene.selected_reward = false
    scene.show_reward()
    scene.update_hud()
    await capture("rewards")
    scene.selected_reward = true
    scene.selected_component = "fire"
    scene.show_reward()
    await capture("forge-full")
    scene.encounter_index = 6
    scene.elapsed = 125
    scene.finish_run(true)
    await capture("victory")
    scene.start_run(4242, {"expedition": "archive", "challenge": "standard", "starting_choice": "ember"})
    scene.update_hud()
    await capture("archive-terrain")
    scene.encounter_index = 6
    scene.start_encounter()
    scene.enemies[0].hp = 400
    scene.update_enemies(0)
    scene.update_hud()
    await capture("archivist")
    if not await scene.audio.shutdown():
        push_error("Capture audio shutdown failed.")
        failures += 1
    for fixture_path in [scene.settings_path, scene.profile_path, scene.bindings_path]:
        for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path + suffix))
    scene.queue_free()
    await process_frame
    quit(1 if failures else 0)
