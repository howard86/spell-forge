extends SceneTree
const Game = preload("res://scripts/game.gd")
const Director = preload("res://scripts/run_director.gd")
var failures := 0
var checks := 0
func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(description)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = Game.new()
    game.settings_path = "user://test-settings-%d.cfg" % Time.get_ticks_usec()
    root.add_child(game)
    game.set_physics_process(false)
    check(game.state == "menu", "launch menu")
    for index in 7:
        check(Director.encounter(42, index) == Director.encounter(42, index), "repeatable encounter")
    check(Director.rewards(42, 0, ["projectile"]) == Director.rewards(42, 0, ["projectile"]), "repeatable rewards")
    check(Director.rewards(42, 0, ["projectile", "fire", "pierce", "split", "bounce", "chain", "explode", "cooldown"]) == ["restore"], "exhausted rewards fallback")
    game.start_run(42)
    check(game.state == "combat" and game.enemies.size() == 4, "start encounter")
    game.update_hud()
    check(game.hud.visible, "combat HUD visible")
    game.choose_reward("fire")
    check(game.owned == ["projectile"], "no rewards in combat")
    game.mana = 0
    check(not game.cast_spell() and game.mana == 0 and game.projectiles.is_empty(), "mana denial is atomic")
    game.mana = 100
    check(game.cast_spell() and game.projectiles.size() == 1 and game.mana == 92, "legal cast spends mana")
    game.toggle_pause()
    var before: Array = game.projectiles.duplicate(true)
    var time_before: float = game.elapsed
    game._physics_process(1.0)
    check(game.elapsed == time_before and game.projectiles == before, "pause stops simulation")
    check(not game.cast_spell(), "pause denies cast")
    game.toggle_pause()
    game.hurt_time = 0
    game.dodge_time = 0.2
    game.damage_player(50)
    check(game.hp == 100, "dodge invulnerability")
    game.dodge_time = 0
    game.damage_player(100)
    check(game.state == "death", "death summary")
    game.update_hud()
    check(not game.hud.visible, "death screen hides combat warnings and pause hint")
    game.start_run(42)
    check(game.hp == 100 and game.mana == 100 and game.kills == 0 and game.encounter_index == 0 and game.projectiles.is_empty(), "restart reset")
    # Scripted hits use the real resolver, kill accounting and reward UI, not auto-win controls.
    for index in 7:
        check(game.state == "combat" and game.encounter_index == index, "encounter progression")
        if index == 6:
            game.enemies[0].hp = 400
            game.update_enemies(0.01)
            check(game.enemies[0].phase == 2, "boss phase transition")
        for enemy in game.enemies:
            while enemy.hp > 0:
                game.cooldown = 0
                game.mana = 100
                game.aim = Vector2.RIGHT
                game.cast_spell()
                var bolt: Dictionary = game.projectiles.back()
                bolt.position = enemy.position
                game.resolve_projectile_hit(bolt, enemy)
        game.simulate(0.001)
        if index < 6:
            check(game.state == "reward", "combat to reward")
            if index == 0:
                game.update_hud()
                check(not game.hud.visible, "reward screen hides combat warnings and pause hint")
            game.choose_reward(game.offers[0])
            check(game.selected_reward, "reward selected")
            var previous: int = game.owned.size()
            game.choose_reward(game.offers[0])
            check(game.owned.size() == previous, "only one reward")
            if index == 0:
                game.message = "Mana recovering… simplify your spell between trials."
                game.message_time = 1.0
            game.apply_reward()
            if index == 0:
                check(game.message.is_empty() and game.message_time == 0, "new encounter clears prior combat warnings")
    check(game.state == "victory", "boss victory summary")
    game.update_hud()
    check(not game.hud.visible, "victory screen hides combat warnings and pause hint")
    game.start_run(777)
    game.compiled = game.Spell.compile(["projectile", "split", "pierce", "bounce"])
    game.cast_spell()
    var parent: Dictionary = game.projectiles[0]
    parent.pierce = 0
    parent.bounces = 0
    parent.position = game.enemies[0].position
    game.resolve_projectile_hit(parent, game.enemies[0])
    check(game.projectiles.size() == 3, "split creates two children")
    check(game.projectiles[1].generation == 1 and game.projectiles[1].pierce == 2 and game.projectiles[1].bounces == 3, "children use fresh compiled traversal counters")
    for i in 200:
        game.add_projectile(Vector2(50, 100), Vector2.LEFT, true)
    check(game.projectiles.size() == game.MAX_PROJECTILES, "global projectile cap")
    game.update_projectiles(10)
    check(game.projectiles.is_empty() and game.casts.is_empty(), "expiry cleans projectiles and casts")
    game.start_run(21)
    game.enemies.clear()
    game.spawn_enemy("pursuer", game.player_pos + Vector2(70, 0), 100)
    game.aim = Vector2.RIGHT
    game.cast_spell()
    var target_hp: float = game.enemies[0].hp
    game.update_projectiles(0.2)
    check(game.enemies[0].hp < target_hp, "swept projectile collision damages enemy")
    game.projectiles.clear()
    game.casts.clear()
    game.hurt_time = 0
    var player_hp: float = game.hp
    game.add_projectile(game.player_pos - Vector2(30, 0), Vector2.RIGHT, true)
    game.update_projectiles(0.2)
    check(game.hp == player_hp - 12, "enemy projectile collision damages player")
    game.enemies.clear()
    game.spawn_enemy("bulwark", Vector2(100, 100), 100)
    var burning: Dictionary = game.enemies[0]
    burning.burn = game.Spell.refresh_burn({}, 4.0, game.elapsed)
    var initial_hp: float = burning.hp
    for i in 180:
        game.elapsed += 1.0 / 60
        game.update_enemies(1.0 / 60)
    check(is_equal_approx(initial_hp - burning.hp, 12.0), "burn deals exactly 4 DPS for 3 seconds")
    burning.hp = 0.01
    burning.burn = game.Spell.refresh_burn({}, 4.0, game.elapsed)
    burning.telegraph = 0.001
    burning.position = game.player_pos
    game.hurt_time = 0
    var health_before: float = game.hp
    game.elapsed += 0.1
    game.update_enemies(0.1)
    check(burning.hp <= 0 and game.hp == health_before, "burn kill cannot attack same tick")
    game.start_run(31)
    game.enemies.clear()
    for i in 3:
        game.spawn_enemy("pursuer", Vector2(200 + i * 70, 200), 100)
    game.compiled = game.Spell.compile(["projectile", "chain"])
    game.cast_spell()
    var chain_bolt: Dictionary = game.projectiles[0]
    chain_bolt.position = game.enemies[0].position
    game.resolve_projectile_hit(chain_bolt, game.enemies[0])
    check(game.effects.size() == 2, "two chain visual hops")
    check(game.effects[0].origin == Vector2(200, 200) and game.effects[0].target == Vector2(270, 200), "first chain visual endpoint")
    check(game.effects[1].origin == Vector2(270, 200) and game.effects[1].target == Vector2(340, 200), "successive chain visual endpoint")
    for i in 100:
        game.add_effect("chain", Vector2.ZERO, Vector2.ONE, 0)
    check(game.effects.size() == 64, "cosmetic effect cap")
    game.update_effects(0.31)
    check(game.effects.is_empty(), "cosmetic effects expire")
    game.add_effect("explode", Vector2.ZERO, Vector2.ZERO, 72)
    game.start_run(99)
    check(game.effects.is_empty(), "restart clears cosmetic effects")
    # Review regressions: collision chronology, impact geometry and death boundaries.
    for reverse_order in [false, true]:
        game.start_run(42)
        game.enemies.clear()
        for x in ([224, 220] if reverse_order else [220, 224]):
            game.spawn_enemy("pursuer", Vector2(x, 200), 100)
        game.player_pos = Vector2(182, 200)
        game.aim = Vector2.RIGHT
        game.cast_spell()
        game.update_projectiles(1.0 / 60)
        for enemy in game.enemies:
            check(enemy.hp == (24.0 if enemy.position.x == 220 else 42.0), "nearest swept target wins regardless of insertion order")
    check(is_equal_approx(game.segment_contact(Vector2(10, 0), 2, Vector2.ZERO, Vector2(20, 0)), 0.4), "swept contact uses circle entry rather than center projection")
    game.start_run(1)
    game.enemies.clear()
    game.spawn_enemy("bulwark", Vector2(550, 300), 100)
    game.spawn_enemy("pursuer", Vector2(380, 300), 100)
    game.compiled = game.Spell.compile(["projectile", "chain", "split", "explode"])
    game.aim = Vector2.RIGHT
    game.cast_spell()
    var impact_start: Vector2 = game.projectiles[0].position
    var expected_contact: Vector2 = impact_start.lerp(impact_start + Vector2(78, 0), game.segment_contact(Vector2(550, 300), game.enemies[0].radius + 5, impact_start, impact_start + Vector2(78, 0)))
    game.update_projectiles(0.2)
    check(game.enemies[1].hp < 42, "chain radius begins at actual swept impact")
    check(game.projectiles.size() == 2 and game.projectiles[0].position.is_equal_approx(expected_contact), "split children originate at actual impact")
    check(game.effects.back().kind == "explode" and game.effects.back().origin.is_equal_approx(expected_contact), "explosion originates at actual impact")
    game.start_run(1)
    game.enemies.clear()
    game.spawn_enemy("bulwark", Vector2(905, 300), 100)
    game.enemies[0].aim = Vector2.LEFT
    var armored_hp: float = game.enemies[0].hp
    game.compiled = game.Spell.compile(["projectile", "bounce", "split"])
    game.aim = Vector2.RIGHT
    game.cast_spell()
    game.projectiles[0].position = Vector2(900, 300)
    game.update_projectiles(0.1)
    check(is_equal_approx(armored_hp - game.enemies[0].hp, 9.9), "incoming wall contact retains directional armor")
    check(game.projectiles.size() == 2 and game.projectiles[0].direction.x > 0, "split retains incoming direction before wall reflection")
    game.start_run(1)
    game.compiled = game.Spell.compile(["projectile", "split"])
    game.cast_spell()
    var capped_bolt: Dictionary = game.projectiles[0]
    for i in 158:
        game.add_projectile(Vector2(50, 100), Vector2.LEFT, true)
    game.resolve_projectile_hit(capped_bolt, game.enemies[0])
    check(game.projectiles.size() == 159 and game.projectiles.filter(func(p): return p.generation == 1).is_empty(), "global cap rejects whole split pair")
    check(game.casts[capped_bolt.cast_id].split_used and game.casts[capped_bolt.cast_id].projectiles_spawned == 3, "rejected world split retains consumed reservation")
    game.start_run(1)
    game.enemies.clear()
    game.spawn_enemy("pursuer", Vector2(510, 296), 100)
    game.aim = Vector2.RIGHT
    game.cast_spell()
    game.projectiles[0].life = 0.01
    game.update_projectiles(1.0 / 60)
    check(game.enemies[0].hp == 24 and game.projectiles.is_empty(), "final partial lifetime resolves contact before expiry")
    for direction in [Vector2.RIGHT, Vector2.DOWN]:
        game.start_run(1)
        game.enemies.clear()
        game.compiled = game.Spell.compile(["projectile", "bounce"])
        game.aim = direction
        game.cast_spell()
        var wall_bolt: Dictionary = game.projectiles[0]
        wall_bolt.position = Vector2(921.5, 300) if direction == Vector2.RIGHT else Vector2(500, 497.5)
        game.update_projectiles(1.0 / 60)
        check(wall_bolt.direction == -direction and wall_bolt.bounces == 2, "exact boundary reflects immediately once")
        game.update_projectiles(1.0 / 60)
        check(wall_bolt.direction == -direction and wall_bolt.bounces == 2, "next tick travels inward without extra bounce")
    for death_source in ["contact", "projectile"]:
        game.start_run(42)
        game.enemies.clear()
        game.player_pos = Vector2(400, 300)
        if death_source == "contact":
            game.spawn_enemy("pursuer", game.player_pos, 100)
        else:
            game.add_projectile(game.player_pos, Vector2.RIGHT, true)
        game.spawn_enemy("swarm", Vector2(470, 300), 100)
        game.aim = Vector2.RIGHT
        game.cast_spell()
        game.projectiles.back().position = Vector2(450, 300)
        game.hp = 1
        game.hurt_time = 0
        game.simulate(1.0 / 60)
        check(game.state == "death" and game.kills == 0, "death stops later projectile damage: " + death_source)
        var summary_found := false
        for child in game.content.get_children():
            if child is Label and child.text.contains("0 defeated"):
                summary_found = true
        check(summary_found, "death summary matches final kill count")
    var original: Dictionary = game.settings.duplicate()
    game.settings.master = 0.25
    game.settings.reduced_flash = true
    game.save_settings()
    game.settings.master = 1.0
    game.settings.reduced_flash = false
    game.load_settings()
    check(game.settings.master == 0.25 and game.settings.reduced_flash, "settings survive reload")
    game.settings = original
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))
    game.queue_free()
    await process_frame
    await create_timer(0.15).timeout
    print("Run integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
