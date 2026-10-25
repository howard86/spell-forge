extends RefCounted
## Offline, data-only profile. Recipes never grant component ownership.
## Boolean mutators persist immediately; discoveries/milestones are batched until save_profile.

const Spell = preload("res://scripts/spell_engine.gd")
const RunReport = preload("res://scripts/run_report.gd")
# JSON numbers preserve every integer exactly through this inclusive portable range.
const MAX_EXACT_INTEGER := RunReport.MAX_EXACT_INTEGER
const SCHEMA_VERSION := 1
const CONTENT_VERSION := "1"
const MAX_FILE_BYTES := 262144
const MAX_RECIPES := 32
# Portable checkpoints reserve 64 KiB / 2048 JSON values for report history.
# A report with unusually large custom detail payloads can exceed this storage budget.
const MAX_REPORT_BYTES := 65536
const MAX_REPORT_VALUES := 2048
const MILESTONES := ["first_clear", "forge_win", "archive_win", "four_slot_win"]
const PROFILE_FIELDS := ["schema_version", "content_version", "recipes", "discoveries", "milestones", "workshop", "checkpoint", "tutorial_seen"]
const CHECKPOINT_FIELDS := ["schema_version", "content_version", "seed", "expedition", "challenge", "starting_choice", "encounter", "state", "hp", "mana", "owned", "components", "draft", "offers", "selected_reward", "selected_component", "elapsed", "kills", "report", "route"]

var path: String = "user://profile.json"
var data: Dictionary = default_data()
var notice: String = ""
var _write_blocked := false
var _write_block_notice := ""

static func default_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "content_version": CONTENT_VERSION,
		"recipes": [], "discoveries": [], "milestones": [], "workshop": "ember",
		"checkpoint": {}, "tutorial_seen": false}

static func normalize_name(value: String) -> String:
	var bounded := value.left(4096)
	for index in bounded.length():
		if bounded.unicode_at(index) < 32 or bounded.unicode_at(index) == 127:
			bounded[index] = " "
	var words := bounded.split(" ", false)
	var clean := " ".join(words).strip_edges()
	for character in ["\n", "\r", "\t"]:
		clean = clean.replace(character, " ")
	clean = " ".join(clean.split(" ", false)).strip_edges().left(40).strip_edges()
	return clean

static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and value >= -MAX_EXACT_INTEGER and value <= MAX_EXACT_INTEGER)

static func valid_seed(value: Variant) -> bool:
	return _integer(value) and value >= -MAX_EXACT_INTEGER and value <= MAX_EXACT_INTEGER

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for key in fields:
		if not value.has(key):
			return false
	return true

static func _ids(value: Variant, maximum: int, allow_restore: bool = false) -> bool:
	if not value is Array or value.size() > maximum:
		return false
	var seen := {}
	var known: Dictionary = Spell.catalog()
	for id in value:
		if not id is String or seen.has(id) or not (known.has(id) or (allow_restore and id == "restore")):
			return false
		seen[id] = true
	return true

static func _build(value: Variant, maximum: int = 5) -> bool:
	return value is Array and value.size() <= maximum and _ids(value, maximum) and Spell.compile(value).valid

static func _json_safe(value: Variant, depth: int = 0, budget: Array = []) -> bool:
	if depth == 0:
		budget = [MAX_REPORT_VALUES]
	budget[0] -= 1
	if budget[0] < 0 or depth > 8:
		return false
	if value == null or value is bool:
		return true
	if value is String:
		return value.length() <= 1024
	if value is int or value is float:
		return is_finite(float(value)) and value >= -MAX_EXACT_INTEGER and value <= MAX_EXACT_INTEGER
	if value is Array:
		if value.size() > 128:
			return false
		for item in value:
			if not _json_safe(item, depth + 1, budget):
				return false
		return true
	if value is Dictionary:
		if value.size() > 64:
			return false
		for key in value:
			if not key is String or key.length() > 80 or not _json_safe(value[key], depth + 1, budget):
				return false
		return true
	return false

