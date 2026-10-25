extends Node2D
const Spell = preload("res://scripts/spell_engine.gd")
const Director = preload("res://scripts/run_director.gd")
const Report = preload("res://scripts/run_report.gd")
const Profile = preload("res://scripts/player_profile.gd")
const Journey = preload("res://scripts/journey_ui.gd")
const Art = preload("res://scripts/presentation.gd")
const ARENA := Rect2(32, 88, 896, 416)
const MAX_PROJECTILES := 160
var state := "menu"
var run_seed := 1
var encounter_index := 0
var layout := 0
var player_pos := Vector2(480, 300)
var aim := Vector2.RIGHT
var cursor_position := Vector2(630, 300)
var hp := 100.0
var mana := 100.0
var cooldown := 0.0
var dodge_time := 0.0
var dodge_cooldown := 0.0
var hurt_time := 0.0
var dodge_direction := Vector2.RIGHT
var elapsed := 0.0
var visual_time := 0.0
var kills := 0
var next_id := 1
var cast_id := 0
var enemies: Array = []
var projectiles: Array = []
var hazards: Array = []
var pending_spawns: Array = []
var delayed_blasts: Array = []
var encounter_waves: Array = []
var next_wave := 0
var wave_threshold := 1
var spawn_warning := 1.0
var player_velocity := Vector2.ZERO
var effects: Array = []
var casts: Dictionary = {}
var owned: Array = ["projectile"]
var components: Array = ["projectile"]
var draft: Array = []
var compiled: Dictionary = {}
var offers: Array = []
var selected_component := "projectile"
var selected_reward := false
var resource_notice := ""
var resource_notice_time := 0.0
var message := ""
var message_time := 0.0
var settings_path := "user://settings.cfg"
var settings := {"master": 0.7, "music": 0.35, "sfx": 0.7, "shake": true, "reduced_flash": false}
var ui: CanvasLayer
var panel: PanelContainer
var content: VBoxContainer
var hud: Control
var audio: Node
var seed_input: LineEdit
var exit_requested := false
var profile_path := "user://profile.json"
var bindings_path := "user://bindings.json"
var profile_enabled := true
var storage_problem := false
var profile = Profile.new()
var report = Report.new()
var journey = Journey.new()
var journey_notice := ""
var practice := false
var expedition := "forge"
var challenge := "standard"
var starting_choice := "ember"
var route := "open"
var next_setup := {"expedition": "forge", "challenge": "standard", "starting_choice": "ember", "seed": 0, "seed_set": false, "configured": false}
var debrief: Dictionary = {}
var denial_times: Dictionary = {}

func max_slots() -> int:
    return 4 if challenge == "four_slot" else 5

func profile_active() -> bool:
    return is_inside_tree() and profile_enabled

func profile_feedback(success: bool, message_value: String) -> bool:
    journey_notice = message_value if success else profile.notice
    storage_problem = not success
    return success

func saving_available() -> bool:
    if profile_active():
        return true
    journey_notice = "Saving is off for this session. Recipes and checkpoints will not be saved."
    return false

func save_recipe(recipe_name: String, recipe_components: Array) -> bool:
    return profile_feedback(profile.save_recipe(recipe_name, recipe_components), "Recipe saved.") if saving_available() else false

func delete_recipe(recipe_name: String) -> bool:
    return profile_feedback(profile.delete_recipe(recipe_name), "Recipe deleted.") if saving_available() else false

func save_progress() -> bool:
    return profile_feedback(profile.save_profile(), "Workshop progress saved.") if saving_available() else false

func clear_checkpoint() -> bool:
    return profile_feedback(profile.clear_checkpoint(), "") if profile_active() else true

func checkpoint() -> Dictionary:
    return {"schema_version": 1, "content_version": "1", "seed": run_seed,
        "expedition": expedition, "challenge": challenge, "starting_choice": starting_choice,
        "encounter": encounter_index, "state": "reward", "hp": hp, "mana": mana,
        "owned": owned.duplicate(), "components": components.duplicate(), "draft": draft.duplicate(),
        "offers": offers.duplicate(), "selected_reward": selected_reward, "selected_component": selected_component,
        "elapsed": elapsed, "kills": kills, "report": report.snapshot(), "route": route}

func save_checkpoint() -> bool:
    if practice or state != "reward" or not profile_active():
        return false
    return profile_feedback(profile.set_checkpoint(checkpoint()), "Safe forge checkpoint saved.")

func suspend_run() -> void:
    if save_checkpoint():
        show_menu()
    else:
        show_reward()

func resume_checkpoint() -> bool:
    if not profile_active():
        return false
    var saved: Dictionary = profile.data.checkpoint.duplicate(true)
    var restored = Report.new()
    if not Profile.validate_checkpoint(saved) or not restored.restore(saved.get("report", {})) or restored.snapshot().finished:
        journey_notice = "Checkpoint is invalid; the current run was preserved."
        if state == "menu":
            show_menu()
        return false
    var restored_data: Dictionary = restored.snapshot()
    if int(restored_data.seed) != int(saved.seed) or restored_data.expedition != saved.expedition or restored_data.owned != saved.owned or restored_data.equipped != saved.components:
        journey_notice = "Checkpoint report does not match its run; the current run was preserved."
        if state == "menu":
            show_menu()
        return false
    practice = false
    report = restored
    run_seed = int(saved.seed)
    expedition = saved.expedition
    challenge = saved.challenge
    starting_choice = saved.starting_choice
    route = saved.route
    encounter_index = int(saved.encounter)
    hp = float(saved.hp)
    mana = float(saved.mana)
    owned = saved.owned.duplicate()
    components = saved.components.duplicate()
    draft = saved.draft.duplicate()
    offers = saved.offers.duplicate()
    selected_reward = saved.selected_reward
    selected_component = saved.selected_component if not str(saved.selected_component).is_empty() else draft[0]
    elapsed = float(saved.elapsed)
    kills = int(saved.kills)
    compiled = Spell.compile(components)
    enemies.clear()
    projectiles.clear()
    hazards.clear()
    casts.clear()
    state = "reward"
    show_reward()
    return true

func abandon_run() -> void:
    if clear_checkpoint():
        show_menu()
    else:
        label_text(journey_notice, 14)

func play_without_saving() -> void:
    if state != "menu":
        return
    profile_enabled = false
    journey_notice = "Saving is off for this session. Recipes and checkpoints will not be saved."
    begin_from_menu()
    if state == "combat":
        resource_notice = "Saving is off · no checkpoints this session"
        resource_notice_time = 3.0

