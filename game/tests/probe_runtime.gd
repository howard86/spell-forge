extends SceneTree
## Editor executable entry. Fixed debug exports use --performance-probe instead.
## godot --path game --script res://tests/probe_runtime.gd -- --probe-write
const Probe = preload("res://scripts/runtime_probe.gd")

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    if "--probe-helper-test" in OS.get_cmdline_user_args():
        var samples: Array = []
        for index in 100:
            samples.append(float(100 - index))
        var value := Probe.distribution(samples)
        var valid: bool = value == {"p50": 50.0, "p95": 95.0, "p99": 99.0, "max": 100.0}
        valid = valid and Probe.distribution([3.0]) == {"p50": 3.0, "p95": 3.0, "p99": 3.0, "max": 3.0}
        valid = valid and Probe.distribution([]).p50 == null and samples[0] == 100.0
        print("Runtime probe percentile helper: ", "PASS" if valid else "FAIL")
        quit(0 if valid else 1)
        return
    var game = load("res://scenes/main.tscn").instantiate()
    game.settings_path = "user://runtime-probe-%d.cfg" % Time.get_ticks_usec()
    if Probe.has_property(game, "profile_enabled"):
        game.set("profile_enabled", false)
    if Probe.has_property(game, "profile_path"):
        game.set("profile_path", game.settings_path + ".profile.json")
    if Probe.has_property(game, "bindings_path"):
        game.set("bindings_path", game.settings_path + ".bindings.json")
    root.add_child(game)
    game.set_physics_process(false)
    var probe := Probe.new()
    probe.entry_mode = "editor_script"
    await probe.run(game)
