extends Node2D
const Spell = preload("res://scripts/spell_engine.gd")
const Director = preload("res://scripts/run_director.gd")
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
var effects: Array = []
var casts: Dictionary = {}
var owned: Array = ["projectile"]
var components: Array = ["projectile"]
var draft: Array = []
var compiled: Dictionary = {}
var offers: Array = []
var selected_reward := false
var message := ""
var message_time := 0.0
var settings_path := "user://settings.cfg"
var settings := {"master": 0.7, "music": 0.35, "sfx": 0.7, "shake": true, "reduced_flash": false}
var ui: CanvasLayer
var panel: PanelContainer
var content: VBoxContainer
var hud: Label
var audio: Node
var seed_input: LineEdit
var exit_requested := false

func _ready() -> void:
    get_tree().auto_accept_quit = false
    load_settings()
    audio = Art.create_audio()
    add_child(audio)
    apply_audio()
    ui = CanvasLayer.new()
    add_child(ui)
    hud = Label.new()
    hud.position = Vector2(36, 16)
    hud.add_theme_font_size_override("font_size", 18)
    ui.add_child(hud)
    panel = PanelContainer.new()
    panel.position = Vector2(160, 90)
    panel.custom_minimum_size = Vector2(640, 340)
    ui.add_child(panel)
    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    panel.add_child(content)
    show_menu()

func clear_panel() -> void:
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
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
    clear_panel()
    label_text("SPELLFORGE", 36)
    label_text("Build a spell. Survive six trials. Break the Warden.")
    seed_input = LineEdit.new()
    seed_input.placeholder_text = "Run seed (blank for a new adventure)"
    seed_input.tooltip_text = "The same integer repeats encounters and reward choices."
    content.add_child(seed_input)
    button("Begin run", func(): start_run(int(seed_input.text) if seed_input.text.is_valid_int() else int(Time.get_unix_time_from_system())))
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
    credits.text = "Spellforge\nOriginal procedural visuals and synthesized music/sound effects created for this project.\nProject source license: undecided; no distribution license is granted here.\n\nGodot Engine\n" + Engine.get_license_text()
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

func start_run(seed_value: int) -> void:
    run_seed = seed_value
    encounter_index = 0
    hp = 100.0
    mana = 100.0
    elapsed = 0.0
    kills = 0
    next_id = 1
    cast_id = 0
    owned = ["projectile"]
    components = ["projectile"]
    compiled = Spell.compile(components)
    message = ""
    start_encounter()

func start_encounter() -> void:
    state = "combat"
    panel.hide()
    enemies.clear()
    projectiles.clear()
    hazards.clear()
    effects.clear()
    casts.clear()
    cooldown = 0.0
    dodge_time = 0.0
    dodge_cooldown = 0.0
    hurt_time = 1.0
    player_pos = ARENA.get_center()
    var encounter: Dictionary = Director.encounter(run_seed, encounter_index)
    layout = encounter.layout
    var rng := RandomNumberGenerator.new()
    rng.seed = encounter.seed
    var roster: Array = encounter.roster
    for i in roster.size():
        var angle := TAU * float(i) / roster.size()
        var pos := ARENA.get_center() + Vector2(cos(angle) * 340, sin(angle) * 155)
        if layout == 1:
            pos = Vector2(110 if i % 2 == 0 else 850, 130 + (i / 2) * 49 % 330)
        elif layout == 2:
            pos = Vector2(130 + i * 113 % 710, 125 if i % 2 == 0 else 465)
        spawn_enemy(roster[i], pos, rng.randf_range(0.8, 2.0))
    audio.play_sfx("reward")

