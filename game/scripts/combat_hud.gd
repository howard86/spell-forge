extends Control
const Art = preload("res://scripts/presentation.gd")
var game: Node
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    size = Vector2(960, 540)
func text_at(value: String, pos: Vector2, color: Color = Art.TEAL, font_size: int = 15) -> void:
    draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
func bar(rect: Rect2, value: float, color: Color) -> void:
    draw_rect(rect, Art.STONE)
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0, 1), rect.size.y)), color)
func _draw() -> void:
    if game.state == "menu":
        return
    text_at("HEALTH  %d / 100" % game.hp, Vector2(36, 22), Art.RED)
    bar(Rect2(36, 29, 180, 8), game.hp / 100.0, Art.RED)
    text_at("MANA  %d / 100" % game.mana, Vector2(238, 22))
    bar(Rect2(238, 29, 180, 8), game.mana / 100.0, Art.TEAL)
    var cost := float(game.compiled.get("mana_cost", 8))
    var marker := 238 + 180 * cost / 100
    draw_line(Vector2(marker, 26), Vector2(marker, 40), Art.GOLD, 2)
    text_at("Cost %d" % cost, Vector2(238, 55), Art.GOLD, 13)
    var ready: Dictionary = game.readiness()
    text_at("CAST  " + ("READY" if ready.cast else ("%.1fs" % game.cooldown if game.cooldown > 0 else "BOLTS ACTIVE" if game.projectiles.size() >= game.MAX_PROJECTILES else "LOW MANA")), Vector2(442, 22), Art.TEAL if ready.cast else Art.GOLD)
    text_at(game.control_hint("dodge") + "  " + ("DODGE READY" if ready.dodge else "%.1fs" % game.dodge_cooldown), Vector2(442, 45), Art.TEAL if ready.dodge else Art.GOLD)
    text_at("Pause: " + game.control_hint("pause"), Vector2(36, 58), Art.EDGE.lightened(0.5), 13)
    text_at(" → ".join(game.components).to_upper(), Vector2(36, 78), Art.GOLD, 14)
    if game.resource_notice_time > 0:
        text_at(game.resource_notice, Vector2(520, 527), Art.GOLD, 14)
    if game.message_time > 0:
        text_at(game.message, Vector2(36, 527), Art.RED, 14)
    var progress := progression()
    for i in 6:
        var pos := Vector2(666 + i * 31, 8)
        draw_rect(Rect2(pos, Vector2(24, 22)), Art.TEAL.darkened(0.6) if i < progress.cleared else Art.STONE)
        if i == progress.current and game.encounter_index < 6:
            draw_rect(Rect2(pos, Vector2(24, 22)), Art.GOLD, false, 2)
        text_at(str(i + 1), pos + Vector2(7, 16), Art.TEAL if i < progress.cleared else Art.GOLD, 13)
    var emblem := Vector2(879, 19)
    draw_colored_polygon(PackedVector2Array([emblem + Vector2(0, -12), emblem + Vector2(12, 0), emblem + Vector2(0, 12), emblem + Vector2(-12, 0)]), Art.GOLD if game.encounter_index == 6 else Art.EDGE)
    text_at("A" if game.expedition == "archive" else "W", emblem + Vector2(-6, 5), Art.INK, 14)
    var boss: Dictionary = {}
    for enemy in game.enemies:
        if enemy.kind in ["boss", "archivist"] and enemy.hp > 0:
            boss = enemy
            break
    if not boss.is_empty():
        text_at(("ARCHIVIST" if boss.kind == "archivist" else "WARDEN") + (" · ENRAGED" if boss.phase == 2 else ""), Vector2(666, 49), Art.RED if boss.phase == 2 else Art.GOLD, 15)
        bar(Rect2(666, 56, 258, 9), boss.hp / boss.max_hp, Art.RED)
        draw_line(Vector2(795, 53), Vector2(795, 68), Art.GOLD, 2)
        text_at("%d / %d" % [maxf(0, boss.hp), boss.max_hp], Vector2(666, 81), Art.GOLD, 12)
        text_at("%d enemies" % game.enemies.filter(func(e): return e.hp > 0).size(), Vector2(854, 81), Art.GOLD, 12)
    else:
        text_at("%d ENEMIES REMAIN" % game.enemies.filter(func(e): return e.hp > 0).size(), Vector2(666, 53), Art.GOLD, 14)
        text_at("SEED %d" % game.run_seed, Vector2(666, 76), Art.EDGE.lightened(0.5), 12)

func progression() -> Dictionary:
    return {"cleared": mini(game.encounter_index, 6), "current": game.encounter_index}
