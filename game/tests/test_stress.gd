extends SceneTree
const Spell = preload("res://scripts/spell_engine.gd")
func _initialize():
    var spell = Spell.compile(["projectile", "split", "chain", "explode", "fire"])
    var targets: Array = []
    for id in 40:
        targets.append({"id": id, "position": Vector2(id % 8 * 12, id / 8 * 12)})
    for id in 10000:
        var cast = Spell.new_cast(id, spell)
        for generation in 2:
            var bolt = {"generation": generation, "hit_ids": [], "position": Vector2.ZERO, "direction": Vector2.RIGHT}
            for target in targets:
                Spell.resolve_hit(cast, bolt, target.id, targets)
        if cast.effects_used > 64 or cast.projectiles_spawned > 16:
            push_error("Budget breached")
            quit(1)
            return
    print("STRESS_OK: 10000 maximum-trigger casts; 800000 contact attempts; all budgets bounded")
    quit()
