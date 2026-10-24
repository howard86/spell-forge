extends RefCounted
## Pure deterministic spell compilation and bounded impact resolution.

const MAX_SLOTS := 5
const MAX_PROJECTILES := 16
const MAX_EFFECTS := 64
const MAX_DEPTH := 1
const MAX_CHAIN_HOPS := 3
const CHAIN_RADIUS := 180.0
const EXPLOSION_RADIUS := 72.0
const BURN_DURATION := 3.0
const BURN_DPS := 4.0
const DELAYED_BLAST_DELAY := 0.6

static func catalog() -> Dictionary:
	return {
		"projectile": {"name": "Projectile", "description": "Launch a bolt. Required first slot.", "cost": 8.0},
		"fire": {"name": "Fire", "description": "Burn for 4 damage/s for 3s; refresh, never stack.", "cost": 4.0},
		"pierce": {"name": "Pierce", "description": "Pass through two additional enemies.", "cost": 5.0},
		"split": {"name": "Split", "description": "First root hit creates two non-triggering child bolts.", "cost": 7.0},
		"bounce": {"name": "Bounce", "description": "Reflect off walls up to three times.", "cost": 4.0},
		"chain": {"name": "Chain", "description": "Jump to up to three unvisited enemies within 180px.", "cost": 8.0},
		"explode": {"name": "Explode", "description": "First root impact explodes in a 72px radius.", "cost": 8.0},
		"cooldown": {"name": "Cooldown", "description": "30% shorter cast delay; extra mana lowers sustained efficiency.", "cost": 5.0},
		"frost": {"name": "Frost", "description": "Root hits slow movement 25% (bosses 10%) for 1s; all bolts deal 15% less direct damage.", "cost": 5.0},
		"wall_charge": {"name": "Wall Charge", "description": "Requires Bounce. Direct damage is 15% lower until a wall reflection, then 50% higher.", "cost": 4.0, "requires": "bounce"},
		"delayed_blast": {"name": "Delayed Blast", "description": "Requires Explode. One blast per cast, with 50% more damage after 0.6s.", "cost": 3.0, "requires": "explode"},
	}

static func compile(components: Array) -> Dictionary:
	var result := {"valid": false, "error": "", "components": components.duplicate(),
		"mana_cost": 0.0, "cooldown": 0.5, "damage": 18.0, "speed": 390.0,
		"life": 1.6, "pierce": 0, "bounces": 0, "fire": false,
		"split": false, "chain": false, "explode": false,
		"frost": false, "wall_charge": false, "delayed_blast": false}
	if components.is_empty() or components.size() > MAX_SLOTS:
		result.error = "Choose 1 to 5 components."
		return result
	if components[0] != "projectile":
		result.error = "Projectile must be the first component."
		return result
	var seen := {}
	var entries := catalog()
	for component in components:
		if not component is String or not entries.has(component):
			result.error = "Unknown component: %s" % str(component)
			return result
		if seen.has(component):
			result.error = "Duplicate components are not allowed."
			return result
		seen[component] = true
		result.mana_cost += entries[component].cost
		match component:
			"fire", "split", "chain", "explode", "frost", "wall_charge", "delayed_blast": result[component] = true
			"pierce": result.pierce = 2
			"bounce": result.bounces = 3
			"cooldown": result.cooldown = maxf(0.18, result.cooldown * 0.7)
	# Dependencies are checked after collecting every slot, independent of order.
	for component in components:
		var prerequisite: String = entries[component].get("requires", "")
		if not prerequisite.is_empty() and not seen.has(prerequisite):
			result.error = "%s requires %s." % [entries[component].name, entries[prerequisite].name]
			return result
	result.valid = true
	return result

static func new_cast(cast_id: int, compiled: Dictionary) -> Dictionary:
	return {"cast_id": cast_id, "compiled": compiled.duplicate(true),
		"projectiles_spawned": 1 if compiled.get("valid", false) else 0,
		"effects_used": 0, "split_used": false, "delayed_blast_used": false, "chain_hops": 0, "visited": {},
		"exhausted": false}

