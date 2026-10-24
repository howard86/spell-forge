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

func test_upgrade_compilation() -> void:
	var entries: Dictionary = EngineRules.catalog()
	for row in [{"id": "frost", "cost": 5.0}, {"id": "wall_charge", "cost": 4.0}, {"id": "delayed_blast", "cost": 3.0}]:
		check(entries.has(row.id) and entries[row.id].cost == row.cost, "Upgrade price: %s" % row.id)
	for row in [
		{"components": ["projectile", "frost"], "cost": 13.0},
		{"components": ["projectile", "bounce", "wall_charge"], "cost": 16.0},
		{"components": ["projectile", "wall_charge", "bounce"], "cost": 16.0},
		{"components": ["projectile", "explode", "delayed_blast"], "cost": 19.0},
		{"components": ["projectile", "delayed_blast", "explode"], "cost": 19.0},
		{"components": ["projectile", "wall_charge", "delayed_blast", "explode", "bounce"], "cost": 27.0},
	]:
		var compiled: Dictionary = EngineRules.compile(row.components)
		check(compiled.valid and is_equal_approx(compiled.mana_cost, row.cost), "Upgrade build pricing: %s" % str(row.components))
		check(compiled.damage == 18.0, "Upgrades preserve base damage")
		for component in ["frost", "wall_charge", "delayed_blast"]:
			check(compiled[component] == row.components.has(component), "Explicit upgrade flag: %s" % component)
	for components in [
		["projectile", "wall_charge"], ["projectile", "delayed_blast"],
		["projectile", "wall_charge", "explode"], ["projectile", "delayed_blast", "bounce"],
		["projectile", "frost", "frost"],
		["projectile", "bounce", "wall_charge", "frost", "explode", "delayed_blast"],
	]:
		var invalid: Dictionary = EngineRules.compile(components)
		check(not invalid.valid and not invalid.error.is_empty(), "Invalid upgrade build rejected: %s" % str(components))
	var plain: Dictionary = EngineRules.compile(["projectile"])
	check(not plain.frost and not plain.wall_charge and not plain.delayed_blast, "Old builds default upgrades off")

func test_upgrade_impacts() -> void:
	# Direct penalties apply to children too, but only a root direct hit carries slow.
	for row in [
		{"components": ["projectile"], "charged": false, "amount": 18.0},
		{"components": ["projectile", "frost", "fire"], "charged": false, "amount": 15.3},
		{"components": ["projectile", "wall_charge", "bounce"], "charged": false, "amount": 15.3},
		{"components": ["projectile", "wall_charge", "bounce"], "charged": true, "amount": 27.0},
		{"components": ["projectile", "frost", "wall_charge", "bounce", "fire"], "charged": false, "amount": 13.005},
		{"components": ["projectile", "frost", "wall_charge", "bounce", "fire"], "charged": true, "amount": 22.95},
	]:
		for generation in [0, 1]:
			var compiled: Dictionary = EngineRules.compile(row.components)
			var projectile := bolt(generation)
			projectile.wall_charged = row.charged
			var events: Array = EngineRules.resolve_hit(EngineRules.new_cast(20, compiled), projectile, 1, [])
			check(events.size() == 1 and is_equal_approx(events[0].amount, row.amount), "Direct damage factors: %s, generation %d" % [str(row.components), generation])
			check(events[0].frost == (compiled.frost and generation == 0), "Frost marks root contacts only")
			check(events[0].burn == compiled.fire, "Direct penalties preserve burn inheritance")
	var charge_spell: Dictionary = EngineRules.compile(["projectile", "bounce", "wall_charge"])
	var charge_cast: Dictionary = EngineRules.new_cast(21, charge_spell)
	var projectile := bolt()
	projectile.bounces = 3
	check(not projectile.get("wall_charged", false), "Missing wall charge state defaults uncharged")
	check(is_equal_approx(EngineRules.resolve_hit(charge_cast, projectile, 1, [])[0].amount, 15.3), "Unreflected projectile pays damage penalty")
	for index in range(3):
		check(EngineRules.consume_bounce(projectile) and projectile.wall_charged, "Successful reflection enables charge")
		var events: Array = EngineRules.resolve_hit(charge_cast, projectile, index + 2, [])
		check(events.size() == 1 and events[0].amount == 27.0, "Repeated reflections never compound charge")
	check(not EngineRules.consume_bounce(projectile) and projectile.wall_charged, "Exhausted bounce retains earlier charge")
	for remaining in [0, -1]:
		var denied := {"bounces": remaining}
		check(not EngineRules.consume_bounce(denied) and not denied.get("wall_charged", false) and denied.bounces == remaining, "Failed reflection never grants charge")
	# Secondary event damage remains based on the unchanged base stat.
	var secondary: Dictionary = EngineRules.compile(["projectile", "frost", "chain", "explode", "fire"])
	var secondary_events: Array = EngineRules.resolve_hit(EngineRules.new_cast(22, secondary), bolt(), 1, [{"id": 2, "position": Vector2(20, 0)}])
	check(secondary_events[1].type == "chain" and is_equal_approx(secondary_events[1].amount, 11.7) and secondary_events[1].burn and not secondary_events[1].get("frost", false), "Frost changes neither chain damage nor its burn and never slows via chain")
	check(secondary_events[2].type == "explode" and secondary_events[2].damage == 13.5 and not secondary_events[2].get("frost", false), "Frost does not amplify or propagate via explosions")
	var wall_secondary: Dictionary = EngineRules.compile(["projectile", "bounce", "wall_charge", "chain", "explode"])
	for charged in [false, true]:
		var wall_bolt := bolt()
		wall_bolt.wall_charged = charged
		var events: Array = EngineRules.resolve_hit(EngineRules.new_cast(23, wall_secondary), wall_bolt, 1, [{"id": 2, "position": Vector2(20, 0)}])
		check(is_equal_approx(events[1].amount, 11.7) and events[2].damage == 13.5, "Wall Charge never changes chain or explosion damage")