static func validate_checkpoint(value: Variant) -> bool:
	if not value is Dictionary or not _exact_fields(value, CHECKPOINT_FIELDS):
		return false
	if not _integer(value.schema_version) or value.schema_version != SCHEMA_VERSION or value.content_version != CONTENT_VERSION:
		return false
	if not valid_seed(value.seed):
		return false
	if not value.expedition in ["forge", "archive"] or not value.challenge in ["standard", "four_slot"] or not value.starting_choice in ["ember", "frost"]:
		return false
	if not _integer(value.encounter) or value.encounter < 0 or value.encounter > 5 or value.state != "reward":
		return false
	if not _number(value.hp, 0, 100) or not _number(value.mana, 0, 100) or not _number(value.elapsed, 0, 1000000000):
		return false
	if not _integer(value.kills) or value.kills < 0 or value.kills > 1000000000:
		return false
	var slots := 4 if value.challenge == "four_slot" else 5
	if not _ids(value.owned, Spell.catalog().size()) or not value.owned.has("projectile") or not _build(value.components, slots) or not _build(value.draft, slots):
		return false
	for id in value.components + value.draft:
		if not value.owned.has(id):
			return false
	if not _ids(value.offers, 4, true) or not value.selected_reward is bool or not value.selected_component is String:
		return false
	if value.selected_component != "" and not value.owned.has(value.selected_component):
		return false
	if not value.route in ["open", "reflector"] or not value.report is Dictionary or not _json_safe(value.report):
		return false
	if JSON.stringify(value.report).to_utf8_buffer().size() > MAX_REPORT_BYTES:
		return false
	var restored := RunReport.new()
	if not restored.restore(value.report):
		return false
	var report: Dictionary = restored.snapshot()
	return not report.finished and report.seed == value.seed and report.expedition == value.expedition and report.owned == value.owned and report.equipped == value.components

static func _valid_profile(value: Variant) -> bool:
	if not value is Dictionary or not _exact_fields(value, PROFILE_FIELDS):
		return false
	if not _integer(value.schema_version) or value.schema_version != SCHEMA_VERSION or value.content_version != CONTENT_VERSION:
		return false
	if not value.recipes is Array or value.recipes.size() > MAX_RECIPES or not _ids(value.discoveries, Spell.catalog().size()):
		return false
	var names := {}
	for recipe in value.recipes:
		if not recipe is Dictionary or not _exact_fields(recipe, ["name", "components"]) or not recipe.name is String or recipe.name.is_empty() or recipe.name != normalize_name(recipe.name) or not _build(recipe.components):
			return false
		var key: String = recipe.name.to_lower()
		if names.has(key):
			return false
		names[key] = true
	if not value.milestones is Array or value.milestones.size() > MILESTONES.size():
		return false
	var seen := {}
	for id in value.milestones:
		if not id is String or not MILESTONES.has(id) or seen.has(id):
			return false
		seen[id] = true
	return value.workshop in ["ember", "frost"] and value.tutorial_seen is bool and value.checkpoint is Dictionary and (value.checkpoint.is_empty() or validate_checkpoint(value.checkpoint))

func _safe_path() -> bool:
	return path.begins_with("user://") and not path.trim_prefix("user://").is_empty() and not path.contains("..") and not path.ends_with("/")

func _read_file(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename):
		return {"missing": true}
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null:
		return {"protected": true, "error": "Cannot classify unreadable profile (%s); original file was preserved." % error_string(FileAccess.get_open_error())}
	if file.get_length() > MAX_FILE_BYTES:
		return {"protected": true, "error": "Profile exceeds the 256 KB limit; its version cannot be classified and the original file was preserved."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "Profile contains malformed JSON."}
	var value: Variant = parser.data
	if value is Dictionary and ((value.has("schema_version") and value.schema_version != SCHEMA_VERSION) or (value.has("content_version") and value.content_version != CONTENT_VERSION)):
		return {"unsupported": true, "protected": true, "error": "Profile version is unsupported; original files were preserved."}
	if not _valid_profile(value):
		return {"error": "Profile data is invalid."}
	return {"data": value}

func _protect_originals(primary: Dictionary, backup: Dictionary) -> bool:
	var reasons: Array[String] = []
	if primary.get("protected", false):
		reasons.append("Primary: " + str(primary.error))
	if backup.get("protected", false):
		reasons.append("Backup: " + str(backup.error))
	if reasons.is_empty():
		return false
	_write_blocked = true
	_write_block_notice = "Writes blocked. " + " ".join(reasons)
	return true

