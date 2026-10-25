extends SceneTree
## Deterministic tactical evidence, not a ranking or a balance acceptance gate.
const Game = preload("res://scripts/game.gd")
const Preview = preload("res://scripts/spell_preview.gd")
const Scenarios = preload("res://scripts/preview_scenarios.gd")
const BUILDS := [
    ["projectile"], ["projectile", "fire"], ["projectile", "pierce"],
    ["projectile", "split"], ["projectile", "bounce"], ["projectile", "chain"],
    ["projectile", "explode"], ["projectile", "cooldown"], ["projectile", "frost"],
    ["projectile", "bounce", "wall_charge"], ["projectile", "explode", "delayed_blast"],
    ["projectile", "split", "chain", "explode", "fire"],
]
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var source = Game.new() # Never enters the tree or reads actual settings/profiles.
    var diagnostic := {"schema_version": 1, "horizon": 2.0, "step": 1.0 / 60.0,
        "assumptions": "Fresh 100 mana, one cast at t=0, fixed trajectories, no AI/attacks/RNG/repeated casts/mana regeneration. Burn observed only through 2s; damage capped by target HP. No universal ranking.",
        "scenarios": [], "outcomes": []}
    for mode in Scenarios.IDS:
        diagnostic.scenarios.append({"id": mode, "description": Scenarios.fixture(mode).description})
        for build in BUILDS:
            var outcome := Preview.evaluate(source, build, mode)
            if not outcome.valid:
                push_error("Diagnostic rejected stable build: %s" % str(build))
                source.free()
                quit(1)
                return
            diagnostic.outcomes.append({"scenario": mode, "components": build,
                "damage": snappedf(outcome.damage, 0.000001), "kills": outcome.kills,
                "mana_cost": outcome.mana_cost, "cooldown": outcome.cooldown, "targets": outcome.targets})
            print("COMPONENT_ROW %s | %s | %.3f damage | %d kills | %.0f mana | %.2fs delay" % [mode, "+".join(build), outcome.damage, outcome.kills, outcome.mana_cost, outcome.cooldown])
    var encoded := JSON.stringify(diagnostic, "  ")
    var args := OS.get_cmdline_user_args()
    var output_index := args.find("--output")
    if output_index >= 0 and output_index + 1 < args.size():
        var file := FileAccess.open(args[output_index + 1], FileAccess.WRITE)
        if file == null:
            push_error("Cannot write diagnostic: %s" % error_string(FileAccess.get_open_error()))
            source.free()
            quit(1)
            return
        file.store_string(encoded + "\n")
        file.close()
    print("COMPONENT_DIAGNOSTIC_JSON ", JSON.stringify(diagnostic))
    source.free()
    quit()
