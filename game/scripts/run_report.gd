extends RefCounted
## Bounded local observations only. No files, randomness, input, ratings or inferred outcomes.

const Registry = preload("res://scripts/content_registry.gd")
const MAX_EVENTS := 128
const MAX_DETAIL_BYTES := 4096
const MAX_EXACT_INTEGER := 9007199254740991
const MAX_TOTAL := 315360000.0
const AGGREGATE_ABSOLUTE_TOLERANCE := 0.000001
const AGGREGATE_RELATIVE_TOLERANCE := 0.000000000001
const TIME_BUCKETS := ["combat", "reward", "paused", "settings"]
const OBSERVATIONS := ["damage_dealt", "damage_taken", "mana_spent", "mana_restored", "health_restored"]
const DAMAGE_SOURCES := ["unknown", "contact", "lane", "sweep", "charge", "melee", "projectile", "hazard"]
const CAST_DENIAL_REASONS := ["mana", "cooldown", "invalid", "capacity"]
var _data: Dictionary = {}

func _init() -> void:
	reset(0)

func reset(seed_value: int, expedition: String = "forge") -> void:
	_data = {
		"schema_version": Registry.SCHEMA_VERSION, "content_version": Registry.CONTENT_VERSION,
		"seed": clampi(seed_value, -MAX_EXACT_INTEGER, MAX_EXACT_INTEGER),
		"expedition": expedition.left(64), "time": {}, "observations": {}, "damage_sources": {}, "cast_denials": {},
		"event_count": 0, "events": [], "offered": [], "chosen": [],
		"owned": ["projectile"], "equipped": ["projectile"],
		"finished": false, "won": false, "encounter": 0,
	}
	for bucket in TIME_BUCKETS:
		_data.time[bucket] = 0.0
	for observation in OBSERVATIONS:
		_data.observations[observation] = 0.0
	for source in DAMAGE_SOURCES:
		_data.damage_sources[source] = 0.0
	for reason in CAST_DENIAL_REASONS:
		_data.cast_denials[reason] = 0

func advance(state: String, delta: float) -> void:
	if _data.finished or not TIME_BUCKETS.has(state) or not is_finite(delta) or delta < 0.0:
		return
	_data.time[state] = minf(MAX_TOTAL, float(_data.time[state]) + minf(delta, MAX_TOTAL))

## Optional details keys: offered/chosen are reward-ID arrays; owned is a component-ID
## inventory; equipped is a valid ordered spell. "restore" is a reward, never a component.
## Observation event kinds accept an actual nonnegative amount in details.amount.
func event(kind: String, details: Dictionary = {}) -> void:
	if _data.finished or _data.event_count >= MAX_EXACT_INTEGER or kind.is_empty() or kind.length() > 64 or not _valid_details(kind, details):
		return
	var next_owned: Array = details.get("owned", _data.owned)
	var next_equipped: Array = details.get("equipped", _data.equipped)
	if not next_owned.has("projectile") or not _subset(next_equipped, next_owned):
		return
	_record_aggregates(_data, kind, details)
	_record_rewards(_data, details)
	_data.owned = next_owned.duplicate()
	_data.equipped = next_equipped.duplicate()
	_data.event_count += 1
	_data.events.append({"index": _data.event_count, "kind": kind, "details": details.duplicate(true)})
	if _data.events.size() > MAX_EVENTS:
		_data.events.pop_front()

func snapshot() -> Dictionary:
	return _data.duplicate(true)

