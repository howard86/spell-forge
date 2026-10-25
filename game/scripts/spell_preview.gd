extends Control
## A detached game instance runs the same projectile/collision/effect code.
## It never enters the tree, reads input, advances the run, or shares mutable state.
const Art = preload("res://scripts/presentation.gd")
class SilentAudio extends Node:
    func play_sfx(_kind: String) -> void:
        pass
const Spell = preload("res://scripts/spell_engine.gd")
const Scenarios = preload("res://scripts/preview_scenarios.gd")
const STEP := 1.0 / 60.0
const TICKS := 120
const HORIZON := 2.0
var source: Node
var frames: Array = []
var frame_time := 0.0
var report := ""
var comparison: Dictionary = {}
var scenario := "cluster"
var picker: OptionButton

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    clip_contents = true
    picker = OptionButton.new()
    picker.position = Vector2(5, 3)
    picker.size = Vector2(118, 25)
    picker.add_theme_font_size_override("font_size", 12)
    for title in Scenarios.TITLES:
        picker.add_item(title)
    picker.item_selected.connect(func(index: int): restart(Scenarios.IDS[index]))
    add_child(picker)
    visibility_changed.connect(func():
        if not is_visible_in_tree():
            set_process(false))
    restart()

## One legal compiled cast at t=0, followed for exactly 120 fixed ticks.
## No regeneration, repeat casts, targeting AI, settings/profile I/O, or live state.
static func evaluate(live_source: Node, components: Array, mode: String = "group") -> Dictionary:
    var spell: Dictionary = Spell.compile(components.duplicate(true))
    var fixture: Dictionary = Scenarios.fixture(mode)
    var result := {"valid": false, "damage": 0.0, "mana_cost": float(spell.mana_cost),
        "cooldown": float(spell.cooldown), "horizon": HORIZON, "frames": [],
        "scenario": fixture.get("id", mode), "description": fixture.get("description", "Unknown scenario."),
        "kills": 0, "targets": [], "casts": 0, "error": "",
        "assumptions": "Fresh 100 mana; one cast at t=0; 2s observation; no repeat casts or mana regeneration. Burn after the horizon is excluded."}
    if not spell.valid or fixture.is_empty() or not is_instance_valid(live_source) or live_source.get_script() == null:
        result.error = spell.error if not spell.valid else "Unknown scenario or unavailable source."
        return result
    var sandbox = live_source.get_script().new()
    sandbox.state = "combat"
    sandbox.compiled = spell
    sandbox.audio = SilentAudio.new()
    sandbox.mana = 100.0
    sandbox.cooldown = 0.0
    sandbox.cast_id = 0
    sandbox.player_pos = fixture.origin - fixture.direction * 18
    sandbox.aim = fixture.direction
    for entry in fixture.targets:
        sandbox.spawn_enemy(entry.kind, entry.position, 99)
        sandbox.enemies[-1].aim = entry.facing
        sandbox.enemies[-1].preview_velocity = entry.velocity
    if not sandbox.cast_spell():
        result.error = "Detached cast was rejected."
        sandbox.audio.free()
        sandbox.free()
        return result
    result.starting_mana = 100.0
    result.remaining_mana = sandbox.mana
    for tick in TICKS:
        sandbox.elapsed = (tick + 1) * STEP
        for enemy in sandbox.enemies:
            if enemy.hp > 0 and not enemy.burn.is_empty():
                var active := maxf(0, minf(sandbox.elapsed, enemy.burn.expires_at) - (sandbox.elapsed - STEP))
                sandbox.hurt_enemy(enemy, enemy.burn.dps * active, false)
                if sandbox.elapsed >= enemy.burn.expires_at:
                    enemy.burn = {}
            Scenarios.advance(enemy, STEP, sandbox.elapsed)
        sandbox.update_delayed_blasts(STEP)
        sandbox.update_projectiles(STEP)
        sandbox.update_effects(STEP)
        result.frames.append({"projectiles": sandbox.projectiles.duplicate(true), "enemies": sandbox.enemies.duplicate(true), "effects": sandbox.effects.duplicate(true), "blasts": sandbox.delayed_blasts.duplicate(true)})
    for enemy in sandbox.enemies:
        var damage := clampf(enemy.max_hp - enemy.hp, 0, enemy.max_hp)
        result.damage += damage
        result.kills += int(enemy.hp <= 0)
        result.targets.append({"id": enemy.id, "kind": enemy.kind, "hp": maxf(0, enemy.hp), "max_hp": enemy.max_hp, "damage": damage})
    result.valid = true
    result.casts = 1
    sandbox.audio.free()
    sandbox.free()
    return result

func outcome_text(label: String, outcome: Dictionary) -> String:
    if not outcome.valid:
        return "%s · invalid: %s" % [label, outcome.error]
    return "%s · %.1f dmg · %d kills · %.0f mana · %.2fs delay" % [label, outcome.damage, outcome.kills, outcome.mana_cost, outcome.cooldown]

func restart(mode: String = "group") -> void:
    frame_time = 0.0
    var equipped := evaluate(source, source.components if is_instance_valid(source) else [], mode)
    var draft_result := evaluate(source, source.draft if is_instance_valid(source) else [], mode)
    comparison = {"equipped": equipped, "draft": draft_result}
    scenario = draft_result.scenario
    frames = draft_result.frames
    report = outcome_text("Equipped", equipped) + "\n" + outcome_text("Draft", draft_result)
    tooltip_text = str(draft_result.description) + "\n" + str(draft_result.assumptions) + "\nAnimation shows draft; equipped uses the identical setup. Run unaffected."
    if is_instance_valid(picker) and scenario in Scenarios.IDS:
        picker.select(Scenarios.IDS.find(scenario))
        picker.tooltip_text = tooltip_text
    set_process(is_visible_in_tree() and not frames.is_empty())
    queue_redraw()
func _process(delta: float) -> void:
    frame_time = minf(2.0, frame_time + delta)
    queue_redraw()
    if frame_time >= 2.0 or not is_visible_in_tree():
        set_process(false)
func point(value: Vector2) -> Vector2:
    return Vector2(12 + (value.x - 32) / 896 * (size.x - 24), 51 + (value.y - 300) * 0.12)
func blast_boundary(origin: Vector2, radius: float) -> PackedVector2Array:
    var boundary := PackedVector2Array()
    for i in 33:
        var angle := TAU * i / 32.0
        boundary.append(point(origin + Vector2(cos(angle), sin(angle)) * radius))
    return boundary
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Art.STONE.darkened(0.3))
    var lines := report.split("\n")
    for i in lines.size():
        draw_string(ThemeDB.fallback_font, Vector2(132, 13 + i * 14), lines[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - 140, 12, Art.TEAL)
    draw_string(ThemeDB.fallback_font, Vector2(7, 41), "1 cast · 2s", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Art.TEAL)
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
        var color: Color = Color(0.55, 0.85, 1.0) if projectile.get("frost", false) else Art.GOLD if projectile.fire else Art.TEAL
        draw_circle(point(projectile.position), 3, color)
        if projectile.get("wall_charge", false) and projectile.get("wall_charged", false):
            draw_arc(point(projectile.position), 5, 0, TAU, 12, Art.GOLD, 1)
    for blast in frame.blasts:
        draw_polyline(blast_boundary(blast.position, float(blast.radius)), Art.GOLD, 1)
    for effect in frame.effects:
        if effect.kind == "chain":
            draw_line(point(effect.origin), point(effect.target), Art.TEAL, 2)
        else:
            draw_polyline(blast_boundary(effect.origin, float(effect.radius)), Art.GOLD, 2)