func spawn_enemy(kind: String, pos: Vector2, timer: float) -> void:
    var health: float = {"pursuer": 42.0, "archer": 34.0, "swarm": 18.0, "bulwark": 100.0, "channeler": 48.0, "boss": 900.0}[kind]
    enemies.append({"id": next_id, "kind": kind, "position": pos, "hp": health, "max_hp": health, "radius": 27.0 if kind == "boss" else 13.0, "telegraph": 0.0, "aim": Vector2.DOWN, "phase": 1, "timer": timer, "burn": {}})
    next_id += 1

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        cursor_position = get_global_transform_with_canvas().affine_inverse() * event.position

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            toggle_pause()
        elif event.keycode == KEY_SPACE and state == "combat" and dodge_cooldown <= 0:
            dodge_time = 0.24
            dodge_cooldown = 1.05
            dodge_direction = movement_direction()
            if dodge_direction == Vector2.ZERO:
                dodge_direction = aim
            audio.play_sfx("dodge")

func movement_direction() -> Vector2:
    return Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()

func _physics_process(delta: float) -> void:
    visual_time += delta
    if state == "combat":
        simulate(delta)
    update_hud()
    queue_redraw()

func simulate(delta: float) -> void:
    elapsed += delta
    cooldown = maxf(0, cooldown - delta)
    dodge_time = maxf(0, dodge_time - delta)
    dodge_cooldown = maxf(0, dodge_cooldown - delta)
    hurt_time = maxf(0, hurt_time - delta)
    message_time = maxf(0, message_time - delta)
    mana = minf(100, mana + delta * 22)
    aim = (cursor_position - player_pos).normalized()
    if aim == Vector2.ZERO:
        aim = Vector2.RIGHT
    player_pos += (dodge_direction * 650 if dodge_time > 0 else movement_direction() * 220) * delta
    player_pos = player_pos.clamp(ARENA.position + Vector2(14, 14), ARENA.end - Vector2(14, 14))
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        cast_spell()
    update_enemies(delta)
    update_projectiles(delta)
    update_hazards(delta)
    update_effects(delta)
    enemies = enemies.filter(func(e): return e.hp > 0)
    if state == "combat" and enemies.is_empty():
        encounter_clear()

func cast_spell() -> bool:
    if state != "combat" or cooldown > 0:
        return false
    if mana < float(compiled.mana_cost):
        message = "Mana recovering… simplify your spell between trials."
        message_time = 1.0
        return false
    if projectiles.size() >= MAX_PROJECTILES:
        return false
    mana -= float(compiled.mana_cost)
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
    projectiles.append({"position": pos, "direction": direction.normalized(), "enemy": hostile, "fire": false if hostile else bool(spell.fire), "radius": 6.0 if hostile else 5.0, "life": 5.0 if hostile else float(spell.life), "speed": 180.0 if hostile else float(spell.speed), "cast_id": owner, "generation": generation, "hit_ids": [], "pierce": 0 if hostile else int(spell.pierce), "bounces": 0 if hostile else int(spell.bounces)})

func update_enemies(delta: float) -> void:
    for enemy in enemies:
        if enemy.hp <= 0:
            continue
        if not enemy.burn.is_empty():
            var active_delta := maxf(0.0, minf(elapsed, float(enemy.burn.expires_at)) - (elapsed - delta))
            hurt_enemy(enemy, float(enemy.burn.dps) * active_delta, false)
            if elapsed >= float(enemy.burn.expires_at):
                enemy.burn = {}
        if enemy.hp <= 0:
            continue
        var to_player: Vector2 = player_pos - enemy.position
        var distance := to_player.length()
        if enemy.kind == "boss" and enemy.hp < enemy.max_hp * 0.5 and enemy.phase == 1:
            enemy.phase = 2
            message = "WARDEN ENRAGED — watch the expanding marks!"
            message_time = 3.0
        if enemy.telegraph > 0:
            enemy.telegraph -= delta
            if enemy.telegraph <= 0:
                enemy_attack(enemy)
                enemy.timer = 1.2 if enemy.phase == 2 else 2.0
        else:
            enemy.aim = to_player.normalized()
            var speed: float = {"pursuer": 91.0, "swarm": 135.0, "bulwark": 52.0, "archer": 47.0, "channeler": 35.0, "boss": 45.0}[enemy.kind]
            if distance > (210 if enemy.kind in ["archer", "channeler"] else 38):
                enemy.position += enemy.aim * speed * delta
            enemy.timer -= delta
            if enemy.timer <= 0:
                enemy.telegraph = 0.8 if enemy.kind != "swarm" else 0.45
        enemy.position = enemy.position.clamp(ARENA.position + Vector2(28, 28), ARENA.end - Vector2(28, 28))
        if distance < enemy.radius + 11:
            damage_player(8.0)

