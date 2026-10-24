extends RefCounted
## Original pixel silhouettes and masonry, drawn at integer coordinates.

const Audio = preload("res://scripts/game_audio.gd")
const INK = Color("111726")
const STONE = Color("283342")
const EDGE = Color("3b4b59")
const TEAL = Color("67d9cb")
const GOLD = Color("e6bc78")
const RED = Color("ef806f")

static func create_audio() -> Node:
    return Audio.new()

static func _box(c: Node2D, p: Vector2, x: float, y: float, w: float, h: float, color: Color) -> void:
    c.draw_rect(Rect2(p + Vector2(x, y), Vector2(w, h)), color)

static func _diamond(c: Node2D, p: Vector2, r: float, color: Color) -> void:
    c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), color)

static func _draw_lane(c: Node2D, origin: Vector2, target: Vector2, half_width: float, progress: float, color: Color) -> void:
    # Capsule boundaries match distance-to-segment damage, including both end caps.
    var width := maxf(half_width, 0.0)
    var direction := origin.direction_to(target)
    if direction.is_zero_approx():
        direction = Vector2.RIGHT
    var normal := direction.orthogonal()
    var side := normal * width
    var fill := Color(color, 0.12)
    if origin.distance_squared_to(target) > 0.001:
        c.draw_colored_polygon(PackedVector2Array([origin + side, target + side, target - side, origin - side]), fill)
    c.draw_circle(origin, width, fill)
    c.draw_circle(target, width, fill)
    c.draw_line(origin + side, target + side, color, 2)
    c.draw_line(origin - side, target - side, color, 2)
    c.draw_arc(origin, width, direction.angle() + PI / 2, direction.angle() + 3 * PI / 2, 16, color, 2)
    c.draw_arc(target, width, direction.angle() - PI / 2, direction.angle() + PI / 2, 16, color, 2)
    # A moving crossbar and directional chevrons communicate countdown and travel.
    var front := origin.lerp(target, clampf(progress, 0, 1))
    c.draw_line(front - side, front + side, Color("fff0c7"), 3)
    var length := origin.distance_to(target)
    for i in range(1, int(length / 42.0) + 1):
        var point := origin + direction * minf(i * 42.0, length)
        c.draw_line(point - direction * 7 + normal * 4, point, color, 1)
        c.draw_line(point - direction * 7 - normal * 4, point, color, 1)

static func _draw_countdown(c: Node2D, position: Vector2, radius: float, progress: float, color: Color) -> void:
    c.draw_arc(position, radius, 0, TAU, 48, color, 2)
    c.draw_arc(position, maxf(radius - 4, 1), -PI / 2, -PI / 2 + TAU * maxf(clampf(progress, 0, 1), 0.001), 48, Color("fff0c7"), 3)
    for i in range(4):
        var direction := Vector2.from_angle(i * PI / 2)
        c.draw_line(position + direction * (radius - 3), position + direction * (radius + 5), color, 2)

