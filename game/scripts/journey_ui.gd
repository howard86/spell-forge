extends RefCounted
## Journey screens use bounded, scrollable pages around the existing forge editor.
const Spell = preload("res://scripts/spell_engine.gd")
const Preview = preload("res://scripts/spell_preview.gd")
const Share = preload("res://scripts/share_code.gd")
var game: Node
var page: VBoxContainer
var practice_backup: Dictionary = {}
var return_action: Callable

func setup_controls() -> void:
    game.next_setup.configured = true
    var row := HBoxContainer.new()
    game.content.add_child(row)
    for spec in [["expedition", ["forge", "archive"], ["Forge · Warden", "Archive · Archivist"]], ["challenge", ["standard", "four_slot"], ["Standard · 5 slots", "Four-slot challenge"]], ["starting_choice", ["ember", "frost"], ["Ember · Fire", "Frost · slow"]]]:
        var picker := OptionButton.new()
        for title in spec[2]:
            picker.add_item(title)
        picker.select(spec[1].find(game.next_setup[spec[0]]))
        picker.item_selected.connect(func(index: int): game.next_setup[spec[0]] = spec[1][index])
        row.add_child(picker)
    game.label_text("Forge begins on open floor; choose each later route in the forge. Archive always has reflector cover.", 12)

func route_controls() -> void:
    if game.practice:
        return
    var row := HBoxContainer.new()
    game.content.add_child(row)
    var description := Label.new()
    description.add_theme_font_size_override("font_size", 12)
    if game.expedition == "archive":
        game.route = "reflector"
        description.text = "ARCHIVE · Reflector rooms: cover and bank shots, narrower paths."
    else:
        var picker := OptionButton.new()
        picker.add_item("Next: Open floor")
        picker.add_item("Next: Reflector route")
        picker.select(1 if game.route == "reflector" else 0)
        picker.item_selected.connect(func(index: int):
            game.route = "reflector" if index == 1 else "open"
            game.save_checkpoint()
            game.show_reward())
        row.add_child(picker)
        description.text = "More room to move." if game.route == "open" else "Cover and bank shots, narrower paths. No reward bonus."
    row.add_child(description)
    var next_room: Dictionary = game.Director.encounter(game.run_seed, game.encounter_index + 1, game.expedition, game.route)
    var map_text := "Next map: open floor; no internal walls."
    if not next_room.obstacles.is_empty():
        map_text = "Next map: two west/east pillars, with paths above, below and through the center." if next_room.layout != 1 else "Next map: north/south horizontal walls; clear center lane and paths around both ends."
    game.label_text(map_text, 12)

func page_start(title: String) -> void:
    game.clear_panel()
    game.label_text(title, 25)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(750, 240)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    game.content.add_child(scroll)
    page = VBoxContainer.new()
    page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page.add_theme_constant_override("separation", 7)
    scroll.add_child(page)

func text(value: String) -> Label:
    var item := Label.new()
    item.text = value
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item.add_theme_font_size_override("font_size", 15)
    page.add_child(item)
    return item

func action(value: String, callback: Callable) -> Button:
    var item := Button.new()
    item.text = value
    item.pressed.connect(callback)
    page.add_child(item)
    return item

func notice() -> void:
    if not game.journey_notice.is_empty():
        text(game.journey_notice)

func back_to_forge() -> void:
    game.show_reward()

func restart_preview(preview: Control, scenario: String) -> void:
    preview.restart(scenario)
    game.preview_scenario = preview.scenario

func restore_preview(preview: Control) -> void:
    restart_preview(preview, game.preview_scenario)
    preview.picker.item_selected.connect(func(_index: int): game.preview_scenario = preview.scenario)