static func _reserve(cast: Dictionary, effects: int, projectiles: int = 0) -> bool:
	if cast.effects_used + effects > MAX_EFFECTS or cast.projectiles_spawned + projectiles > MAX_PROJECTILES:
		cast.exhausted = true
		return false
	cast.effects_used += effects
	cast.projectiles_spawned += projectiles
	return true

static func resolve_hit(cast: Dictionary, projectile: Dictionary, target_id: int, targets: Array) -> Array:
	var events: Array = []
	var spell: Dictionary = cast.compiled
	var generation := int(projectile.get("generation", 0))
	if not spell.get("valid", false) or generation < 0 or generation > MAX_DEPTH:
		return events
	if not projectile.has("hit_ids"):
		projectile.hit_ids = []
	if projectile.hit_ids.has(target_id) or not _reserve(cast, 1):
		return events
	projectile.hit_ids.append(target_id)
	cast.visited[target_id] = true
	var direct_damage := float(spell.damage)
	if spell.get("frost", false):
		direct_damage *= 0.85
	if spell.get("wall_charge", false):
		direct_damage *= 1.5 if projectile.get("wall_charged", false) else 0.85
	events.append({"type": "damage", "target_id": target_id, "amount": direct_damage,
		"burn": spell.fire, "frost": spell.get("frost", false) and generation == 0})
	if generation > 0:
		return events
	var impact: Vector2 = projectile.get("position", Vector2.ZERO)
	for component in spell.components:
		match component:
			"split":
				if not cast.split_used and _reserve(cast, 2, 2):
					cast.split_used = true
					var direction: Vector2 = projectile.get("direction", Vector2.RIGHT)
					if direction.is_zero_approx():
						direction = Vector2.RIGHT
					for angle in [-0.32, 0.32]:
						events.append({"type": "split", "position": impact, "direction": direction.normalized().rotated(angle), "generation": 1})
			"chain":
				var origin := impact
				while cast.chain_hops < MAX_CHAIN_HOPS:
					var nearest := _nearest(origin, targets, cast.visited)
					if nearest.is_empty() or not _reserve(cast, 1):
						break
					var next_id := int(nearest.id)
					cast.visited[next_id] = true
					cast.chain_hops += 1
					events.append({"type": "chain", "target_id": next_id, "amount": spell.damage * 0.65, "burn": spell.fire})
					origin = nearest.position
			"explode":
				if spell.get("delayed_blast", false):
					if not cast.get("delayed_blast_used", false) and _reserve(cast, 1):
						cast.delayed_blast_used = true
						projectile.exploded = true
						events.append({"type": "delayed_explode", "position": impact,
							"radius": EXPLOSION_RADIUS, "damage": spell.damage * 0.75 * 1.5, "delay": DELAYED_BLAST_DELAY})
				elif not projectile.get("exploded", false) and _reserve(cast, 1):
					projectile.exploded = true
					events.append({"type": "explode", "position": impact, "radius": EXPLOSION_RADIUS, "damage": spell.damage * 0.75})
	return events

static func _nearest(origin: Vector2, targets: Array, visited: Dictionary) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := CHAIN_RADIUS * CHAIN_RADIUS
	for target in targets:
		if visited.has(int(target.id)):
			continue
		var distance := origin.distance_squared_to(target.position)
		if distance > best_distance:
			continue
		if nearest.is_empty() or distance < best_distance or int(target.id) < int(nearest.id):
			nearest = target
			best_distance = distance
	return nearest

## Caller reflects velocity only when this returns true; otherwise remove bolt.
static func consume_bounce(projectile: Dictionary) -> bool:
	if int(projectile.get("bounces", 0)) <= 0:
		return false
	projectile.bounces -= 1
	projectile.wall_charged = true
	return true

## Caller applies this single status by elapsed simulation time, without procs.
static func refresh_burn(existing: Dictionary, incoming_dps: float, now: float) -> Dictionary:
	var active_dps := float(existing.get("dps", 0.0)) if float(existing.get("expires_at", 0.0)) > now else 0.0
	return {"dps": maxf(active_dps, incoming_dps), "expires_at": now + BURN_DURATION}