func reject_seed() -> void:
    journey_notice = "Use a whole-number seed from -9007199254740991 to 9007199254740991."
    resource_notice = "Seed out of range · current run preserved"
    resource_notice_time = 3.0
    if state == "menu":
        show_menu()

func begin_from_menu() -> void:
    var value := seed_input.text.strip_edges()
    if value.is_empty():
        begin_setup_run(int(next_setup.seed) if next_setup.get("seed_set", false) else int(Time.get_unix_time_from_system()))
        return
    var digits := value.trim_prefix("-").trim_prefix("+")
    while digits.begins_with("0"):
        digits = digits.trim_prefix("0")
    if not value.is_valid_int() or digits.length() > 16 or (digits.length() == 16 and digits > "9007199254740991"):
        reject_seed()
        return
    begin_setup_run(int(value))

func begin_setup_run(seed_value: int) -> void:
    start_run(seed_value, next_setup if next_setup.get("configured", false) else {})

func deny_cast(reason: String) -> void:
    if not is_inside_tree() or practice:
        return
    # Held input reports at most once per second for each denial reason.
    if elapsed - float(denial_times.get(reason, -100.0)) >= 1.0:
        report.event("cast_denied", {"reason": reason, "mana": mana, "needed": compiled.get("mana_cost", 8)})
        denial_times[reason] = elapsed


func _ready() -> void:
    get_tree().auto_accept_quit = false
    var smoke_test := OS.is_debug_build() and "--smoke-test" in OS.get_cmdline_user_args()
    if smoke_test:
        settings_path = "user://export-smoke-%d.cfg" % Time.get_ticks_usec()
    if settings_path != "user://settings.cfg":
        if profile_path == "user://profile.json":
            profile_path = settings_path + ".profile.json"
        if bindings_path == "user://bindings.json":
            bindings_path = settings_path + ".bindings.json"
    profile.path = profile_path
    if profile_enabled:
        storage_problem = not profile.load_profile()
        journey_notice = profile.notice
    journey.game = self
    load_settings()
    audio = Art.create_audio()
    add_child(audio)
    apply_audio()
    ui = CanvasLayer.new()
    add_child(ui)
    hud = preload("res://scripts/combat_hud.gd").new()
    hud.game = self
    ui.add_child(hud)
    panel = PanelContainer.new()
    panel.position = Vector2(80, 94)
    panel.custom_minimum_size = Vector2(800, 340)
    var surface := StyleBoxFlat.new()
    surface.bg_color = Art.INK
    surface.border_color = Art.TEAL.darkened(0.4)
    surface.set_border_width_all(2)
    surface.content_margin_left = 18
    surface.content_margin_right = 18
    surface.content_margin_top = 12
    surface.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", surface)
    ui.add_child(panel)
    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)
    show_menu()
    if smoke_test:
        call_deferred("run_export_smoke")

func run_export_smoke() -> void:
    await preload("res://scripts/export_smoke.gd").new().run(self)

func clear_panel() -> void:
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    panel.size = Vector2(800, 340)
    content.add_theme_constant_override("separation", 5)
    var surface = panel.get_theme_stylebox("panel").duplicate()
    surface.border_color = Color(0.9, 0.5, 0.2) if profile.data.workshop == "ember" else Color(0.45, 0.75, 1.0)
    panel.add_theme_stylebox_override("panel", surface)
    panel.show()

func label_text(value: String, size: int = 18) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(label)
    return label

func button(value: String, action: Callable, tip: String = "") -> Button:
    var item := Button.new()
    item.text = value
    item.tooltip_text = tip
    item.pressed.connect(action)
    content.add_child(item)
    return item

func show_menu() -> void:
    state = "menu"
    effects.clear()
    pending_spawns.clear()
    delayed_blasts.clear()
    clear_panel()
    label_text("SPELLFORGE", 36)
    label_text("Build a spell. Survive six trials. Break the Warden.")
    seed_input = LineEdit.new()
    seed_input.max_length = 32
    seed_input.placeholder_text = "Run seed (blank for a new adventure)"
    seed_input.tooltip_text = "The same integer repeats encounters and reward choices."
    content.add_child(seed_input)
    button("Begin run", begin_from_menu)
    if profile_enabled and not profile.data.checkpoint.is_empty():
        button("Resume safe forge", resume_checkpoint)
    var extras := HBoxContainer.new()
    content.add_child(extras)
    for entry in [["Practice forge", journey.show_practice], ["First experiment" if not profile.data.tutorial_seen else "Experiment guide", journey.show_tutorial], ["Workshop", journey.show_workshop], ["Share / import", journey.show_sharing]]:
        var item := button(entry[0], entry[1])
        content.remove_child(item)
        extras.add_child(item)
    if profile_enabled and storage_problem:
        var offline_button := button("Play without saving", play_without_saving)
        content.remove_child(offline_button)
        extras.add_child(offline_button)
    if not profile_enabled:
        journey_notice = "Saving is off for this session. Recipes and checkpoints will not be saved."
    if not journey_notice.is_empty():
        var notice := label_text(journey_notice, 13)
        notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button("Settings", func(): show_settings("menu"))
    button("Credits", show_credits)
    button("Quit", request_exit)
    label_text("WASD / arrows: move · Mouse: aim · Hold left click: cast\nSpace: dodge · Esc: pause · Craft between encounters", 15)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        request_exit()

func request_exit() -> void:
    if exit_requested:
        return
    exit_requested = true
    state = "shutdown"
    if is_instance_valid(audio):
        if not await audio.shutdown():
            push_warning("Audio shutdown timed out; exiting with playback cleanup pending.")
    get_tree().quit()

func show_credits() -> void:
    state = "credits"
    clear_panel()
    label_text("CREDITS & ENGINE LICENSES", 24)
    var credits := TextEdit.new()
    credits.editable = false
    credits.custom_minimum_size = Vector2(600, 240)
    credits.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    var project_license := FileAccess.get_file_as_string("res://assets/LICENSE.txt")
    credits.text = "Spellforge\nOriginal code, documentation, procedural visuals and synthesized music/sound effects: MIT License.\n\nPROJECT LICENSE\n" + project_license + "\n\nGodot Engine\n" + Engine.get_license_text()
    credits.text += "\n\nTHIRD-PARTY ATTRIBUTIONS\n"
    for entry in Engine.get_copyright_info():
        credits.text += str(entry.get("name", "")) + "\n"
        for part in entry.get("parts", []):
            credits.text += "Files: " + ", ".join(part.get("files", [])) + "\n"
            credits.text += "Copyright: " + "; ".join(part.get("copyright", [])) + "\n"
            credits.text += "License: " + str(part.get("license", "")) + "\n\n"
    var licenses: Dictionary = Engine.get_license_info()
    for license_name in licenses:
        credits.text += "\n" + str(license_name) + "\n" + str(licenses[license_name]) + "\n"
    content.add_child(credits)
    button("Back", show_menu)

