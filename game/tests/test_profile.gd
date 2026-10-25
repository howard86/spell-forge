extends SceneTree

const Profile = preload("res://scripts/player_profile.gd")
const Report = preload("res://scripts/run_report.gd")
var checks := 0
var failures := 0
var fixture: String

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func checkpoint() -> Dictionary:
	var value := {"schema_version": 1, "content_version": "1", "seed": 137,
		"expedition": "forge", "challenge": "standard", "starting_choice": "ember",
		"encounter": 1, "state": "reward", "hp": 80.0, "mana": 50.0,
		"owned": ["projectile", "fire"], "components": ["projectile"], "draft": ["projectile", "fire"],
		"offers": ["fire", "frost", "restore"], "selected_reward": true, "selected_component": "fire",
		"elapsed": 15.3, "kills": 5, "report": {}, "route": "open"}
	sync_report(value)
	return value

func sync_report(value: Dictionary) -> void:
	var report := Report.new()
	report.reset(int(value.seed), value.expedition)
	report.event("checkpoint_inventory", {"owned": value.owned, "equipped": value.components})
	value.report = report.snapshot()

func write_file(filename: String, value: String) -> void:
	var file := FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func text_file(filename: String) -> String:
	return FileAccess.get_file_as_string(filename)

func test_checkpoint() -> void:
	check(Profile.validate_checkpoint(checkpoint()), "Valid checkpoint")
	for change in [
		{"schema_version": 2}, {"content_version": "next"}, {"seed": 1.5}, {"seed": true}, {"seed": Profile.MAX_EXACT_INTEGER + 1},
		{"expedition": "other"}, {"challenge": "daily"}, {"starting_choice": "other"}, {"encounter": 6},
		{"state": "combat"}, {"hp": -1}, {"hp": 101}, {"mana": "50"}, {"elapsed": NAN}, {"elapsed": INF},
		{"kills": -1}, {"kills": 1.5}, {"owned": ["projectile", "fire", "fire"]}, {"owned": ["projectile", "unknown"]},
		{"owned": ["fire"]}, {"draft": ["projectile", "frost"]}, {"components": ["projectile", "fire", "fire"]},
		{"draft": ["projectile", "wall_charge"]}, {"draft": ["fire"]}, {"offers": ["unknown"]},
		{"offers": ["restore", "restore"]}, {"offers": ["projectile", "fire", "frost", "chain", "restore"]},
		{"selected_reward": 1}, {"selected_component": "frost"}, {"route": "secret"}, {"report": []},
		{"report": {"events": 1}}, {"report": {"object": Vector2.ZERO}}, {"report": {"large": "x".repeat(1025)}},
	]:
		var value := checkpoint()
		value.merge(change, true)
		check(not Profile.validate_checkpoint(value), "Reject invalid checkpoint %s" % str(change))
	var extra := checkpoint()
	extra.extra = true
	check(not Profile.validate_checkpoint(extra), "Reject extra checkpoint fields")
	var missing := checkpoint()
	missing.erase("route")
	check(not Profile.validate_checkpoint(missing), "Reject missing checkpoint field")
	var four := checkpoint()
	four.challenge = "four_slot"
	four.owned = ["projectile", "fire", "frost", "pierce", "chain"]
	four.draft = four.owned.duplicate()
	check(not Profile.validate_checkpoint(four), "Four-slot challenge caps checkpoint slots")
	var nested: Dictionary = {}
	for index in 10:
		nested = {"nested": nested}
	var deep := checkpoint()
	deep.report = nested
	check(not Profile.validate_checkpoint(deep), "Report depth bounded")

	var full := checkpoint()
	full.owned = ["projectile", "fire", "frost", "pierce", "chain", "bounce"]
	full.components = ["projectile", "fire", "frost", "pierce", "chain"]
	full.draft = full.components.duplicate()
	full.selected_component = "bounce"
	sync_report(full)
	check(Profile.validate_checkpoint(full), "Full slots preserve selected owned but unequipped reward")
	full.draft.remove_at(1)
	full.selected_component = "fire"
	check(Profile.validate_checkpoint(full), "Removed selected component remains inspectable while owned")
	var report := Report.new()
	report.reset(137, "forge")
	for index in 128:
		if index % 16 == 0:
			report.event("reward_chosen", {"owned": full.owned, "equipped": full.components, "chosen": ["bounce"], "offered": ["bounce", "restore"]})
		else:
			report.event("damage_dealt", {"amount": 18.0})
	full.report = report.snapshot()
	check(full.report.events.size() == 128 and Profile.validate_checkpoint(full), "Full actual report with damage and choice history fits checkpoint budget")
	check(JSON.stringify(full.report).to_utf8_buffer().size() <= Profile.MAX_REPORT_BYTES, "Typical report fits serialized budget")

	for change in [{"seed": 138}, {"expedition": "archive"}, {"schema_version": 2}, {"content_version": "future"}, {"owned": ["projectile"]}, {"equipped": ["projectile", "fire"]}]:
		var mismatched := checkpoint()
		mismatched.report.merge(change, true)
		check(not Profile.validate_checkpoint(mismatched), "Report identity/version mismatch rejected: %s" % str(change))
	var finished := checkpoint()
	var completed_report := Report.new()
	check(completed_report.restore(finished.report), "Valid fixture report restores")
	finished.report = completed_report.finish(true, 1, finished.owned, finished.components)
	check(not Profile.validate_checkpoint(finished), "Finished report cannot resume from reward checkpoint")
	for seed_value in [-Profile.MAX_EXACT_INTEGER, -2147483648, 2147483648, Profile.MAX_EXACT_INTEGER]:
		var portable := checkpoint()
		portable.seed = seed_value
		sync_report(portable)
		check(Profile.validate_checkpoint(portable), "Exact-JSON seed validates: %s" % seed_value)
		check(Profile.validate_checkpoint(JSON.parse_string(JSON.stringify(portable))), "Exact-JSON checkpoint round trip: %s" % seed_value)
	for seed_value in [-Profile.MAX_EXACT_INTEGER - 1, Profile.MAX_EXACT_INTEGER + 1]:
		var outside := checkpoint()
		outside.seed = seed_value
		check(not Profile.validate_checkpoint(outside), "Beyond exact-JSON checkpoint seed rejected")