func enemy_attack(enemy: Dictionary) -> void:
    if enemy.kind in ["archer", "boss"]:
        var count: int = (7 if enemy.phase == 2 else 5) if enemy.kind == "boss" else 1
        for i in count:
            add_projectile(enemy.position, enemy.aim.rotated((i - (count - 1) / 2.0) * 0.22), true)
    if enemy.kind in ["channeler", "boss"]:
        hazards.append({"position": player_pos, "radius": 49.0 if enemy.kind == "boss" else 38.0, "progress": 0.0, "life": 1.2})
    if enemy.kind in ["pursuer", "swarm", "bulwark"]:
        enemy.position += enemy.aim * (68 if enemy.kind != "bulwark" else 45)
        if enemy.position.distance_to(player_pos) < 35:
            damage_player(15.0)

func update_projectiles(delta: float) -> void:
    var current: Array = projectiles.duplicate()
    for projectile in current:
        projectile.life -= delta
        if projectile.life <= 0:
            continue
        var previous: Vector2 = projectile.position
        projectile.position += projectile.direction * projectile.speed * delta
        if not ARENA.has_point(projectile.position):
            if projectile.bounces > 0:
                if projectile.position.x < ARENA.position.x or projectile.position.x > ARENA.end.x:
                    projectile.direction.x *= -1
                if projectile.position.y < ARENA.position.y or projectile.position.y > ARENA.end.y:
                    projectile.direction.y *= -1
                projectile.position = projectile.position.clamp(ARENA.position, ARENA.end)
                projectile.bounces -= 1
            else:
                projectile.life = 0
        if projectile.enemy:
            if segment_distance(player_pos, previous, projectile.position) < 15:
                damage_player(12.0)
                projectile.life = 0
        else:
            for enemy in enemies:
                if enemy.hp <= 0 or projectile.hit_ids.has(enemy.id):
                    continue
                if segment_distance(enemy.position, previous, projectile.position) > enemy.radius + projectile.radius:
                    continue
                resolve_projectile_hit(projectile, enemy)
                if projectile.pierce <= 0:
                    projectile.life = 0
                    break
                projectile.pierce -= 1
    projectiles = projectiles.filter(func(p): return p.life > 0)
    var live: Dictionary = {}
    for projectile in projectiles:
        if not projectile.enemy:
            live[projectile.cast_id] = true
    for id in casts.keys():
        if not live.has(id):
            casts.erase(id)

func segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
    return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, finish))

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
                        if event.get("burn", false):
                            target.burn = Spell.refresh_burn(target.burn, Spell.BURN_DPS, elapsed)
            "split":
                add_projectile(event.position, event.direction, false, projectile.cast_id, 1)
            "explode":
                add_effect("explode", event.position, event.position, float(event.radius))
                for target in enemies:
                    if target.position.distance_to(event.position) <= event.radius:
                        hurt_enemy(target, float(event.damage))

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
    enemy.hp -= amount
    if enemy.hp <= 0:
        kills += 1
        audio.play_sfx("hit")
    elif sound:
        audio.play_sfx("hit")

func update_hazards(delta: float) -> void:
    for hazard in hazards:
        hazard.progress += delta / hazard.life
        if hazard.progress >= 1 and player_pos.distance_to(hazard.position) < hazard.radius + 11:
            damage_player(22.0)
    hazards = hazards.filter(func(h): return h.progress < 1)

func damage_player(amount: float) -> void:
    if state != "combat" or dodge_time > 0 or hurt_time > 0:
        return
    hp = maxf(0, hp - amount)
    hurt_time = 0.65
    audio.play_sfx("hit")
    if hp <= 0:
        finish_run(false)