func start_run(seed_value: int, setup: Dictionary = {}) -> void:
    if seed_value < -9007199254740991 or seed_value > 9007199254740991:
        reject_seed()
        return
    if not clear_checkpoint():
        show_menu()
        return
    practice = false
    expedition = str(setup.get("expedition", "forge"))
    challenge = str(setup.get("challenge", "standard"))
    starting_choice = str(setup.get("starting_choice", "ember"))
    route = "open"
    report.reset(seed_value, expedition)
    denial_times.clear()
    run_seed = seed_value
    encounter_index = 0
    hp = 100.0
    mana = 100.0
    elapsed = 0.0
    kills = 0
    next_id = 1
    cast_id = 0
    owned = ["projectile"]
    selected_component = "projectile"
    components = ["projectile"]
    if not setup.is_empty():
        var starter := "frost" if starting_choice == "frost" else "fire"
        owned.append(starter)
        components.append(starter)
    compiled = Spell.compile(components)
    report.event("run_started", {"owned": owned, "equipped": components})
    message = ""
    start_encounter()

func start_encounter() -> void:
    state = "combat"
    message = "WARDEN CHAMBER · break the Warden" if encounter_index == 6 else "TRIAL %d / 6 · clear every enemy" % (encounter_index + 1)
    message_time = 2.5
    resource_notice = ""
    resource_notice_time = 0.0
    panel.hide()
    enemies.clear()
    projectiles.clear()
    hazards.clear()
    effects.clear()
    pending_spawns.clear()
    delayed_blasts.clear()
    casts.clear()
    cooldown = 0.0
    dodge_time = 0.0
    dodge_cooldown = 0.0
    hurt_time = 1.0
    player_pos = ARENA.get_center()
    var encounter: Dictionary = Director.encounter(run_seed, encounter_index)
    layout = encounter.layout
    encounter_waves = encounter.get("waves", [encounter.roster]).duplicate(true)
    next_wave = 0
    wave_threshold = int(encounter.get("wave_threshold", 1))
    spawn_warning = float(encounter.get("spawn_warning", 1.0))
    queue_wave(true)
    audio.play_sfx("reward")

func queue_wave(immediate: bool = false) -> void:
    if next_wave >= encounter_waves.size():
        return
    var roster: Array = encounter_waves[next_wave]
    var rng := RandomNumberGenerator.new()
    rng.seed = run_seed + encounter_index * 7919 + next_wave * 3571
    for i in roster.size():
        var angle := TAU * float(i) / maxi(1, roster.size()) + rng.randf_range(-0.12, 0.12)
        var pos := ARENA.get_center() + Vector2(cos(angle) * 340, sin(angle) * 155)
        if pos.distance_to(player_pos) < 100:
            pos = ARENA.get_center() - (pos - ARENA.get_center())
        if immediate:
            spawn_enemy(roster[i], pos, rng.randf_range(0.8, 2.0))
        else:
            pending_spawns.append({"kind": roster[i], "position": pos, "remaining": spawn_warning, "duration": spawn_warning})
    next_wave += 1

func update_spawns(delta: float) -> void:
    for spawn in pending_spawns:
        spawn.remaining -= delta
        if spawn.remaining <= 0:
            # The player may approach a warning; postpone materialization until safe.
            if spawn.position.distance_to(player_pos) < 100:
                spawn.remaining = 0.05
            else:
                spawn_enemy(spawn.kind, spawn.position, 0.8)
    pending_spawns = pending_spawns.filter(func(spawn): return spawn.remaining > 0)
    if pending_spawns.is_empty() and enemies.filter(func(enemy): return enemy.hp > 0).size() <= wave_threshold:
        queue_wave()

func spawn_enemy(kind: String, pos: Vector2, timer: float) -> void:
    var health: float = {"pursuer": 42.0, "archer": 34.0, "lane_archer": 34.0, "swarm": 18.0, "bulwark": 100.0, "channeler": 48.0, "boss": 900.0}[kind]
    enemies.append({"id": next_id, "kind": kind, "position": pos, "hp": health, "max_hp": health, "radius": 27.0 if kind == "boss" else 13.0, "telegraph": 0.0, "aim": Vector2.DOWN, "phase": 1, "timer": timer, "burn": {}, "attack_step": 0, "frost_until": 0.0})
    next_id += 1

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        cursor_position = get_global_transform_with_canvas().affine_inverse() * event.position

func _unhandled_input(event: InputEvent) -> void:
    # Action events reject keyboard echoes by default and remain unhandled-only.
    if event.is_action_pressed("pause"):
        toggle_pause()
    elif event.is_action_pressed("dodge") and state == "combat" and dodge_cooldown <= 0:
        dodge_time = 0.24
        dodge_cooldown = 1.05
        dodge_direction = movement_direction()
        if dodge_direction == Vector2.ZERO:
            dodge_direction = aim
        audio.play_sfx("dodge")

func movement_direction() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(delta: float) -> void:
    visual_time += delta
    if state == "combat":
        simulate(delta)
    elif not practice:
        report.advance(state, delta)
    update_hud()
    queue_redraw()

