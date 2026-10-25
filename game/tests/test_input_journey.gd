extends SceneTree
const Game = preload("res://scripts/game.gd")
const Share = preload("res://scripts/share_code.gd")
const Entry = preload("res://scripts/text_entry.gd")
const Bindings = preload("res://scripts/input_bindings.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func settle() -> void:
    for i in 6:
        await process_frame
func button(node: Node, prefix: String) -> Button:
    if node is Button and node.text.begins_with(prefix):
        return node
    for child in node.get_children():
        var found := button(child, prefix)
        if found != null:
            return found
    return null
func fully_visible(control: Control, description: String) -> void:
    var rect := control.get_global_rect()
    var visible := rect
    var ancestor := control.get_parent()
    while ancestor != null:
        if ancestor is Control and ancestor.clip_contents:
            visible = visible.intersection(ancestor.get_global_rect())
        ancestor = ancestor.get_parent()
    check(control.is_visible_in_tree() and visible.size.is_equal_approx(rect.size) and rect.size.x > 0 and rect.size.y > 0, description + " fully inside all clipping ancestors: " + str(rect) + " visible " + str(visible))
func exported_code(node: Node) -> String:
    if node is TextEdit:
        return node.text
    for child in node.get_children():
        var code := exported_code(child)
        if not code.is_empty():
            return code
    return ""
func press(index: JoyButton, down := true) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.button_index = index
    event.pressed = down
    return event
func back(game: Node) -> void:
    game._unhandled_input(press(JOY_BUTTON_B))
func focused(game: Node, name: String) -> void:
    check(game.panel.get_global_rect().end.x <= 960.1 and game.panel.get_global_rect().end.y <= 540.1, name + " panel stays within viewport")
    var owner := root.gui_get_focus_owner()
    check(owner != null and owner.is_visible_in_tree() and game.panel.is_ancestor_of(owner), name + " initial visible focus")
    var controls: Array[Control] = []
    game.Navigation._collect(game.content, controls)
    for control in controls:
        check(not control.focus_neighbor_bottom.is_empty(), name + " D-pad connected")
        control.grab_focus()
        game.Navigation._reveal(control)
        check(root.gui_get_focus_owner() == control, name + " reachable control")
func run() -> void:
    root.size = Vector2i(960, 540)
    var original := {}
    for action in Bindings.ACTIONS + Bindings.AIM_ACTIONS + ["ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down"]:
        if InputMap.has_action(action):
            original[action] = [InputMap.action_get_events(action), InputMap.action_get_deadzone(action)]
    var game := Game.new()
    game.settings_path = "user://input-journey-%d.cfg" % Time.get_ticks_usec()
    root.add_child(game)
    game.set_physics_process(false)
    await settle()
    focused(game, "menu")
    var prior_focus := root.gui_get_focus_owner()
    root.push_input(press(JOY_BUTTON_DPAD_DOWN), true)
    root.push_input(press(JOY_BUTTON_DPAD_DOWN, false), true)
    check(root.gui_get_focus_owner() != prior_focus, "real D-pad event moves focus")
    button(game.content, "Enter seed with controller").pressed.emit()
    await settle()
    var entry: Node = game.panel.get_child(1)
    check(entry is Entry and root.gui_get_focus_owner().text == "Done", "entry starts on Done")
    for character in ["-", "1", "2", "3"]:
        button(entry, character).pressed.emit()
    button(entry, "Done").grab_focus()
    root.push_input(press(JOY_BUTTON_A), true)
    root.push_input(press(JOY_BUTTON_A, false), true)
    check(game.seed_input.text == "-123", "controller entry commits seed")
    game.open_entry(game.seed_input, "seed")
    entry = game.panel.get_child(1)
    entry.append_key("456")
    back(game)
    check(game.seed_input.text == "-123" and game.state == "menu", "entry Back cancels only modal")
    game.show_settings("menu")
    back(game)
    check(game.seed_input.text == "-123", "controller Done seed survives Settings and Back")
    game.seed_input.text = "004242"
    game.show_credits()
    back(game)
    check(game.seed_input.text == "004242", "manual seed text survives Credits and Back without normalization")
    game.show_settings("menu")
    back(game)
    check(game.seed_input.text == "004242", "manual seed survives Settings and Back")
    game.journey.show_sharing()
    button(game.content, "Export next challenge").pressed.emit()
    var exported: Dictionary = Share.decode(exported_code(game.content))
    check(exported.valid and exported.payload.seed == 4242, "share export uses typed pending seed")
    back(game)
    back(game)
    check(game.seed_input.text == "4242", "export and visible pending seed agree")
    game.seed_input.text = "9007199254740992"
    game.begin_from_menu()
    check(game.state == "menu" and game.seed_input.text == "9007199254740992", "rejected seed stays editable")
    game.journey.show_sharing()
    button(game.content, "Export next challenge").pressed.emit()
    check(exported_code(game.content).is_empty() and game.journey_notice.contains("whole-number"), "invalid pending seed produces no misleading exported code")
    back(game)
    check(game.seed_input.text == "9007199254740992", "invalid seed survives sharing Back")
    var imported := Share.encode_challenge(73, "archive", "four_slot", "frost")
    check(game.journey.import_code(imported), "challenge import accepted with existing pending text")
    game.show_menu()
    check(game.seed_input.text == "73" and game.next_setup.expedition == "archive", "import replaces pending seed visibly and preserves challenge setup")
    game.seed_input.text = ""
    game.show_settings("menu")
    back(game)
    check(game.seed_input.text.is_empty() and game.seed_input.placeholder_text.contains("73") and game.pending_seed().seed == 73, "blank imported seed retains explicit visible fallback")
    game.next_setup.seed_set = false
    game.seed_input.text = ""
    game.journey.show_sharing()
    button(game.content, "Export next challenge").pressed.emit()
    exported = Share.decode(exported_code(game.content))
    check(exported.valid and exported.payload.seed == game.pending_seed().seed and not game.menu_seed_text.is_empty(), "blank export freezes a new seed shared by Begin run")
    game.show_menu()
    game.next_setup = {"expedition": "forge", "challenge": "standard", "starting_choice": "ember", "seed": 0, "seed_set": false, "configured": false}
    var chars := Entry.new()
    chars.setup("", "share")
    root.add_child(chars)
    chars.append_key("SF1:/+=_-")
    check(chars.value == "SF1:/+=_-", "share punctuation preserved")
    chars.append_key("A".repeat(4100))
    check(chars.value.length() == 4096, "share length bounded")
    chars.setup("", "recipe")
    chars.append_key("Z".repeat(50))
    check(chars.value.length() == 40, "recipe length bounded")
    chars.queue_free()
    game.start_run(42)
    Input.action_press("aim_up", 1)
    game.simulate(0.01)
    check(game.stick_aim and game.aim.y < -0.9, "controller aims up")
    Input.action_release("aim_up")
    game.simulate(0.01)
    check(game.aim.y < -0.9, "neutral stick retains aim")
    var mouse := InputEventMouseMotion.new()
    mouse.position = game.player_pos + Vector2(80, 0)
    game._input(mouse)
    game.simulate(0.01)
    check(not game.stick_aim and game.aim.x > 0.9, "mouse retakes aim")
    game.suppress_combat = false
    game._unhandled_input(press(JOY_BUTTON_A))
    check(game.dodge_time > 0, "controller south button dodges")
    game._unhandled_input(press(JOY_BUTTON_START))
    await settle()
    check(game.state == "paused", "Start pauses")
    focused(game, "pause")
    game.show_settings("paused")
    await settle()
    focused(game, "settings")
    back(game)
    check(game.state == "paused", "settings Back preserves pause")
    Input.action_press("cast")
    Input.action_press("ui_accept")
    back(game)
    var casts := game.cast_id
    game.simulate(0.01)
    check(game.state == "combat" and game.cast_id == casts, "resume suppresses held confirm/cast")
    Input.action_release("cast")
    Input.action_release("ui_accept")
    game.simulate(0.01)
    Input.action_press("cast")
    game.simulate(0.01)
    check(game.cast_id > casts, "cast works after release")
    Input.action_release("cast")
    game.show_settings("paused")
    button(game.content, "Cast:").pressed.emit()
    var key := InputEventKey.new()
    key.physical_keycode = KEY_K
    key.pressed = true
    game._input(key)
    check(Bindings.action_label("cast").contains("K"), "capture changes binding")
    check(FileAccess.file_exists(game.bindings_path), "capture persists binding")
    game.bindings.reset_defaults()
    check(game.bindings.load_bindings() and Bindings.action_label("cast").contains("K"), "saved remap loads on restart")
    button(game.content, "Dodge:").pressed.emit()
    game._input(key)
    check(game.capture_action == "dodge" and game.journey_notice.contains("already used"), "conflict stays in capture without removing cast")
    game._input(press(JOY_BUTTON_B))
    button(game.content, "Cast:").pressed.emit()
    game._input(press(JOY_BUTTON_B))
    check(game.capture_action.is_empty() and game.state == "settings", "capture cancel stays in settings")
    button(game.content, "Reset controls").pressed.emit()
    check(not Bindings.action_label("cast").contains("K"), "reset removes custom key")
    game.settings.large_text = true
    game.save_settings()
    game.settings.large_text = false
    game.load_settings()
    check(game.settings.large_text, "large text persists")
    var invalid := ConfigFile.new()
    invalid.set_value("accessibility", "large_text", "bad")
    invalid.set_value("accessibility", "master", 900)
    invalid.save(game.settings_path)
    game.load_settings()
    check(game.settings.large_text and game.settings.master == 1.0, "settings reject wrong boolean type and clamp volume")
    game.show_settings("menu")
    await settle()
    check(game.panel.get_global_rect().end.x <= 960 and game.panel.get_global_rect().end.y <= 540, "large settings panel fits viewport")
    focused(game, "large settings")
    game.show_menu()
    var before: Array = [game.components.duplicate(), game.owned.duplicate(), game.profile.data.duplicate(true)]
    game.journey.show_practice()
    await settle()
    focused(game, "practice")
    game.journey.show_grimoire()
    await settle()
    focused(game, "grimoire")
    check(button(game.content, "Name with controller") != null, "recipe controller entry available")
    back(game)
    check(game.practice, "grimoire Back keeps practice")
    back(game)
    check(not game.practice and game.state == "menu" and before == [game.components, game.owned, game.profile.data], "practice Back restores progress")
    game.profile_enabled = false
    game.components = ["projectile", "frost"]
    game.owned = ["projectile", "frost", "bounce"]
    game.draft = ["projectile", "bounce"]
    game.selected_component = "bounce"
    game.selected_reward = false
    game.challenge = "four_slot"
    game.obstacles = [Rect2(310, 200, 40, 120)]
    var offline_before: Array = [game.components.duplicate(), game.owned.duplicate(), game.draft.duplicate(), game.selected_component, game.selected_reward, game.challenge, game.obstacles.duplicate(), game.profile.data.duplicate(true)]
    game.journey.show_practice()
    await settle()
    check(button(game.content, "Abandon unsaved run") == null and button(game.content, "Suspend to menu") == null, "offline practice hides exits that bypass restore")
    game.journey.show_grimoire()
    button(game.content, "Name with controller").pressed.emit()
    back(game)
    check(game.practice and not game.journey.practice_backup.is_empty(), "offline text-entry Back preserves practice backup")
    back(game)
    check(game.practice, "offline grimoire Back returns practice")
    button(game.content, "Return to menu").pressed.emit()
    check(not game.practice and game.journey.practice_backup.is_empty() and game.state == "menu", "offline Return restores exactly once")
    check(offline_before == [game.components, game.owned, game.draft, game.selected_component, game.selected_reward, game.challenge, game.obstacles, game.profile.data], "offline Return restores nondefault spell inventory selection challenge terrain and progress")
    game.journey.show_practice()
    back(game)
    check(offline_before == [game.components, game.owned, game.draft, game.selected_component, game.selected_reward, game.challenge, game.obstacles, game.profile.data] and not game.practice, "offline root Back restores nondefault state")
    game.profile_enabled = true
    for show_page in [game.journey.show_workshop, game.journey.show_sharing, game.show_credits]:
        show_page.call()
        await settle()
        focused(game, game.state)
        back(game)
        check(game.state == "menu", "page Back returns menu")
    game.journey.show_tutorial()
    await settle()
    focused(game, "tutorial")
    back(game)
    check(game.state == "menu", "tutorial Back returns menu")
    game.start_run(42)
    game.finish_run(false)
    await settle()
    focused(game, "death")
    game.journey.show_debrief()
    await settle()
    focused(game, "debrief")
    game.journey.show_report_details()
    await settle()
    focused(game, "details")
    back(game)
    check(button(game.content, "Reward / observation details") != null, "details Back restores debrief")
    for viewport_size in [Vector2i(960, 540), Vector2i(1280, 720)]:
        root.size = viewport_size
        for large in [false, true]:
            game.settings.large_text = large
            game.storage_problem = true
            var previous_focus := root.gui_get_focus_owner()
            if previous_focus != null:
                previous_focus.release_focus()
            game.show_menu()
            await settle()
            var begin := button(game.content, "Begin run")
            check(root.gui_get_focus_owner() == begin, "fresh menu focuses Begin at %s large=%s" % [viewport_size, large])
            fully_visible(begin, "settled Begin")
            fully_visible(game.content.get_child(0), "fresh menu heading")
            for title in ["Practice forge", "Experiment guide", "Workshop", "Share / import", "Play without saving"]:
                var extra := button(game.content, title)
                check(extra != null and extra.size.x >= 100 and extra.size.y <= 100, "menu extra has usable dimensions: " + title)
                extra.grab_focus()
                await settle()
                fully_visible(extra, "focused menu extra " + title)
            game.journey.show_practice()
            var lab = load("res://scripts/spell_lab.gd").new()
            lab.open(game)
            await settle()
            check(root.gui_get_focus_owner() == lab.picker, "lab initially focuses selector")
            fully_visible(lab.picker, "settled lab selector")
            lab.back_button.grab_focus()
            await settle()
            fully_visible(lab.back_button, "lab Back visible after scrolling")
            lab.picker.grab_focus()
            await settle()
            fully_visible(lab.picker, "lab selector visible after returning from bottom")
            lab.close()
            game.journey.leave_practice()
    root.size = Vector2i(960, 540)
    for path in [game.settings_path, game.profile_path, game.bindings_path]:
        for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
    await game.audio.shutdown()
    game.queue_free()
    await settle()
    for action in Bindings.ACTIONS + Bindings.AIM_ACTIONS + ["ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down"]:
        Input.action_release(action)
        InputMap.erase_action(action)
        if original.has(action):
            InputMap.add_action(action, original[action][1])
            for event in original[action][0]:
                InputMap.action_add_event(action, event)
    print("Input journey: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