func encounter_clear() -> void:
    projectiles.clear()
    hazards.clear()
    effects.clear()
    casts.clear()
    if encounter_index >= 6:
        finish_run(true)
        return
    state = "reward"
    hp = minf(100, hp + 15)
    mana = 100
    offers = Director.rewards(run_seed, encounter_index, owned)
    selected_reward = false
    draft = components.duplicate()
    show_reward()

func choose_reward(id: String) -> void:
    if state != "reward" or selected_reward or not offers.has(id):
        return
    selected_reward = true
    audio.play_sfx("reward")
    if id == "restore":
        hp = minf(100, hp + 25)
    elif not owned.has(id):
        owned.append(id)
        if draft.size() < 5:
            draft.append(id)
    show_reward()

func show_reward() -> void:
    clear_panel()
    label_text("TRIAL %d CLEARED · +15 health" % (encounter_index + 1), 25)
    var catalog: Dictionary = Spell.catalog()
    if not selected_reward:
        label_text("Choose one component to keep this run")
        for id in offers:
            if id == "restore":
                button("Restore 25 extra health", func(): choose_reward(id))
            else:
                button(str(catalog[id].name), func(): choose_reward(id), str(catalog[id].description) + " · Mana +%s" % catalog[id].cost)
        return
    label_text("Click a slot to remove; add below in order", 16)
    var slots := HBoxContainer.new()
    content.add_child(slots)
    for i in draft.size():
        var item := Button.new()
        item.text = "%d %s" % [i + 1, str(catalog[draft[i]].name)]
        item.disabled = i == 0
        item.tooltip_text = str(catalog[draft[i]].description) + " · Remove and re-add to reorder."
        item.pressed.connect(func(): draft.remove_at(i); show_reward())
        slots.add_child(item)
    var row := HBoxContainer.new()
    content.add_child(row)
    for id in owned:
        if id == "projectile":
            continue
        var item := Button.new()
        item.text = str(catalog[id].name)
        item.disabled = draft.has(id) or draft.size() >= 5
        item.tooltip_text = str(catalog[id].description) + " · Mana +%s" % catalog[id].cost
        item.pressed.connect(func(): draft.append(id); show_reward())
        row.add_child(item)
    var preview: Dictionary = Spell.compile(draft)
    label_text("Mana %s / 100 · Cast delay %.2fs · Slots %d / 5" % [preview.get("mana_cost", 0), preview.get("cooldown", 0), draft.size()] if preview.valid else str(preview.error), 16)
    button("Enter the Warden's chamber" if encounter_index == 5 else "Enter next trial", apply_reward).disabled = not preview.valid

func apply_reward() -> void:
    if state != "reward" or not selected_reward:
        return
    var candidate: Dictionary = Spell.compile(draft)
    if not candidate.valid:
        return
    compiled = candidate
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
        button("Abandon run", show_menu)
    elif state == "paused":
        state = "combat"
        panel.hide()

func finish_run(won: bool) -> void:
    state = "victory" if won else "death"
    effects.clear()
    clear_panel()
    label_text("WARDEN DEFEATED" if won else "YOUR RUN ENDS", 32)
    label_text("Seed %d · %d defeated · %d:%02d\n%s" % [run_seed, kills, int(elapsed) / 60, int(elapsed) % 60, " → ".join(components)], 18)
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
    if state == "menu":
        hud.text = "SPELLFORGE / THE RUNIC TRIALS"
    else:
        hud.text = "HP %d / 100    MANA %d / 100    %s    SEED %d\n%s" % [int(hp), int(mana), "WARDEN" if encounter_index == 6 else "TRIAL %d / 6" % (encounter_index + 1), run_seed, message if message_time > 0 else " · ".join(components) + "     [Esc] pause"]

func _draw() -> void:
    var shake := Vector2.ZERO
    if settings.shake and hurt_time > 0.35 and state == "combat":
        shake = Vector2(sin(visual_time * 90), cos(visual_time * 73)) * 2
    draw_set_transform(shake)
    Art.draw_arena(self, ARENA, layout, visual_time)
    if state != "menu":
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
