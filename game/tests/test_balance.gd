extends SceneTree
const Game = preload("res://scripts/game.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func reset(game) -> void:
    game.start_run(42)
    game.enemies.clear()
    game.encounter_waves.clear()
    game.next_wave = 0
    game.hurt_time = 0
func hit(game, components: Array, position: Vector2 = Vector2(400, 300)) -> Dictionary:
    game.compiled = game.Spell.compile(components)
    game.cooldown = 0
    game.mana = 100
    game.player_pos = position - Vector2(70, 0)
    game.aim = Vector2.RIGHT
    game.cast_spell()
    var projectile: Dictionary = game.projectiles.back()
    game.update_projectiles(0.2)
    return projectile
func run() -> void:
    var game = Game.new()
    game.settings_path = "user://balance-test-%d.cfg" % Time.get_ticks_usec()
    root.add_child(game)
    game.set_physics_process(false)
    game.start_run(42)
    check(game.enemies.size() == 1 and game.enemies[0].kind == "lane_archer", "first wave teaches a lone lane archer")
    game.enemies[0].hp = 0
    game.simulate(0.01)
    check(game.state == "combat" and game.pending_spawns.size() == 3, "pending wave blocks reward transition")
    var announced: Array = game.pending_spawns.duplicate(true)
    game.toggle_pause()
    game.simulate(2)
    check(game.pending_spawns == announced, "pause freezes spawn warnings")
    game.toggle_pause()
    game.simulate(1.01)
    check(game.enemies.size() == 3 and game.pending_spawns.is_empty(), "announced wave materializes")
    for enemy in game.enemies:
        check(enemy.position.distance_to(game.player_pos) >= 100, "spawn keeps safe player distance")
    for enemy in game.enemies:
        enemy.hp = 0
    game.simulate(0.01)
    check(game.state == "reward" and game.offers.has("restore"), "all waves clear to recovery choice")
    game.hp = 100
    game.choose_reward("restore")
    check(game.selected_reward and game.hp == 100, "restore at full health advances choice")
    reset(game)
    game.player_pos = Vector2(400, 300)
    game.player_velocity = Vector2(220, 0)
    game.spawn_enemy("lane_archer", Vector2(200, 300), 0)
    var archer: Dictionary = game.enemies[0]
    game.update_enemies(0.01)
    check(is_equal_approx(archer.telegraph, 0.9), "lane warning lasts .9 seconds")
    var origin: Vector2 = archer.attack_origin
    var target: Vector2 = archer.attack_target
    game.player_pos = Vector2(400, 400)
    game.update_enemies(0.5)
    check(archer.attack_origin == origin and archer.attack_target == target, "lane endpoints freeze despite player movement")
    game.update_enemies(0.41)
    check(game.hp == 100, "moving outside warned lane avoids damage")
    game.player_pos = origin.lerp(target, 0.3)
    game.enemy_attack(archer)
    check(game.hp == 78, "warned lane damages along its capsule")
    reset(game)
    game.player_pos = Vector2(400, 300)
    game.spawn_enemy("boss", Vector2(200, 300), 0)
    var boss: Dictionary = game.enemies[0]
    var kinds: Array = []
    for i in 3:
        game.begin_enemy_warning(boss)
        kinds.append(boss.attack_kind)
    check(kinds == ["fan", "sweep", "charge"], "boss alternates three taught patterns")
    var charge_target: Vector2 = boss.attack_target
    game.player_pos = Vector2(300, 300)
    game.update_enemies(1.01)
    check(game.hp == 85 and boss.position == charge_target, "charge swept contact catches crossed player without retargeting")
    check(boss.timer >= 0.8, "boss punish recovery is at least .8 seconds")
    boss.hp = 400
    game.update_enemies(0.01)
    check(boss.phase == 2 and boss.max_hp == 900, "phase two preserves boss health budget")
    boss.attack_step = 0
    game.begin_enemy_warning(boss)
    check(boss.attack_kind == "charge", "phase two varies the taught sequence")
    reset(game)
    game.spawn_enemy("pursuer", Vector2(400, 300), 10)
    var slowed: Dictionary = game.enemies[0]
    hit(game, ["projectile", "frost"])
    check(is_equal_approx(slowed.hp, 42 - 15.3) and slowed.frost_until == game.elapsed + 1, "real frost collision applies damage tradeoff and refresh deadline")
    var old_position: Vector2 = slowed.position
    var old_timer: float = slowed.timer
    game.update_enemies(0.2)
    check(is_equal_approx(old_position.distance_to(slowed.position), 91 * 0.75 * 0.2), "frost reduces only movement")
    check(is_equal_approx(old_timer - slowed.timer, 0.2), "frost does not slow attack timer")
    game.elapsed = 1.1
    old_position = slowed.position
    game.player_pos = Vector2(100, 300)
    game.update_enemies(0.1)
    check(is_equal_approx(old_position.distance_to(slowed.position), 9.1) and slowed.frost_amount == 0, "frost expires without stacking")
    reset(game)
    game.spawn_enemy("bulwark", Vector2(400, 300), 10)
    var blasted: Dictionary = game.enemies[0]
    blasted.aim = Vector2.RIGHT
    hit(game, ["projectile", "explode", "delayed_blast"])
    check(game.delayed_blasts.size() == 1 and is_equal_approx(blasted.hp, 82), "collision queues blast without immediate explosion")
    check(game.projectiles.is_empty() and game.casts.is_empty(), "delayed blast outlives projectile and cast")
    game.toggle_pause()
    game.update_delayed_blasts(1)
    check(is_equal_approx(blasted.hp, 82), "paused delayed blast cannot damage")
    game.toggle_pause()
    game.update_delayed_blasts(0.59)
    check(is_equal_approx(blasted.hp, 82), "delayed blast waits its full warning")
    game.update_delayed_blasts(0.02)
    check(is_equal_approx(blasted.hp, 61.75) and game.delayed_blasts.is_empty(), "delayed blast resolves once for 20.25 damage")
    reset(game)
    game.spawn_enemy("pursuer", Vector2(850, 300), 10)
    game.compiled = game.Spell.compile(["projectile", "bounce", "wall_charge"])
    game.player_pos = Vector2(880, 300)
    game.aim = Vector2.RIGHT
    game.cast_spell()
    var bank: Dictionary = game.projectiles[0]
    game.update_projectiles(0.2)
    check(bank.wall_charged and bank.direction == Vector2.LEFT, "actual wall reflection charges projectile")
    game.update_projectiles(0.3)
    check(is_equal_approx(game.enemies[0].hp, 15), "bank shot deals 27 direct damage")
    reset(game)
    game.spawn_enemy("bulwark", Vector2(400, 300), 100)
    game.enemies[0].aim = Vector2.RIGHT
    game.compiled = game.Spell.compile(["projectile", "explode", "delayed_blast"])
    game.player_pos = Vector2(330, 300)
    game.cursor_position = Vector2(500, 300)
    game.aim = Vector2.RIGHT
    game.cast_spell()
    game.simulate(0.7)
    check(game.delayed_blasts.size() == 1 and is_equal_approx(game.delayed_blasts[0].remaining, 0.6), "new blast retains full warning even on a long collision frame")
    reset(game)
    game.spawn_enemy("boss", Vector2(400, 300), 100)
    var durable: Dictionary = game.enemies[0]
    durable.hp = 100000
    for i in 70:
        hit(game, ["projectile", "explode", "delayed_blast"])
    check(game.delayed_blasts.size() == 64, "delayed blast capacity is bounded at 64")
    game.delayed_blasts.clear()
    hit(game, ["projectile", "frost"])
    var refresh: float = durable.frost_until
    game.elapsed += 0.2
    hit(game, ["projectile", "frost"])
    check(is_equal_approx(durable.frost_until, refresh + 0.2), "frost refreshes deadline instead of stacking duration")
    game.player_pos = Vector2(100, 300)
    var boss_start: Vector2 = durable.position
    game.update_enemies(0.1)
    check(is_equal_approx(boss_start.distance_to(durable.position), 45 * 0.9 * 0.1), "boss frost movement slow capped at ten percent")
    game.encounter_clear()
    game.owned = ["projectile", "bounce", "wall_charge", "explode", "delayed_blast"]
    game.draft = ["projectile"]
    game.selected_reward = false
    game.offers = ["wall_charge", "restore"]
    game.owned.erase("wall_charge")
    game.choose_reward("wall_charge")
    check(game.owned.has("wall_charge") and not game.draft.has("wall_charge"), "dependent reward stays owned without invalid autoequip")
    game.edit_draft("add", -1, "wall_charge")
    check(game.draft == ["projectile"], "editor rejects dependency without prerequisite")
    game.edit_draft("add", -1, "bounce")
    game.edit_draft("add", -1, "wall_charge")
    game.edit_draft("remove", 1)
    check(game.draft == ["projectile", "bounce", "wall_charge"], "editor prevents removing required parent")
    game.edit_draft("remove", 2)
    game.edit_draft("remove", 1)
    check(game.draft == ["projectile"], "dependent then prerequisite can be removed")
    for boundary in ["death", "restart", "room", "menu"]:
        reset(game)
        game.delayed_blasts.append({"position": Vector2.ZERO, "radius": 72, "damage": 20.25, "remaining": 0.6, "duration": 0.6})
        game.pending_spawns.append({"kind": "pursuer", "position": Vector2.ZERO, "remaining": 1.0, "duration": 1.0})
        match boundary:
            "death": game.damage_player(100)
            "restart": game.start_run(8)
            "room": game.encounter_clear()
            "menu": game.show_menu()
        check(game.delayed_blasts.is_empty() and game.pending_spawns.is_empty(), "boundary clears delayed work: " + boundary)
    game.queue_free()
    await process_frame
    print("Balance integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
