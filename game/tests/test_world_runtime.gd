extends SceneTree
const Game = preload("res://scripts/game.gd")
const Geometry = preload("res://scripts/arena_geometry.gd")
const Preview = preload("res://scripts/spell_preview.gd")
const Share = preload("res://scripts/share_code.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)

func _initialize() -> void:
    call_deferred("run")

func reset(game) -> void:
    game.start_run(42)
    game.enemies.clear()
    game.pending_spawns.clear()
    game.encounter_waves = [["pursuer"]]
    game.next_wave = 1
    game.obstacles = [Rect2(300, 238, 44, 116)]
    game.hurt_time = 0
    game.player_pos = Vector2(250, 300)
    game.cursor_position = Vector2(600, 300)

func cast(game, build: Array, position := Vector2(250, 300), direction := Vector2.RIGHT) -> Dictionary:
    game.compiled = game.Spell.compile(build)
    game.player_pos = position
    game.aim = direction
    game.cooldown = 0
    game.mana = 100
    game.cast_spell()
    return game.projectiles.back()

func valid_circle(position: Vector2, radius: float, blocks: Array, arena: Rect2) -> bool:
    return position.is_equal_approx(Geometry.safe_position(position, radius, arena, blocks))

func release_input() -> void:
    for name in ["move_left", "move_right", "move_up", "move_down", "cast"]:
        Input.action_release(name)

func steer(direction: Vector2) -> void:
    for pair in [["move_left", maxf(-direction.x, 0)], ["move_right", maxf(direction.x, 0)], ["move_up", maxf(-direction.y, 0)], ["move_down", maxf(direction.y, 0)]]:
        if pair[1] > 0.01:
            Input.action_press(pair[0], pair[1])
        else:
            Input.action_release(pair[0])

func check_review_regressions(game) -> void:
    # Original grazing lane: centerline misses cover, but its lower edge is shielded.
    reset(game)
    game.spawn_enemy("lane_archer", Vector2(250, 230), 99)
    game.player_pos = Vector2(600, 230)
    game.begin_enemy_warning(game.enemies[0])
    var archer: Dictionary = game.enemies[0]
    var boundary := Geometry.lane_boundary(archer.attack_origin, archer.attack_target, archer.attack_width, game.ARENA, game.obstacles)
    game.player_pos = Vector2(365, 245)
    game.enemy_attack(archer)
    check(not Geometry2D.is_point_in_polygon(game.player_pos, boundary) and game.hp == 100, "Grazing lane warning and actual damage exclude the protected player")
    game.player_pos = Vector2(365, 225)
    game.enemy_attack(archer)
    check(Geometry2D.is_point_in_polygon(game.player_pos, boundary) and game.hp == 78, "Uncovered portion of grazing lane still warns and damages")
    reset(game)
    game.player_pos = Vector2(365, 245)
    game.hazards = [{"kind": "lane", "origin": Vector2(250, 230), "target": Vector2(928, 230), "width": 16.0, "progress": 0.0, "life": 1.0}]
    game.update_hazards(1)
    check(game.hp == 100, "Lane hazards use the same cover protection as lane warnings")
    # An unperformed hidden Chain hop must not consume the shared cast budget.
    reset(game)
    for position in [Vector2(280, 300), Vector2(357, 300), Vector2(280, 200), Vector2(280, 150)]:
        game.spawn_enemy("pursuer", position, 99)
    var chained := cast(game, ["projectile", "pierce", "chain"], Vector2(280, 336), Vector2.UP)
    game.resolve_projectile_hit(chained, game.enemies[0])
    var chain_cast: Dictionary = game.casts[chained.cast_id]
    check(game.enemies[1].hp == 42 and is_equal_approx(game.enemies[2].hp, 30.3) and is_equal_approx(game.enemies[3].hp, 30.3), "Chain skips the nearer hidden target and performs visible C/D hops")
    check(chain_cast.chain_hops == 2 and chain_cast.effects_used == 3 and not chain_cast.visited.has(game.enemies[1].id), "Only performed visible Chain hops consume effects, hops, and visits")
    game.spawn_enemy("pursuer", Vector2(210, 150), 99)
    chained.position = Vector2(280, 218)
    game.resolve_projectile_hit(chained, game.enemies[2])
    check(chain_cast.chain_hops == 3 and is_equal_approx(game.enemies[4].hp, 30.3), "Later piercing contact can use the unspent hop on a newly eligible visible target")
    # Initial muzzle offset crosses this rounded corner before its old projection.
    for build in [["projectile"], ["projectile", "bounce", "wall_charge"]]:
        reset(game)
        game.spawn_enemy("pursuer", Vector2(330, 190), 99)
        var corner_shot := cast(game, build, Vector2(286, 250), Vector2(0.6, -0.8))
        check(corner_shot.position.distance_to(Vector2(295, 238)) < 0.002, "Muzzle is clipped to the first swept corner contact")
        game.update_projectiles(0.2)
        check(game.enemies[0].hp == 42, "Muzzle offset cannot launch a shot past a blocking corner")
        if build.has("bounce"):
            check(corner_shot.bounces == 2 and corner_shot.wall_charged and corner_shot.direction.x < 0, "Muzzle corner reflection consumes Bounce and grants Wall Charge")
        else:
            check(game.projectiles.is_empty(), "Blocked muzzle removes a bolt without Bounce")
    reset(game)
    game.obstacles = []
    game.compiled = game.Spell.compile(["projectile", "bounce"])
    game.casts[901] = game.Spell.new_cast(901, game.compiled)
    game.add_projectile(Vector2(828, 454), Vector2(2, 1), false, 901)
    var outer_corner: Dictionary = game.projectiles.back()
    game.update_projectiles(0.4)
    check(outer_corner.position.distance_to(Vector2(928, 504)) < 0.002 and outer_corner.direction.distance_to(Vector2(-2, -1).normalized()) < 0.002, "Unequal simultaneous outer-wall contact reflects each independent axis")
    check(outer_corner.bounces == 2, "Simultaneous outer corner consumes one Bounce")

func run() -> void:
    root.size = Vector2i(960, 540)
    var game = Game.new()
    game.settings_path = "user://world-runtime-%d.cfg" % Time.get_ticks_usec()
    root.add_child(game)
    game.set_physics_process(false)
    check_review_regressions(game)
    game.show_menu()
    # Menu setup is deliberate, while legacy direct callers keep their original spell.
    check(game.next_setup.configured, "menu deliberately configures the displayed Ember starter")
    var setup_pickers: Array = []
    for row in game.content.get_children():
        for child in row.get_children():
            if child is OptionButton:
                setup_pickers.append(child)
    check(setup_pickers.size() == 3, "menu exposes expedition, challenge, and starter controls")
    for picker in setup_pickers:
        picker.item_selected.emit(1)
    check(game.next_setup.expedition == "archive" and game.next_setup.challenge == "four_slot" and game.next_setup.starting_choice == "frost", "visible setup controls update their own configuration fields")
    for picker in setup_pickers:
        picker.item_selected.emit(0)
    game.begin_setup_run(91)
    check(game.components == ["projectile", "fire"], "displayed Ember setup starts with Fire")
    game.start_run(91)
    check(game.components == ["projectile"] and game.obstacles.is_empty(), "direct Forge/open baseline remains projectile-only and empty")
    reset(game)
    game.spawn_enemy("pursuer", Vector2(700, 450), 99)
    Input.action_press("move_right")
    game.simulate(1)
    Input.action_release("move_right")
    check(is_equal_approx(game.player_pos.x, 286), "normal player movement sweeps rather than tunnels through cover")
    game.player_pos = Vector2(250, 300)
    game.dodge_time = 0.24
    game.dodge_direction = Vector2.RIGHT
    game.simulate(0.2)
    check(is_equal_approx(game.player_pos.x, 286), "dodge sweeps full high-speed travel")
    reset(game)
    game.player_pos = Vector2(600, 300)
    game.spawn_enemy("pursuer", Vector2(250, 300), 99)
    game.update_enemies(4)
    check(valid_circle(game.enemies[0].position, 13, game.obstacles, game.ARENA), "long-frame enemy movement cannot tunnel into cover")
    reset(game)
    game.player_pos = Vector2(600, 300)
    game.spawn_enemy("boss", Vector2(250, 300), 99)
    var warden: Dictionary = game.enemies[0]
    warden.attack_step = 2
    game.begin_enemy_warning(warden)
    check(is_equal_approx(warden.attack_target.x, 273), "Warden charge warning stops at body contact with cover")
    var hp_before: float = game.hp
    game.enemy_attack(warden)
    check(is_equal_approx(warden.position.x, 273) and game.hp == hp_before, "charge cannot teleport through terrain or damage beyond it")
    reset(game)
    game.player_pos = Vector2(400, 300)
    game.spawn_enemy("pursuer", Vector2(270, 300), 0)
    game.begin_enemy_warning(game.enemies[0])
    var melee_target: Vector2 = game.enemies[0].attack_target
    game.enemy_attack(game.enemies[0])
    check(game.enemies[0].position.is_equal_approx(melee_target) and is_equal_approx(melee_target.x, 287), "melee arrow endpoint and actual lunge share body-sized cover clipping")
    # Every authored route permits circle navigation from both sides of each block.
    for layout in 3:
        game.obstacles = Geometry.obstacles(layout, "forge", "reflector")
        for start in [Vector2(180, 300), Vector2(780, 300), Vector2(480, 140), Vector2(480, 460)]:
            var destination: Vector2 = game.ARENA.get_center()
            var position: Vector2 = start
            for tick in 1000:
                position = Geometry.move_circle(position, game.navigation_direction(position, destination, 14) * 3, 14, game.ARENA, game.obstacles)
                if position.distance_to(destination) < 4:
                    break
            check(position.distance_to(destination) < 4, "bounded navigation reaches center from route %d/%s" % [layout, start])
    reset(game)
    game.spawn_enemy("pursuer", Vector2(400, 300), 99)
    cast(game, ["projectile"])
    game.update_projectiles(1)
    check(game.enemies[0].hp == 42 and game.projectiles.is_empty(), "terrain shields enemies from friendly projectiles")
    reset(game)
    game.player_pos = Vector2(400, 300)
    game.add_projectile(Vector2(250, 300), Vector2.RIGHT, true)
    game.update_projectiles(1)
    check(game.hp == 100 and game.projectiles.is_empty(), "same terrain shields player from hostile projectiles")
    reset(game)
    game.spawn_enemy("pursuer", Vector2(275, 300), 99)
    var incoming := cast(game, ["projectile", "bounce", "wall_charge"], Vector2(230, 300))
    game.update_projectiles(1)
    check(is_equal_approx(game.enemies[0].hp, 26.7) and not incoming.wall_charged and incoming.bounces == 3, "enemy before wall is hit before bounce or Wall Charge")
    reset(game)
    var bank := cast(game, ["projectile", "bounce", "wall_charge"])
    game.update_projectiles(1)
    check(bank.position.is_equal_approx(Vector2(295, 300)) and bank.direction == Vector2.LEFT and bank.wall_charged and bank.bounces == 2, "internal reflection consumes one bounce and charges only at actual contact")
    game.update_projectiles(0.01)
    check(bank.bounces == 2 and bank.position.x < 295, "next tick leaves contact without repeated reflection")
    reset(game)
    game.spawn_enemy("pursuer", Vector2(400, 300), 99)
    game.compiled = game.Spell.compile(["projectile", "bounce", "wall_charge"])
    var safe_shot := cast(game, ["projectile", "bounce", "wall_charge"], Vector2(285, 300))
    check(valid_circle(safe_shot.position, 5, game.obstacles, game.ARENA.grow(5)) and not safe_shot.wall_charged, "initial shot overlap is projected without granting Wall Charge")
    reset(game)
    game.spawn_enemy("lane_archer", Vector2(250, 300), 99)
    game.player_pos = Vector2(400, 300)
    var archer: Dictionary = game.enemies[0]
    game.begin_enemy_warning(archer)
    check(is_equal_approx(archer.attack_target.x, 300), "visible line telegraph clips to cover")
    game.enemy_attack(archer)
    check(game.hp == 100 and game.effects[-1].target == archer.attack_target, "actual beam and effect use the clipped warning endpoint")
    game.player_pos = Vector2(280, 300)
    game.enemy_attack(archer)
    check(game.hp == 78, "uncovered part of clipped lane still damages")
    # Marks/explosions use line of sight at detonation; Dodge immunity remains central.
    reset(game)
    game.player_pos = Vector2(355, 300)
    game.hazards = [{"position": Vector2(290, 300), "radius": 80, "progress": 0.0, "life": 1.0}]
    game.update_hazards(1)
    check(game.hp == 100, "terrain also shields radial ground damage")
    # Independent-review repro: the blast at (480,180) must not visually include
    # a covered target at (480,237), while a clear target still takes real damage.
    reset(game)
    game.obstacles = Geometry.obstacles(1, "forge", "reflector")
    var blast_origin := Vector2(480, 180)
    game.spawn_enemy("bulwark", Vector2(480, 237), 99)
    game.spawn_enemy("bulwark", Vector2(530, 150), 99)
    game.delayed_blasts = [{"position": blast_origin, "radius": 72.0, "damage": 20.25, "remaining": 0.6, "duration": 0.6}]
    var blast_footprint := Geometry.radial_boundary(blast_origin, 72, game.ARENA, game.obstacles)
    check(not Geometry2D.is_point_in_polygon(game.enemies[0].position, blast_footprint) and Geometry2D.is_point_in_polygon(game.enemies[1].position, blast_footprint), "original covered/uncovered repro agrees with combat warning footprint")
    game.update_delayed_blasts(0.61)
    check(game.enemies[0].hp == 100 and is_equal_approx(game.enemies[1].hp, 79.75), "original repro: actual delayed blast shields covered enemy and damages clear enemy")
    var effect_footprint := Geometry.radial_boundary(game.effects[-1].origin, game.effects[-1].radius, game.ARENA, game.obstacles, 40)
    check(not Geometry2D.is_point_in_polygon(game.enemies[0].position, effect_footprint) and Geometry2D.is_point_in_polygon(game.enemies[1].position, effect_footprint), "actual detonation effect excludes the same shielded target")
    var repro_preview := Preview.new()
    repro_preview.size = Vector2(740, 76)
    repro_preview.terrain = game.obstacles.duplicate()
    var preview_footprint := repro_preview.blast_boundary(blast_origin, 72)
    check(not Geometry2D.is_point_in_polygon(repro_preview.point(game.enemies[0].position), preview_footprint) and Geometry2D.is_point_in_polygon(repro_preview.point(game.enemies[1].position), preview_footprint), "mapped preview warning/effect boundaries match covered/uncovered damage")
    repro_preview.free()
    game.player_pos = game.enemies[0].position
    game.hazards = [{"position": blast_origin, "radius": 72.0, "progress": 0.0, "life": 1.0}]
    game.update_hazards(1)
    check(game.hp == 100, "same clipped hazard footprint excludes the shielded player")
    game.player_pos = game.enemies[1].position
    game.hazards = [{"position": blast_origin, "radius": 72.0, "progress": 0.0, "life": 1.0}]
    game.update_hazards(1)
    check(game.hp == 78, "same hazard footprint still damages an uncovered player")
    # The announced ring gap is also safe under the actual hostile-shot collision.
    for stand_in_danger in [false, true]:
        reset(game)
        game.obstacles = []
        game.spawn_enemy("archivist", game.ARENA.get_center(), 99)
        game.player_pos = Vector2(700, 300)
        game.begin_enemy_warning(game.enemies[0])
        if stand_in_danger:
            game.player_pos = Vector2(480, 140)
        game.enemy_attack(game.enemies[0])
        game.update_projectiles(1.3)
        check(game.hp == (88 if stand_in_danger else 100), "actual ring %s agrees with locked gap and dangerous rays" % ("ray hit" if stand_in_danger else "safe gap"))
    # The detached preview copies actual terrain for both builds and preserves baseline fixtures.
    reset(game)
    game.components = ["projectile", "bounce", "wall_charge"]
    game.draft = game.components.duplicate()
    var snapshot := [game.enemies.duplicate(true), game.report.snapshot(), game.profile.data.duplicate(true), game.obstacles.duplicate()]
    var first := Preview.evaluate(game, game.draft, "cluster", game.obstacles)
    check(first.valid and first.obstacles == game.obstacles and first.description.contains("not a room rehearsal"), "preview labels current terrain as a controlled test scenario")
    check(first == Preview.evaluate(game, game.draft, "cluster", game.obstacles), "terrain preview reproduces every frame")
    check(snapshot == [game.enemies, game.report.snapshot(), game.profile.data, game.obstacles], "terrain evaluation preserves live state, profile, report, and terrain")
    var preview := Preview.new()
    preview.source = game
    preview.restart("cluster")
    check(preview.comparison.equipped == preview.comparison.draft and preview.terrain == game.obstacles, "paired comparison uses one identical terrain copy")
    var frame: Dictionary = first.frames[0]
    for target in frame.enemies:
        check(valid_circle(target.position, target.radius, game.obstacles, game.ARENA), "preview fixture targets project safely")
    # Direct runtime and detached evaluation share the exact first trajectory.
    reset(game)
    game.components = ["projectile", "bounce", "wall_charge"]
    game.draft = game.components.duplicate()
    var expected := Preview.evaluate(game, game.draft, "cluster", game.obstacles)
    game.enemies.clear()
    game.player_pos = Vector2(242, 300)
    game.aim = Vector2.RIGHT
    game.compiled = game.Spell.compile(game.draft)
    game.cast_spell()
    for tick in 120:
        game.update_projectiles(1.0 / 60)
        var expected_shots: Array = expected.frames[tick].projectiles
        check(game.projectiles == expected_shots, "preview/runtime collision trajectory tick %d" % tick)
    preview.free()
    var before_practice: Array = game.obstacles.duplicate()
    game.journey.show_practice()
    var practice_preview = game.content.get_node("SpellPreview")
    check(game.obstacles.is_empty() and practice_preview.terrain.is_empty(), "Practice clears inherited live terrain and uses its empty baseline")
    game.journey.leave_practice()
    check(game.obstacles == before_practice and not game.practice, "leaving Practice restores the run terrain without mutation")
    # Configured slot cap applies to preview and the forge submission path.
    game.challenge = "four_slot"
    game.draft = ["projectile", "fire", "pierce", "bounce", "cooldown"]
    check(not Preview.evaluate(game, game.draft).valid, "preview rejects five-slot challenge build")
    game.state = "reward"
    game.selected_reward = true
    var index_before: int = game.encounter_index
    game.apply_reward()
    check(game.encounter_index == index_before and game.state == "reward", "submission cannot bypass four-slot limit")
    game.start_run(50, {"challenge": "four_slot", "starting_choice": "frost"})
    game.owned = ["projectile", "frost", "pierce", "bounce", "cooldown"]
    game.components = ["projectile", "frost", "pierce", "bounce"]
    game.compiled = game.Spell.compile(game.components)
    game.encounter_clear()
    game.offers = ["fire", "restore"]
    game.choose_reward("fire")
    check(game.owned.has("fire") and game.draft.size() == 4 and not game.draft.has("fire"), "four-slot reward acquisition cannot autoequip fifth component")
    game.edit_draft("add", -1, "fire")
    check(game.draft.size() == 4, "four-slot editor rejects fifth component")
    var five_slot_recipe := {"name": "Too many", "components": ["projectile", "frost", "pierce", "bounce", "cooldown"]}
    check(game.journey.import_code(Share.encode_recipe(five_slot_recipe.name, five_slot_recipe.components)), "portable five-slot recipe may be stored as an idea")
    check(not game.journey.equip_recipe(five_slot_recipe) and game.draft.size() == 4, "stored or imported recipe cannot bypass four-slot equip limit")
    check(game.Profile.validate_checkpoint(game.checkpoint()), "four-slot checkpoint is valid before oversize-draft mutation")
    var invalid_checkpoint: Dictionary = game.checkpoint()
    invalid_checkpoint.draft = five_slot_recipe.components.duplicate()
    check(not game.Profile.validate_checkpoint(invalid_checkpoint), "checkpoint validator rejects fifth challenge slot")
    # A baseline direct caller remains projectile-only even after safe-forge resume/retry.
    game.start_run(51)
    game.encounter_clear()
    game.choose_reward("restore")
    check(game.resume_checkpoint() and game.retry_setup().is_empty(), "legacy baseline resume does not invent a configured starter on retry")
    # Route choice is a safe-forge checkpoint property and reconstructs the next room.
    game.start_run(121, {"expedition": "forge", "challenge": "four_slot", "starting_choice": "frost"})
    game.encounter_clear()
    game.choose_reward("restore")
    game.route = "reflector"
    check(game.save_checkpoint(), "route checkpoint saves at forge boundary")
    game.route = "open"
    check(game.resume_checkpoint() and game.route == "reflector" and game.challenge == "four_slot" and game.components.has("frost"), "checkpoint restores route, starter, and challenge")
    game.apply_reward()
    check(game.encounter_index == 1 and game.obstacles == game.Director.encounter(121, 1, "forge", "reflector").obstacles, "resumed route generates the promised next terrain")
    var code: String = Share.encode_challenge(72, "archive", "four_slot", "frost")
    check(game.journey.import_code(code), "portable Archive challenge imports")
    game.begin_setup_run(int(game.next_setup.seed))
    check(game.expedition == "archive" and game.route == "reflector" and game.max_slots() == 4 and game.components == ["projectile", "frost"], "imported challenge starts Archive/Frost/four-slot terrain")
    # Distinct boss: locked safe rays, locked ground marks, both phases and recovery.
    game.encounter_index = 6
    game.start_encounter()
    var archivist: Dictionary = game.enemies[0]
    check(archivist.kind == "archivist" and archivist.hp == 900 and archivist.position.distance_to(game.player_pos) >= 100, "Archive seventh room has safely separated 900 HP Archivist")
    game.player_pos = Vector2(700, 300)
    game.begin_enemy_warning(archivist)
    var gap: float = archivist.gap_angle
    var directions: Array = archivist.ring_directions.duplicate()
    var targets: Array = archivist.ring_targets.duplicate()
    check(archivist.attack_kind == "ring" and archivist.telegraph >= 1, "Archivist begins readable ring windup")
    for direction: Vector2 in directions:
        check(absf(wrapf(direction.angle() - gap, -PI, PI)) > archivist.gap_half, "every damaging ray avoids announced safe wedge")
    for i in directions.size():
        check(targets[i].is_equal_approx(Geometry.sweep(archivist.attack_origin, archivist.attack_origin + directions[i] * 1000, 6, game.ARENA.grow(6), game.obstacles).position), "ring warning endpoint matches hostile shot terrain sweep")
    game.player_pos = Vector2(480, 450)
    game.update_enemies(0.5)
    check(archivist.gap_angle == gap and archivist.ring_directions == directions and archivist.ring_targets == targets, "safe wedge and ray endpoints do not track during warning")
    game.update_enemies(0.61)
    check(game.projectiles.size() == directions.size() and archivist.timer >= 1.2, "ring emits exactly warned finite rays and enters recovery")
    for i in game.projectiles.size():
        check(game.projectiles[i].direction.is_equal_approx(directions[i]), "hostile ray direction equals telegraph")
    var step_before: int = archivist.attack_step
    game.update_enemies(1.19)
    check(archivist.telegraph <= 0 and archivist.attack_step == step_before, "recovery permits at least 1.2 seconds without another windup")
    game.projectiles.clear()
    game.player_pos = Vector2(700, 300)
    game.begin_enemy_warning(archivist)
    var marks: Array = archivist.mark_positions.duplicate()
    check(archivist.attack_kind == "archive_marks" and marks.size() == 1, "alternating pattern warns one locked mark in phase one")
    game.player_pos = Vector2(700, 420)
    game.update_enemies(1.11)
    check(archivist.mark_positions == marks and game.hazards.size() == 1 and game.hazards[0].position == marks[0], "ground marks retain their warned target when player moves")
    var health: float = game.hp
    game.update_hazards(1)
    check(game.hp == health and game.hazards.is_empty(), "leaving ground mark avoids delayed damage")
    archivist.hp = 449
    game.update_enemies(0)
    check(archivist.phase == 2 and archivist.position == game.ARENA.get_center(), "phase two retains stationary identity and health budget")
    game.begin_enemy_warning(archivist)
    check(archivist.attack_kind == "ring" and archivist.mark_positions.size() == 1, "phase-two ring adds only one delayed mark and retains safe wedge")
    game.update_enemies(1.11)
    check(archivist.timer >= 1.2 and game.projectiles.size() <= 24 and game.hazards.size() == 1, "phase-two ring remains bounded with recovery")
    game.begin_enemy_warning(archivist)
    check(archivist.mark_positions.size() == 3, "phase-two mark pattern adds two nearby warned positions")
    game.projectiles.clear()
    game.hazards.clear()
    for repetition in 20:
        game.enemy_attack(archivist)
    check(game.hazards.size() == 60, "mark generation stays finite before capacity")
    game.enemy_attack(archivist)
    game.enemy_attack(archivist)
    check(game.hazards.size() == 64, "Archivist marks obey 64-hazard capacity")
    game.hazards.clear()
    game.player_pos = marks[0]
    game.hurt_time = 0
    game.dodge_time = 0.2
    game.queue_archive_marks([game.player_pos])
    game.update_hazards(1)
    check(game.hp == health, "normal dodge immunity also blocks Archivist marks")
    game.dodge_time = 0
    game.queue_archive_marks([game.player_pos])
    game.update_hazards(1)
    check(game.hp == health - 22, "same visible mark damages outside dodge")
    game.hp = 1
    game.hurt_time = 0
    game.damage_player(5)
    check(game.state == "death", "Archive death uses normal summary")
    var retry: Dictionary = game.retry_setup()
    game.start_run(game.run_seed, retry)
    check(game.expedition == "archive" and game.run_seed == 72 and game.challenge == "four_slot" and game.components == ["projectile", "frost"] and game.route == "reflector" and game.encounter_index == 0, "retry preserves seed, expedition, slot limit and starter with initial route policy")
    # A deterministic invulnerable pilot clears the complete Archive through real
    # traveling spells and navigation, without setting enemy HP or teleporting damage.
    game.start_run(303, {"expedition": "archive", "challenge": "standard", "starting_choice": "ember"})
    game.owned = ["projectile", "fire", "pierce", "explode", "cooldown"]
    game.components = game.owned.duplicate()
    game.compiled = game.Spell.compile(game.components)
    game.report.event("spell_equipped", {"owned": game.owned, "equipped": game.components})
    release_input()
    game.simulate(1.0 / 60) # Release the menu-to-combat action latch before holding Cast.
    Input.action_press("cast")
    var total_ticks := 0
    for room in 7:
        var ticks := 0
        while game.state == "combat" and ticks < 18000:
            game.hurt_time = 1000 # Defensive-only fixture: this is not a balance claim.
            var target: Dictionary = {}
            for enemy in game.enemies:
                if enemy.hp > 0 and (target.is_empty() or enemy.position.distance_squared_to(game.player_pos) < target.position.distance_squared_to(game.player_pos)):
                    target = enemy
            if not target.is_empty():
                game.cursor_position = target.position
                var direction := Vector2.ZERO
                if game.player_pos.distance_to(target.position) > 160 or Geometry.sweep(game.player_pos, target.position, 6, game.ARENA.grow(6), game.obstacles).hit:
                    direction = game.navigation_direction(game.player_pos, target.position, 14)
                steer(direction)
            else:
                steer(Vector2.ZERO)
            game.simulate(1.0 / 60)
            ticks += 1
        total_ticks += ticks
        check(game.state == ("victory" if room == 6 else "reward"), "traveling-spell pilot completes Archive room %d within 300s (%d ticks)" % [room + 1, ticks])
        if game.state not in ["reward", "victory"]:
            print("PILOT STALLED: ", game.player_pos, " enemies=", game.enemies)
            break
        if room < 6:
            release_input()
            game.choose_reward("restore")
            game.apply_reward()
            game.simulate(1.0 / 60) # Each forge transition also requires a released frame.
            Input.action_press("cast")
    release_input()
    check(game.state == "victory" and game.encounter_index == 6 and game.profile.data.milestones.has("archive_win"), "complete alternative expedition reaches victory and records Archive milestone")
    print("Archive pilot: %d simulation ticks" % total_ticks)
    check(await game.audio.shutdown(), "test audio shuts down")
    for path in [game.settings_path, game.profile_path, game.bindings_path]:
        for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
    game.queue_free()
    await process_frame
    print("World runtime: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
