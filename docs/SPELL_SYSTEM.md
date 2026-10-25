# Spell System — Technical and Design Contract

The standard engine has eleven components. [ADR 0001](decisions/0001-spell-semantics.md), [ADR 0002](decisions/0002-encounter-balance.md), `game/scripts/spell_engine.gd` and their tests define normal rules. The optional [practice lab](SPELL_EXPERIMENTS.md) is a separate candidate runtime and does not replace these rules.

## Standard composition

| Stable ID | Behavior / cost |
| --- | --- |
| `projectile` | Required first slot; aimed bolt, 18 base damage; 8 mana. |
| `fire` | 4 damage/s Burn for 3 seconds; refresh without stacking; 4 mana. |
| `pierce` | Two additional enemy contacts per projectile; 5 mana. |
| `split` | First eligible root hit creates two non-triggering children; 7 mana. |
| `bounce` | Up to three successful reflections; 4 mana. |
| `chain` | Up to three unvisited targets within 180 px, 65% base damage; 8 mana. |
| `explode` | One eligible root impact, 72 px radius, 75% base damage; 8 mana. |
| `cooldown` | 30% shorter cast delay; 5 mana, with a 0.18-second lower bound. |
| `frost` | Root direct hits slow movement 25% (bosses 10%) for one second; all bolts lose 15% direct damage; 5 mana. |
| `wall_charge` | Requires equipped Bounce; 15% lower direct damage until a successful reflection, then 50% higher; 4 mana. |
| `delayed_blast` | Requires equipped Explode; replaces its explosion with one 50%-stronger area blast after 0.6 seconds; 3 mana. |

One to five unique lowercase IDs form a legal spell; Projectile is mandatory first. The optional Four-slot run enforces a smaller cap across editing, recipes, imports and previews without changing the global compiler maximum. Dependencies are checked after collecting all slots, so prerequisite order is flexible. Display names and catalog positions are not save identifiers: `content_registry.gd` exposes stable IDs with schema 1/content `"1"`.

Compile snapshots ordered components and derives cost/cooldown/flags. Casts snapshot the compiled configuration; later editing cannot mutate an in-flight cast. Cooldown begins at 0.5 seconds before modifiers. Insufficient mana, recovering cooldown, invalid spells or world projectile capacity deny a cast without partial mana spending.

## Ordered resolution and bounds

Direct impact comes first; eligible trigger components then resolve in slot order. Split and Explode each use root-only once-per-projectile/cast eligibility as specified in the ADR; children cannot recursively Split, Chain or Explode. They retain applicable direct modifiers and Burn, but standard children never apply Frost slow. Standard Split children may hit the parent's surviving target; the spread-only exclusion is a lab experiment. Pierce deduplicates targets for each projectile. Chain uses stable distance/ID ordering and never revisits a target within its cast budget.

Every cast caps at **16 projectiles, 64 effects, one child generation and three Chain hops**. Split reserves both children atomically. A global world cap may reject the pair while preserving its consumed reservation. Exhausted resolution terminates without a partially applied impact. Burn refresh preserves the strongest active DPS without stacking; expired Burn may be replaced. Delayed blasts reserve their bounded effect when queued and retain the actual impact position.

The live world also caps projectiles at 160, hazards at 64 and cosmetic effects at 64. Actual swept contacts resolve in travel order before a reflection changes direction. Internal cover uses projectile-radius collision; reflections consume Bounce, enable Wall Charge and discard the remaining movement for that tick. Shared clipped warning/damage geometry, Chain visibility and area-effect cover behavior are specified in [EXPEDITIONS.md](EXPEDITIONS.md). No bitwise full-input replay across platforms is promised.

## Truthful comparisons and observations

The equipped/draft preview executes real detached runtime code in the same fixture and copied terrain. Its six scenarios observe one paid cast over 120 fixed ticks with fresh 100 mana, no repeated casts, regeneration, attacks or live input; Burn after two seconds is excluded. Damage is actual target HP removed with overkill capped, not raw potential damage. Default fixtures use open floor; copied terrain is explicitly labeled as a test scenario, not an exact next-room rehearsal. [COMPONENT_DIAGNOSTIC.md](COMPONENT_DIAGNOSTIC.md) documents the reproducible baseline measurements; [SPELL_EXPERIMENTS.md](SPELL_EXPERIMENTS.md) records later isolated candidate implementation.

Run reports receive actual clamped damage/resource changes and explicit offered/chosen/owned/equipped data. They retain a bounded recent tail and full-run aggregates rather than a complete replay. Causes are only recorded when supplied by the damage path; missing causes stay unknown. Complete-history restoration replays aggregate accounting under the same saturation policy. See [ROADMAP_GAPS.md](ROADMAP_GAPS.md) for exact limits.

## Optional candidate rules

Only Practice's Experimental spell lab opts into Frost/Split ordering, parent-target exclusion for Split, or virtual-slot Repulse. These candidates are not additional standard catalog IDs, recipe flags, unlocks or shareable rule changes. Correctness comparisons do not accept their balance. Human comprehension, tactical usefulness, repeated-cast resource pressure and full-encounter outcomes remain pending.

## Verification

`test_spells`, `test_run`, `test_balance`, `test_preview`, `test_world_runtime` and `test_experiments` cover standard semantics, integration, geometry and lab isolation. `test_registry`, `test_report`, `test_profile` and `test_sharing` exercise stable identity and malformed data. `test_stress` checks resolver bounds; the separate [performance harness](PERFORMANCE.md) measures a controlled runtime workload when executed. Use [TESTING.md](TESTING.md) for commands, [PLAYTEST.md](PLAYTEST.md) for viable-build evidence and [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for observed results.
