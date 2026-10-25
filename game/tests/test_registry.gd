extends SceneTree

const Registry = preload("res://scripts/content_registry.gd")
const Spell = preload("res://scripts/spell_engine.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var expected := ["projectile", "fire", "pierce", "split", "bounce", "chain", "explode", "cooldown", "frost", "wall_charge", "delayed_blast"]
	check(Registry.SCHEMA_VERSION == 1 and Registry.CONTENT_VERSION == "1", "Explicit persistence and content versions")
	check(Registry.component_ids() == expected, "Stable component identities and ordering")
	var ids: Array = Registry.component_ids()
	ids.clear()
	check(Registry.component_ids() == expected, "Caller cannot mutate registry")
	check(Spell.catalog().keys() == expected, "Every current catalog component has a stable ID")
	for components in [["projectile"], ["projectile", "frost"], ["projectile", "wall_charge", "bounce"], ["projectile", "delayed_blast", "explode"]]:
		check(Registry.valid_components(components), "Legal current spell accepted: %s" % str(components))
	for components in [null, {}, "projectile", [], ["fire"], ["fire", "projectile"], ["projectile", 2], ["projectile", "unknown"], ["projectile", "restore"], ["projectile", "fire", "fire"], ["projectile", "wall_charge"], ["projectile", "delayed_blast"], ["projectile", "fire", "pierce", "split", "chain", "explode"]]:
		check(not Registry.valid_components(components), "Malformed/incompatible spell rejected: %s" % str(components))
	check(Registry.valid_components(["projectile", "fire", "pierce", "split"], 4), "Optional smaller slot cap accepted")
	check(not Registry.valid_components(["projectile", "fire", "pierce", "split", "chain"], 4), "Optional slot cap enforced")
	check(not Registry.valid_components(["projectile"], 0) and not Registry.valid_components(["projectile"], 6), "Invalid cap cannot bypass compiler maximum")
	print("Content registry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
