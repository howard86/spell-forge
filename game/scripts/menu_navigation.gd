extends RefCounted
## Call after each menu rebuild, once its controls have entered the scene tree.

static func _eligible(control: Control) -> bool:
	return control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled)

static func _collect(node: Node, controls: Array[Control]) -> void:
	if node is Control and not node.is_visible_in_tree():
		return
	if node is Control and _eligible(node):
		controls.append(node)
	for child in node.get_children():
		_collect(child, controls)

static func _reveal(control: Control) -> void:
	_reveal_now(control)
	if is_instance_valid(control) and control.is_inside_tree():
		_reveal_after_layout(control)

static func _reveal_after_layout(control: Control) -> void:
	# Container sorting and text wrapping settle after focus_entered. Recheck the
	# current owner before each pass so an obsolete callback cannot steal scrolling.
	var tree := control.get_tree()
	for pass_index in 3:
		await tree.process_frame
		if not is_instance_valid(control) or not control.is_inside_tree() or control.is_queued_for_deletion():
			return
		if control.get_viewport().gui_get_focus_owner() != control:
			return
		_reveal_now(control)

static func _reveal_now(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree() or control.size.x <= 0 or control.size.y <= 0:
		return
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
		parent = parent.get_parent()

static func focus_first(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var controls: Array[Control] = []
	_collect(root, controls)
	if not controls.is_empty():
		controls[0].grab_focus()
		_reveal(controls[0])

static func ensure_focus(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var current := root.get_viewport().gui_get_focus_owner()
	if current != null and (current == root or root.is_ancestor_of(current)) and _eligible(current):
		return
	if current != null and (current == root or root.is_ancestor_of(current)):
		current.release_focus()
	focus_first(root)

static func connect_focus_neighbors(root: Control) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var controls: Array[Control] = []
	_collect(root, controls)
	for index in controls.size():
		var control := controls[index]
		var previous := control.get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
		var next := control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = previous
		control.focus_neighbor_left = previous
		control.focus_neighbor_bottom = next
		control.focus_neighbor_right = next
		var reveal := _reveal.bind(control)
		if not control.focus_entered.is_connected(reveal):
			control.focus_entered.connect(reveal)
