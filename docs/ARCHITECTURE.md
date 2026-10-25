# Architecture and Engineering Guidelines

**Stack:** Godot 4.7.2, GDScript and Git/GitHub. The main scene is `game/scenes/main.tscn`; original procedural drawing and synthesized audio are documented in [provenance](../game/assets/PROVENANCE.md). The runtime is an integrated candidate, not the proposed component tree from the original planning document.

## Actual module ownership

| Module under `game/scripts/` | Responsibility |
| --- | --- |
| `game.gd` | Owns live combat arrays, run state, timing, collision/damage integration, menu lifecycle, profile/checkpoint integration and input handoff. |
| `spell_engine.gd` | Pure standard spell compilation and bounded hit resolution. Cast dictionaries snapshot validated ordered components. |
| `content_registry.gd` | Stable component IDs, schema/content version and compiler-backed identity validation. |
| `run_director.gd` | Seeded authored waves, independent rewards, expedition and route terrain definitions. |
| `arena_geometry.gd` | Shared safe-position, circle sweep, sliding and obstacle geometry used by actors, projectiles and previews. |
| `presentation.gd`, `combat_hud.gd`, `game_audio.gd` | Drawing, readiness/notice HUD, menus' visual vocabulary and bounded audio lifecycle. |
| `journey_ui.gd` | Practice, guide, recipes, prospective reward inspection, workshop, sharing and factual report screens. |
| `spell_preview.gd`, `preview_scenarios.gd` | Paired equipped/draft comparisons using a detached real-runtime instance and six fixed fixtures. |
| `player_profile.gd`, `share_code.gd` | Bounded versioned local profile/backup/checkpoint data and portable primitive recipe/challenge codes. |
| `run_report.gd` | Pure bounded observations, time buckets, recent events, persistent aggregates and strict restore. |
| `input_bindings.gd`, `menu_navigation.gd`, `text_entry.gd` | Validated saved remaps, bounded focus/scroll/Back behavior and local controller text entry. |
| `experimental_spell_runtime.gd`, `spell_lab.gd` | Explicit practice-only candidate rules and comparison UI; standard catalog/profiles/sharing remain unchanged. |
| `runtime_probe.gd`, `export_smoke.gd` | Fixed debug-only in-package performance/smoke entry points. |

`player.gd` is an earlier foundation placeholder, not the active player controller. The current root still coordinates combat and UI; the conceptual PlayerController/CombatWorld split was a planning direction, not implemented scene boundaries.

## State and persistence

Menu-selected setup chooses expedition, challenge and starting spell. Each expedition has six trials plus a boss. Forge route decisions occur at safe rewards; Archive fixes the reflector route. `reward` is the supported checkpoint boundary, preserving reward eligibility, draft, inventory, equipment, route, seed and bounded report. Resume validates report/run identity before touching live state. Retry restores starting conditions, not later player choices. See [EXPEDITIONS.md](EXPEDITIONS.md).

Production defaults are `user://profile.json`, `user://settings.cfg` and the runtime's `user://bindings.json` filename (validated ConfigFile contents, despite its extension). Profile schema 1/content `"1"` uses primitive JSON, an exact field allowlist, a 256 KiB file cap, up to 32 recipes, validated names/builds, a last-good `.bak` and a temporary-write/rename save path. Checkpoint reports have tighter size/value limits than standalone report events. Unsupported/future originals are preserved and write-protected; an explicitly future-version primary refuses older-backup downgrade. Other recovery can read a valid backup while protected originals still block saving. Failures are visible, and no-save play is an explicit session mode.

Recipe designs and discoveries do not grant permanent combat power. Challenge codes contain only seed/expedition/cap/starter. Report, profile and portable challenge seeds share the inclusive ±9,007,199,254,740,991 exact-JSON range. Unknown versions, fields and component IDs are rejected; future content renames require a deliberate migration.

## Isolation and observations

Previews instantiate the game's script without tree insertion or `_ready`, copy mutable build/terrain inputs, use silent audio and run one actual cast over 120 fixed ticks. They perform no profile/settings I/O, input sampling, run advancement, repeated casting or mana regeneration. Practice temporarily replaces inventory/build for unrestricted standard experimentation and restores its backup on every exit path. Experimental previews opt into a separate runtime subclass; their flags are not persisted.

The report accepts caller-observed clamped damage/resource changes, exclusive state time and explicit reward/inventory/build data. It keeps 128 recent events plus bounded full-run aggregates. Incoming-damage sources share one saturation ceiling; complete-history restore reconstructs aggregates, while evicted-history denial counts must be compatible with the retained tail. Missing damage cause remains unknown. [ROADMAP_GAPS.md](ROADMAP_GAPS.md) specifies limits and validation, and the debrief never infers motivation.

Every test/capture must set an isolated settings path before scene insertion; the runtime derives matching profile/bindings fixture paths. Detached previews must remain safe without `_ready`. Run editor import serially, never while another test mutates the import cache. See [TESTING.md](TESTING.md) and [PERFORMANCE.md](PERFORMANCE.md) for separate correctness and measurement procedures.

## Rule and engineering boundaries

Standard cast limits are five slots, 16 projectiles, 64 effect events, one child generation and three Chain hops; optional four-slot mode narrows the run cap. The live world additionally bounds projectiles, hazards and cosmetic effects. Shared terrain must keep movement, warning geometry, hit order and preview behavior consistent. Reflection discards remaining motion in that simulation tick; no bitwise cross-platform full-input replay is promised.

Use source-backed contracts and focused regressions for behavior changes. Keep mutable rendering/UI state outside pure compiler, report, identity and data validators. Validate complete persistence candidates before applying them, and preserve unrelated user files. Prefer measured workload evidence before optimization; a bounded resolver stress pass is not graphical frame-time acceptance.

See [standard rules](SPELL_SYSTEM.md), [expedition geometry](EXPEDITIONS.md), [input integration](INPUT_JOURNEY.md), [diagnostics](COMPONENT_DIAGNOSTIC.md), [optional experiments](SPELL_EXPERIMENTS.md), [research](OCTALYSIS_RESEARCH.md), [roadmap queue](roadmap_queue.json) and [evidence ledger](IMPLEMENTATION_STATUS.md). Material contract changes should update the relevant ADR under `docs/decisions/`.