## Reject malformed/unknown versions atomically; failed restore preserves the active report.
func restore(value: Dictionary) -> bool:
	if value.size() != _data.size():
		return false
	for key in _data:
		if not value.has(key):
			return false
	if not _integer(value.schema_version, Registry.SCHEMA_VERSION, Registry.SCHEMA_VERSION) or value.content_version != Registry.CONTENT_VERSION:
		return false
	if not _integer(value.seed, -MAX_EXACT_INTEGER, MAX_EXACT_INTEGER) or not value.expedition is String or value.expedition.length() > 64:
		return false
	if not _valid_totals(value.time, TIME_BUCKETS) or not _valid_totals(value.observations, OBSERVATIONS) or not _valid_totals(value.damage_sources, DAMAGE_SOURCES):
		return false
	if not value.cast_denials is Dictionary or value.cast_denials.size() != CAST_DENIAL_REASONS.size():
		return false
	for reason in CAST_DENIAL_REASONS:
		if not value.cast_denials.has(reason) or not _integer(value.cast_denials[reason], 0, MAX_EXACT_INTEGER):
			return false
	for key in ["offered", "chosen", "owned"]:
		if not _valid_ids(value[key], key != "owned"):
			return false
	if not value.owned.has("projectile") or not Registry.valid_components(value.equipped) or not _subset(value.equipped, value.owned):
		return false
	if not value.finished is bool or not value.won is bool or (value.won and not value.finished) or not _integer(value.encounter, 0, 64):
		return false
	if not _integer(value.event_count, 0, MAX_EXACT_INTEGER) or not value.events is Array or value.events.size() > MAX_EVENTS or value.events.size() != mini(int(value.event_count), MAX_EVENTS):
		return false
	var denial_count := 0
	for reason in CAST_DENIAL_REASONS:
		denial_count += int(value.cast_denials[reason])
	if denial_count > int(value.event_count):
		return false
	var damage_sum := 0.0
	for source in DAMAGE_SOURCES:
		damage_sum += float(value.damage_sources[source])
	var damage_total := float(value.observations.damage_taken)
	if not _same_amount(damage_sum, damage_total):
		return false
	if value.event_count == 0:
		for observation in OBSERVATIONS:
			if value.observations[observation] != 0:
				return false
	var expected: int = int(value.event_count) - value.events.size() + 1
	for row in value.events:
		if not row is Dictionary or row.size() != 3 or not row.has_all(["index", "kind", "details"]):
			return false
		if not _integer(row.index, expected, expected) or not row.kind is String or row.kind.is_empty() or row.kind.length() > 64 or not row.details is Dictionary or not _valid_details(row.kind, row.details):
			return false
		expected += 1
	var retained: Dictionary = _aggregate_rows(value.events)
	var evicted_count: int = int(value.event_count) - value.events.size()
	var evicted_denials := 0
	for reason in CAST_DENIAL_REASONS:
		var unretained: int = int(value.cast_denials[reason]) - int(retained.cast_denials[reason])
		if unretained < 0:
			return false
		evicted_denials += unretained
	if evicted_denials > evicted_count:
		return false
	# Even an incomplete tail is a lower bound on lifetime observations. Starting
	# from zero applies the same cap, without inventing missing earlier amounts.
	for observation in OBSERVATIONS:
		if _less_amount(float(value.observations[observation]), float(retained.observations[observation])):
			return false
	# Earlier saturation can consume capacity before a retained damage source is
	# observed. Source lower bounds are only certain when the total never capped.
	if not _same_amount(damage_total, MAX_TOTAL):
		for source in DAMAGE_SOURCES:
			if _less_amount(float(value.damage_sources[source]), float(retained.damage_sources[source])):
				return false
	for key in ["offered", "chosen"]:
		if not _subset(retained[key], value[key]) or (evicted_count == 0 and value[key] != retained[key]):
			return false
	if evicted_count == 0:
		# With complete history, every aggregate can be reconstructed under exactly
		# the same saturation policy used while accepting events.
		for observation in OBSERVATIONS:
			if not _same_amount(float(value.observations[observation]), float(retained.observations[observation])):
				return false
		for source in DAMAGE_SOURCES:
			if not _same_amount(float(value.damage_sources[source]), float(retained.damage_sources[source])):
				return false
	_data = value.duplicate(true)
	_data.seed = int(_data.seed)
	_data.event_count = int(_data.event_count)
	_data.encounter = int(_data.encounter)
	for reason in CAST_DENIAL_REASONS:
		_data.cast_denials[reason] = int(_data.cast_denials[reason])
	return true

func finish(won: bool, encounter: int, owned: Array, equipped: Array) -> Dictionary:
	if _data.finished:
		return snapshot()
	if encounter < 0 or encounter > 64 or not _valid_ids(owned) or not owned.has("projectile") or not Registry.valid_components(equipped) or not _subset(equipped, owned):
		return {}
	event("finished", {"owned": owned, "equipped": equipped, "won": won, "encounter": encounter})
	# A full event counter rejects further log entries, but validated final state
	# must still describe the supplied inventory and spell.
	_data.owned = owned.duplicate()
	_data.equipped = equipped.duplicate()
	_data.finished = true
	_data.won = won
	_data.encounter = encounter
	return snapshot()

