extends RefCounted

# Each room teaches one added role, then asks the player to handle that role
# alongside an established threat. Seeds choose authored variants, never a bag
# of unrelated enemies. Keep the totals at 4, 6, 8, 10, 12 and 14.
const ENCOUNTER_TEMPLATES := [
	[
		[["lane_archer"], ["pursuer", "pursuer", "pursuer"]],
	],
	[
		[["lane_archer", "pursuer", "pursuer"], ["archer", "pursuer", "pursuer"]],
		[["lane_archer", "pursuer", "pursuer"], ["archer", "archer", "pursuer"]],
	],
	[
		[["bulwark", "pursuer", "pursuer", "lane_archer"], ["bulwark", "pursuer", "archer", "pursuer"]],
		[["bulwark", "pursuer", "archer", "pursuer"], ["bulwark", "lane_archer", "archer", "pursuer"]],
	],
	[
		[["bulwark", "channeler", "pursuer", "pursuer", "lane_archer"], ["bulwark", "channeler", "pursuer", "pursuer", "archer"]],
		[["bulwark", "channeler", "pursuer", "archer", "archer"], ["bulwark", "channeler", "pursuer", "pursuer", "lane_archer"]],
	],
	[
		[["channeler", "swarm", "swarm", "swarm", "pursuer", "lane_archer"], ["channeler", "swarm", "swarm", "swarm", "pursuer", "archer"]],
		[["channeler", "swarm", "swarm", "swarm", "swarm", "bulwark"], ["channeler", "swarm", "swarm", "swarm", "pursuer", "lane_archer"]],
	],
	[
		[["bulwark", "channeler", "lane_archer", "pursuer", "swarm", "swarm", "swarm"], ["bulwark", "channeler", "archer", "pursuer", "swarm", "swarm", "pursuer"]],
		[["bulwark", "channeler", "archer", "archer", "pursuer", "swarm", "swarm"], ["bulwark", "channeler", "lane_archer", "pursuer", "pursuer", "swarm", "swarm"]],
	],
]

const REWARD_COMPONENTS := ["fire", "pierce", "split", "bounce", "chain", "explode", "cooldown", "frost", "wall_charge", "delayed_blast"]
const REWARD_REQUIREMENTS := {"wall_charge": "bounce", "delayed_blast": "explode"}

static func encounter(seed_value: int, index: int) -> Dictionary:
	var encounter_seed := seed_value + index * 7919
	var rng := RandomNumberGenerator.new()
	rng.seed = encounter_seed
	var waves: Array = []
	if index >= ENCOUNTER_TEMPLATES.size():
		waves = [["boss"]]
	else:
		var templates: Array = ENCOUNTER_TEMPLATES[maxi(index, 0)]
		waves = templates[rng.randi_range(0, templates.size() - 1)].duplicate(true)
	var roster: Array = []
	for wave in waves:
		roster.append_array(wave)
	return {
		"layout": rng.randi_range(0, 2),
		"roster": roster,
		"seed": encounter_seed,
		"waves": waves,
		# The first lane must be resolved alone before its pursuing wave arrives.
		"wave_threshold": 0 if index <= 0 else 1,
		"spawn_warning": 1.0,
	}

static func rewards(seed_value: int, index: int, owned: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + index * 104729 + 17
	var pool: Array = []
	for id in REWARD_COMPONENTS:
		if owned.has(id):
			continue
		if REWARD_REQUIREMENTS.has(id) and not owned.has(REWARD_REQUIREMENTS[id]):
			continue
		pool.append(id)
	var result: Array = []
	while not pool.is_empty() and result.size() < 2:
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	result.append("restore")
	return result
