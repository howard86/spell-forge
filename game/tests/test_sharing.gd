extends SceneTree

const Share = preload("res://scripts/share_code.gd")
const Profile = preload("res://scripts/player_profile.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func raw_code(value: Variant) -> String:
	return "SF1:" + Marshalls.raw_to_base64(JSON.stringify(value).to_utf8_buffer())

func _initialize() -> void:
	var recipe := ["projectile", "wall_charge", "bounce", "frost"]
	var code := Share.encode_recipe("  Wall   dance  ", recipe)
	var decoded: Dictionary = Share.decode(code)
	check(decoded.valid and decoded.error.is_empty() and decoded.payload.name == "Wall dance" and decoded.payload.components == recipe, "Recipe round trip preserves slot order and prerequisites")
	check(recipe == ["projectile", "wall_charge", "bounce", "frost"], "Encoding preserves input")
	check(Share.decode(Share.encode_recipe("x".repeat(39) + " next", ["projectile"])).valid, "Truncated names round trip canonically")
	for seed in [0, -Profile.MAX_EXACT_INTEGER, -2147483648, 2147483648, Profile.MAX_EXACT_INTEGER]:
		for expedition in ["forge", "archive"]:
			for challenge in ["standard", "four_slot"]:
				for choice in ["ember", "frost"]:
					var result: Dictionary = Share.decode(Share.encode_challenge(seed, expedition, challenge, choice))
					check(result.valid and result.payload.seed == seed and result.payload.expedition == expedition and result.payload.challenge == challenge and result.payload.starting_choice == choice, "Challenge round trip")
	check(Share.encode_recipe("Bad", ["projectile", "wall_charge"]).is_empty(), "Encoding requires compiler prerequisites")
	check(Share.encode_recipe(" ", ["projectile"]).is_empty(), "Encoding requires name")
	check(Share.encode_challenge(Profile.MAX_EXACT_INTEGER + 1, "forge", "standard", "ember").is_empty(), "Encoding bounds seed")
	check(Share.encode_challenge(-Profile.MAX_EXACT_INTEGER - 1, "forge", "standard", "ember").is_empty(), "Encoding bounds negative seed")
	check(Share.encode_challenge(1, "unknown", "standard", "ember").is_empty(), "Encoding validates modes")
	for malformed in ["", "SF2:AAAA", "SF1:", "SF1:!!!!", "SF1:abcd=", "SF1:AAAA====", "SF1:ab==", "SF1:" + "A".repeat(4096), "SF1:" + Marshalls.raw_to_base64("{bad".to_utf8_buffer()), raw_code([]), raw_code(null)]:
		var result: Dictionary = Share.decode(malformed)
		check(not result.valid and not result.error.is_empty() and result.payload.is_empty(), "Malformed share rejected")
	var base := {"schema_version": 1, "content_version": "1", "kind": "recipe", "name": "Build", "components": ["projectile"]}
	for change in [{"schema_version": 2}, {"schema_version": true}, {"content_version": "future"}, {"kind": "resource"}, {"name": 1}, {"name": ""}, {"name": "x".repeat(41)}, {"name": "  name"}, {"components": "projectile"}, {"components": ["projectile", "unknown"]}, {"components": ["projectile", "fire", "fire"]}, {"components": ["projectile", "delayed_blast"]}, {"components": ["projectile", "fire", "chain", "frost", "pierce", "bounce"]}, {"extra": "res://payload.gd"}]:
		var payload := base.duplicate(true)
		payload.merge(change, true)
		check(not Share.decode(raw_code(payload)).valid, "Invalid recipe payload rejected: %s" % str(change))
	var challenge := {"schema_version": 1, "content_version": "1", "kind": "challenge", "seed": 1, "expedition": "forge", "challenge": "standard", "starting_choice": "ember"}
	for change in [{"seed": true}, {"seed": 1.5}, {"seed": Profile.MAX_EXACT_INTEGER + 1}, {"seed": -Profile.MAX_EXACT_INTEGER - 1}, {"expedition": "unknown"}, {"challenge": "daily"}, {"starting_choice": "unknown"}, {"owned": ["fire"]}]:
		var payload := challenge.duplicate(true)
		payload.merge(change, true)
		check(not Share.decode(raw_code(payload)).valid, "Invalid challenge payload rejected")
	var missing := base.duplicate(true)
	missing.erase("components")
	check(not Share.decode(raw_code(missing)).valid, "Missing fields rejected without access errors")
	check(not Share.decode(raw_code({"large": "x".repeat(3000)})).valid, "Oversized decoded payload rejected")
	var malformed_utf8 := JSON.stringify(base).to_utf8_buffer()
	var name_start := JSON.stringify(base).find("Build")
	malformed_utf8[name_start] = 0xFF
	var utf8_result: Dictionary = Share.decode("SF1:" + Marshalls.raw_to_base64(malformed_utf8))
	print("UTF-8 probe: invalid byte accepted=%s error=%s" % [utf8_result.valid, utf8_result.error])
	check(not utf8_result.valid, "Invalid UTF-8 byte in otherwise valid recipe is rejected")
	check(Share.decode(Share.encode_recipe("寒霜 🔥", ["projectile", "frost"])).valid, "Valid multibyte UTF-8 recipe names round trip")
	print("Sharing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