func add_preview(equipped: Array, candidate: Array) -> void:
    # Detached source owns copied arrays; prospective inspection cannot commit edits.
    var source = game.get_script().new()
    source.profile_enabled = false
    source.components = equipped.duplicate(true)
    source.draft = candidate.duplicate(true)
    source.challenge = game.challenge
    source.obstacles = [] if game.practice else game.obstacles.duplicate()
    var preview := Preview.new()
    preview.source = source
    preview.name = "JourneyPreview"
    preview.custom_minimum_size = Vector2(720, 92)
    preview.tree_exited.connect(func(): source.free(), CONNECT_ONE_SHOT)
    page.add_child(preview)
    restore_preview(preview)
    text("Same setup, one cast over two seconds. Choose a scenario above; this observation does not predict a run outcome.")

func show_practice() -> void:
    if not game.practice:
        practice_backup = {"owned": game.owned.duplicate(), "components": game.components.duplicate(),
            "draft": game.draft.duplicate(), "selected_component": game.selected_component,
            "challenge": game.challenge, "selected_reward": game.selected_reward, "obstacles": game.obstacles.duplicate()}
        game.practice = true
        game.challenge = "standard"
        game.obstacles = []
        game.owned = Spell.catalog().keys()
        game.components = ["projectile"]
        game.draft = ["projectile"]
        game.selected_component = "projectile"
        game.selected_reward = true
    game.state = "practice"
    game.show_reward()

func leave_practice() -> void:
    if not practice_backup.is_empty():
        for key in practice_backup:
            game.set(key, practice_backup[key])
    practice_backup.clear()
    game.practice = false
    game.show_menu()

func inspect_reward(id: String) -> void:
    if game.state != "reward" or game.selected_reward or not game.offers.has(id) or not Spell.catalog().has(id):
        return
    page_start("INSPECT REWARD · " + str(Spell.catalog()[id].name))
    text("Inspection only. Choosing the reward is separate; it has not been added to inventory.")
    var candidate: Array = game.draft.duplicate()
    if candidate.size() < game.max_slots() and Spell.compile(candidate + [id]).valid:
        candidate.append(id)
    else:
        text("This draft has no legal empty slot for the reward. Remove a slot or add its required component after choosing it.")
        candidate = ["projectile"]
        if id == "wall_charge":
            candidate.append("bounce")
        if id == "delayed_blast":
            candidate.append("explode")
        candidate.append(id)
        text("The comparison below uses a separate minimal legal demonstration build: " + ", ".join(candidate))
    add_preview(game.components, candidate)
    game.button("Back to reward choices", game.show_reward)

func show_grimoire() -> void:
    page_start("GRIMOIRE · recipes remember ideas, not ownership")
    var name := LineEdit.new()
    name.placeholder_text = "Recipe name (up to 40 characters)"
    name.max_length = 40
    page.add_child(name)
    action("Save current draft", func():
        game.save_recipe(name.text, game.draft)
        show_grimoire())
    notice()
    for recipe in game.profile.data.recipes:
        var status: Dictionary = game.profile.recipe_status(recipe, game.owned, game.max_slots())
        text(str(recipe.name) + " · " + ", ".join(recipe.components))
        text("Available in this forge." if status.valid else "Unavailable · missing: " + ", ".join(status.missing) if not status.missing.is_empty() else "Unavailable · exceeds this challenge's slots.")
        var equip := action("Equip " + str(recipe.name), func(): equip_recipe(recipe))
        equip.disabled = not status.valid
        action("Export " + str(recipe.name), func(): show_code(Share.encode_recipe(recipe.name, recipe.components), show_grimoire))
        action("Delete " + str(recipe.name), func():
            game.delete_recipe(recipe.name)
            show_grimoire())
    game.button("Back to forge", game.show_reward)

func equip_recipe(recipe: Dictionary) -> bool:
    var status: Dictionary = game.profile.recipe_status(recipe, game.owned, game.max_slots())
    if not status.valid:
        game.journey_notice = "Recipe unavailable: missing components or challenge slot limit."
        return false
    game.draft = status.components.duplicate()
    game.selected_component = game.draft[0]
    game.journey_notice = "Recipe loaded into draft."
    if not game.practice:
        game.save_checkpoint()
    game.show_reward()
    return true