func test_storage_preservation() -> void:
	var profile := Profile.new()
	profile.path = fixture + "/preserved.json"
	var valid := JSON.stringify(Profile.default_data())
	for version_only in [{"schema_version": 2}, {"content_version": "future"}]:
		var original := JSON.stringify(version_only)
		write_file(profile.path, original)
		write_file(profile.path + ".bak", valid)
		check(not profile.load_profile() and profile.notice.contains("Writes blocked"), "Single unsupported version key blocks recovery writes")
		check(not profile.save_profile() and text_file(profile.path) == original and text_file(profile.path + ".bak") == valid, "Future version-only primary and good backup preserved")
		var fresh := Profile.new()
		fresh.path = profile.path
		check(not fresh.save_profile() and text_file(profile.path) == original, "Save without load also preserves future version-only primary")
	var oversized := "{\"schema_version\":2,\"padding\":\"" + "x".repeat(Profile.MAX_FILE_BYTES) + "\"}"
	write_file(profile.path, oversized)
	write_file(profile.path + ".bak", valid)
	check(profile.load_profile() and profile.notice.contains("backup") and profile.notice.contains("Writes blocked"), "Oversized unclassified primary permits read recovery with explicit write block")
	check(not profile.save_recipe("Blocked", ["projectile"]) and text_file(profile.path) == oversized and text_file(profile.path + ".bak") == valid, "Oversized primary and valid backup remain untouched")
	write_file(profile.path, valid)
	write_file(profile.path + ".bak", oversized)
	check(profile.load_profile() and profile.notice.contains("Backup") and profile.notice.contains("Writes blocked"), "Valid primary surfaces oversized backup preservation")
	check(not profile.save_profile() and text_file(profile.path) == valid and text_file(profile.path + ".bak") == oversized, "Oversized backup cannot be rotated away")
	var without_load := Profile.new()
	without_load.path = profile.path
	check(not without_load.save_profile() and text_file(profile.path + ".bak") == oversized, "Save without load preserves oversized backup")
	write_file(profile.path, "{corrupt")
	write_file(profile.path + ".bak", valid)
	check(profile.load_profile() and profile.save_profile() and text_file(profile.path + ".bak") == valid, "Ordinary malformed-current recovery still saves and retains good backup")
	for seed_value in [-Profile.MAX_EXACT_INTEGER, Profile.MAX_EXACT_INTEGER]:
		var portable := checkpoint()
		portable.seed = seed_value
		sync_report(portable)
		check(profile.set_checkpoint(portable), "Boundary seed checkpoint persists")
		check(profile.load_profile() and profile.data.checkpoint.get("seed") == seed_value, "Boundary seed checkpoint reloads exactly")