func simulate(delta: float) -> void:
    if state != "combat":
        return
    elapsed += delta
    report.advance("combat", delta)
    cooldown = maxf(0, cooldown - delta)
    dodge_time = maxf(0, dodge_time - delta)
    dodge_cooldown = maxf(0, dodge_cooldown - delta)
    hurt_time = maxf(0, hurt_time - delta)
    message_time = maxf(0, message_time - delta)
    resource_notice_time = maxf(0, resource_notice_time - delta)
    var previous_mana := mana
    mana = minf(100, mana + delta * 22)
    if mana > previous_mana:
        report.event("mana_restored", {"amount": mana - previous_mana})
    aim = (cursor_position - player_pos).normalized()
    if aim == Vector2.ZERO:
        aim = Vector2.RIGHT
    player_velocity = dodge_direction * 650 if dodge_time > 0 else movement_direction() * 220
    player_pos += player_velocity * delta
    player_pos = player_pos.clamp(ARENA.position + Vector2(14, 14), ARENA.end - Vector2(14, 14))
    if Input.is_action_pressed("cast"):
        cast_spell()
    update_enemies(delta)
    if state != "combat":
        return
    update_delayed_blasts(delta)
    update_projectiles(delta)
    if state != "combat":
        return
    update_hazards(delta)
    if state != "combat":
        return
    update_spawns(delta)
    update_effects(delta)
    enemies = enemies.filter(func(e): return e.hp > 0)
    if state == "combat" and enemies.is_empty() and pending_spawns.is_empty() and next_wave >= encounter_waves.size():
        encounter_clear()

func cast_spell() -> bool:
    if state != "combat":
        return false
    if cooldown > 0:
        deny_cast("cooldown")
        return false
    if mana < float(compiled.mana_cost):
        deny_cast("mana")
        resource_notice = "Mana recovering · need %d mana" % compiled.mana_cost
        resource_notice_time = 1.0
        return false
    if projectiles.size() >= MAX_PROJECTILES:
        deny_cast("capacity")
        return false
    mana -= float(compiled.mana_cost)
    report.event("mana_spent", {"amount": float(compiled.mana_cost)})
    cooldown = compiled.cooldown
    cast_id += 1
    casts[cast_id] = Spell.new_cast(cast_id, compiled.duplicate(true))
    add_projectile(player_pos + aim * 18, aim, false, cast_id, 0)
    audio.play_sfx("cast")
    return true

func add_projectile(pos: Vector2, direction: Vector2, hostile: bool, owner: int = 0, generation: int = 0) -> void:
    if projectiles.size() >= MAX_PROJECTILES:
        return
    var spell: Dictionary = casts[owner].compiled if not hostile and casts.has(owner) else compiled
    projectiles.append({"position": pos, "direction": direction.normalized(), "enemy": hostile, "fire": false if hostile else bool(spell.fire), "radius": 6.0 if hostile else 5.0, "life": 5.0 if hostile else float(spell.life), "speed": 180.0 if hostile else float(spell.speed), "cast_id": owner, "generation": generation, "hit_ids": [], "wall_charged": false, "wall_charge": false if hostile else bool(spell.get("wall_charge", false)), "frost": false if hostile else bool(spell.get("frost", false)) and generation == 0, "pierce": 0 if hostile else int(spell.pierce), "bounces": 0 if hostile else int(spell.bounces)})

func update_enemies(delta: float) -> void:
    for enemy in enemies:
        if state != "combat":
            return
        if enemy.hp <= 0:
            continue
        if not enemy.burn.is_empty():
            var active_delta := maxf(0.0, minf(elapsed, float(enemy.burn.expires_at)) - (elapsed - delta))
            hurt_enemy(enemy, float(enemy.burn.dps) * active_delta, false)
            if elapsed >= float(enemy.burn.expires_at):
                enemy.burn = {}
        if enemy.hp <= 0:
            continue
        if elapsed >= float(enemy.get("frost_until", 0.0)):
            enemy.frost_amount = 0.0
        var to_player: Vector2 = player_pos - enemy.position
        var distance := to_player.length()
        if enemy.kind == "boss" and enemy.hp < enemy.max_hp * 0.5 and enemy.phase == 1:
            enemy.phase = 2
            message = "WARDEN ENRAGED · watch the marks!"
            message_time = 3.0
        if enemy.telegraph > 0:
            enemy.telegraph -= delta
            if enemy.telegraph <= 0:
                enemy_attack(enemy)
                enemy.timer = 1.2 if enemy.phase == 2 else 2.0
        else:
            enemy.aim = to_player.normalized()
            var speed: float = {"pursuer": 91.0, "swarm": 135.0, "bulwark": 52.0, "archer": 47.0, "lane_archer": 47.0, "channeler": 35.0, "boss": 45.0}[enemy.kind]
            if elapsed < float(enemy.get("frost_until", 0.0)):
                speed *= 0.9 if enemy.kind == "boss" else 0.75
            if distance > (210 if enemy.kind in ["archer", "lane_archer", "channeler"] else 38):
                enemy.position += enemy.aim * speed * delta
            enemy.timer -= delta
            if enemy.timer <= 0:
                begin_enemy_warning(enemy)
        enemy.position = enemy.position.clamp(ARENA.position + Vector2(28, 28), ARENA.end - Vector2(28, 28))
        if distance < enemy.radius + 11:
            damage_player(8.0, "contact")

func begin_enemy_warning(enemy: Dictionary) -> void:
    var kind := "melee"
    var duration := 0.8 if enemy.kind != "swarm" else 0.45
    if enemy.kind == "lane_archer":
        kind = "lane"
        duration = 0.9
    elif enemy.kind == "boss":
        var sequence: Array = ["fan", "sweep", "charge"] if enemy.phase == 1 else ["charge", "fan", "sweep", "fan", "charge", "sweep"]
        kind = sequence[int(enemy.get("attack_step", 0)) % sequence.size()]
        enemy.attack_step = int(enemy.get("attack_step", 0)) + 1
        duration = 1.0
    elif enemy.kind == "archer":
        kind = "fan"
    elif enemy.kind == "channeler":
        kind = "mark"
    enemy.attack_shots = 5 if enemy.kind == "boss" else 1
    enemy.attack_kind = kind
    enemy.warning_duration = duration
    enemy.telegraph = duration
    enemy.attack_origin = enemy.position
    var predicted: Vector2 = (player_pos + player_velocity * 0.3).clamp(ARENA.position + Vector2(28, 28), ARENA.end - Vector2(28, 28))
    enemy.aim = (predicted - enemy.position).normalized()
    enemy.attack_target = predicted
    enemy.attack_width = 16.0 if kind == "lane" else float(enemy.radius) if kind == "charge" else 30.0
    if kind in ["lane", "sweep"]:
        enemy.attack_target = enemy.position + enemy.aim * 700.0