static func draw_arena(c: Node2D, rect: Rect2, layout: int, time: float) -> void:
    c.draw_rect(Rect2(0, 0, 960, 540), INK)
    c.draw_rect(rect.grow(10), Color("171f2d"))
    c.draw_rect(rect.grow(5), EDGE, false, 2)
    c.draw_rect(rect, Color("1e2835"))
    # Decoration is flat floor detail: it never implies a collidable obstacle.
    for y in range(int(rect.position.y), int(rect.end.y), 32):
        for x in range(int(rect.position.x), int(rect.end.x), 48):
            var shade := int(x / 48.0 + y / 32.0 * 7 + layout * 3) % 5
            var tile := Rect2(x + 1, y + 1, minf(46, rect.end.x - x - 1), minf(30, rect.end.y - y - 1))
            if tile.size.x <= 0 or tile.size.y <= 0:
                continue
            c.draw_rect(tile, Color(0.12 + shade * 0.006, 0.16 + shade * 0.006, 0.21 + shade * 0.007))
            c.draw_line(tile.position, tile.position + Vector2(tile.size.x, 0), Color("303c49"))
            if shade == 0:
                c.draw_line(tile.position + Vector2(8, 12), tile.position + Vector2(17, 14), Color("17222f"))
    var center := rect.get_center()
    var rune_color := Color(0.28, 0.53, 0.54, 0.17)
    c.draw_arc(center, 92 + layout * 12, 0, TAU, 48, rune_color, 2)
    c.draw_arc(center, 102 + layout * 12, 0, TAU, 48, rune_color, 1)
    for i in range(8):
        _diamond(c, center + Vector2.from_angle(i * TAU / 8.0) * (97 + layout * 12), 4, rune_color)
    for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
        var inward: Vector2 = (center - corner).sign()
        var p: Vector2 = corner + inward * 15
        _box(c, p, -9, -8, 18, 20, INK)
        _box(c, p, -7, -8, 14, 14, EDGE)
        _box(c, p, -5, -6, 10, 6, STONE)
        _box(c, p, -2, -7, 4, 9, TEAL.darkened(0.45))
        var flame := 2 + int(sin(time * 3.0 + p.x) * 1.5)
        _box(c, p, -3, -15, 6, 7, TEAL.darkened(0.25))
        _box(c, p, -1, -16 - flame, 2, 8 + flame, Color("b9f5df"))
    for i in range(12):
        var p := Vector2(rect.position.x + fposmod(i * 79.0 + time * 2, rect.size.x), rect.position.y + fposmod(i * 43.0 - time * 4, rect.size.y))
        _box(c, p.floor(), 0, 0, 2, 2, Color(0.5, 0.75, 0.7, 0.18))

static func draw_player(c: Node2D, position: Vector2, aim: Vector2, dodging: bool, hurt: bool, _time: float) -> void:
    var p := position.round()
    var robe := Color("568eaf") if not hurt else Color("f4d5c3")
    if dodging:
        for i in range(1, 4):
            _box(c, p - aim.normalized() * i * 7, -7, -9, 14, 19, Color(0.4, 0.85, 0.84, 0.22 / i))
    _box(c, p, -10, 9, 21, 4, Color(0.03, 0.06, 0.1, 0.6))
    _box(c, p, -7, -5, 14, 17, INK)
    _box(c, p, -6, -4, 12, 14, robe)
    _box(c, p, -8, 5, 16, 5, robe.darkened(0.2))
    _box(c, p, -3, -4, 3, 14, robe.lightened(0.23))
    _box(c, p, -5, 10, 4, 3, INK)
    _box(c, p, 3, 10, 4, 3, INK)
    _box(c, p, -5, -13, 11, 10, INK)
    _box(c, p, -3, -11, 7, 6, Color("d9be9c"))
    _box(c, p, -10, -14, 21, 4, INK)
    _box(c, p, -9, -15, 18, 3, robe)
    _box(c, p, -5, -21, 10, 7, robe)
    _box(c, p, -2, -25, 5, 5, robe)
    _box(c, p, 1, -27, 5, 3, robe)
    _box(c, p, -5, -17, 10, 2, GOLD)
    var side := 1.0 if aim.x >= 0 else -1.0
    _box(c, p, side * 12, -13, 2, 25, GOLD.darkened(0.25))
    _diamond(c, p + Vector2(side * 13 + 1, -16), 5, INK)
    _diamond(c, p + Vector2(side * 13 + 1, -17), 3, TEAL)
    _box(c, p, 1 if side > 0 else -3, -9, 2, 2, INK)
    _diamond(c, p + aim.normalized() * 24, 2, Color(0.6, 0.95, 0.88, 0.55))

