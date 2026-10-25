extends SceneTree
## Reproducible diagnostic; neither a human playtest nor a pass/fail balance gate.
## Run patrol: godot --headless --path game --script res://tests/probe_balance.gd
## Run heuristic: append -- --reactive to the command above.
## Copy this script unchanged to the baseline project's tests folder for comparison.
## Both policies use perfect nearest-target aim, legal offered rewards, immediate
## intermissions, fixed 1/60 physics steps, and a 900-second simulation-frame cap.
## The reactive heuristic sidesteps marked lanes/sweeps/charges; it does not model
## human perception, reaction delay, route planning, or learning.
## Combat stats, damage, mana, enemy rosters, collision, and rewards stay unchanged.
## damage_taken sums accepted health loss inside damage_player, before room healing;
## mana_limited_seconds counts ready-to-cast steps without enough mana;
## reaction_frames counts steps selecting a reactive escape, not separate attacks.

class ProbeGame:
    extends "res://scripts/game.gd"
    var probe_damage := 0.0

    func damage_player(amount: float) -> void:
        var before := hp
        super.damage_player(amount)
        probe_damage += before - hp

var game
var reactive := "--reactive" in OS.get_cmdline_user_args()
func _initialize():
    call_deferred("run")
func run():
    for seed_value in [4242, 12345, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
        game = ProbeGame.new()
        game.settings_path = "user://capture-test-%d.cfg" % Time.get_ticks_usec()
        root.add_child(game)
        game.set_physics_process(false)
        game.start_run(seed_value)
        var frames := 0
        var reward_log: Array = []
        var corner_index := 0
        var mana_limited := 0.0
        var route_reactions := 0
        while game.state in ["combat", "reward"] and frames < 54000:
            if game.state == "reward":
                var choice = game.offers[0]
                for preferred in ["fire", "chain", "pierce", "cooldown", "explode", "split", "bounce"]:
                    if game.offers.has(preferred):
                        choice = preferred
                        break
                game.choose_reward(choice)
                reward_log.append(choice)
                game.apply_reward()
            var nearest: Dictionary = {}
            var distance := INF
            for enemy in game.enemies:
                var d: float = game.player_pos.distance_to(enemy.position)
                if d < distance:
                    distance = d
                    nearest = enemy
            if not nearest.is_empty():
                game.cursor_position = nearest.position
            # Fixed rectangular patrol: input only, no player position/health/damage edits.
            var corners := [Vector2(180,180), Vector2(780,180), Vector2(780,410), Vector2(180,410)]
            var corner: Vector2 = corners[corner_index]
            if game.player_pos.distance_to(corner) < 25:
                corner_index = (corner_index + 1) % 4
                corner = corners[corner_index]
            var direction: Vector2 = (corner - game.player_pos).normalized()
            if reactive:
                for enemy in game.enemies:
                    if float(enemy.get("telegraph", 0.0)) <= 0 or not enemy.get("attack_kind", "") in ["lane", "sweep", "charge"]:
                        continue
                    var origin: Vector2 = enemy.attack_origin
                    var target: Vector2 = enemy.attack_target
                    var near: Vector2 = Geometry2D.get_closest_point_to_segment(game.player_pos, origin, target)
                    var next: Vector2 = game.player_pos + direction * 80
                    var future: Vector2 = Geometry2D.get_closest_point_to_segment(next, origin, target)
                    if game.player_pos.distance_to(near) < float(enemy.get("attack_width", 30.0)) + 35 or next.distance_to(future) < float(enemy.get("attack_width", 30.0)) + 35:
                        var escape: Vector2 = (game.player_pos - near).normalized()
                        if escape.is_zero_approx(): escape = (target - origin).normalized().orthogonal()
                        var waypoint: Vector2 = game.player_pos + escape * 110
                        if not game.ARENA.grow(-35).has_point(waypoint): escape = -escape
                        direction = escape
                        route_reactions += 1
                        break
            for action in ["move_left", "move_right", "move_up", "move_down"]:
                Input.action_release(action)
            if direction.x < -0.2: Input.action_press("move_left")
            if direction.x > 0.2: Input.action_press("move_right")
            if direction.y < -0.2: Input.action_press("move_up")
            if direction.y > 0.2: Input.action_press("move_down")
            Input.action_press("cast")
            if distance < 80 and game.dodge_cooldown <= 0:
                var dodge := InputEventAction.new()
                dodge.action = "dodge"
                dodge.pressed = true
                game._unhandled_input(dodge)
            if game.cooldown <= 0 and game.mana < float(game.compiled.mana_cost): mana_limited += 1.0 / 60.0
            game._physics_process(1.0 / 60.0)
            frames += 1
            if frames % 60 == 0: await process_frame
        print("RUN_PROBE ", JSON.stringify({"policy":"reactive" if reactive else "patrol","damage_taken":game.probe_damage,"mana_limited_seconds":mana_limited,"reaction_frames":route_reactions,"seed":seed_value,"state":game.state,"combat_seconds":game.elapsed,"hp":game.hp,"encounter":game.encounter_index,"kills":game.kills,"rewards":reward_log,"components":game.components}))
        for action in ["cast", "move_left", "move_right", "move_up", "move_down"]:
            Input.action_release(action)
        await game.audio.shutdown()
        game.queue_free()
        await process_frame
    quit()