func enemy_attack(enemy: Dictionary) -> void:
    var kind: String = enemy.get("attack_kind", "melee")
    if kind == "fan":
        var count := int(enemy.get("attack_shots", 5 if enemy.kind == "boss" else 1))
        for i in count:
            add_projectile(enemy.position, enemy.aim.rotated((i - (count - 1) / 2.0) * 0.22), true)
    elif kind in ["lane", "sweep"]:
        if segment_contact(player_pos, float(enemy.attack_width) + 11.0, enemy.attack_origin, enemy.attack_target) != INF:
            damage_player(22.0, kind)
        add_effect("chain", enemy.attack_origin, enemy.attack_target, 0)
    elif kind == "mark":
        hazards.append({"position": enemy.get("attack_target", player_pos), "radius": 38.0, "progress": 0.0, "life": 1.2, "source": "hazard"})
    elif kind == "charge" or enemy.kind in ["pursuer", "swarm", "bulwark"]:
        var origin: Vector2 = enemy.position
        var destination: Vector2 = enemy.get("attack_target", origin) if kind == "charge" else origin + enemy.aim * (45 if enemy.kind == "bulwark" else 68)
        destination = destination.clamp(ARENA.position + Vector2(28, 28), ARENA.end - Vector2(28, 28))
        if segment_contact(player_pos, float(enemy.radius) + 11.0, origin, destination) != INF:
            damage_player(15.0, kind)
        enemy.position = destination

func update_projectiles(delta: float) -> void:
    var current: Array = projectiles.duplicate()
    for projectile in current:
        if state != "combat":
            return
        var travel_time := minf(delta, maxf(0.0, projectile.life))
        if travel_time <= 0:
            continue
        var previous: Vector2 = projectile.position
        var destination: Vector2 = previous + projectile.direction * projectile.speed * travel_time
        # Clip to the first wall; contacts on the incoming segment precede reflection.
        var wall_fraction := 1.0
        var movement: Vector2 = destination - previous
        for axis in 2:
            if movement[axis] > 0 and destination[axis] >= ARENA.end[axis]:
                wall_fraction = minf(wall_fraction, (ARENA.end[axis] - previous[axis]) / movement[axis])
            elif movement[axis] < 0 and destination[axis] <= ARENA.position[axis]:
                wall_fraction = minf(wall_fraction, (ARENA.position[axis] - previous[axis]) / movement[axis])
        destination = previous.lerp(destination, clampf(wall_fraction, 0.0, 1.0))
        var consumed := false
        if projectile.enemy:
            var contact := segment_contact(player_pos, 15.0, previous, destination)
            if contact != INF:
                projectile.position = previous.lerp(destination, contact)
                damage_player(12.0, "projectile")
                consumed = true
        else:
            var contacts: Array = []
            for enemy in enemies:
                if enemy.hp <= 0 or projectile.hit_ids.has(enemy.id):
                    continue
                var contact := segment_contact(enemy.position, enemy.radius + projectile.radius, previous, destination)
                if contact != INF:
                    contacts.append({"enemy": enemy, "time": contact})
            contacts.sort_custom(func(a, b): return a.time < b.time if a.time != b.time else a.enemy.id < b.enemy.id)
            for contact in contacts:
                if contact.enemy.hp <= 0:
                    continue
                projectile.position = previous.lerp(destination, contact.time)
                resolve_projectile_hit(projectile, contact.enemy)
                if projectile.pierce <= 0:
                    consumed = true
                    break
                projectile.pierce -= 1
        if not consumed:
            projectile.position = destination
            var hit_x: bool = (destination.x >= ARENA.end.x and projectile.direction.x > 0) or (destination.x <= ARENA.position.x and projectile.direction.x < 0)
            var hit_y: bool = (destination.y >= ARENA.end.y and projectile.direction.y > 0) or (destination.y <= ARENA.position.y and projectile.direction.y < 0)
            if hit_x or hit_y:
                if Spell.consume_bounce(projectile):
                    if hit_x:
                        projectile.direction.x *= -1
                    if hit_y:
                        projectile.direction.y *= -1
                else:
                    consumed = true
        projectile.life = 0.0 if consumed else maxf(0.0, projectile.life - delta)
    projectiles = projectiles.filter(func(p): return p.life > 0)
    var live: Dictionary = {}
    for projectile in projectiles:
        if not projectile.enemy:
            live[projectile.cast_id] = true
    for id in casts.keys():
        if not live.has(id):
            casts.erase(id)

# First swept circle contact as a fraction of the segment, including initial overlap.
func segment_contact(point: Vector2, radius: float, start: Vector2, finish: Vector2) -> float:
    var offset := start - point
    var c := offset.length_squared() - radius * radius
    if c <= 0:
        return 0.0
    var movement := finish - start
    var a := movement.length_squared()
    if a <= 0:
        return INF
    var b := offset.dot(movement)
    var discriminant := b * b - a * c
    if discriminant < 0:
        return INF
    var contact := (-b - sqrt(discriminant)) / a
    return contact if contact >= 0 and contact <= 1 else INF

func resolve_projectile_hit(projectile: Dictionary, enemy: Dictionary) -> void:
    var targets: Array = []
    for candidate in enemies:
        if candidate.hp > 0:
            targets.append({"id": candidate.id, "position": candidate.position})
    if not casts.has(projectile.cast_id):
        return
    var events: Array = Spell.resolve_hit(casts[projectile.cast_id], projectile, enemy.id, targets)
    if not projectile.hit_ids.has(enemy.id):
        projectile.hit_ids.append(enemy.id)
    # World capacity rejects the entire reserved Split pair; never emit half a pair.
    # Resolver budgets remain consumed, so rejection cannot retry or bypass limits.
    var split_count := events.filter(func(event): return event.type == "split").size()
    var allow_split := projectiles.size() + split_count <= MAX_PROJECTILES
    var chain_origin: Vector2 = projectile.position
    for event in events:
        match event.type:
            "damage", "chain":
                if event.type == "chain":
                    for target in enemies:
                        if target.id == event.target_id:
                            add_effect("chain", chain_origin, target.position, 0.0)
                            chain_origin = target.position
                for target in enemies:
                    if target.id == event.target_id:
                        var amount := float(event.amount)
                        if target.kind == "bulwark" and projectile.direction.dot(target.aim) < -0.35:
                            amount *= 0.55
                        hurt_enemy(target, amount)
                        if event.get("frost", false):
                            target.frost_until = elapsed + 1.0
                            target.frost_amount = 0.1 if target.kind == "boss" else 0.25
                        if event.get("burn", false):
                            target.burn = Spell.refresh_burn(target.burn, Spell.BURN_DPS, elapsed)
            "split":
                if allow_split:
                    add_projectile(event.position, event.direction, false, projectile.cast_id, 1)
            "delayed_explode":
                if delayed_blasts.size() < 64:
                    delayed_blasts.append({"position": event.position, "radius": event.radius, "damage": event.damage, "remaining": event.delay, "duration": event.delay})
            "explode":
                add_effect("explode", event.position, event.position, float(event.radius))
                for target in enemies:
                    if target.position.distance_to(event.position) <= event.radius:
                        hurt_enemy(target, float(event.damage))

