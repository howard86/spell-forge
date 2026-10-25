extends "res://scripts/game.gd"
## Detached, opt-in preview runtime. Never add this node to a scene tree.
const EXPERIMENT_IDS := ["frost_split_order", "split_spread", "repulse"]
var experiment_id := ""
var contact_id := -1
var accepted_contact := false

func configure_experiment(id: String) -> bool:
    if id not in EXPERIMENT_IDS or not compiled.valid:
        return false
    if id == "repulse":
        if compiled.components.size() >= 5:
            return false
        compiled.mana_cost += 5.0
    experiment_id = id
    return true

func hurt_enemy(enemy: Dictionary, amount: float, sound: bool = true) -> void:
    var before := float(enemy.hp)
    super.hurt_enemy(enemy, amount, sound)
    if enemy.id == contact_id and enemy.hp < before:
        accepted_contact = true

func resolve_projectile_hit(projectile: Dictionary, enemy: Dictionary) -> void:
    var already_hit: bool = projectile.hit_ids.has(enemy.id)
    var first_new := projectiles.size()
    contact_id = enemy.id
    accepted_contact = false
    super.resolve_projectile_hit(projectile, enemy)
    var accepted := accepted_contact and not already_hit
    contact_id = -1
    if experiment_id == "frost_split_order":
        var recipe: Array = compiled.components
        var inherits := recipe.has("frost") and recipe.has("split") and recipe.find("frost") < recipe.find("split")
        for index in range(first_new, projectiles.size()):
            projectiles[index].inherited_frost = inherits
            projectiles[index].frost = inherits
        if accepted and projectile.get("inherited_frost", false):
            enemy.frost_until = elapsed + 1.0
            enemy.frost_amount = 0.1 if enemy.kind in ["boss", "archivist"] else 0.25
    elif experiment_id == "split_spread":
        for index in range(first_new, projectiles.size()):
            projectiles[index].hit_ids.append(enemy.id)
    elif experiment_id == "repulse" and accepted and projectile.generation == 0 and enemy.hp > 0:
        var distance := 12.0 if enemy.kind in ["boss", "archivist"] else 48.0
        enemy.position = Geometry.move_circle(enemy.position, projectile.direction.normalized() * distance, enemy.radius, ARENA, obstacles)
