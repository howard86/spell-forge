extends SceneTree
const Game = preload("res://scripts/game.gd")
const Share = preload("res://scripts/share_code.gd")
const Preview = preload("res://scripts/spell_preview.gd")
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
    for index in 3:
        await process_frame
func bounds(node: Node) -> void:
    for child in node.get_children():
        if child is ScrollContainer:
            var rect: Rect2 = child.get_global_rect()
            check(rect.end.x <= 960.1 and rect.end.y <= 540.1, "scroll page fits viewport")
            # Descendants are deliberately clipped and may extend beyond its viewport.
            continue
        if child is Control and child.is_visible_in_tree():
            var rect: Rect2 = child.get_global_rect()
            check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 960.1 and rect.end.y <= 540.1, "journey UI fits: %s %s" % [child.name, rect])
        bounds(child)
func button_named(node: Node, title: String) -> Button:
    for child in node.get_children():
        if child is Button and child.text == title:
            return child
        var found := button_named(child, title)
        if found != null:
            return found
    return null
func select_preview(game: Node, scenario: String) -> void:
    var preview = game.content.find_child("SpellPreview", true, false)
    var index: int = preview.Scenarios.IDS.find(scenario)
    preview.picker.select(index)
    preview.picker.item_selected.emit(index)
func preview_is(game: Node, scenario: String) -> bool:
    var preview = game.content.find_child("SpellPreview", true, false)
    return preview.scenario == scenario and preview.comparison.equipped.scenario == scenario and preview.comparison.draft.scenario == scenario
func snapshot(game: Node) -> Array:
    return [game.hp, game.mana, game.kills, game.elapsed, game.owned.duplicate(), game.components.duplicate(), game.draft.duplicate(), game.report.snapshot(), game.profile.data.duplicate(true)]
