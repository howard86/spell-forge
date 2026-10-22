extends SceneTree
## Diagnostic, not a human playtest or a pass/fail pacing gate.
## Fixed 1/60 simulation steps; intermissions are chosen immediately.
## Health, damage, mana, rosters, rewards and collision retain game defaults.
## Perfect nearest-target aim and a continuous rectangular patrol are scripted.
## Run: godot --headless --path game --script res://tests/probe_playthrough.gd
var game
func _initialize():
    call_deferred("run")
func run():
    for seed_value in [4242, 12345, 1]:
        game = load("res://scenes/main.tscn").instantiate()
        root.add_child(game)
        game.set_physics_process(false)
        game.start_run(seed_value)
        var frames := 0
        var reward_log: Array = []
        var corner_index := 0
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
            game._physics_process(1.0 / 60.0)
            frames += 1
            if frames % 60 == 0: await process_frame
        print("RUN_PROBE ", JSON.stringify({"seed":seed_value,"state":game.state,"combat_seconds":game.elapsed,"hp":game.hp,"encounter":game.encounter_index,"kills":game.kills,"rewards":reward_log,"components":game.components}))
        for action in ["cast", "move_left", "move_right", "move_up", "move_down"]:
            Input.action_release(action)
        await game.audio.shutdown()
        game.queue_free()
        await process_frame
    quit()