func show_tutorial() -> void:
    return_action = game.show_reward if game.state in ["reward", "practice"] else game.show_menu
    page_start("FIRST EXPERIMENT · choose, predict, test, revise")
    text("1. Choose a change: add Fire to Projectile.\n2. Predict: will a durable target take more damage within two seconds?\n3. Test both spells on the same target below.\n4. Revise: try a line or moving target, then change one slot in Practice forge.")
    add_preview(["projectile"], ["projectile", "fire"])
    text("Try another target situation, then change one slot and compare again. Practice has every component and cannot unlock run inventory.")
    if game.state == "menu":
        action("Try the practice forge", func(): mark_tutorial_seen(); show_practice())
    action("I finished my experiment", finish_tutorial)
    game.button("Skip guide", finish_tutorial)

func mark_tutorial_seen() -> bool:
    var previous: bool = game.profile.data.tutorial_seen
    game.profile.data.tutorial_seen = true
    if game.save_progress():
        return true
    game.profile.data.tutorial_seen = previous
    return false

func finish_tutorial() -> void:
    mark_tutorial_seen()
    return_action.call()

func show_workshop() -> void:
    game.state = "workshop"
    page_start("WORKSHOP · a record of experiments")
    text("Ember and Frost change the workshop's accent only. There are no permanent combat bonuses.")
    text("Discoveries: " + (", ".join(game.profile.data.discoveries) if not game.profile.data.discoveries.is_empty() else "Clear a trial to record components you owned."))
    for id in ["first_clear", "forge_win", "archive_win", "four_slot_win"]:
        var lore: Dictionary = {"first_clear": "First clear — a new page rests beside the forge.", "forge_win": "Forge victory — the Warden's ember lights the workshop.", "archive_win": "Archive victory — a recovered inscription joins the shelf.", "four_slot_win": "Four-slot victory — a small frame holds a carefully chosen spell."}
        text(("✓ " if id in game.profile.data.milestones else "○ ") + lore[id])
    for palette in ["ember", "frost"]:
        action("Palette: " + palette.capitalize() + (" ✓" if game.profile.data.workshop == palette else ""), func():
            var previous: String = game.profile.data.workshop
            game.profile.data.workshop = palette
            if not game.save_progress():
                game.profile.data.workshop = previous
            show_workshop())
    var surface = game.panel.get_theme_stylebox("panel").duplicate()
    surface.border_color = Color(0.9, 0.5, 0.2) if game.profile.data.workshop == "ember" else Color(0.45, 0.75, 1.0)
    game.panel.add_theme_stylebox_override("panel", surface)
    notice()
    game.button("Back", game.show_menu)

func show_code(code: String, back: Callable) -> void:
    page_start("PORTABLE CODE · select and copy")
    var field := TextEdit.new()
    field.editable = false
    field.text = code
    field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    field.custom_minimum_size = Vector2(700, 160)
    page.add_child(field)
    text("Share manually wherever you choose. Challenges repeat seed, expedition, slot limit and starter. Route and reward choices are made during play and may differ.")
    game.button("Back", back)

func import_code(value: String) -> bool:
    var result: Dictionary = Share.decode(value.strip_edges())
    if not result.valid:
        game.journey_notice = result.error
        return false
    var payload: Dictionary = result.payload
    if payload.kind == "recipe":
        if not game.save_recipe(payload.name, payload.components):
            return false
        game.journey_notice = "Recipe imported; inventory unchanged."
        return true
    game.next_setup = {"seed": int(payload.seed), "expedition": payload.expedition, "challenge": payload.challenge, "starting_choice": payload.starting_choice, "seed_set": true, "configured": true}
    game.journey_notice = "Next run configured: seed %d · %s · %s · %s. Begin run from the menu to start it." % [payload.seed, payload.expedition, payload.challenge, payload.starting_choice]
    return true