func update_delayed_blasts(delta: float) -> void:
    if state != "combat":
        return
    for blast in delayed_blasts:
        blast.remaining -= delta
        if blast.remaining <= 0:
            add_effect("explode", blast.position, blast.position, float(blast.radius))
            for target in enemies:
                if target.hp > 0 and target.position.distance_to(blast.position) <= blast.radius:
                    hurt_enemy(target, float(blast.damage))
    delayed_blasts = delayed_blasts.filter(func(blast): return blast.remaining > 0)

# Cosmetic effects have no collision or damage authority.
func add_effect(kind: String, origin: Vector2, target: Vector2, radius: float) -> void:
    if effects.size() >= 64:
        effects.pop_front()
    effects.append({"kind": kind, "origin": origin, "target": target, "radius": radius, "life": 0.3})

func update_effects(delta: float) -> void:
    for effect in effects:
        effect.life -= delta
    effects = effects.filter(func(effect): return effect.life > 0)

func hurt_enemy(enemy: Dictionary, amount: float, sound: bool = true) -> void:
    if enemy.hp <= 0:
        return
    report.event("damage_dealt", {"amount": minf(maxf(0, amount), float(enemy.hp))})
    enemy.hp -= amount
    if enemy.hp <= 0:
        kills += 1
        audio.play_sfx("hit")
    elif sound:
        audio.play_sfx("hit")

func update_hazards(delta: float) -> void:
    for hazard in hazards:
        if state != "combat":
            return
        hazard.progress += delta / hazard.life
        if hazard.progress >= 1 and (segment_contact(player_pos, float(hazard.width) + 11.0, hazard.origin, hazard.target) != INF if hazard.get("kind", "circle") == "lane" else player_pos.distance_to(hazard.position) < hazard.radius + 11):
            damage_player(22.0, str(hazard.get("source", "unknown")))
    hazards = hazards.filter(func(h): return h.progress < 1)

func damage_player(amount: float, source: String = "unknown") -> void:
    if state != "combat" or dodge_time > 0 or hurt_time > 0:
        return
    report.event("damage_taken", {"amount": minf(maxf(amount, 0), hp), "source": source})
    hp = maxf(0, hp - amount)
    hurt_time = 0.65
    audio.play_sfx("hit")
    if hp <= 0:
        finish_run(false)

func encounter_clear() -> void:
    projectiles.clear()
    hazards.clear()
    effects.clear()
    pending_spawns.clear()
    delayed_blasts.clear()
    casts.clear()
    if encounter_index >= 6:
        finish_run(true)
        return
    state = "reward"
    var previous_hp := hp
    hp = minf(100, hp + 15)
    report.event("health_restored", {"amount": hp - previous_hp})
    report.event("mana_restored", {"amount": 100 - mana})
    mana = 100
    offers = Director.rewards(run_seed, encounter_index, owned)
    selected_reward = false
    draft = components.duplicate()
    report.event("reward_offered", {"encounter": encounter_index, "offered": offers, "owned": owned, "equipped": components})
    if profile_active():
        profile.discover(owned)
        profile.milestone("first_clear")
        save_checkpoint()
    show_reward()

func choose_reward(id: String) -> void:
    if state != "reward" or selected_reward or not offers.has(id):
        return
    selected_reward = true
    audio.play_sfx("reward")
    if id == "restore":
        var previous_hp := hp
        hp = minf(100, hp + 25)
        report.event("health_restored", {"amount": hp - previous_hp})
    elif not owned.has(id):
        owned.append(id)
        selected_component = id
        if draft.size() < max_slots() and Spell.compile(draft + [id]).valid:
            draft.append(id)
    report.event("reward_chosen", {"encounter": encounter_index, "chosen": [id], "owned": owned, "equipped": components})
    if profile_active():
        profile.discover(owned)
        save_checkpoint()
    show_reward()

func component_icon(id: String) -> String:
    return {"projectile": "◆", "fire": "▲", "pierce": "⇥", "split": "⑂", "bounce": "↔", "chain": "ϟ", "explode": "✦", "cooldown": "◷", "frost": "❄", "wall_charge": "↯", "delayed_blast": "◉", "restore": "+"}.get(id, "◆")

func component_use(id: String) -> String:
    return {"frost": "Slow movement, not enemy attacks.", "wall_charge": "Requires Bounce equipped; aim at a wall.", "delayed_blast": "Requires Explode equipped; enemies can escape the marker.", "projectile": "Your spell starts here.", "fire": "Wear down durable enemies.", "pierce": "Aim through a line of enemies.", "split": "Spread into nearby enemies.", "bounce": "Use walls for another pass.", "chain": "Connect clustered enemies.", "explode": "Strike tightly packed groups.", "cooldown": "Spend mana faster for rapid casts."}.get(id, "Recover before the next trial.")

func edit_draft(action: String, index: int = -1, id: String = "") -> void:
    if state not in ["reward", "practice"] or not selected_reward:
        return
    var previous_draft := draft.duplicate()
    match action:
        "remove":
            if index > 0 and index < draft.size():
                draft.remove_at(index)
        "left", "right":
            var destination := index + (-1 if action == "left" else 1)
            if index > 0 and index < draft.size() and destination > 0 and destination < draft.size():
                var previous = draft[index]
                draft[index] = draft[destination]
                draft[destination] = previous
        "add":
            if owned.has(id) and not draft.has(id) and draft.size() < max_slots():
                draft.append(id)
    if not Spell.compile(draft).valid:
        draft = previous_draft
    if not draft.has(selected_component):
        selected_component = draft[0]
    if not practice:
        save_checkpoint()
    show_reward()