func test_delayed_blast() -> void:
	var compiled: Dictionary = EngineRules.compile(["projectile", "pierce", "delayed_blast", "explode", "frost"])
	var cast: Dictionary = EngineRules.new_cast(24, compiled)
	var root := bolt()
	root.position = Vector2(37, 48)
	var first: Array = EngineRules.resolve_hit(cast, root, 1, [])
	check(count_type(first, "delayed_explode") == 1 and count_type(first, "explode") == 0, "Delayed Blast replaces immediate explosion")
	var blast: Dictionary = first[1]
	check(blast.position == Vector2(37, 48) and blast.radius == 72.0 and blast.damage == 20.25 and blast.delay == 0.6, "Delayed Blast snapshots fixed position, radius, unpenalized damage and delay")
	check(cast.effects_used == 2 and cast.delayed_blast_used and root.exploded, "Delayed Blast reserves exactly one effect and records success")
	check(not blast.has("burn") and not blast.has("frost"), "Delayed area event carries no status procs")
	check(EngineRules.resolve_hit(cast, root, 1, []).is_empty(), "Repeated delayed contact is deduplicated")
	check(EngineRules.resolve_hit(cast, root, 2, []).size() == 1, "Piercing root never repeats delayed blast")
	check(EngineRules.resolve_hit(cast, bolt(), 3, []).size() == 1, "A second root cannot repeat a cast's delayed blast")
	check(EngineRules.resolve_hit(cast, bolt(1), 4, []).size() == 1, "Child cannot trigger delayed blast")
	root.position = Vector2(90, 90)
	check(blast.position == Vector2(37, 48), "Queued event position survives later projectile movement")
	var separate: Array = EngineRules.resolve_hit(EngineRules.new_cast(25, compiled), bolt(), 1, [])
	check(count_type(separate, "delayed_explode") == 1, "New cast has a fresh delayed allowance")
	var denied: Dictionary = EngineRules.new_cast(26, compiled)
	denied.effects_used = EngineRules.MAX_EFFECTS - 1
	var denied_bolt := bolt()
	var denied_events: Array = EngineRules.resolve_hit(denied, denied_bolt, 1, [])
	check(denied_events.size() == 1 and denied.effects_used == 64 and denied.exhausted, "Delayed Blast cannot exceed effect cap")
	check(not denied.delayed_blast_used and not denied_bolt.get("exploded", false), "Denied delayed reservation leaves trigger unused")
	var exact: Dictionary = EngineRules.new_cast(27, compiled)
	exact.effects_used = EngineRules.MAX_EFFECTS - 2
	check(count_type(EngineRules.resolve_hit(exact, bolt(), 1, []), "delayed_explode") == 1 and exact.effects_used == 64, "Delayed Blast fits exact remaining budget")
	for row in [
		{"components": ["projectile", "split", "explode", "delayed_blast"], "splits": 2, "blasts": 0, "used": 64},
		{"components": ["projectile", "delayed_blast", "explode", "split"], "splits": 0, "blasts": 1, "used": 63},
	]:
		var ordered: Dictionary = EngineRules.new_cast(28, EngineRules.compile(row.components))
		ordered.effects_used = 61
		var events: Array = EngineRules.resolve_hit(ordered, bolt(), 1, [])
		check(count_type(events, "split") == row.splits and count_type(events, "delayed_explode") == row.blasts and ordered.effects_used == row.used, "Delayed replacement preserves slot-ordered budget semantics")

func _initialize() -> void:
	test_upgrade_compilation()
	test_upgrade_impacts()
	test_delayed_blast()
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
