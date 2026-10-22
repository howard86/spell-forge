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
            game.choose_reward(game.offers[0])
            check(game.selected_reward, "reward selected")
            var previous: int = game.owned.size()
            game.choose_reward(game.offers[0])
            check(game.owned.size() == previous, "only one reward")
            game.apply_reward()
    check(game.state == "victory", "boss victory summary")
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
