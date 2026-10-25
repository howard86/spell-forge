extends SceneTree
const Game = preload("res://scripts/game.gd")
const Preview = preload("res://scripts/spell_preview.gd")
const Scenarios = preload("res://scripts/preview_scenarios.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func snapshot(source: Node) -> Dictionary:
    var result := {}
    for property in source.get_property_list():
        if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
            var value = source.get(property.name)
            result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
    return result

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    # Detached source never enters the tree: _ready cannot read settings/profiles.
    var source = Game.new()
    source.hp = 61
    source.mana = 13
    source.elapsed = 27
    source.kills = 4
    source.components = ["projectile", "fire"]
    source.draft = ["projectile", "split", "chain", "explode"]
    source.spawn_enemy("boss", Vector2(100, 100), 1)
    source.compiled = source.Spell.compile(source.components)
    source.casts[8] = source.Spell.new_cast(8, source.compiled)
    source.add_projectile(Vector2(200, 200), Vector2.LEFT, false, 8)
    var before := snapshot(source)
    for mode in Scenarios.IDS:
        var first := Preview.evaluate(source, source.draft, mode)
        var second := Preview.evaluate(source, source.draft, mode)
        check(first.valid and first == second, "%s reproduces every outcome and frame" % mode)
        check(first.starting_mana == 100 and is_equal_approx(first.remaining_mana, 100 - first.mana_cost), "%s cast pays its stated mana from a fresh budget" % mode)
        check(first.frames.size() == 120 and first.horizon == 2 and first.casts == 1, "%s uses one cast and 120 frames" % mode)
        var total := 0.0
        var kills := 0
        for target in first.targets:
            check(target.damage >= 0 and target.damage <= target.max_hp and target.hp >= 0, "%s reports capped target damage" % mode)
            total += target.damage
            kills += int(target.hp <= 0)
        check(is_equal_approx(total, first.damage) and kills == first.kills, "%s total damage/kills agree with targets" % mode)
    check(snapshot(source) == before, "all source script properties remain unchanged")
    var plain := Preview.evaluate(source, ["projectile"], "isolated")
    var split := Preview.evaluate(source, ["projectile", "split"], "isolated")
    check(plain.damage == 18 and split.damage == 42 and split.kills == 1, "Split same-target overkill caps at isolated 42 HP")
    var boss := Preview.evaluate(source, ["projectile", "split"], "boss")
    check(boss.damage == 54 and boss.kills == 0 and boss.description.contains("no frontal shield"), "Boss has HP/radius but no invented armor")
    var armored := Preview.evaluate(source, ["projectile"], "line")
    check(is_equal_approx(armored.damage, 9.9), "frontal bulwark shield uses runtime multiplier")
    check(Preview.evaluate(source, ["projectile", "pierce"], "line").damage > armored.damage, "Pierce benefits the armored line")
    var cluster := Preview.evaluate(source, ["projectile", "explode", "delayed_blast"], "cluster")
    var moving := Preview.evaluate(source, ["projectile", "explode", "delayed_blast"], "moving")
    check(cluster.damage > moving.damage, "moving targets can escape the delayed blast")
    check(moving.frames[0].enemies[0].position != moving.frames[-1].enemies[0].position, "moving fixture actually advances target positions")
    check(Preview.evaluate(source, ["projectile"], "wall").damage == 0, "wall fixture requires a bank shot")
    check(Preview.evaluate(source, ["projectile", "bounce", "wall_charge"], "wall").damage == 27, "runtime reflection enables Wall Charge")
    var frost := Preview.evaluate(source, ["projectile", "frost"], "moving")
    check(frost.frames[-1].enemies[0].position.x < moving.frames[-1].enemies[0].position.x, "controlled paths respect actual Frost duration/speed multiplier")
    var burning := Preview.evaluate(source, ["projectile", "fire"], "cluster")
    var ignition := -1
    for i in burning.frames.size():
        if not burning.frames[i].enemies[0].burn.is_empty():
            ignition = i
            break
    check(ignition >= 0 and ignition < 119, "actual runtime impact ignites burn")
    if ignition >= 0 and ignition < 119:
        check(is_equal_approx(burning.frames[ignition].enemies[0].hp - burning.frames[ignition + 1].enemies[0].hp, 4.0 / 60), "burn tick applies only elapsed time after impact")
        check(is_equal_approx(burning.damage, 18 + (119 - ignition) * 4.0 / 60), "burn totals exclude remaining duration after the horizon")
    var rapid := Preview.evaluate(source, ["projectile", "cooldown"], "isolated")
    check(rapid.damage == plain.damage and rapid.mana_cost == 13 and is_equal_approx(rapid.cooldown, 0.35), "one-cast preview shows Cooldown cost/delay without invented repeat casts")
    check(Preview.evaluate(source, ["projectile"], "group") == Preview.evaluate(source, ["projectile"], "cluster"), "group remains cluster alias")
    for invalid in [[], ["fire"], ["projectile", "wall_charge"], ["projectile", "unknown"]]:
        var rejected := Preview.evaluate(source, invalid)
        check(not rejected.valid and rejected.frames.is_empty() and rejected.casts == 0 and not rejected.error.is_empty(), "invalid draft rejected safely: %s" % str(invalid))
    check(not Preview.evaluate(source, ["projectile"], "unknown").valid, "unknown scenario rejected")
    check(not Preview.evaluate(null, ["projectile"]).valid, "missing source rejected")
    var preview = Preview.new()
    preview.source = source
    preview.restart("moving")
    check(preview.frames == preview.comparison.draft.frames and preview.comparison.equipped.valid, "restart exposes paired outcomes and animates draft")
    source.draft = source.components.duplicate()
    preview.restart()
    check(preview.comparison.equipped == preview.comparison.draft, "identical equipped/draft builds have identical outcomes")
    source.draft = ["fire"]
    preview.restart()
    check(not preview.comparison.draft.valid and preview.frames.is_empty(), "invalid restart clears previous animation")
    # Build the picker without adding the source game or triggering its _ready.
    source.draft = ["projectile"]
    preview.custom_minimum_size = Vector2(740, 76)
    root.add_child(preview)
    check(preview.picker.item_count == 6 and preview.custom_minimum_size == Vector2(740, 76), "six scenario controls fit the existing preview area")
    preview.picker.item_selected.emit(5)
    check(preview.scenario == "boss", "picker changes both comparison fixtures")
    preview._process(2.0)
    check(not preview.is_processing(), "finished animation stops processing")
    preview.free()
    source.free()
    print("PREVIEW_TESTS: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