func test_storage() -> void:
	var profile := Profile.new()
	profile.path = fixture + "/profile.json"
	check(profile.load_profile() and profile.data == Profile.default_data(), "Missing profile loads default")
	check(profile.save_recipe("  Ember   test\n ", ["projectile", "fire"]), "Save normalized recipe")
	check(profile.data.recipes[0].name == "Ember test", "Recipe name normalized")
	check(profile.save_recipe("ember TEST", ["projectile", "frost"]), "Case-insensitive recipe replacement")
	check(profile.data.recipes.size() == 1 and profile.data.recipes[0].components == ["projectile", "frost"], "Recipe replacement bounded")
	check(not profile.save_recipe("\t\n", ["projectile"]) and not profile.save_recipe("Bad", ["projectile", "wall_charge"]), "Reject blank names and missing prerequisites")
	check(profile.save_recipe("x".repeat(60), ["projectile"]), "Long recipe name truncated")
	check(profile.data.recipes[1].name.length() == 40, "Recipe name cap")
	check(profile.save_recipe("x".repeat(39) + " next", ["projectile"]) and profile.data.recipes[2].name == "x".repeat(39), "Truncated name remains canonical")
	var owned := ["projectile"]
	var saved: Dictionary = profile.data.recipes[0].duplicate(true)
	var status: Dictionary = profile.recipe_status(saved, owned)
	check(not status.valid and status.missing == ["frost"] and owned == ["projectile"], "Loading recipe never grants ownership")
	status.components.clear()
	check(saved.components == ["projectile", "frost"], "Recipe status independent copy")
	check(profile.recipe_status(saved, ["projectile", "frost"]).valid, "Owned recipe valid")
	check(not profile.recipe_status({"components": ["projectile", "fire"]}, ["projectile", "fire"], 1).valid, "Recipe status honors challenge slots")
	profile.discover(["fire", "fire", "unknown", 2, "frost"])
	profile.milestone("first_clear")
	profile.milestone("first_clear")
	profile.milestone("unknown")
	check(profile.data.discoveries == ["fire", "frost"] and profile.data.milestones == ["first_clear"], "Bounded known progression only")
	check(profile.set_checkpoint(checkpoint()), "Persist checkpoint")
	var restored := Profile.new()
	restored.path = profile.path
	check(restored.load_profile() and restored.data == JSON.parse_string(JSON.stringify(profile.data)), "Profile JSON round trip")
	check(restored.clear_checkpoint() and restored.data.checkpoint.is_empty(), "Clear checkpoint")
	var good_backup := text_file(profile.path + ".bak")
	write_file(profile.path, "{corrupt")
	check(restored.load_profile() and not restored.notice.is_empty() and not restored.data.checkpoint.is_empty(), "Malformed primary recovers backup")
	check(restored.save_profile() and text_file(profile.path + ".bak") == good_backup, "Recovery save preserves last-good backup")
	var future: Dictionary = Profile.default_data()
	future.schema_version = 2
	write_file(profile.path, JSON.stringify(future))
	var future_text := text_file(profile.path)
	check(not restored.load_profile() and not restored.save_profile() and text_file(profile.path) == future_text, "Future schema remains untouched")
	future.schema_version = 1
	future.content_version = "future"
	write_file(profile.path, JSON.stringify(future))
	check(not restored.load_profile() and not restored.save_recipe("Blocked", ["projectile"]) and text_file(profile.path) == JSON.stringify(future), "Future content blocks mutation")
	write_file(profile.path, "x".repeat(Profile.MAX_FILE_BYTES + 1))
	check(restored.load_profile() and restored.notice.contains("backup") and restored.notice.contains("Writes blocked"), "Oversized primary safely recovers bounded backup read-only")
	check(not restored.save_profile(), "Oversized unclassified primary blocks writes")
	write_file(profile.path + ".bak", "{bad")
	check(not restored.load_profile(), "Both invalid files fail visibly")
	profile.path = fixture + "/library.json"
	profile.data = Profile.default_data()
	for index in Profile.MAX_RECIPES:
		check(profile.save_recipe("Recipe %d" % index, ["projectile"]), "Save bounded library entry %d" % index)
	check(not profile.save_recipe("Overflow", ["projectile"]) and profile.data.recipes.size() == 32, "Recipe library cap")
	check(profile.save_recipe("Recipe 0", ["projectile", "fire"]), "Full library allows replacement")
	check(profile.delete_recipe("Recipe 0") and not profile.delete_recipe("missing"), "Delete recipe")
	var invalid := checkpoint()
	invalid.hp = INF
	check(not profile.set_checkpoint(invalid), "Invalid checkpoint never written")
	profile.path = "user://../outside.json"
	check(not profile.save_profile(), "Reject traversal paths")
	profile.path = fixture + "/failure/profile.json"
	write_file(fixture + "/failure", "file blocks directory")
	var previous := profile.data.duplicate(true)
	check(not profile.save_recipe("Cannot persist", ["projectile"]) and not profile.notice.is_empty() and profile.data == previous, "Write failure surfaced and mutation rolled back")

func cleanup() -> void:
	var directory := DirAccess.open(fixture)
	if directory == null:
		return
	for filename in directory.get_files():
		directory.remove(filename)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))

func _initialize() -> void:
	fixture = "user://test_profile_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	test_checkpoint()
	test_storage()
	test_storage_preservation()
	cleanup()
	print("Profile: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