static func _record_aggregates(data: Dictionary, kind: String, details: Dictionary) -> void:
	if OBSERVATIONS.has(kind) and kind != "damage_taken":
		data.observations[kind] = minf(MAX_TOTAL, float(data.observations[kind]) + float(details.amount))
	if kind == "damage_taken":
		var source: String = details.get("source", "unknown")
		if not DAMAGE_SOURCES.has(source):
			source = "unknown"
		# Sources share the total's remaining capacity, including during restore.
		var previous_total: float = data.observations.damage_taken
		var next_total := minf(MAX_TOTAL, previous_total + float(details.amount))
		data.damage_sources[source] += next_total - previous_total
		data.observations.damage_taken = next_total
	if kind == "cast_denied":
		data.cast_denials[details.reason] = mini(MAX_EXACT_INTEGER, int(data.cast_denials[details.reason]) + 1)

static func _record_rewards(data: Dictionary, details: Dictionary) -> void:
	for key in ["offered", "chosen"]:
		for id in details.get(key, []):
			if not data[key].has(id):
				data[key].append(id)

static func _aggregate_rows(rows: Array) -> Dictionary:
	var data := {"observations": {}, "damage_sources": {}, "cast_denials": {}, "offered": [], "chosen": []}
	for observation in OBSERVATIONS:
		data.observations[observation] = 0.0
	for source in DAMAGE_SOURCES:
		data.damage_sources[source] = 0.0
	for reason in CAST_DENIAL_REASONS:
		data.cast_denials[reason] = 0
	for row in rows:
		_record_aggregates(data, row.kind, row.details)
		_record_rewards(data, row.details)
	return data

static func _less_amount(first: float, second: float) -> bool:
	return first < second and not _same_amount(first, second)

static func _same_amount(first: float, second: float) -> bool:
	var tolerance := maxf(AGGREGATE_ABSOLUTE_TOLERANCE, maxf(first, second) * AGGREGATE_RELATIVE_TOLERANCE)
	return absf(first - second) <= tolerance

static func _valid_ids(value: Variant, rewards: bool = false) -> bool:
	if not value is Array or value.size() > Registry.COMPONENT_IDS.size() + int(rewards):
		return false
	var seen := {}
	for id in value:
		if not id is String or (not Registry.COMPONENT_IDS.has(id) and not (rewards and id == "restore")) or seen.has(id):
			return false
		seen[id] = true
	return true

static func _valid_details(kind: String, details: Dictionary) -> bool:
	if not _valid_json(details) or JSON.stringify(details).to_utf8_buffer().size() > MAX_DETAIL_BYTES:
		return false
	for key in ["offered", "chosen"]:
		if details.has(key) and not _valid_ids(details[key], true):
			return false
	if details.has("owned") and (not _valid_ids(details.owned) or not details.owned.has("projectile")):
		return false
	if details.has("equipped") and not Registry.valid_components(details.equipped):
		return false
	if details.has("owned") and details.has("equipped") and not _subset(details.equipped, details.owned):
		return false
	if kind == "damage_taken" and details.has("source") and (not details.source is String or details.source.length() > 64):
		return false
	if kind == "cast_denied" and (not details.has("reason") or not details.reason is String or not CAST_DENIAL_REASONS.has(details.reason)):
		return false
	return not OBSERVATIONS.has(kind) or (details.has("amount") and _bounded_number(details.amount, MAX_TOTAL))

static func _subset(values: Array, inventory: Array) -> bool:
	for value in values:
		if not inventory.has(value):
			return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

static func _bounded_number(value: Variant, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum

static func _valid_totals(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key) or not _bounded_number(value[key], MAX_TOTAL):
			return false
	return true

static func _valid_json(value: Variant, depth: int = 0) -> bool:
	if depth > 4:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL: return true
		TYPE_INT: return value >= -MAX_EXACT_INTEGER and value <= MAX_EXACT_INTEGER
		TYPE_FLOAT: return is_finite(value)
		TYPE_STRING: return value.length() <= 256
		TYPE_ARRAY:
			if value.size() > 32:
				return false
			for item in value:
				if not _valid_json(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 16:
				return false
			for key in value:
				if not key is String or key.length() > 64 or not _valid_json(value[key], depth + 1):
					return false
			return true
	return false
