extends SceneTree

const Director = preload("res://scripts/run_director.gd")
const COMPONENTS := ["fire", "pierce", "split", "bounce", "chain", "explode", "cooldown", "frost", "wall_charge", "delayed_blast"]
const KINDS := ["pursuer", "lane_archer", "archer", "bulwark", "channeler", "swarm"]
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func check_encounters() -> void:
	var seeds: Array = [-104729, -1, 0, 1, 42, 7919, 2147483647]
	for seed_value in range(64):
		seeds.append(seed_value)
	var layouts: Dictionary = {}
	var variants: Dictionary = {}
	for seed_value in seeds:
		var normal_total := 0
		for index in range(7):
			var encounter: Dictionary = Director.encounter(seed_value, index)
			check(encounter == Director.encounter(seed_value, index), "Encounter must replay from seed and room")
			check(encounter.seed == seed_value + index * 7919, "Encounter retains per-room seed")
			check(encounter.layout >= 0 and encounter.layout <= 2, "Layout stays within supported variants")
			layouts[encounter.layout] = true
			check(encounter.waves.size() >= 1 and encounter.waves.size() <= 2, "Finite encounter has at most two waves")
			check(encounter.spawn_warning == 1.0, "Reinforcements receive a full warning")
			check(encounter.wave_threshold == (0 if index == 0 else 1), "Solo lesson clears before reinforcements; later rooms permit one survivor")
			var flattened: Array = []
			for wave in encounter.waves:
				check(not wave.is_empty(), "Authored wave cannot be empty")
				for kind in wave:
					check(kind is String and (KINDS.has(kind) or kind == "boss"), "Wave contains a known enemy kind")
				flattened.append_array(wave)
			check(flattened == encounter.roster, "Legacy roster exactly flattens wave order")
			if index == 6:
				check(encounter.waves == [["boss"]], "Boss is one enemy in one wave")
				continue
			check(encounter.roster.size() == 4 + index * 2, "Normal room preserves original threat count")
			normal_total += encounter.roster.size()
			if index == 0:
				check(encounter.waves == [["lane_archer"], ["pursuer", "pursuer", "pursuer"]], "Teach one lane before three pursuers")
			if index < 2:
				check(not encounter.roster.has("bulwark"), "Bulwarks wait until room three")
			if index < 3:
				check(not encounter.roster.has("channeler"), "Channelers wait until room four")
			if index < 4:
				check(not encounter.roster.has("swarm"), "Swarms wait until room five")
			if index == 2:
				for wave in encounter.waves:
					check(wave.has("bulwark") and wave.has("pursuer"), "Bulwarks are paired with moving pressure")
			if index == 3:
				for wave in encounter.waves:
					check(wave.has("bulwark") and wave.has("channeler"), "Protected channelers form the authored room-four pair")
			if index == 4:
				for wave in encounter.waves:
					check(wave.has("swarm") and wave.has("channeler"), "Swarms are paired with area denial")
			if index > 0:
				variants["%d:%s" % [index, str(encounter.waves)]] = true
		check(normal_total == 54, "Six normal rooms retain 54 total enemies")
	check(layouts.size() == 3, "Seeds exercise all layouts")
	check(variants.size() == 10, "Seeds exercise both authored variants in each later room")
	var mutable: Dictionary = Director.encounter(42, 2)
	mutable.waves[0].clear()
	mutable.roster.clear()
	check(Director.encounter(42, 2).roster.size() == 8, "Returned encounter cannot mutate authored templates")