func run() -> void:
    root.size = Vector2i(960, 540)
    var game = Game.new()
    game.settings_path = "user://journey-test-%d.cfg" % Time.get_ticks_usec()
    root.add_child(game)
    game.set_physics_process(false)
    check(game.profile_path == game.settings_path + ".profile.json" and game.bindings_path == game.settings_path + ".bindings.json", "legacy settings isolation derives profile/bindings sibling paths")
    await settle()
    bounds(game.panel)
    game.start_run(9007199254740991)
    check(game.state == "combat" and game.run_seed == 9007199254740991, "largest exact JSON integer seed accepted")
    var seed_state := snapshot(game)
    game.start_run(9007199254740992)
    check(game.state == "combat" and snapshot(game) == seed_state and not game.journey_notice.is_empty(), "oversized seed rejected before any checkpoint or run mutation")
    game.show_menu()
    game.seed_input.text = "999999999999999999999999999999999999"
    game.begin_from_menu()
    check(game.state == "menu" and game.run_seed == 9007199254740991 and not game.journey_notice.is_empty(), "oversized typed seed rejected before integer conversion")
    game.start_run(42)
    check(game.components == ["projectile"], "direct start remains projectile-only")
    game.hurt_time = 0
    game.damage_player(7, "lane")
    game.mana = 0
    game.cast_spell()
    game.cast_spell()
    game._physics_process(0.1)
    game.toggle_pause()
    game._physics_process(0.2)
    game.show_settings("paused")
    game._physics_process(0.3)
    var observed: Dictionary = game.report.snapshot()
    check(is_equal_approx(observed.time.combat, 0.1) and is_equal_approx(observed.time.paused, 0.2) and is_equal_approx(observed.time.settings, 0.3), "report counts simulation and noncombat timing once")
    check(observed.damage_sources.lane == 7 and observed.observations.damage_taken == 7, "explicit source and actual damage recorded")
    check(observed.cast_denials.mana == 1, "held input denial coalesced")
    game.state = "combat"
    game.hp = 50
    game.encounter_clear()
    check(game.hp == 65 and not game.profile.data.checkpoint.is_empty(), "clear heals once and saves safe checkpoint")
    check(game.profile.data.milestones.has("first_clear"), "first clear milestone saved at safe boundary")
    var offered: Array = game.offers.duplicate()
    var before := snapshot(game)
    game.journey.inspect_reward(offered[0])
    check(snapshot(game) == before, "reward inspection changes no inventory draft profile report or resources")
    await settle()
    bounds(game.panel)
    game.show_reward()
    game.choose_reward(offered[0])
    var saved := snapshot(game)
    check(game.profile.data.checkpoint.selected_reward, "reward choice persisted")
    game.edit_draft("remove", 1)
    check(game.profile.data.checkpoint.draft == game.draft, "forge draft edits persisted")
    game.suspend_run()
    check(game.state == "menu", "explicit suspend returns to menu")
    await settle()
    bounds(game.panel)
    var reloaded = Game.new()
    reloaded.settings_path = game.settings_path
    root.add_child(reloaded)
    reloaded.set_physics_process(false)
    check(reloaded.resume_checkpoint() and reloaded.hp == 65 and reloaded.selected_reward and reloaded.offers == offered and reloaded.draft == game.draft, "fresh scene resumes persisted safe boundary without repeated choice or healing")
    check(await reloaded.audio.shutdown(), "reloaded fixture audio shutdown")
    reloaded.queue_free()
    await settle()
    check(game.resume_checkpoint(), "safe checkpoint resumes")
    check(game.hp == 65 and game.selected_reward and game.offers == offered, "resume neither rerolls nor heals or grants again")
    var size_before: int = game.owned.size()
    game.choose_reward(offered[1])
    check(game.owned.size() == size_before and game.hp == 65, "resumed chosen reward cannot be chosen twice")
    game._physics_process(0.4)
    check(is_equal_approx(game.report.snapshot().time.reward, 0.4), "reward time counted")
    var valid_checkpoint: Dictionary = game.profile.data.checkpoint.duplicate(true)
    game.profile.data.checkpoint.report = {"bad": true}
    before = snapshot(game)
    var state_before: String = game.state
    check(not game.resume_checkpoint() and snapshot(game) == before and game.state == state_before, "malformed report rejected atomically")
    game.profile.data.checkpoint = valid_checkpoint
    check(game.profile.save_recipe("Missing", ["projectile", "chain"]), "recipe can remember unavailable component")
    before = snapshot(game)
    check(not game.journey.equip_recipe({"name": "Missing", "components": ["projectile", "chain"]}) and snapshot(game) == before, "recipe cannot equip unowned component")
    game.journey.show_grimoire()
    await settle()
    bounds(game.panel)
    game.show_reward()
    game.apply_reward()
    check(game.state == "combat" and game.profile.data.checkpoint.is_empty(), "entering combat consumes safe checkpoint")
    game.hurt_time = 0
    game.hp = 5
    game.damage_player(100, "projectile")
    check(game.debrief.observations.damage_taken == 12 and game.debrief.damage_sources.projectile == 5, "overkill reports actual capped damage")
    check(game.profile.data.checkpoint.is_empty() and game.state == "death", "finish clears checkpoint")
    game.journey.show_debrief()
    await settle()
    bounds(game.panel)
    game.show_menu()
    before = snapshot(game)
    game.journey.show_practice()
    check(game.practice and game.owned.size() == game.Spell.catalog().size() and game.state == "practice", "practice exposes full catalog")
    await settle()
    bounds(game.panel)
    select_preview(game, "moving")
    game.edit_draft("add", -1, "fire")
    check(preview_is(game, "moving"), "adding a component keeps the selected moving fixture for both spells")
    select_preview(game, "boss")
    game.edit_draft("add", -1, "pierce")
    check(preview_is(game, "boss"), "adding another component keeps the selected boss fixture")
    game.edit_draft("left", 2)
    check(preview_is(game, "boss"), "reordering a component keeps the selected boss fixture")
    game.edit_draft("remove", 1)
    check(preview_is(game, "boss"), "removing a component keeps the selected boss fixture")
    var wall := button_named(game.content, "Wall shot ↻")
    wall.pressed.emit()
    game.edit_draft("add", -1, "pierce")
    check(preview_is(game, "wall"), "wall shortcut becomes the fixture used after the next edit")
    check(game.draft == ["projectile", "fire", "pierce"], "practice reuses real forge editor")
    var live_report: Dictionary = game.report.snapshot()
    Preview.evaluate(game, game.draft, "group")
    check(game.report.snapshot() == live_report, "detached preview does not pollute live report")
    game.journey.leave_practice()
    check(snapshot(game) == before and game.state == "menu", "leaving practice restores inventory draft report profile and resources")
    game.journey.show_tutorial()
    await settle()
    bounds(game.panel)
    game.journey.finish_tutorial()
    check(game.profile.data.tutorial_seen and game.state == "menu", "tutorial skip persists seen and returns without reward")
    game.journey.show_workshop()
    await settle()
    bounds(game.panel)
    game.show_menu()
    var validation_profile: Dictionary = game.profile.data.duplicate(true)
    check(not game.save_recipe("   ", ["projectile"]) and not game.storage_problem and not game.journey_notice.is_empty(), "blank recipe name shows validation feedback without a storage outage")
    game.show_menu()
    check(button_named(game.content, "Play without saving") == null, "blank recipe name does not offer storage fallback on menu")
    game.profile.data.recipes.clear()
    for index in game.Profile.MAX_RECIPES:
        game.profile.data.recipes.append({"name": "Full %d" % index, "components": ["projectile"]})
    check(not game.journey.import_code(Share.encode_recipe("Overflow", ["projectile"])) and not game.storage_problem, "full recipe library import is validation feedback, not a storage outage")
    game.show_menu()
    check(button_named(game.content, "Play without saving") == null, "full recipe library does not offer storage fallback on menu")
    game.profile.data = validation_profile
    var inventory: Array = game.owned.duplicate()
    check(game.journey.import_code(Share.encode_recipe("Portable", ["projectile", "frost"])) and game.owned == inventory, "recipe import never grants ownership")
    check(not game.journey.import_code("broken") and not game.journey_notice.is_empty(), "invalid import visible")
    check(game.journey.import_code(Share.encode_challenge(777, "forge", "four_slot", "frost")), "challenge import accepted")
    check(game.next_setup.seed_set and game.next_setup.seed == 777 and game.next_setup.challenge == "four_slot" and game.run_seed == 42, "challenge configures only next run")
    game.journey.show_sharing()
    await settle()
    bounds(game.panel)
    check(game.journey.import_code(Share.encode_challenge(0, "forge", "standard", "ember")) and game.next_setup.seed == 0 and game.next_setup.seed_set, "zero seed challenge remains explicit")
    game.journey.import_code(Share.encode_challenge(777, "forge", "four_slot", "frost"))
    game.begin_setup_run(777)
    check(game.components == ["projectile", "frost"] and game.max_slots() == 4, "explicit starting setup and slot cap applied")
    game.encounter_index = 6
    game.finish_run(true)
    check(game.profile.data.milestones.has("forge_win") and game.profile.data.milestones.has("four_slot_win"), "victory records distinct milestones without bonuses")
    game.start_run(77)
    game.hp = 40
    game.encounter_clear()
    game.choose_reward("restore")
    check(game.hp == 80, "restore choice adds only actual available health")
    game.suspend_run()
    check(game.resume_checkpoint() and game.hp == 80 and game.selected_reward, "resumed restore choice does not heal twice")
    game.start_run(78)
    game.encounter_clear()
    var old_path: String = game.profile.path
    var saved_primary := FileAccess.get_file_as_string(old_path)
    var saved_backup := FileAccess.get_file_as_string(old_path + ".bak")
    game.profile.path = "res://cannot-write-profile.json"
    game.suspend_run()
    check(game.state == "reward" and not game.journey_notice.is_empty(), "save failure preserves forge and shows feedback")
    check(game.storage_problem and button_named(game.content, "Continue without saving") != null, "storage fallback is also available before selecting a reward")
    await settle()
    bounds(game.panel)
    game.apply_reward()
    check(game.state == "reward", "unselected reward cannot enter next combat")
    game.choose_reward(game.offers[0])
    game.apply_reward()
    check(game.state == "reward" and not game.journey_notice.is_empty(), "failed checkpoint deletion does not enter combat")
    await settle()
    bounds(game.panel)
    var stranded_run := snapshot(game)
    var old_encounter: int = game.encounter_index
    var continue_button := button_named(game.content, "Continue without saving")
    check(continue_button != null, "failed forge storage exposes explicit continue-without-saving action")
    if continue_button != null:
        continue_button.pressed.emit()
        check(game.state == "reward" and not game.profile_enabled and snapshot(game) == stranded_run and game.run_seed == 78, "no-save action retains the current forge run and existing profile data")
        game.apply_reward()
        check(game.state == "combat" and game.encounter_index == old_encounter + 1 and game.components == stranded_run[6], "no-save forge action permits advancing the retained draft")
        game.encounter_clear()
        check(game.state == "reward" and game.profile.data == stranded_run[8], "later no-save forge leaves old checkpoint and progress untouched")
        check(FileAccess.get_file_as_string(old_path) == saved_primary and FileAccess.get_file_as_string(old_path + ".bak") == saved_backup, "continuing without saving preserves primary and backup bytes")
    game.show_menu()
    await settle()
    bounds(game.panel)
    var profile_before_offline: Dictionary = game.profile.data.duplicate(true)
    game.seed_input.text = "99"
    game.play_without_saving()
    check(game.state == "combat" and not game.profile_enabled and game.run_seed == 99, "explicit play-without-saving starts despite storage failure")
    check(not game.save_recipe("Offline", ["projectile", "fire"]) and game.profile.data == profile_before_offline, "saving-off session cannot write recipes or clear old profile")
    game.encounter_clear()
    check(game.state == "reward" and game.profile.data == profile_before_offline, "saving-off clear leaves checkpoint and progress untouched")
    game.profile.path = old_path
    check(await game.audio.shutdown(), "audio shutdown")
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(game.profile_path + suffix))
    game.queue_free()
    await settle()
    print("Journey integration: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