static func draw_enemy(c: Node2D, enemy: Dictionary, time: float) -> void:
    var p: Vector2 = enemy.position.round()
    var kind: String = enemy.kind
    var r: float = enemy.radius
    var facing: Vector2 = enemy.get("aim", Vector2.DOWN)
    if kind == "bulwark":
        # Matches the damage guard: incoming direction dot aim < -0.35.
        var half_arc := acos(0.35)
        c.draw_arc(p, r + 5, facing.angle() - half_arc, facing.angle() + half_arc, 20, TEAL, 4)
    if not enemy.get("burn", {}).is_empty():
        var flame := p + Vector2(r + 8, -18)
        _diamond(c, flame, 5, GOLD)
        _box(c, flame, -2, -8, 4, 9, RED)
        _box(c, flame, -1, -4, 2, 6, Color("fff0b0"))
    if float(enemy.get("frost_amount", 0.0)) > 0:
        # Ice brackets and a snowflake stay legible without relying on hue.
        var ice := Color("c5f0ff")
        for side in [-1.0, 1.0]:
            c.draw_line(p + Vector2(side * (r + 4), -8), p + Vector2(side * (r + 4), 8), ice, 2)
            c.draw_line(p + Vector2(side * (r + 4), 8), p + Vector2(side * (r - 2), 12), ice, 2)
        var snow := p + Vector2(-r - 8, -r - 5)
        for i in range(3):
            var spoke := Vector2.from_angle(i * PI / 3) * 6
            c.draw_line(snow - spoke, snow + spoke, ice, 2)
    if float(enemy.get("telegraph", 0.0)) > 0:
        var attack_kind: String = enemy.get("attack_kind", "")
        if attack_kind in ["lane", "sweep", "charge"]:
            var origin: Vector2 = enemy.get("attack_origin", p)
            var target: Vector2 = enemy.get("attack_target", origin + facing * 210)
            var duration := maxf(float(enemy.get("warning_duration", 0.9)), 0.001)
            var progress := 1.0 - clampf(float(enemy.get("telegraph", 0.0)) / duration, 0, 1)
            var default_width := r if attack_kind == "charge" else (30.0 if attack_kind == "sweep" else 16.0)
            _draw_lane(c, origin, target, float(enemy.get("attack_width", default_width)), progress, GOLD if attack_kind == "charge" else RED)
        else:
            if kind in ["pursuer", "swarm", "bulwark"]:
                var tip := p + facing * (45 if kind == "bulwark" else 68)
                c.draw_line(p + facing * r, tip, GOLD, 3)
                c.draw_line(tip, tip - facing.rotated(0.6) * 15, GOLD, 3)
                c.draw_line(tip, tip - facing.rotated(-0.6) * 15, GOLD, 3)
            if kind in ["archer", "boss"] or attack_kind == "fan":
                var shots: int = int(enemy.get("attack_shots", 5)) if kind == "boss" else 1
                for i in shots:
                    var direction := facing.rotated((i - (shots - 1) / 2.0) * 0.22)
                    c.draw_line(p + direction * (r + 8), p + direction * (r + 53), RED, 1)
            if kind == "channeler" or (kind == "boss" and attack_kind.is_empty()):
                # Legacy overhead sigil; the actual ground hazard marks its target.
                var sigil := p + Vector2(0, -r - 22)
                _diamond(c, sigil, 9, GOLD)
                _diamond(c, sigil, 6, INK)
                c.draw_line(sigil - Vector2(12, 0), sigil + Vector2(12, 0), GOLD, 2)
                c.draw_line(sigil - Vector2(0, 12), sigil + Vector2(0, 12), GOLD, 2)
    _box(c, p, -r, r * 0.55, r * 2, 5, Color(0.02, 0.04, 0.08, 0.65))
    match kind:
        "pursuer":
            _box(c, p, -8, -10, 16, 20, INK)
            _box(c, p, -6, -7, 12, 16, Color("a95162"))
            _box(c, p, -7, -14, 14, 9, Color("d4bca5"))
            _box(c, p, -4, -11, 8, 3, INK)
            _box(c, p, -11, 0, 4, 12, Color("e4a08a"))
            _box(c, p, 8, -4, 3, 14, Color("e4a08a"))
        "archer":
            _box(c, p, -7, -9, 14, 20, INK)
            _box(c, p, -5, -6, 10, 16, Color("8f7858"))
            _box(c, p, -6, -15, 12, 10, Color("b4a17a"))
            _box(c, p, -3, -11, 7, 3, INK)
            c.draw_arc(p + Vector2(7, -1), 10, -1.2, 1.2, 6, GOLD, 3)
            c.draw_line(p + Vector2(10, -10), p + Vector2(10, 9), Color("ece0bd"))
        "lane_archer":
            # Tall pointed hood and wide crossbow distinguish the lane specialist.
            _box(c, p, -8, -9, 16, 22, INK)
            _box(c, p, -6, -7, 12, 18, Color("92724e"))
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -9), p + Vector2(0, -25), p + Vector2(8, -9)]), GOLD)
            _box(c, p, -4, -12, 8, 4, INK)
            _box(c, p, -16, -2, 32, 4, INK)
            _box(c, p, -15, -1, 30, 2, GOLD)
            c.draw_line(p + Vector2(-14, -7), p + Vector2(-18, 2), GOLD, 3)
            c.draw_line(p + Vector2(14, -7), p + Vector2(18, 2), GOLD, 3)
            _box(c, p, -1, -9, 2, 18, Color("f3e7c3"))
            _box(c, p, -6, 11, 4, 4, INK)
            _box(c, p, 2, 11, 4, 4, INK)
        "bulwark":
            _box(c, p, -13, -13, 26, 25, INK)
            _box(c, p, -10, -10, 20, 20, Color("697b85"))
            _box(c, p, -7, -17, 14, 10, Color("98a8a9"))
            _box(c, p, -5, -13, 10, 3, INK)
            _box(c, p, -15, -4, 13, 20, INK)
            _box(c, p, -13, -3, 9, 16, Color("aa916b"))
            _box(c, p, -10, -1, 3, 12, GOLD)
        "swarm":
            var wing := roundf(2.0 * sin(time * 14 + p.x))
            _box(c, p, -12, -5 + wing, 8, 5, Color("b091bd"))
            _box(c, p, 4, -5 - wing, 8, 5, Color("b091bd"))
            _diamond(c, p, 7, INK)
            _diamond(c, p, 5, Color("c9a7cb"))
            _box(c, p, -2, -2, 4, 2, INK)
        "channeler":
            _box(c, p, -9, -6, 18, 18, INK)
            _box(c, p, -7, -5, 14, 15, Color("876fa7"))
            _box(c, p, -5, -15, 10, 12, Color("af97c3"))
            _box(c, p, -3, -11, 6, 4, INK)
            _diamond(c, p + Vector2(0, -23), 5, GOLD)
            _box(c, p, -14, -8, 4, 10, Color("af97c3"))
            _box(c, p, 10, -8, 4, 10, Color("af97c3"))
        "warden", "boss":
            var armor := Color("768d9b") if int(enemy.get("phase", 1)) < 2 else Color("b77d91")
            _box(c, p, -22, -23, 44, 44, INK)
            _box(c, p, -17, -19, 34, 37, armor.darkened(0.25))
            _box(c, p, -26, -20, 13, 17, armor)
            _box(c, p, 13, -20, 13, 17, armor)
            _box(c, p, -11, -34, 22, 19, armor)
            _box(c, p, -15, -39, 5, 14, GOLD)
            _box(c, p, 10, -39, 5, 14, GOLD)
            _box(c, p, -8, -28, 16, 4, INK)
            _box(c, p, -6, -27, 12, 2, RED)
            _diamond(c, p + Vector2(0, -4), 9, INK)
            _diamond(c, p + Vector2(0, -4), 6, GOLD)
            _box(c, p, -17, 17, 12, 8, armor)
            _box(c, p, 5, 17, 12, 8, armor)
        _:
            _diamond(c, p, r, RED)
    var hp: float = float(enemy.hp) / maxf(float(enemy.max_hp), 1.0)
    if hp < 1.0:
        _box(c, p, -r, r + 9, r * 2, 3, INK)
        _box(c, p, -r, r + 9, r * 2 * clampf(hp, 0, 1), 2, RED)

