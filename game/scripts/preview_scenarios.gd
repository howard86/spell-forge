extends RefCounted
## Fixed tactical fixtures, never encounter AI or combat RNG.
const IDS := ["isolated", "line", "cluster", "moving", "wall", "boss"]
const TITLES := ["Isolated", "Armored line", "Cluster", "Moving", "Wall shot", "Boss"]

static func fixture(mode: String) -> Dictionary:
    var id := "cluster" if mode == "group" else mode
    var result := {"id": id, "origin": Vector2(260, 300), "direction": Vector2.RIGHT, "targets": []}
    match id:
        "isolated":
            result.description = "One stationary pursuer (42 HP), no shield."
            result.targets = [target("pursuer", Vector2(440, 300))]
        "line":
            result.description = "Four stationary bulwarks (100 HP each), facing the shot: direct and chain damage use frontal shields."
            for i in 4:
                result.targets.append(target("bulwark", Vector2(440 + i * 85, 300), Vector2.LEFT))
        "cluster":
            result.description = "Four stationary bulwarks (100 HP each), facing away: no frontal shield reduction."
            for position in [Vector2(440, 300), Vector2(478, 315), Vector2(478, 280), Vector2(500, 300)]:
                result.targets.append(target("bulwark", position))
        "moving":
            result.description = "Four bulwarks retreat horizontally at 52px/s, facing away; Frost slows the controlled paths using runtime status duration. No attacks or AI."
            for position in [Vector2(440, 300), Vector2(478, 315), Vector2(478, 280), Vector2(500, 300)]:
                result.targets.append(target("bulwark", position, Vector2.RIGHT, Vector2(52, 0)))
        "wall":
            result.description = "Four stationary bulwarks behind the origin, facing left: bank off the right arena wall; return shots bypass shields."
            result.origin = Vector2(850, 300)
            for i in 4:
                result.targets.append(target("bulwark", Vector2(800 - i * 85, 300), Vector2.LEFT))
        "boss":
            result.description = "One stationary Warden (900 HP, 27px radius), no frontal shield or armor reduction. Frost would slow movement 10%; this fixture does not move or attack."
            result.targets = [target("boss", Vector2(440, 300))]
        _:
            return {}
    return result

static func target(kind: String, position: Vector2, facing: Vector2 = Vector2.RIGHT, velocity: Vector2 = Vector2.ZERO) -> Dictionary:
    return {"kind": kind, "position": position, "facing": facing, "velocity": velocity}

static func advance(enemy: Dictionary, delta: float, elapsed: float) -> void:
    if enemy.hp <= 0:
        return
    var factor := 1.0
    if elapsed < float(enemy.get("frost_until", 0.0)):
        factor = 0.9 if enemy.kind == "boss" else 0.75
    enemy.position += enemy.preview_velocity * delta * factor
