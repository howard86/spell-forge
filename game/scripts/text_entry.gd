extends VBoxContainer
## Local bounded entry; never reads the clipboard automatically.
signal accepted(value: String)
signal cancelled
const Navigation = preload("res://scripts/menu_navigation.gd")
var value := ""
var mode := "recipe"
var limit := 40
var uppercase := false
var display: Label
var keys: GridContainer
func setup(initial: String, kind: String) -> void:
    mode = kind
    limit = 4096 if mode == "share" else 32 if mode == "seed" else 40
    value = initial.left(limit)
func _ready() -> void:
    custom_minimum_size = Vector2(750, 390)
    display = Label.new()
    display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(display)
    keys = GridContainer.new()
    keys.columns = 12
    add_child(keys)
    rebuild()
func append_key(character: String) -> void:
    value = (value + character).left(limit)
    refresh()
func refresh() -> void:
    display.text = "%s entry · %d / %d\n%s" % [mode.capitalize(), value.length(), limit, value.right(100)]
func add_key(title: String, action: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(58, 32)
    button.pressed.connect(action)
    keys.add_child(button)
func rebuild() -> void:
    for child in keys.get_children():
        keys.remove_child(child)
        child.queue_free()
    add_key("Done", func(): accepted.emit(value))
    add_key("Cancel", func(): cancelled.emit())
    add_key("Erase", func(): value = value.left(maxi(0, value.length() - 1)); refresh())
    add_key("Clear", func(): value = ""; refresh())
    if mode != "seed":
        add_key("Case", func(): uppercase = not uppercase; rebuild())
        add_key("Space", func(): append_key(" "))
    var alphabet := "0123456789-+" if mode == "seed" else "abcdefghijklmnopqrstuvwxyz0123456789-_:/.+=!?()"
    if uppercase:
        alphabet = alphabet.to_upper()
    for character in alphabet:
        add_key(character, func(): append_key(character))
    refresh()
    focus_keys()
func focus_keys() -> void:
    Navigation.connect_focus_neighbors(self)
    Navigation.connect_grid_neighbors(keys)
    Navigation.ensure_focus(self)
