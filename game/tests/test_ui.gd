extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)
func _initialize() -> void:
    call_deferred("run")
func settle() -> void:
    for i in 4:
        await process_frame
func visible_bounds(node: Node) -> void:
    for child in node.get_children():
        if child is Control and child.is_visible_in_tree():
            var rect: Rect2 = child.get_global_rect()
            check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 960.1 and rect.end.y <= 540.1, "visible UI fits 960x540: %s %s" % [child.get_path(), rect])
        visible_bounds(child)
func find_button(node: Node, prefix: String) -> Button:
    if node is Button and node.text.begins_with(prefix):
        return node
    for child in node.get_children():
        var found := find_button(child, prefix)
        if found != null:
            return found
    return null
func labels(node: Node) -> String:
    var result := ""
    if node is Label or node is Button:
        result += node.text + "\n"
    for child in node.get_children():
        result += labels(child)
    return result
func run() -> void:
    root.size = Vector2i(960, 540)
    var scene = load("res://scenes/main.tscn").instantiate()
    scene.settings_path = "user://ui-test-%d.cfg" % Time.get_ticks_usec()
    root.add_child(scene)
    scene.set_physics_process(false)
    scene.start_run(4242)
    check(scene.ARENA == Rect2(32, 88, 896, 416), "arena unchanged")
    check(scene.readiness().cast and scene.readiness().dodge, "initial cast/dodge readiness")
    scene.projectiles.resize(scene.MAX_PROJECTILES)
    check(not scene.readiness().cast and not scene.cast_spell(), "projectile capacity blocks readiness and casting")
    scene.projectiles.clear()
    scene.cooldown = 0.2
    scene.dodge_cooldown = 0.2
    check(not scene.readiness().cast and not scene.readiness().dodge, "cooldowns disable readiness")
    scene.cooldown = 0
    scene.mana = 0
    scene.message = "WARDEN ENRAGED · watch the marks!"
    scene.message_time = 3
    check(not scene.cast_spell(), "insufficient mana rejects cast")
    check(scene.message.begins_with("WARDEN ENRAGED") and scene.message_time == 3 and scene.resource_notice_time == 1, "boss warning survives low mana notice")
    check(not scene.readiness().cast, "low mana disables readiness")
    var font := ThemeDB.fallback_font
    check(font.get_string_size(scene.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x < 470, "encounter message fits reserved left region")
    check(font.get_string_size(scene.resource_notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x < 404, "mana notice fits separate right region")
    scene.state = "reward"
    scene.owned = ["projectile", "fire", "pierce", "split", "bounce"]
    scene.components = scene.owned.duplicate()
    scene.draft = scene.components.duplicate()
    scene.offers = ["chain", "explode", "cooldown"]
    scene.selected_reward = false
    scene.show_reward()
    await settle()
    visible_bounds(scene.panel)
    check(labels(scene.panel).contains("Mana +8") and labels(scene.panel).contains("Five slots full"), "reward cards expose costs and full-slot ownership")
    find_button(scene.panel, scene.component_icon("chain")).pressed.emit()
    check(scene.owned.has("chain") and not scene.draft.has("chain") and scene.draft.size() == 5, "full-slot reward acquired but not equipped")
    scene.owned.append_array(["explode", "cooldown"])
    scene.show_reward()
    await settle()
    visible_bounds(scene.panel)
    check(labels(scene.panel).contains("Chain: Jump") and labels(scene.panel).contains("+ Chain"), "selected effect explanation and owned label visible")
    var original: Array = scene.draft.duplicate()
    scene.edit_draft("remove", 0)
    scene.edit_draft("left", 1)
    check(scene.draft == original, "Projectile cannot be removed or displaced")
    find_button(scene.panel, "2  ").get_parent().get_child(1).get_child(1).pressed.emit()
    check(scene.draft[1] == "pierce" and scene.draft[2] == "fire", "move right swaps explicit slots")
    scene.edit_draft("left", 2)
    check(scene.draft == original, "move left restores ordering")
    scene.edit_draft("remove", 2)
    check(scene.draft.size() == 4 and not scene.draft.has("pierce"), "remove frees slot")
    check(labels(scene.panel).contains("5  — Empty —"), "five slots include empty placeholder")
    scene.edit_draft("add", -1, "chain")
    check(scene.draft[-1] == "chain" and scene.draft.size() == 5, "owned component adds to next slot")
    scene.edit_draft("add", -1, "explode")
    check(not scene.draft.has("explode"), "full slot add rejected")
    var snapshot := [scene.hp, scene.mana, scene.kills, scene.elapsed, scene.cast_id, scene.enemies.duplicate(true), scene.projectiles.duplicate(true), scene.compiled.duplicate(true), scene.components.duplicate(), scene.owned.duplicate()]
    var preview = scene.content.get_node("SpellPreview")
    preview.restart()
    var frames: Array = preview.frames.duplicate(true)
    preview.restart()
    check(preview.frames == frames and frames.size() == 120, "real-runtime preview deterministic")
    check(snapshot == [scene.hp, scene.mana, scene.kills, scene.elapsed, scene.cast_id, scene.enemies, scene.projectiles, scene.compiled, scene.components, scene.owned], "preview does not mutate any live run data")
    check(frames[-1].enemies[0].hp < 100 and not frames[-1].enemies[0].burn.is_empty(), "preview applies actual hits and burn")
    var saved_draft: Array = scene.draft.duplicate()
    scene.draft = ["projectile", "fire"]
    preview.restart("group")
    var first_burn := -1
    for i in preview.frames.size():
        if not preview.frames[i].enemies[0].burn.is_empty():
            first_burn = i
            break
    check(first_burn >= 0 and first_burn + 1 < preview.frames.size(), "preview contains a burn ignition and following frame")
    if first_burn >= 0 and first_burn + 1 < preview.frames.size():
        var hit_hp: float = preview.frames[first_burn].enemies[0].hp
        var next_hp: float = preview.frames[first_burn + 1].enemies[0].hp
        check(is_equal_approx(hit_hp, 82.0), "burn ignition frame contains only the actual 18 direct damage")
        check(is_equal_approx(hit_hp - next_hp, 4.0 / 60), "next preview tick applies exactly 4/60 burn damage")
    scene.draft = ["projectile"]
    preview.restart("wall")
    check(preview.frames[-1].enemies[0].hp == 100, "wall shot without Bounce never hits target behind origin")
    scene.draft = ["projectile", "bounce"]
    preview.restart("wall")
    check(preview.frames[-1].enemies[0].hp < 100, "wall shot with Bounce reflects and damages target")
    preview._process(2.0)
    check(not preview.is_processing(), "finished preview stops processing")
    preview.restart()
    scene.panel.hide()
    check(not preview.is_processing(), "hidden preview stops processing")
    scene.draft = saved_draft
    scene.encounter_index = 5
    check(scene.hud.progression().cleared == 5, "five trials cleared before sixth")
    scene.apply_reward()
    check(scene.encounter_index == 6 and scene.hud.progression().cleared == 6 and scene.message.contains("WARDEN CHAMBER"), "boss progression and encounter intro")
    scene.enemies[0].hp = 440
    scene.update_enemies(0)
    check(scene.enemies[0].phase == 2, "actual health threshold activates phase cue")
    scene.message_time = 0
    check(scene.enemies[0].phase == 2, "enraged remains after temporary banner expires")
    scene.elapsed = 125
    scene.finish_run(true)
    await settle()
    check(labels(scene.panel).contains("6 / 6 trials cleared") and labels(scene.panel).contains("Combat time 2:05") and labels(scene.panel).contains("FINAL SPELL"), "victory results state progression, combat time and final tiles")
    visible_bounds(scene.panel)
    scene.encounter_index = 0
    scene.finish_run(false)
    check(labels(scene.panel).contains("0 / 6 trials cleared"), "first trial defeat does not count current trial cleared")
    check(await scene.audio.shutdown(), "audio shuts down cleanly")
    scene.queue_free()
    await settle()
    print("UI integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
