extends SceneTree

const EngineRules = preload("res://scripts/spell_engine.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func bolt(generation: int = 0) -> Dictionary:
	return {"generation": generation, "hit_ids": [], "position": Vector2.ZERO, "direction": Vector2.RIGHT}

func count_type(events: Array, kind: String) -> int:
	var total := 0
	for event in events:
		if event.type == kind:
			total += 1
	return total

func _initialize() -> void:
	for invalid in [[], ["fire"], ["projectile", "projectile"], ["projectile", "unknown"], ["projectile", 2], ["projectile", "fire", "pierce", "split", "chain", "explode"]]:
		var result: Dictionary = EngineRules.compile(invalid)
		check(not result.valid and not result.error.is_empty(), "Invalid build accepted: %s" % str(invalid))
	var builds := [
		["projectile"], ["projectile", "fire"], ["projectile", "pierce"],
		["projectile", "split"], ["projectile", "bounce"], ["projectile", "chain"],
		["projectile", "explode"], ["projectile", "cooldown"],
		["projectile", "pierce", "split", "fire"],
		["projectile", "split", "chain", "explode", "fire"],
		["projectile", "bounce", "pierce", "cooldown", "fire"],
		["projectile", "explode", "chain", "split", "cooldown"],
	]
	for build in builds:
		var compiled: Dictionary = EngineRules.compile(build)
		var expected_cost := 0.0
		for component in build:
			expected_cost += EngineRules.catalog()[component].cost
		check(compiled.valid, "Valid build rejected")
		check(is_equal_approx(compiled.mana_cost, expected_cost), "Cost must sum all components")
		check(compiled.mana_cost >= 8.0 and compiled.mana_cost <= 36.0, "Mana bound")
		check(compiled.cooldown >= 0.18 and compiled.cooldown <= 0.5, "Cooldown bound")
		check(not EngineRules.resolve_hit(EngineRules.new_cast(1, compiled), bolt(), 0, []).is_empty(), "Every build hits")
	var spell: Dictionary = EngineRules.compile(["projectile", "pierce", "split", "fire", "explode"])
	var cast: Dictionary = EngineRules.new_cast(2, spell)
	var root := bolt()
	var first: Array = EngineRules.resolve_hit(cast, root, 1, [])
	check(count_type(first, "split") == 2 and count_type(first, "explode") == 1, "First impact triggers")
	check(first[0].burn and first[0].amount == 18.0, "Global modifiers affect base hit")
	check(EngineRules.resolve_hit(cast, root, 1, []).is_empty(), "Repeated contact deduplicated")
	var second: Array = EngineRules.resolve_hit(cast, root, 2, [])
	check(second.size() == 1, "Piercing root never repeats split or explosion")
	var child: Array = EngineRules.resolve_hit(cast, bolt(1), 1, [])
	check(child.size() == 1 and child[0].burn, "Child inherits fire but cannot trigger")
	check(EngineRules.resolve_hit(cast, bolt(2), 8, []).is_empty(), "Depth greater than one rejected")
	check(cast.projectiles_spawned == 3, "Initial and children counted")
	# Inputs and the compiled cast are isolated from subsequent editor changes.
	var source := ["projectile", "fire"]
	var snapshot: Dictionary = EngineRules.compile(source)
	source.clear()
	var independent: Dictionary = EngineRules.new_cast(3, snapshot)
	snapshot.components.clear()
	check(independent.compiled.components == ["projectile", "fire"], "Cast snapshots configuration")
	var targets := [{"id": 4, "position": Vector2(30, 0)}, {"id": 2, "position": Vector2(10, 0)}, {"id": 3, "position": Vector2(-10, 0)}, {"id": 5, "position": Vector2(40, 0)}, {"id": 9, "position": Vector2(1000, 0)}]
	var chain_spell: Dictionary = EngineRules.compile(["projectile", "chain", "fire"])
	var chain_cast: Dictionary = EngineRules.new_cast(4, chain_spell)
	var log_a: Array = EngineRules.resolve_hit(chain_cast, bolt(), 1, targets)
	targets.reverse()
	var log_b: Array = EngineRules.resolve_hit(EngineRules.new_cast(4, chain_spell), bolt(), 1, targets)
	check(log_a == log_b, "Target input order does not change canonical event log")
	check(count_type(log_a, "chain") == 3 and log_a[1].target_id == 2, "Chain cap and stable-ID distance tie")
	check(count_type(EngineRules.resolve_hit(chain_cast, bolt(), 7, targets), "chain") == 0, "Chain hop cap is per cast")
	check(chain_cast.visited.size() == 5, "Chain visits recorded exactly once")
	var far_cast: Dictionary = EngineRules.new_cast(5, chain_spell)
	check(EngineRules.resolve_hit(far_cast, bolt(), 1, [{"id": 9, "position": Vector2(181, 0)}]).size() == 1, "Chain radius enforced")
	var split_spell: Dictionary = EngineRules.compile(["projectile", "split", "explode"])
	var capped: Dictionary = EngineRules.new_cast(6, split_spell)
	capped.projectiles_spawned = 15
	var capped_log: Array = EngineRules.resolve_hit(capped, bolt(), 1, [])
	check(count_type(capped_log, "split") == 0 and capped.projectiles_spawned == 15, "Split reserves both children atomically")
	check(capped.exhausted and count_type(capped_log, "explode") == 1, "Denied split still permits affordable later trigger")
	var exact: Dictionary = EngineRules.new_cast(6, split_spell)
	exact.projectiles_spawned = 14
	EngineRules.resolve_hit(exact, bolt(), 1, [])
	check(exact.projectiles_spawned == 16, "Projectile cap inclusive")
	var ordered_a: Dictionary = EngineRules.new_cast(7, split_spell)
	ordered_a.effects_used = 61
	var ordered_b: Dictionary = EngineRules.new_cast(7, EngineRules.compile(["projectile", "explode", "split"]))
	ordered_b.effects_used = 61
	var order_a: Array = EngineRules.resolve_hit(ordered_a, bolt(), 1, [])
	var order_b: Array = EngineRules.resolve_hit(ordered_b, bolt(), 1, [])
	check(count_type(order_a, "split") == 2 and count_type(order_a, "explode") == 0, "Split-first budget order")
	check(count_type(order_b, "explode") == 1 and count_type(order_b, "split") == 0, "Explosion-first budget order")
	check(ordered_a.effects_used == 64 and ordered_b.effects_used == 63, "Effect cap never exceeded")
	var exhausted_bolt := bolt()
	check(EngineRules.resolve_hit(ordered_a, exhausted_bolt, 9, []).is_empty() and exhausted_bolt.hit_ids.is_empty(), "Exhausted impact has no hit side effect")
	var invalid_cast: Dictionary = EngineRules.new_cast(8, EngineRules.compile([]))
	check(invalid_cast.projectiles_spawned == 0 and EngineRules.resolve_hit(invalid_cast, bolt(), 1, []).is_empty(), "Invalid cast inert")
	var bouncing := {"bounces": 3}
	for index in range(3):
		check(EngineRules.consume_bounce(bouncing), "Allowed bounce %d" % index)
	check(not EngineRules.consume_bounce(bouncing) and bouncing.bounces == 0, "Bounce stops at zero")
	var burning: Dictionary = EngineRules.refresh_burn({}, 8.0, 0.0)
	burning = EngineRules.refresh_burn(burning, 4.0, 1.0)
	check(burning.dps == 8.0 and burning.expires_at == 4.0, "Weaker burn refreshes strongest without stacking")
	burning = EngineRules.refresh_burn(burning, 12.0, 2.0)
	check(burning.dps == 12.0 and burning.expires_at == 5.0, "Stronger burn replaces strength")
	burning = EngineRules.refresh_burn(burning, 4.0, 5.0)
	check(burning.dps == 4.0, "Expired burn does not preserve old strength")
	print("Spell engine: %d checks, %d failures; %d builds" % [checks, failures, builds.size()])
	quit(1 if failures else 0)