func show_sharing() -> void:
    game.state = "sharing"
    page_start("SHARE / IMPORT · next run setup")
    text("Current next setup: %s · %s · %s. A pasted challenge changes the next setup, never a running game." % [game.next_setup.expedition, game.next_setup.challenge, game.next_setup.starting_choice])
    var field := LineEdit.new()
    field.placeholder_text = "Paste SF1 recipe or challenge code (maximum 4096 characters)"
    field.max_length = 4096
    page.add_child(field)
    action("Import code", func(): import_code(field.text); show_sharing())
    action("Export next challenge", func():
        var seed_value: int = int(game.next_setup.seed)
        if not game.next_setup.get("seed_set", false):
            seed_value = game.run_seed
        show_code(Share.encode_challenge(seed_value, game.next_setup.expedition, game.next_setup.challenge, game.next_setup.starting_choice), show_sharing))
    for starter in ["ember", "frost"]:
        action("Next starting spell: " + starter.capitalize(), func():
            game.next_setup.starting_choice = starter
            game.next_setup.configured = true
            game.journey_notice = "Starting spell chosen for the next run."
            show_sharing())
    notice()
    game.button("Back", game.show_menu)

func show_report_details() -> void:
    page_start("REPORT DETAILS · rewards and recent observations")
    var data: Dictionary = game.debrief
    text("Offered: " + ", ".join(data.offered) + "\nChosen: " + ", ".join(data.chosen) + "\nOwned: " + ", ".join(data.owned) + "\nEquipped: " + ", ".join(data.equipped))
    var detail := TextEdit.new()
    detail.editable = false
    detail.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    detail.custom_minimum_size = Vector2(700, 180)
    detail.text = "Recent observations (up to 128):\n" + JSON.stringify(data.events, "  ")
    page.add_child(detail)
    game.button("Back to report", show_debrief)

func show_debrief() -> void:
    page_start("RUN REPORT · recorded observations")
    var data: Dictionary = game.debrief
    if data.is_empty():
        text("No completed run report is available.")
    else:
        var encounter_name := "Final chamber" if int(data.encounter) >= 6 else "Trial %d of 6" % (int(data.encounter) + 1)
        text("Seed %s · %s · build: %s" % [data.seed, encounter_name, ", ".join(data.equipped)])
        text("Time (seconds): combat %.1f · forge %.1f · paused %.1f · settings %.1f" % [data.time.combat, data.time.reward, data.time.paused, data.time.settings])
        text("Damage dealt %.1f · damage taken %.1f\nMana spent %.1f · mana restored %.1f · health restored %.1f" % [data.observations.damage_dealt, data.observations.damage_taken, data.observations.mana_spent, data.observations.mana_restored, data.observations.health_restored])
        var damage_recorded := false
        var source_labels := {"unknown": "Unspecified source", "contact": "Contact", "lane": "Lane attacks", "sweep": "Sweeps", "charge": "Charges", "melee": "Melee attacks", "projectile": "Projectiles", "hazard": "Hazards"}
        for source in data.get("damage_sources", {}):
            if float(data.damage_sources[source]) > 0:
                text("%s: %.1f damage" % [source_labels.get(source, "Unspecified source"), data.damage_sources[source]])
                damage_recorded = true
        if not damage_recorded:
            text("No damage recorded.")
        var denials_recorded := false
        var denial_labels := {"mana": "Not enough mana", "cooldown": "Spell recovering", "capacity": "Projectile capacity reached", "invalid": "Spell unavailable"}
        for reason in data.get("cast_denials", {}):
            if int(data.cast_denials[reason]) > 0:
                text("%s: %d blocked-cast observations" % [denial_labels.get(reason, reason), data.cast_denials[reason]])
                denials_recorded = true
        if not denials_recorded:
            text("No blocked casts recorded.")
        else:
            text("Held input records at most one blocked-cast observation per second for each reason.")
        text("Next experiment: change one component and compare the equipped and draft spells in the same practice scenario.")
        action("Reward / observation details", show_report_details)
    game.button("Main menu", game.show_menu)
