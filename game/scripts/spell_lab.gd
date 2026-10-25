extends VBoxContainer
const Preview = preload("res://scripts/spell_preview.gd")
const Navigation = preload("res://scripts/menu_navigation.gd")
const IDS := ["frost_split_order", "split_spread", "repulse"]
const RULES := ["Frost before Split: children inherit the 1s slow. Split before Frost: only root hits slow. All bolts retain the 15% direct damage penalty.", "Split children exclude their parent's hit target. All damage, angles, counts and resource costs stay the same.", "Repulse occupies one extra slot and costs +5 mana. Accepted root hits push living ordinary targets 48px; bosses 12px. Cover and bounds block movement. Child hits never push."]
var game: Node
var proxy: Node
var experiment := 0
var reversed_order := false
var preview: Control
var body: VBoxContainer
var picker: OptionButton
var order_button: Button
var back_button: Button

func open(owner_game: Node) -> void:
    if not owner_game.practice:
        free()
        return
    game = owner_game
    game.journey.page_start("EXPERIMENTAL SPELL LAB · practice only")
    game.journey.page.add_child(self)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    proxy = game.get_script().new()
    proxy.obstacles = game.obstacles.duplicate(true)
    var note := Label.new()
    note.text = "Only this lab uses these rules. Runs and saved recipes use standard rules."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(note)
    picker = OptionButton.new()
    for title in ["Frost / Split ordering", "Split target exclusion", "Repulse (+1 slot, +5 mana)"]:
        picker.add_item(title)
    picker.item_selected.connect(func(index: int): experiment = index; rebuild())
    add_child(picker)
    body = VBoxContainer.new()
    add_child(body)
    back_button = Button.new()
    back_button.text = "Back to practice forge"
    back_button.pressed.connect(close)
    add_child(back_button)
    if game.has_method("finish_menu"):
        game.back_action = close
    rebuild()

func rebuild() -> void:
    var previous_focus := get_viewport().gui_get_focus_owner()
    var restore_order := is_instance_valid(order_button) and previous_focus == order_button
    order_button = null
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    var rule := Label.new()
    rule.text = RULES[experiment]
    rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(rule)
    var recipe: Array = ["projectile", "split"]
    if experiment == 0:
        recipe = ["projectile", "split", "frost"] if reversed_order else ["projectile", "frost", "split"]
        order_button = Button.new()
        order_button.text = "Swap Frost / Split order"
        order_button.pressed.connect(func(): reversed_order = not reversed_order; rebuild())
        body.add_child(order_button)
    elif experiment == 2:
        recipe = ["projectile", "explode", "delayed_blast"]
    proxy.components = recipe.duplicate()
    proxy.draft = recipe.duplicate()
    var label := Label.new()
    label.text = "Both builds: " + " → ".join(recipe) + (" + virtual Repulse in prototype" if experiment == 2 else "")
    body.add_child(label)
    preview = Preview.new()
    preview.source = proxy
    preview.experiment_id = IDS[experiment]
    preview.scenario = "moving" if experiment == 0 else "boss" if experiment == 1 else "cluster"
    preview.custom_minimum_size = Vector2(720, 145)
    body.add_child(preview)
    var caveat := Label.new()
    caveat.text = "Animation: prototype. Baseline uses identical recipe, terrain and scenario. One cast / 2 seconds; no attacks. These are candidates, not accepted balance changes."
    caveat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(caveat)
    var target: Control = order_button if restore_order and is_instance_valid(order_button) else previous_focus
    if not is_instance_valid(target) or not is_ancestor_of(target):
        target = picker
    call_deferred("restore_navigation", target)

func restore_navigation(target: Control) -> void:
    if not is_inside_tree() or is_queued_for_deletion():
        return
    # Rebuild neighbors only after new controls have entered the tree. The page's
    # menu pass may choose its default; restore the user's local control after it.
    if game.has_method("finish_menu"):
        game.finish_menu()
    else:
        Navigation.connect_focus_neighbors(self)
    if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
        target = picker
    target.grab_focus()
    Navigation._reveal(target)

func close() -> void:
    game.show_reward()

func _exit_tree() -> void:
    if is_instance_valid(proxy):
        proxy.free()
