extends RefCounted
## Fixed debug-export checks. No external scripts or arbitrary commands are loaded.
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)

func run(game: Node) -> void:
    game.set_physics_process(false)
    check(Engine.get_version_info().string.begins_with("4.7.2"), "packaged engine version")
    check(game.state == "menu", "packaged main scene starts")
    check(game.settings.master == 0.7, "smoke uses isolated default settings")
    var license := FileAccess.get_file_as_string("res://assets/LICENSE.txt").replace("\r\n", "\n")
    check(license.begins_with("MIT License") and license.contains('THE SOFTWARE IS PROVIDED "AS IS"'), "packaged license")
    game.show_credits()
    var credits_found := false
    for child in game.content.get_children():
        if child is TextEdit and child.text.contains(license) and child.text.contains(Engine.get_license_text()):
            credits_found = true
    check(credits_found, "credits display packaged notices")
    game.start_run(4242)
    check(game.state == "combat" and game.enemies.size() == 1 and game.enemies[0].kind == "lane_archer", "start seeded lane teaching wave")
    Input.action_press("move_right")
    var start: Vector2 = game.player_pos
    game.simulate(1.0 / 60)
    Input.action_release("move_right")
    check(game.player_pos.x > start.x, "configured movement input")
    check(game.cast_spell() and game.projectiles.size() == 1 and game.mana < 100, "casting and mana")
    game.toggle_pause()
    var elapsed: float = game.elapsed
    game._physics_process(1.0)
    check(game.state == "paused" and game.elapsed == elapsed, "pause freezes simulation")
    game.toggle_pause()
    game.enemies[0].hp = 0
    game.simulate(0.01)
    check(game.state == "combat" and game.pending_spawns.size() == 3, "queued reinforcements prevent early clear")
    game.simulate(1.01)
    check(game.enemies.size() == 3 and game.pending_spawns.is_empty(), "announced second wave spawns")
    game.hurt_time = 0
    game.damage_player(100)
    check(game.state == "death", "death transition")
    game.start_run(4242)
    check(game.hp == 100 and game.kills == 0 and game.state == "combat", "retry reset")
    game.cast_spell()
    game.update_hud()
    game.queue_redraw()
    await game.get_tree().create_timer(0.25).timeout
    if DisplayServer.get_name() != "headless":
        var picture := game.get_viewport().get_texture().get_image()
        check(not picture.is_empty(), "rendered viewport")
        picture.save_png("user://export-smoke.png")
    check(await game.audio.shutdown(), "audio cleanup completes")
    for fixture_path in [game.settings_path, game.profile_path, game.bindings_path]:
        for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path + suffix))
    print("Export smoke: %d checks, %d failures" % [checks, failures])
    game.get_tree().quit(1 if failures else 0)