static func draw_projectile(c: Node2D, projectile: Dictionary, _time: float) -> void:
    var p: Vector2 = projectile.position.round()
    var direction: Vector2 = projectile.get("direction", Vector2.RIGHT)
    var hostile: bool = projectile.get("enemy", false)
    var fire: bool = projectile.get("fire", false)
    var r: float = projectile.get("radius", 4.0)
    var color := RED if hostile else (GOLD if fire else TEAL)
    c.draw_line(p - direction * 14, p, color.darkened(0.45), 3)
    if hostile:
        _diamond(c, p, r + 2, INK)
        _diamond(c, p, r, color)
        _box(c, p, -1, -1, 2, 2, Color("ffe3bd"))
    else:
        _box(c, p, -r, -r, r * 2, r * 2, color)
        _box(c, p, -2, -2, 4, 4, Color("e4fff4"))

    if not hostile and bool(projectile.get("wall_charge", false)) and bool(projectile.get("wall_charged", false)):
        _diamond(c, p, r + 6, Color("fff0c7"))
        _diamond(c, p, r + 3, INK)
        _diamond(c, p, r, color)
        var normal := direction.orthogonal()
        for distance in [14.0, 21.0]:
            var trail: Vector2 = p - direction * float(distance)
            c.draw_line(trail - direction * 4 + normal * 5, trail, Color("fff0c7"), 2)
            c.draw_line(trail - direction * 4 - normal * 5, trail, Color("fff0c7"), 2)

    if not hostile and bool(projectile.get("frost", false)):
        var ice := Color("c5f0ff")
        for i in range(3):
            var spoke := Vector2.from_angle(i * PI / 3) * (r + 4)
            c.draw_line(p - spoke, p + spoke, ice, 1)

