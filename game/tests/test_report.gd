extends SceneTree

const Report = preload("res://scripts/run_report.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var report = Report.new()
	report.reset(4242, "forge")
	for bucket in ["combat", "reward", "paused", "settings"]:
		report.advance(bucket, 2.5)
		report.advance(bucket, -1.0)
		report.advance(bucket, NAN)
		report.advance(bucket, INF)
	report.advance("menu", 50.0)
	check(report.snapshot().time == {"combat": 2.5, "reward": 2.5, "paused": 2.5, "settings": 2.5}, "State buckets exclude unknown, negative and nonfinite deltas")
	report.event("reward_offered", {"offered": ["fire", "restore"]})
	report.event("reward_chosen", {"chosen": ["restore"]})
	report.event("spell_equipped", {"owned": ["projectile", "fire"], "equipped": ["projectile"]})
	check(report.snapshot().offered == ["fire", "restore"] and report.snapshot().chosen == ["restore"], "Offered and chosen are explicit and distinct")
	check(report.snapshot().owned == ["projectile", "fire"] and report.snapshot().equipped == ["projectile"], "Inventory does not imply equipment")
	var source := {"nested": {"items": ["original"]}}
	report.event("note", source)
	source.nested.items[0] = "mutated"
	var detached: Dictionary = report.snapshot()
	detached.events[3].details.nested.items[0] = "detached"
	detached.time.combat = 99
	check(report.snapshot().events[3].details.nested.items == ["original"] and report.snapshot().time.combat == 2.5, "Event input and snapshots are deeply isolated")
	for observation in Report.OBSERVATIONS:
		report.event(observation, {"amount": 7.5})
		report.event(observation, {"amount": -2})
		report.event(observation, {"amount": INF})
		check(report.snapshot().observations[observation] == 7.5, "Only observed valid amounts accumulate: %s" % observation)
	var before: Dictionary = report.snapshot()
	for details in [{"owned": ["fire"]}, {"equipped": ["projectile", "bounce"]}, {"offered": ["typo"]}, {"object": Vector2.ZERO}, {"bad": NAN}, {"nested": {"a": {"b": {"c": {"d": 1}}}}}]:
		report.event("bad", details)
	check(report.snapshot() == before, "Malformed payloads leave report unchanged")
	for index in range(200):
		report.event("sample", {"sample": index})
	var capped: Dictionary = report.snapshot()
	check(capped.event_count == 209 and capped.events.size() == 128, "Recent event cap preserves total accepted-event count")
	check(capped.events[0].index == 82 and capped.events[-1].index == 209, "Recent rows retain monotonic original indices")
	check(capped.offered == ["fire", "restore"] and capped.observations.damage_dealt == 7.5, "Bounded factual summaries survive event eviction")
	var resumed = Report.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(capped))), "Snapshot survives JSON round trip and strict restore")
	check(JSON.parse_string(JSON.stringify(resumed.snapshot())) == JSON.parse_string(JSON.stringify(capped)), "Restore preserves all JSON-observable data")
	var restored_before: Dictionary = resumed.snapshot()
	var broken_values: Array = []
	for field in ["schema_version", "time", "events", "seed"]:
		var broken: Dictionary = capped.duplicate(true)
		broken.erase(field)
		broken_values.append(broken)
	for change in [
		{"schema_version": 2}, {"content_version": "future"}, {"event_count": 209.5},
		{"time": {"combat": NAN, "reward": 0, "paused": 0, "settings": 0}},
		{"equipped": ["projectile", "chain"]}, {"owned": ["projectile", "unknown"]},
		{"won": true}, {"encounter": -1}, {"seed": "4242"}, {"extra": "field"},
	]:
		var broken: Dictionary = capped.duplicate(true)
		broken.merge(change, true)
		broken_values.append(broken)
	var wrong_index: Dictionary = capped.duplicate(true)
	wrong_index.events[0].index = 1
	broken_values.append(wrong_index)
	var wrong_event: Dictionary = capped.duplicate(true)
	wrong_event.events[0].details = {"offered": ["typo"]}
	broken_values.append(wrong_event)
	var excess: Dictionary = capped.duplicate(true)
	excess.events.append(excess.events[-1])
	broken_values.append(excess)
	for broken in broken_values:
		check(not resumed.restore(broken) and resumed.snapshot() == restored_before, "Malformed restore rejects atomically")
	check(report.finish(true, 6, ["projectile"], ["projectile", "fire"]).is_empty(), "Finish rejects equipment outside inventory")
	var final: Dictionary = report.finish(true, 6, ["projectile", "fire"], ["projectile", "fire"])
	check(final.finished and final.won and final.encounter == 6 and final.equipped == ["projectile", "fire"], "Finish records actual outcome and final spell")
	report.event("damage_taken", {"amount": 10})
	report.advance("combat", 10)
	check(report.snapshot() == final and report.finish(false, 0, [], []) == final, "Finished report is immutable and finish idempotent")
	check(resumed.restore(JSON.parse_string(JSON.stringify(final))), "Final report restores after JSON round trip")
	report.reset(7, "test")
	check(report.snapshot().event_count == 0 and report.snapshot().seed == 7 and not report.snapshot().finished and report.snapshot().time.combat == 0.0, "Reset clears run observations")
	report.advance("combat", Report.MAX_TOTAL * 2.0)
	check(report.snapshot().time.combat == Report.MAX_TOTAL, "Time totals have a finite documented ceiling")
	report.reset(12, "archive")
	report.event("route_selected", {"route": "archive_left", "expedition": "archive"})
	check(report.snapshot().expedition == "archive" and report.snapshot().events[0].details.route == "archive_left", "Alternative expedition and route strings are factual observations")
	var oversized := {}
	for index in range(16):
		oversized["key_%d" % index] = "x".repeat(256)
	var before_oversize: Dictionary = report.snapshot()
	report.event("note", oversized)
	check(report.snapshot() == before_oversize, "Details byte cap rejects oversized bounded-structure payloads")
	var too_large: Dictionary = report.snapshot()
	too_large.events[0].details = oversized
	check(not report.restore(too_large) and report.snapshot() == before_oversize, "Restore enforces encoded details byte cap atomically")
	var aggregate = Report.new()
	for source_kind in Report.DAMAGE_SOURCES:
		aggregate.event("damage_taken", {"amount": 1.0, "source": source_kind})
	aggregate.event("damage_taken", {"amount": 2.0})
	aggregate.event("damage_taken", {"amount": 3.0, "source": "unclassified_observation"})
	for reason in Report.CAST_DENIAL_REASONS:
		aggregate.event("cast_denied", {"reason": reason})
	var before_invalid_denial: Dictionary = aggregate.snapshot()
	aggregate.event("cast_denied", {"reason": "guessed"})
	aggregate.event("damage_taken", {"amount": 1.0, "source": 2})
	check(aggregate.snapshot() == before_invalid_denial, "Malformed denial and source leave aggregates unchanged")
	for index in range(140):
		aggregate.event("sample", {"sample": index})
	var aggregate_state: Dictionary = aggregate.snapshot()
	check(aggregate_state.events.size() == 128 and aggregate_state.events[0].kind == "sample", "Aggregate observations can leave the recent-event tail")
	check(aggregate_state.observations.damage_taken == 13.0 and aggregate_state.damage_sources.unknown == 6.0 and aggregate_state.damage_sources.charge == 1.0, "Damage source totals persist after rollover without guessing missing causes")
	check(aggregate_state.cast_denials == {"mana": 1, "cooldown": 1, "invalid": 1, "capacity": 1}, "Denial counts persist after rollover")
	var restored_aggregate = Report.new()
	check(restored_aggregate.restore(JSON.parse_string(JSON.stringify(aggregate_state))) and restored_aggregate.snapshot().damage_sources == aggregate_state.damage_sources and restored_aggregate.snapshot().cast_denials == aggregate_state.cast_denials, "Damage and denial aggregates round trip through JSON")
	for aggregate_field in ["damage_sources", "cast_denials"]:
		var invalid_aggregate: Dictionary = aggregate_state.duplicate(true)
		invalid_aggregate[aggregate_field]["unexpected"] = 1
		check(not restored_aggregate.restore(invalid_aggregate), "Aggregate restore rejects non-whitelisted categories")
	var invalid_denial_count: Dictionary = aggregate_state.duplicate(true)
	invalid_denial_count.cast_denials.mana = 1.5
	check(not restored_aggregate.restore(invalid_denial_count), "Denial count must be a bounded nonnegative integer")
	var coherent = Report.new()
	var fresh: Dictionary = coherent.snapshot()
	var impossible_denial: Dictionary = fresh.duplicate(true)
	impossible_denial.cast_denials.mana = 1
	check(not coherent.restore(impossible_denial) and coherent.snapshot() == fresh, "Fresh report cannot restore denial observations without events; rejection is atomic")
	var excessive_denials: Dictionary = aggregate_state.duplicate(true)
	excessive_denials.cast_denials.mana = excessive_denials.event_count
	check(not coherent.restore(excessive_denials) and coherent.snapshot() == fresh, "Sum of denial categories cannot exceed accepted event count")
	var contradictory_damage: Dictionary = aggregate_state.duplicate(true)
	contradictory_damage.damage_sources.contact += 1.0
	check(not coherent.restore(contradictory_damage) and coherent.snapshot() == fresh, "Damage source sum must agree with observed incoming damage; rejection is atomic")
	var rounded_damage: Dictionary = aggregate_state.duplicate(true)
	rounded_damage.damage_sources.contact += 0.0000001
	check(coherent.restore(rounded_damage), "Restore tolerates bounded numeric rounding in damage-source sums")
	var saturation = Report.new()
	saturation.event("damage_taken", {"amount": Report.MAX_TOTAL - 5.0, "source": "lane"})
	saturation.event("damage_taken", {"amount": 10.0, "source": "charge"})
	saturation.event("damage_taken", {"amount": Report.MAX_TOTAL, "source": "hazard"})
	var saturated: Dictionary = saturation.snapshot()
	check(saturated.observations.damage_taken == Report.MAX_TOTAL and saturated.damage_sources.lane == Report.MAX_TOTAL - 5.0 and saturated.damage_sources.charge == 5.0 and saturated.damage_sources.hazard == 0.0, "Only remaining total capacity is credited to sources at saturation")
	check(coherent.restore(JSON.parse_string(JSON.stringify(saturated))), "Coherently saturated damage totals round trip through JSON")
	saturation.reset(0)
	saturation.event("damage_taken", {"amount": Report.MAX_TOTAL, "source": "contact"})
	saturation.event("damage_taken", {"amount": Report.MAX_TOTAL, "source": "projectile"})
	var two_maxima: Dictionary = saturation.snapshot()
	check(two_maxima.observations.damage_taken == Report.MAX_TOTAL and two_maxima.damage_sources.contact == Report.MAX_TOTAL and two_maxima.damage_sources.projectile == 0.0, "Original two-source MAX_TOTAL scenario cannot double the attributed total")
	check(coherent.restore(two_maxima), "Original saturation regression produces a coherent restorable report")
	var ceiling = Report.new()
	var ceiling_state: Dictionary = ceiling.snapshot()
	ceiling_state.event_count = Report.MAX_EXACT_INTEGER
	for index in range(Report.MAX_EVENTS):
		ceiling_state.events.append({"index": Report.MAX_EXACT_INTEGER - Report.MAX_EVENTS + index + 1, "kind": "sample", "details": {}})
	check(ceiling.restore(ceiling_state), "Directly constructed valid 128-row tail restores at exact event-count ceiling")
	var ceiling_finished: Dictionary = ceiling.finish(true, 6, ["projectile", "fire"], ["projectile", "fire"])
	check(ceiling_finished.finished and ceiling_finished.won and ceiling_finished.owned == ["projectile", "fire"] and ceiling_finished.equipped == ["projectile", "fire"], "Finish updates final inventory and spell even when the log counter is full")
	check(ceiling_finished.event_count == Report.MAX_EXACT_INTEGER and ceiling_finished.events == ceiling_state.events, "Finishing at event ceiling preserves bounded log without overflow")
	check(coherent.restore(ceiling_finished), "Finished ceiling snapshot remains strictly restorable")
	var full_history = Report.new()
	full_history.event("sample")
	var one_sample: Dictionary = full_history.snapshot()
	var forged_denial: Dictionary = one_sample.duplicate(true)
	forged_denial.cast_denials.mana = 1
	check(not full_history.restore(forged_denial) and full_history.snapshot() == one_sample, "Original one-sample forged-denial restore is rejected atomically")
	full_history.event("damage_taken", {"amount": 5.0, "source": "lane"})
	full_history.event("mana_spent", {"amount": 3.0})
	full_history.event("cast_denied", {"reason": "mana"})
	var full_observations: Dictionary = full_history.snapshot()
	var changed_total: Dictionary = full_observations.duplicate(true)
	changed_total.observations.damage_taken = 7.0
	changed_total.damage_sources.lane = 7.0
	check(not full_history.restore(changed_total) and full_history.snapshot() == full_observations, "Complete history rejects altered damage even when source sum matches")
	var changed_source: Dictionary = full_observations.duplicate(true)
	changed_source.damage_sources.lane = 0.0
	changed_source.damage_sources.charge = 5.0
	check(not full_history.restore(changed_source) and full_history.snapshot() == full_observations, "Complete history rejects reassigned damage sources")
	var changed_observation: Dictionary = full_observations.duplicate(true)
	changed_observation.observations.mana_spent = 4.0
	check(not full_history.restore(changed_observation) and full_history.snapshot() == full_observations, "Complete history rejects altered non-damage observations")
	check(full_history.restore(JSON.parse_string(JSON.stringify(full_observations))), "Unaltered complete observation history still round trips")
	var rolled_history = Report.new()
	rolled_history.event("cast_denied", {"reason": "mana"})
	rolled_history.event("damage_taken", {"amount": Report.MAX_TOTAL, "source": "lane"})
	for index in range(Report.MAX_EVENTS):
		rolled_history.event("sample")
	rolled_history.event("cast_denied", {"reason": "cooldown"})
	rolled_history.event("damage_taken", {"amount": 5.0, "source": "charge"})
	var rolled_state: Dictionary = rolled_history.snapshot()
	check(coherent.restore(JSON.parse_string(JSON.stringify(rolled_state))) and coherent.snapshot().damage_sources.charge == 0.0, "Evicted saturated damage history accepts an uncredited later source")
	var missing_tail_denial: Dictionary = rolled_state.duplicate(true)
	missing_tail_denial.cast_denials.cooldown = 0
	check(not rolled_history.restore(missing_tail_denial) and rolled_history.snapshot() == rolled_state, "Retained denial rows cannot exceed their aggregate category")
	var impossible_evicted_denials: Dictionary = rolled_state.duplicate(true)
	impossible_evicted_denials.cast_denials.mana = rolled_state.event_count - rolled_state.events.size() + 1
	check(not rolled_history.restore(impossible_evicted_denials) and rolled_history.snapshot() == rolled_state, "Unretained denials cannot exceed the number of evicted events")
	var reward_history = Report.new()
	reward_history.event("reward_offered", {"offered": ["fire", "restore"]})
	reward_history.event("reward_chosen", {"chosen": ["fire"]})
	var reward_state: Dictionary = reward_history.snapshot()
	for summary in ["offered", "chosen"]:
		var erased_rewards: Dictionary = reward_state.duplicate(true)
		erased_rewards[summary] = []
		check(not reward_history.restore(erased_rewards) and reward_history.snapshot() == reward_state, "Complete history rejects erased %s rewards atomically" % summary)
	for index in range(Report.MAX_EVENTS):
		reward_history.event("sample")
	check(coherent.restore(reward_history.snapshot()), "Evicted reward history preserves its valid lifetime summaries")
	reward_history.event("reward_chosen", {"chosen": ["restore"]})
	var missing_retained_reward: Dictionary = reward_history.snapshot()
	missing_retained_reward.chosen = ["fire"]
	check(not coherent.restore(missing_retained_reward), "Rollover cannot erase retained reward facts")
	var observation_tail = Report.new()
	for index in range(Report.MAX_EVENTS):
		observation_tail.event("sample")
	for observation in Report.OBSERVATIONS:
		observation_tail.event(observation, {"amount": 10.0, "source": "lane"} if observation == "damage_taken" else {"amount": 10.0})
	var tail_state: Dictionary = observation_tail.snapshot()
	check(coherent.restore(JSON.parse_string(JSON.stringify(tail_state))), "Unaltered observation tail remains restorable after rollover")
	for observation in Report.OBSERVATIONS:
		var missing_observation: Dictionary = tail_state.duplicate(true)
		missing_observation.observations[observation] = 0.0
		if observation == "damage_taken":
			missing_observation.damage_sources.lane = 0.0
		check(not observation_tail.restore(missing_observation) and observation_tail.snapshot() == tail_state, "Rollover cannot erase retained positive %s observations" % observation)
	var shifted_tail_source: Dictionary = tail_state.duplicate(true)
	shifted_tail_source.damage_sources.lane = 0.0
	shifted_tail_source.damage_sources.contact = 10.0
	check(not observation_tail.restore(shifted_tail_source), "Unsaturated rollover cannot reassign retained damage sources")
	print("Run report: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