func check_expeditions() -> void:
	# Captured from the unmodified director at ad162de using Godot 4.7.2.
	var golden_layouts := {
		-104729: [0, 0, 0, 2, 0, 0, 0],
		0: [2, 1, 0, 2, 1, 0, 1],
		42: [2, 1, 0, 2, 2, 1, 1],
		2147483647: [1, 2, 0, 0, 2, 1, 2],
	}
	for seed_value in golden_layouts:
		for index in range(7):
			var original: Dictionary = Director.encounter(seed_value, index)
			check(original == Director.encounter(seed_value, index, "forge", "open"), "Two-argument semantics remain Forge/open")
			check(original.layout == golden_layouts[seed_value][index], "Forge preserves baseline RNG layout sequence")
			check(original.expedition == "forge" and original.obstacles.is_empty(), "Default Forge keeps the open arena")
			var reflected: Dictionary = Director.encounter(seed_value, index, "forge", "reflector")
			for key in ["layout", "roster", "seed", "waves", "wave_threshold", "spawn_warning"]:
				check(reflected[key] == original[key], "Route changes terrain without hidden encounter tuning")
			check(reflected.obstacles.size() in [1, 2], "Reflector route supplies real cover")
	var seen: Dictionary = {}
	var variants: Dictionary = {}
	for seed_value in range(64):
		var total := 0
		for index in range(7):
			var archive: Dictionary = Director.encounter(seed_value, index, "archive")
			check(archive == Director.encounter(seed_value, index, "archive"), "Archive replays from seed and room")
			check(archive.expedition == "archive" and not archive.obstacles.is_empty(), "Archive always uses reflector terrain")
			check(archive.seed == seed_value + index * 7919, "Archive retains explicit per-room seed")
			if index == 6:
				check(archive.waves == [["archivist"]] and archive.roster == ["archivist"], "Archive culminates in its own boss after six trials")
				continue
			check(archive.waves.size() == 2 and archive.roster.size() == 4 + index * 2, "Archive preserves finite trial counts")
			var flattened: Array = []
			for wave in archive.waves:
				flattened.append_array(wave)
			check(flattened == archive.roster, "Archive roster flattens waves in order")
			for kind in archive.roster:
				check(KINDS.has(kind), "Archive reuses existing normal enemy roles")
				seen[kind] = true
			variants["%d:%s" % [index, str(archive.waves)]] = true
			total += archive.roster.size()
		check(total == 54, "Archive has six trials and 54 normal enemies")
	check(seen.size() == 6 and variants.size() == 12, "Archive exercises all six roles and twelve authored wave variants")
	var mutable: Dictionary = Director.encounter(42, 2, "archive")
	mutable.waves[0].clear()
	mutable.roster.clear()
	mutable.obstacles.clear()
	var replay: Dictionary = Director.encounter(42, 2, "archive")
	check(replay.roster.size() == 8 and replay.obstacles.size() == 2, "Archive results own mutable arrays")
	check(Director.encounter(42, 0, "unknown") == Director.encounter(42, 0), "Unknown expedition falls back deterministically to Forge")

func check_rewards() -> void:
	var seen: Dictionary = {}
	# Exhaust every ownership subset, including inconsistent imported ownership.
	# Prerequisites must already be owned, never merely offered alongside a child.
	for mask in range(1 << COMPONENTS.size()):
		var owned: Array = ["projectile"]
		for bit in range(COMPONENTS.size()):
			if mask & (1 << bit):
				owned.append(COMPONENTS[bit])
		var original: Array = owned.duplicate()
		var eligible: Array = []
		for id in COMPONENTS:
			if owned.has(id):
				continue
			if id == "wall_charge" and not owned.has("bounce"):
				continue
			if id == "delayed_blast" and not owned.has("explode"):
				continue
			eligible.append(id)
		for index in range(6):
			var offers: Array = Director.rewards(mask - 512, index, owned)
			check(offers == Director.rewards(mask - 512, index, owned), "Reward draw must replay from seed, room and ownership")
			check(owned == original, "Reward selection preserves ownership input")
			check(offers.size() == mini(2, eligible.size()) + 1, "Offer contains at most two available components plus recovery")
			check(offers.back() == "restore" and offers.count("restore") == 1, "Recovery is always offered exactly once")
			for id in offers:
				check(offers.count(id) == 1, "Reward offers are unique")
				if id != "restore":
					check(eligible.has(id) and not owned.has(id), "Only unowned components with owned prerequisites are eligible")
					seen[id] = true
	check(seen.size() == COMPONENTS.size(), "Every component can appear in eligible draws")
	check(Director.rewards(42, 0, COMPONENTS) == ["restore"], "Exhausted pool still offers recovery")
	var only_charge: Array = COMPONENTS.duplicate()
	only_charge.erase("wall_charge")
	check(Director.rewards(42, 0, only_charge) == ["wall_charge", "restore"], "Single eligible component is retained beside recovery")
	var gated: Array = COMPONENTS.duplicate()
	gated.erase("bounce")
	gated.erase("wall_charge")
	check(Director.rewards(42, 0, gated) == ["bounce", "restore"], "Offering Bounce does not unlock Wall Charge in the same draw")

func _initialize() -> void:
	check_encounters()
	check_rewards()
	check_expeditions()
	print("Run director: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
