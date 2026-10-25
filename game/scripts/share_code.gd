extends RefCounted
## Portable JSON data only. Decoding never loads resources or changes ownership.
## Challenge seeds share the profile/report exact-JSON range, inclusive ±9007199254740991.

const Profile = preload("res://scripts/player_profile.gd")
const PREFIX := "SF1:"
const MAX_CODE_LENGTH := 4096
const MAX_PAYLOAD_BYTES := 2048

static func _encode(payload: Dictionary) -> String:
	var raw := JSON.stringify(payload).to_utf8_buffer()
	if raw.size() > MAX_PAYLOAD_BYTES:
		return ""
	return PREFIX + Marshalls.raw_to_base64(raw)

static func encode_recipe(name: String, components: Array) -> String:
	var clean := Profile.normalize_name(name)
	if clean.is_empty() or not Profile._build(components):
		return ""
	return _encode({"schema_version": 1, "content_version": "1", "kind": "recipe", "name": clean, "components": components.duplicate()})

static func encode_challenge(seed: int, expedition: String, challenge: String, starting_choice: String) -> String:
	var payload := {"schema_version": 1, "content_version": "1", "kind": "challenge", "seed": seed, "expedition": expedition, "challenge": challenge, "starting_choice": starting_choice}
	if not _valid_payload(payload):
		return ""
	return _encode(payload)

static func _valid_payload(payload: Dictionary) -> bool:
	if not Profile._integer(payload.get("schema_version")) or payload.get("schema_version") != 1 or payload.get("content_version") != "1":
		return false
	match payload.get("kind"):
		"recipe":
			return Profile._exact_fields(payload, ["schema_version", "content_version", "kind", "name", "components"]) and payload.name is String and not payload.name.is_empty() and payload.name == Profile.normalize_name(payload.name) and Profile._build(payload.components)
		"challenge":
			return Profile._exact_fields(payload, ["schema_version", "content_version", "kind", "seed", "expedition", "challenge", "starting_choice"]) and Profile.valid_seed(payload.seed) and payload.expedition in ["forge", "archive"] and payload.challenge in ["standard", "four_slot"] and payload.starting_choice in ["ember", "frost"]
	return false

static func _invalid(message: String) -> Dictionary:
	return {"valid": false, "error": message, "payload": {}}

static func decode(code: String) -> Dictionary:
	if code.length() > MAX_CODE_LENGTH or not code.begins_with(PREFIX):
		return _invalid("Use a supported SF1 share code (up to 4096 characters).")
	var encoded := code.trim_prefix(PREFIX)
	if encoded.is_empty() or encoded.length() % 4 != 0:
		return _invalid("Share code has malformed base64.")
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9+/]+={0,2}$")
	if pattern.search(encoded) == null:
		return _invalid("Share code has malformed base64.")
	var raw := Marshalls.base64_to_raw(encoded)
	if raw.is_empty() or raw.size() > MAX_PAYLOAD_BYTES or Marshalls.raw_to_base64(raw) != encoded:
		return _invalid("Share code payload is malformed or too large.")
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _invalid("Share code contains malformed JSON.")
	if not _valid_payload(parser.data):
		return _invalid("Share code version or contents are unsupported.")
	return {"valid": true, "error": "", "payload": parser.data.duplicate(true)}