static func draw_hazard(c: Node2D, hazard: Dictionary, _time: float) -> void:
    if hazard.get("kind", "circle") == "lane":
        var origin: Vector2 = hazard.get("origin", Vector2.ZERO)
        var target: Vector2 = hazard.get("target", origin)
        _draw_lane(c, origin, target, float(hazard.get("width", 16.0)), float(hazard.get("progress", 0.0)), RED)
        return
    var p: Vector2 = hazard.position
    var r: float = hazard.radius
    var progress: float = clampf(hazard.get("progress", 0.0), 0, 1)
    c.draw_circle(p, r, Color(0.9, 0.3, 0.27, 0.1))
    c.draw_arc(p, r, 0, TAU, 32, RED, 2)
    c.draw_arc(p, r - 4, -PI / 2, -PI / 2 + TAU * maxf(progress, 0.001), 32, GOLD, 3)
    for i in range(4):
        _diamond(c, p + Vector2.from_angle(i * PI / 2) * r, 4, RED)
    c.draw_line(p - Vector2(5, 5), p + Vector2(5, 5), RED, 2)
    c.draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), RED, 2)

static func draw_spawn_warning(c: Node2D, spawn: Dictionary, _time: float) -> void:
    var position: Vector2 = spawn.get("position", Vector2.ZERO)
    var duration := maxf(float(spawn.get("duration", 1.0)), 0.001)
    var progress := 1.0 - clampf(float(spawn.get("remaining", duration)) / duration, 0, 1)
    c.draw_circle(position, 23, Color(0.9, 0.3, 0.27, 0.12))
    _draw_countdown(c, position, 23, progress, RED)
    # An empty doorway with an inward arrow signals an arriving enemy.
    c.draw_line(position + Vector2(-7, 8), position + Vector2(-7, -8), RED, 2)
    c.draw_line(position + Vector2(-7, -8), position + Vector2(7, -8), RED, 2)
    c.draw_line(position + Vector2(7, -8), position + Vector2(7, 8), RED, 2)
    c.draw_line(position + Vector2(0, 2), position + Vector2(0, 14), Color("fff0c7"), 2)
    c.draw_line(position + Vector2(-4, 10), position + Vector2(0, 14), Color("fff0c7"), 2)
    c.draw_line(position + Vector2(4, 10), position + Vector2(0, 14), Color("fff0c7"), 2)

static func draw_delayed_blast(c: Node2D, blast: Dictionary, _time: float) -> void:
    var position: Vector2 = blast.get("position", Vector2.ZERO)
    var radius := maxf(float(blast.get("radius", 72.0)), 1.0)
    var duration := maxf(float(blast.get("duration", 0.6)), 0.001)
    var progress := 1.0 - clampf(float(blast.get("remaining", duration)) / duration, 0, 1)
    c.draw_circle(position, radius, Color(0.9, 0.73, 0.47, 0.08))
    _draw_countdown(c, position, radius, progress, GOLD)
    # Central burst rune distinguishes the player's queued blast from hostile X marks.
    _diamond(c, position, 8, GOLD)
    _diamond(c, position, 4, INK)
    for i in range(8):
        var direction := Vector2.from_angle(i * TAU / 8)
        c.draw_line(position + direction * 12, position + direction * 18, GOLD, 2)
