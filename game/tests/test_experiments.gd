extends SceneTree
const Game = preload("res://scripts/game.gd")
const Preview = preload("res://scripts/spell_preview.gd")
const Lab = preload("res://scripts/spell_lab.gd")
const Runtime = preload("res://scripts/experimental_spell_runtime.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func activate_focused() -> void:
    var event := InputEventAction.new()
    event.action = "ui_accept"
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    event = InputEventAction.new()
    event.action = "ui_accept"
    event.pressed = false
    Input.parse_input_event(event)
    for index in 3:
        await process_frame

func run() -> void:
    var source = Game.new()
    source.mana = 13
    source.components = ["projectile"]
    source.draft = ["projectile", "fire"]
    var baseline := Preview.evaluate(source, ["projectile", "split"], "boss")
    var spread := Preview.evaluate(source, ["projectile", "split"], "boss", [], "split_spread")
    check(baseline.damage == 54 and spread.damage == 18, "parent exclusion: boss 54 -> 18")
    var cluster := Preview.evaluate(source, ["projectile", "split"], "cluster", [], "split_spread")
    check(cluster.damage > 18, "excluded parent still permits other targets")
    for id in Runtime.EXPERIMENT_IDS:
        var result := Preview.evaluate(source, ["projectile", "frost", "split"], "moving", [], id)
        check(result.valid and result.frames.size() == 120 and result.casts == 1, "bounded valid preview: " + id)
        check(result.remaining_mana == 100 - result.mana_cost, "actual paid cost: " + id)
        for frame in result.frames:
            check(frame.projectiles.size() <= Game.MAX_PROJECTILES, "world projectile cap")
    check(not Preview.evaluate(source, ["projectile"], "boss", [], "unknown").valid, "unknown ID rejected")
    check(not Preview.evaluate(source, ["projectile", "fire", "split", "pierce", "explode"], "boss", [], "repulse").valid, "repulse requires extra slot")
    var plain := Preview.evaluate(source, ["projectile"], "boss")
    var push := Preview.evaluate(source, ["projectile"], "boss", [], "repulse")
    check(push.damage == plain.damage and push.mana_cost == plain.mana_cost + 5, "repulse changes cost but not damage")
    check(push.frames[-1].enemies[0].position.x == 452, "boss push is 12px")
    var ordinary := Preview.evaluate(source, ["projectile"], "isolated", [], "repulse")
    check(ordinary.frames[-1].enemies[0].position.x == 488, "ordinary push is 48px")
    var blocked := Preview.evaluate(source, ["projectile"], "isolated", [Rect2(466, 260, 20, 80)], "repulse")
    check(blocked.frames[-1].enemies[0].position.x < 466, "cover blocks push")
    var recipe := ["projectile", "explode", "delayed_blast"]
    var blast_base := Preview.evaluate(source, recipe, "cluster")
    var blast_push := Preview.evaluate(source, recipe, "cluster", [], "repulse")
    print("Comparisons: Split boss ", baseline.damage, " -> ", spread.damage, "; spread cluster ", cluster.damage, "; delayed blast cluster ", blast_base.damage, " -> ", blast_push.damage)
    check(blast_push.frames[-1].enemies[0].position.x != blast_base.frames[-1].enemies[0].position.x, "actual delayed blast target displaced")
    # Direct contacts isolate child status from the root's existing slow.
    for recipe_order in [["projectile", "frost", "split"], ["projectile", "split", "frost"]]:
        var runtime = Runtime.new()
        runtime.compiled = runtime.Spell.compile(recipe_order)
        check(runtime.configure_experiment("frost_split_order"), "configure frost")
        runtime.audio = Preview.SilentAudio.new()
        runtime.state = "combat"
        runtime.casts[1] = runtime.Spell.new_cast(1, runtime.compiled)
        runtime.spawn_enemy("boss", Vector2(440, 300), 1)
        runtime.spawn_enemy("boss", Vector2(480, 320), 1)
        runtime.add_projectile(Vector2(440, 300), Vector2.RIGHT, false, 1)
        runtime.resolve_projectile_hit(runtime.projectiles[0], runtime.enemies[0])
        check(runtime.projectiles.size() == 3, "exact split pair")
        runtime.resolve_projectile_hit(runtime.projectiles[1], runtime.enemies[1])
        check((runtime.enemies[1].frost_until > 0) == (recipe_order[1] == "frost"), "only Frost before Split inherits child slow")
        check(runtime.projectiles.size() == 3, "child has no triggers")
        runtime.enemies[1].frost_until = 0.0
        runtime.resolve_projectile_hit(runtime.projectiles[1], runtime.enemies[1])
        check(runtime.enemies[1].frost_until == 0, "rejected repeat cannot slow")
        runtime.audio.free()
        runtime.free()
    check(source.mana == 13 and source.components == ["projectile"] and source.draft == ["projectile", "fire"] and source.enemies.is_empty(), "source unchanged")
    source.free()
    for mode in ["normal", "child", "exhausted", "repeated"]:
        var runtime = Runtime.new()
        runtime.compiled = runtime.Spell.compile(["projectile", "frost"])
        runtime.configure_experiment("repulse")
        runtime.audio = Preview.SilentAudio.new()
        runtime.casts[1] = runtime.Spell.new_cast(1, runtime.compiled)
        runtime.spawn_enemy("boss", Vector2(440, 300), 1)
        runtime.add_projectile(Vector2(440, 300), Vector2.RIGHT, false, 1, 1 if mode == "child" else 0)
        if mode == "exhausted":
            runtime.casts[1].effects_used = runtime.Spell.MAX_EFFECTS
        runtime.resolve_projectile_hit(runtime.projectiles[0], runtime.enemies[0])
        if mode == "repeated":
            runtime.resolve_projectile_hit(runtime.projectiles[0], runtime.enemies[0])
        check(runtime.enemies[0].position.x == (440 if mode in ["child", "exhausted"] else 452), "repulse accepted root only: " + mode)
        check(runtime.casts[1].effects_used <= runtime.Spell.MAX_EFFECTS, "effect cap retained")
        runtime.audio.free()
        runtime.free()
    var capped = Runtime.new()
    capped.compiled = capped.Spell.compile(["projectile", "split"])
    capped.configure_experiment("split_spread")
    capped.audio = Preview.SilentAudio.new()
    capped.state = "combat"
    capped.casts[1] = capped.Spell.new_cast(1, capped.compiled)
    capped.spawn_enemy("boss", Vector2(440, 300), 1)
    for index in Game.MAX_PROJECTILES - 1:
        capped.add_projectile(Vector2(440, 300), Vector2.RIGHT, false, 1)
    capped.resolve_projectile_hit(capped.projectiles[0], capped.enemies[0])
    check(capped.projectiles.size() == Game.MAX_PROJECTILES - 1, "insufficient capacity rejects whole split pair")
    capped.add_projectile(Vector2(440, 300), Vector2.RIGHT, false, 1)
    var unspent := float(capped.mana)
    check(not capped.cast_spell() and capped.mana == unspent, "world cap rejects cast without payment")
    check(capped.casts[1].projectiles_spawned <= capped.Spell.MAX_PROJECTILES, "resolver projectile budget retained")
    capped.audio.free()
    capped.free()
    var standard = Game.new()
    standard.compiled = standard.Spell.compile(["projectile", "frost", "split"])
    standard.audio = Preview.SilentAudio.new()
    standard.casts[1] = standard.Spell.new_cast(1, standard.compiled)
    standard.spawn_enemy("boss", Vector2(440, 300), 1)
    standard.add_projectile(Vector2(440, 300), Vector2.RIGHT, false, 1, 1)
    standard.resolve_projectile_hit(standard.projectiles[0], standard.enemies[0])
    check(standard.enemies[0].frost_until == 0, "standard child remains root-only Frost")
    check(is_equal_approx(900 - standard.enemies[0].hp, 15.3), "child retains global 15 percent direct penalty")
    standard.audio.free()
    standard.free()
    var live = Game.new()
    live.settings_path = "user://lab-test-%d.cfg" % Time.get_ticks_usec()
    root.add_child(live)
    live.set_physics_process(false)
    live.journey.show_practice()
    var saved: Array = [live.draft.duplicate(true), live.owned.duplicate(true), live.profile.data.duplicate(true), live.report.snapshot(), live.obstacles.duplicate(true)]
    var lab = Lab.new()
    lab.open(live)
    await process_frame
    check(lab.is_inside_tree() and lab.preview.comparison.draft.valid, "lab enters with actual paired preview")
    for index in 3:
        await process_frame
    check(root.gui_get_focus_owner() == lab.picker, "initial lab focuses experiment selector")
    lab.order_button.grab_focus()
    for index in 4:
        var before_order: bool = lab.reversed_order
        var previous_button: Button = lab.order_button
        await activate_focused()
        check(lab.reversed_order != before_order, "focused accept activates swap %d" % index)
        check(not is_instance_valid(previous_button) and root.gui_get_focus_owner() == lab.order_button, "replacement swap retains focus %d" % index)
        check(lab.order_button.get_node(lab.order_button.focus_neighbor_top) == lab.picker, "swap previous neighbor is selector")
        check(lab.order_button.get_node(lab.order_button.focus_neighbor_bottom) == lab.preview.picker, "swap next neighbor is rebuilt scenario selector")
    for index in 3:
        lab.picker.grab_focus()
        lab.picker.select(index)
        lab.picker.item_selected.emit(index)
        for frame in 3:
            await process_frame
        check(root.gui_get_focus_owner() == lab.picker, "experiment selector retains focus %d" % index)
        lab.experiment = index
        lab.rebuild()
        await process_frame
        check(lab.preview.comparison.draft.valid, "lab selector preview: %d" % index)
    var proxy: Node = lab.proxy
    lab.back_button.grab_focus()
    await activate_focused()
    await process_frame
    check(not is_instance_valid(proxy), "back releases detached proxy")
    check(saved == [live.draft, live.owned, live.profile.data, live.report.snapshot(), live.obstacles], "lab/back preserves draft inventory profile report terrain")
    check(await live.audio.shutdown(), "UI audio shuts down cleanly")
    live.free()
    print("Experimental lab: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
