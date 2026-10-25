extends RefCounted
## Persist IDs, never display names or catalog positions. Changing these IDs requires migration.

const Spell = preload("res://scripts/spell_engine.gd")
const SCHEMA_VERSION := 1
const CONTENT_VERSION := "1"
const COMPONENT_IDS := ["projectile", "fire", "pierce", "split", "bounce", "chain", "explode", "cooldown", "frost", "wall_charge", "delayed_blast"]

static func component_ids() -> Array:
	return COMPONENT_IDS.duplicate()

static func valid_components(value: Variant, max_slots: int = 5) -> bool:
	if not value is Array or max_slots < 1 or max_slots > Spell.MAX_SLOTS:
		return false
	if value.is_empty() or value.size() > max_slots or value[0] != "projectile":
		return false
	var seen := {}
	for id in value:
		if not id is String or not COMPONENT_IDS.has(id) or seen.has(id):
			return false
		seen[id] = true
	return bool(Spell.compile(value).valid)