func load_profile() -> bool:
	notice = ""
	_write_blocked = false
	_write_block_notice = ""
	if not _safe_path():
		notice = "Profile path must be inside user storage."
		return false
	var primary := _read_file(path)
	var backup := _read_file(path + ".bak")
	_protect_originals(primary, backup)
	if primary.has("data"):
		data = primary.data.duplicate(true)
		notice = _write_block_notice
		return true
	if primary.get("unsupported", false):
		notice = _write_block_notice
		return false
	if backup.has("data"):
		data = backup.data.duplicate(true)
		notice = "Recovered the last good profile backup."
		if _write_blocked:
			notice += " " + _write_block_notice
		return true
	if primary.get("missing", false) and backup.get("missing", false):
		data = default_data()
		return true
	notice = _write_block_notice if _write_blocked else str(primary.get("error", backup.get("error", "Profile could not be recovered.")))
	return false

func _write_text(filename: String, content: String) -> bool:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		notice = "Cannot write profile (%s)." % error_string(FileAccess.get_open_error())
		return false
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		notice = "Cannot finish profile write (%s)." % error_string(error)
		return false
	return true

func save_profile() -> bool:
	notice = ""
	if not _safe_path():
		notice = "Profile path must be inside user storage."
		return false
	if _write_blocked:
		notice = _write_block_notice
		return false
	if not _valid_profile(data):
		notice = "Invalid profile was not saved."
		return false
	var primary := _read_file(path)
	var backup := _read_file(path + ".bak")
	if _protect_originals(primary, backup):
		notice = _write_block_notice
		return false
	var serialized := JSON.stringify(data)
	if serialized.to_utf8_buffer().size() > MAX_FILE_BYTES:
		notice = "Profile exceeds the 256 KB limit."
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if directory_error != OK:
		notice = "Cannot create profile storage (%s)." % error_string(directory_error)
		return false
	if not _write_text(path + ".tmp", serialized):
		return false
	# Rotate only a validated primary, so corruption cannot replace last-good backup.
	if primary.has("data"):
		if not _write_text(path + ".bak.tmp", JSON.stringify(primary.data)):
			return false
		var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"), ProjectSettings.globalize_path(path + ".bak"))
		if backup_error != OK:
			notice = "Cannot preserve profile backup (%s)." % error_string(backup_error)
			return false
	var commit_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if commit_error != OK:
		notice = "Cannot replace profile (%s)." % error_string(commit_error)
		return false
	return true

func _persist(previous: Dictionary) -> bool:
	if save_profile():
		return true
	data = previous
	return false

func save_recipe(name: String, components: Array) -> bool:
	var clean := normalize_name(name)
	if clean.is_empty() or not _build(components):
		notice = "Choose a name and a valid spell recipe."
		return false
	var previous := data.duplicate(true)
	var recipe := {"name": clean, "components": components.duplicate()}
	for index in data.recipes.size():
		if data.recipes[index].name.to_lower() == clean.to_lower():
			data.recipes[index] = recipe
			return _persist(previous)
	if data.recipes.size() >= MAX_RECIPES:
		notice = "The recipe library is full (32 recipes)."
		return false
	data.recipes.append(recipe)
	return _persist(previous)

func delete_recipe(name: String) -> bool:
	var key := normalize_name(name).to_lower()
	for index in data.recipes.size():
		if data.recipes[index].name.to_lower() == key:
			var previous := data.duplicate(true)
			data.recipes.remove_at(index)
			return _persist(previous)
	notice = "Recipe not found."
	return false

func recipe_status(recipe: Dictionary, owned: Array, max_slots: int = 5) -> Dictionary:
	var components: Variant = recipe.get("components", [])
	var result := {"valid": false, "missing": [], "components": components.duplicate() if components is Array else []}
	if max_slots < 1 or max_slots > 5 or not _build(components, max_slots):
		return result
	for id in components:
		if not owned.has(id):
			result.missing.append(id)
	result.valid = result.missing.is_empty()
	return result

func discover(ids: Array) -> void:
	for id in ids:
		if id is String and Spell.catalog().has(id) and not data.discoveries.has(id):
			data.discoveries.append(id)

func milestone(id: String) -> void:
	if MILESTONES.has(id) and not data.milestones.has(id):
		data.milestones.append(id)

func set_checkpoint(value: Dictionary) -> bool:
	if not validate_checkpoint(value):
		notice = "Only a valid reward-screen checkpoint can be saved."
		return false
	var previous := data.duplicate(true)
	data.checkpoint = value.duplicate(true)
	return _persist(previous)

func clear_checkpoint() -> bool:
	var previous := data.duplicate(true)
	data.checkpoint = {}
	return _persist(previous)