func show_reward() -> void:
    clear_panel()
    content.add_theme_constant_override("separation", 3)
    label_text("PRACTICE FORGE · no run progress" if practice else "TRIAL %d CLEARED · +15 health" % (encounter_index + 1), 24)
    var catalog: Dictionary = Spell.catalog()
    if not selected_reward:
        label_text("Choose one component or recover health", 17)
        var cards := HBoxContainer.new()
        cards.add_theme_constant_override("separation", 10)
        content.add_child(cards)
        for id in offers:
            var card := Button.new()
            card.custom_minimum_size = Vector2(245, 190)
            card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            card.text = ("+  RESTORE\n\nRecover %d health now (up to 25).\n\n%s" % [mini(25, int(100 - hp)), "Already at full health; no healing gained." if hp >= 100 else "Prepare for the next fight."]) if id == "restore" else "%s  %s\n\n%s\n\nMana +%d · %s" % [component_icon(id), catalog[id].name, catalog[id].description, catalog[id].cost, component_use(id)]
            card.pressed.connect(func(): choose_reward(id))
            cards.add_child(card)
        label_text("%s slots full? Your reward stays owned. Remove a slot to equip it." % ("Four" if max_slots() == 4 else "Five") if draft.size() == max_slots() else "Auto-equips when a slot and required components are available.", 15)
        var inspect_row := HBoxContainer.new()
        content.add_child(inspect_row)
        for offer in offers:
            if offer != "restore":
                var inspect := Button.new()
                inspect.text = "Inspect " + str(catalog[offer].name)
                inspect.pressed.connect(func(): journey.inspect_reward(offer))
                inspect_row.add_child(inspect)
        button("Suspend to menu" if profile_enabled else "Return to menu (abandon unsaved run)", suspend_run if profile_enabled else show_menu)
        if not journey_notice.is_empty():
            label_text(journey_notice, 12)
        return
    label_text("SPELL FORGE · ordered slots · Projectile is fixed", 16)
    var slots := HBoxContainer.new()
    slots.add_theme_constant_override("separation", 5)
    content.add_child(slots)
    for i in max_slots():
        var slot := VBoxContainer.new()
        slot.custom_minimum_size.x = 142
        slots.add_child(slot)
        var title := Button.new()
        title.text = "%d  %s %s" % [i + 1, component_icon(draft[i]), catalog[draft[i]].name] if i < draft.size() else "%d  — Empty —" % (i + 1)
        title.add_theme_font_size_override("font_size", 16)
        title.disabled = i >= draft.size()
        if i < draft.size():
            title.pressed.connect(func(): selected_component = draft[i]; show_reward())
        slot.add_child(title)
        var controls := HBoxContainer.new()
        slot.add_child(controls)
        for action in ["left", "right", "remove"]:
            var item := Button.new()
            item.text = {"left": "←", "right": "→", "remove": "Remove"}[action]
            item.add_theme_font_size_override("font_size", 13)
            item.disabled = i == 0 or i >= draft.size() or (action == "left" and i == 1) or (action == "right" and i == draft.size() - 1)
            if action == "remove" and i > 0 and i < draft.size():
                var without := draft.duplicate()
                without.remove_at(i)
                if not Spell.compile(without).valid:
                    item.disabled = true
                    item.tooltip_text = "Remove Wall Charge before Bounce, or Delayed Blast before Explode."
            item.pressed.connect(func(): edit_draft(action, i))
            controls.add_child(item)
    var row := GridContainer.new()
    row.columns = 5
    content.add_child(row)
    for id in owned:
        if id == "projectile":
            continue
        var item := Button.new()
        item.add_theme_font_size_override("font_size", 13)
        item.text = ("✓ " if draft.has(id) else "+ ") + str(catalog[id].name)
        item.disabled = draft.has(id) or draft.size() >= max_slots() or not Spell.compile(draft + [id]).valid
        item.tooltip_text = ("Equipped. " if draft.has(id) else "Owned; remove a slot to equip. " if draft.size() >= max_slots() else "Owned; add to next empty slot. ") + str(catalog[id].description)
        if not draft.has(id) and not Spell.compile(draft + [id]).valid and draft.size() < max_slots():
            item.tooltip_text = "Equip Bounce first." if id == "wall_charge" else "Equip Explode first."
        item.pressed.connect(func(): edit_draft("add", -1, id))
        row.add_child(item)
    var preview: Dictionary = Spell.compile(draft)
    label_text("Mana %d / 100 · Cast delay %.2fs · Slots %d / %d · ✓ equipped / + owned" % [preview.get("mana_cost", 0), preview.get("cooldown", 0), draft.size(), max_slots()], 15)
    var explanation := label_text("%s: %s %s" % [catalog[selected_component].name, catalog[selected_component].description, component_use(selected_component)], 14)
    explanation.tooltip_text = "Impact triggers resolve left → right. Child bolts cannot trigger Split, Chain or Explode. Select a slot to inspect its effect."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var test_area := preload("res://scripts/spell_preview.gd").new()
    test_area.name = "SpellPreview"
    test_area.custom_minimum_size = Vector2(740, 76)
    test_area.source = self
    content.add_child(test_area)
    var actions := HBoxContainer.new()
    content.add_child(actions)
    var test_button := Button.new()
    test_button.text = "Test group ↻"
    test_button.pressed.connect(func(): test_area.restart("group"))
    actions.add_child(test_button)
    var wall_button := Button.new()
    wall_button.text = "Wall shot ↻"
    wall_button.tooltip_text = "Fire toward a wall to test Bounce. Targets wait behind you."
    wall_button.pressed.connect(func(): test_area.restart("wall"))
    actions.add_child(wall_button)
    var enter := Button.new()
    enter.text = "Enter the Warden's chamber →" if encounter_index == 5 else "Enter next trial →"
    enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enter.modulate = Art.TEAL
    enter.disabled = not preview.valid
    enter.pressed.connect(journey.leave_practice if practice else apply_reward)
    if practice:
        enter.text = "Return to menu"
    actions.add_child(enter)
    var extra := HBoxContainer.new()
    content.add_child(extra)
    for entry in [["Grimoire / save recipe", journey.show_grimoire], ["Experiment guide", journey.show_tutorial], ["Suspend to menu" if profile_enabled else "Abandon unsaved run", suspend_run if profile_enabled else show_menu]]:
        if practice and entry[0] == "Suspend to menu":
            continue
        var item := Button.new()
        item.text = entry[0]
        item.pressed.connect(entry[1])
        extra.add_child(item)
    if not journey_notice.is_empty():
        label_text(journey_notice, 12)

