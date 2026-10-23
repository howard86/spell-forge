extends Control
## A detached game instance runs the same projectile/collision/effect code.
## It never enters the tree, reads input, advances the run, or shares mutable state.
const Art = preload("res://scripts/presentation.gd")
class SilentAudio extends Node:
    func play_sfx(_kind: String) -> void:
        pass
var source: Node
var frames: Array = []
var frame_time := 0.0
var report := ""
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    visibility_changed.connect(func():
        if not is_visible_in_tree():
            set_process(false))
    restart()
func restart(mode: String = "group") -> void:
    frames.clear()
    frame_time = 0.0
    set_process(is_visible_in_tree())
    var sandbox = source.get_script().new()
    sandbox.state = "combat"
    sandbox.compiled = source.Spell.compile(source.draft.duplicate())
    sandbox.audio = SilentAudio.new()
    sandbox.cast_id = 1
    sandbox.casts[1] = source.Spell.new_cast(1, sandbox.compiled)
    for i in 4:
        var target := Vector2(800 - i * 85, 300) if mode == "wall" else Vector2(440 + i * 85, 290 + (i % 2) * 30)
        sandbox.spawn_enemy("bulwark", target, 99)
        sandbox.enemies[-1].aim = Vector2.LEFT if mode == "wall" else Vector2.RIGHT
    sandbox.add_projectile(Vector2(850 if mode == "wall" else 260, 300), Vector2.RIGHT, false, 1)
    for tick in 120:
        sandbox.elapsed += 1.0 / 60
        for enemy in sandbox.enemies:
            if not enemy.burn.is_empty():
                var active := maxf(0, minf(sandbox.elapsed, enemy.burn.expires_at) - (sandbox.elapsed - 1.0 / 60))
                sandbox.hurt_enemy(enemy, enemy.burn.dps * active, false)
                if sandbox.elapsed >= enemy.burn.expires_at:
                    enemy.burn = {}
        sandbox.update_projectiles(1.0 / 60)
        sandbox.update_effects(1.0 / 60)
        frames.append({"projectiles": sandbox.projectiles.duplicate(true), "enemies": sandbox.enemies.duplicate(true), "effects": sandbox.effects.duplicate(true)})
    var damage := 0.0
    for enemy in sandbox.enemies:
        damage += enemy.max_hp - enemy.hp
    report = "%s · %.1f damage over 2s · run unaffected" % ["WALL SHOT · Bounce returns toward targets" if mode == "wall" else "TEST GROUP · 4 armored targets facing away", damage]
    sandbox.audio.free()
    sandbox.free()
    queue_redraw()
func _process(delta: float) -> void:
    frame_time = minf(2.0, frame_time + delta)
    queue_redraw()
    if frame_time >= 2.0 or not is_visible_in_tree():
        set_process(false)
func point(value: Vector2) -> Vector2:
    return Vector2(12 + (value.x - 32) / 896 * (size.x - 24), 27 + (value.y - 220) * 0.25)
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Art.STONE.darkened(0.3))
    draw_string(ThemeDB.fallback_font, Vector2(10, 17), report, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.TEAL)
    draw_line(Vector2(size.x - 12, 24), Vector2(size.x - 12, size.y - 4), Art.GOLD, 2)
    if frames.is_empty():
        return
    var frame: Dictionary = frames[mini(int(frame_time * 60), frames.size() - 1)]
    for enemy in frame.enemies:
        var pos := point(enemy.position)
        draw_rect(Rect2(pos - Vector2(6, 8), Vector2(12, 16)), Art.EDGE if enemy.hp > 0 else Art.INK)
        draw_rect(Rect2(pos + Vector2(-8, 10), Vector2(16 * maxf(0, enemy.hp) / enemy.max_hp, 3)), Art.RED)
        if not enemy.burn.is_empty():
            draw_circle(pos + Vector2(0, -12), 3, Art.GOLD)
    for projectile in frame.projectiles:
        draw_circle(point(projectile.position), 3, Art.GOLD if projectile.fire else Art.TEAL)
    for effect in frame.effects:
        if effect.kind == "chain":
            draw_line(point(effect.origin), point(effect.target), Art.TEAL, 2)
        else:
            draw_arc(point(effect.origin), effect.radius * 0.25, 0, TAU, 24, Art.GOLD, 2)