func apply_reward() -> void:
    if state != "reward" or not selected_reward:
        return
    var candidate: Dictionary = Spell.compile(draft)
    if not candidate.valid:
        return
    if not clear_checkpoint():
        show_reward()
        return
    compiled = candidate
    report.event("spell_equipped", {"owned": owned, "equipped": draft})
    components = draft.duplicate()
    encounter_index += 1
    start_encounter()

func toggle_pause() -> void:
    if state == "combat":
        state = "paused"
        clear_panel()
        label_text("PAUSED", 32)
        label_text("WASD / arrows: move · Mouse: aim / cast\nSpace: dodge through attacks · Esc: resume", 17)
        button("Resume", toggle_pause)
        button("Settings", func(): show_settings("paused"))
        button("Abandon run", abandon_run)
    elif state == "paused":
        state = "combat"
        panel.hide()

func finish_run(won: bool) -> void:
    debrief = report.finish(won, encounter_index, owned, components)
    if profile_active() and not practice:
        profile.discover(owned)
        if won:
            profile.milestone(expedition + "_win")
            if challenge == "four_slot":
                profile.milestone("four_slot_win")
        clear_checkpoint()
    state = "victory" if won else "death"
    effects.clear()
    pending_spawns.clear()
    delayed_blasts.clear()
    clear_panel()
    label_text("WARDEN DEFEATED" if won else "YOUR RUN ENDS", 32)
    label_text("%d / 6 trials cleared · %d enemies defeated" % [mini(encounter_index, 6), kills], 20)
    label_text("Combat time %d:%02d · Seed %d" % [int(elapsed) / 60, int(elapsed) % 60, run_seed], 17)
    label_text("FINAL SPELL", 16)
    var tiles := HBoxContainer.new()
    tiles.alignment = BoxContainer.ALIGNMENT_CENTER
    tiles.add_theme_constant_override("separation", 8)
    content.add_child(tiles)
    for id in components:
        var tile := Label.new()
        tile.text = "%s %s" % [component_icon(id), Spell.catalog()[id].name]
        tile.add_theme_color_override("font_color", Art.GOLD)
        tile.add_theme_font_size_override("font_size", 18)
        var cell := PanelContainer.new()
        var tile_style := StyleBoxFlat.new()
        tile_style.bg_color = Art.STONE
        tile_style.content_margin_left = 10
        tile_style.content_margin_right = 10
        tile_style.content_margin_top = 8
        tile_style.content_margin_bottom = 8
        cell.add_theme_stylebox_override("panel", tile_style)
        cell.add_child(tile)
        tiles.add_child(cell)
    if not journey_notice.is_empty():
        label_text(journey_notice, 12)
    button("Run report / next experiment", journey.show_debrief)
    button("Retry this seed", func(): start_run(run_seed))
    button("New run", func(): start_run(int(Time.get_unix_time_from_system())))
    button("Main menu", show_menu)
    audio.play_sfx("victory" if won else "death")

func show_settings(return_state: String) -> void:
    state = "settings"
    clear_panel()
    label_text("SETTINGS", 28)
    for key in ["master", "music", "sfx"]:
        var row := HBoxContainer.new()
        content.add_child(row)
        var text_label := Label.new()
        text_label.text = key.capitalize()
        text_label.custom_minimum_size.x = 100
        row.add_child(text_label)
        var slider := HSlider.new()
        slider.min_value = 0
        slider.max_value = 1
        slider.step = 0.05
        slider.value = settings[key]
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.tooltip_text = "Adjust " + key + " volume"
        slider.value_changed.connect(func(value): settings[key] = value; apply_audio(); save_settings())
        row.add_child(slider)
    for key in ["shake", "reduced_flash"]:
        var check := CheckButton.new()
        check.text = "Camera shake" if key == "shake" else "Reduced flashing"
        check.button_pressed = settings[key]
        check.toggled.connect(func(value): settings[key] = value; save_settings())
        content.add_child(check)
    button("Back", func():
        if return_state == "menu":
            show_menu()
        else:
            state = "combat"
            toggle_pause())

func apply_audio() -> void:
    if is_instance_valid(audio):
        audio.set_levels(settings.master, settings.music, settings.sfx)

func save_settings() -> void:
    var config := ConfigFile.new()
    for key in settings:
        config.set_value("accessibility", key, settings[key])
    config.save(settings_path)

func load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(settings_path) == OK:
        for key in settings:
            var value = config.get_value("accessibility", key, settings[key])
            if key in ["master", "music", "sfx"] and (value is float or value is int):
                settings[key] = clampf(float(value), 0, 1)
            elif key in ["shake", "reduced_flash"] and value is bool:
                settings[key] = value

func update_hud() -> void:
    hud.visible = state in ["menu", "combat", "paused"]
    hud.queue_redraw()

func readiness() -> Dictionary:
    return {"cast": cooldown <= 0 and mana >= float(compiled.get("mana_cost", 8)) and projectiles.size() < MAX_PROJECTILES,
        "dodge": dodge_cooldown <= 0}

func _draw() -> void:
    var shake := Vector2.ZERO
    if settings.shake and hurt_time > 0.35 and state == "combat":
        shake = Vector2(sin(visual_time * 90), cos(visual_time * 73)) * 2
    draw_set_transform(shake)
    Art.draw_arena(self, ARENA, layout, visual_time)
    if state != "menu":
        for spawn in pending_spawns:
            Art.draw_spawn_warning(self, spawn, visual_time)
        for blast in delayed_blasts:
            Art.draw_delayed_blast(self, blast, visual_time)
        for hazard in hazards:
            Art.draw_hazard(self, hazard, visual_time)
        for enemy in enemies:
            if enemy.hp > 0:
                Art.draw_enemy(self, enemy, visual_time)
        for projectile in projectiles:
            Art.draw_projectile(self, projectile, visual_time)
        for effect in effects:
            var opacity: float = (0.45 if settings.reduced_flash else 0.8) * clampf(effect.life / 0.3, 0.0, 1.0)
            if effect.kind == "chain":
                draw_line(effect.origin, effect.target, Color(0.55, 0.8, 1.0, opacity), 2.0)
            else:
                var radius: float = effect.radius if settings.reduced_flash else effect.radius * (1.0 - effect.life / 0.6)
                draw_arc(effect.origin, radius, 0, TAU, 40, Color(1.0, 0.7, 0.35, opacity), 2.0)
        Art.draw_player(self, player_pos, aim, dodge_time > 0, hurt_time > 0 and not settings.reduced_flash, visual_time)
    draw_set_transform(Vector2.ZERO)
