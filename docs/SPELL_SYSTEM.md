# Spell System — Technical and Design Contract

**Status:** Proposed MVP contract. Implementation details can change through an ADR.

## Objective
Enable ordered composition of spells with predictable outcomes, bounded execution, and visible trade-offs. This is **not** a general-purpose scripting language or node graph in the MVP.

## Component catalog
| Component | Type | Intent |
| --- | --- | --- |
| Projectile | Source | Spawn an aimed projectile; mandatory starting component |
| Fire | Modifier | Adds burning damage over time |
| Pierce | Modifier | Projectile can travel through limited targets |
| Split | Trigger | Spawn limited child projectiles at a defined event |
| Bounce | Modifier | Reflect from walls a limited number of times |
| Chain | Trigger | On eligible hit, affect a nearby new target |
| Explode | Trigger | Area damage on a defined impact event |
| Cooldown | Modifier | Reduce cast delay within minimum limits |

The names above specify gameplay intent, **not** final parameter values.

## Spell schema (conceptual)
```text
SpellDefinition {
  id
  ordered_component_ids[]
  mana_cost
  cooldown_ms
}
CastContext {
  cast_id
  seed
  owner_id
  origin
  aim_direction
  event_budget
}
```

Store tunable values in engine-native Resources; separate definitions from runtime instances and effects.

## Execution phases
1. **Validate:** Require a source first, enforce slot limits and compatible component placement.
2. **Compile:** Resolve modifiers and triggers into an immutable cast configuration.
3. **Price:** Calculate mana/cooldown and display them before confirmation.
4. **Cast:** Check player state and resources; emit initial projectile event.
5. **Resolve:** Process collisions and trigger events from a bounded queue.
6. **Cleanup:** Release expired projectiles, deduplicate hits, discard exhausted casts.

## Proposed trigger rules
- Component order matters; rendering/order in the UI must match execution order.
- Split creates **one generation** of child projectiles; child projectiles do not re-trigger Split by default.
- Child projectiles inherit applicable damage modifiers but not one-shot spawn triggers unless explicitly whitelisted.
- Chain can select only previously unvisited targets, up to a bounded hop count.
- Pierce cannot damage the same target repeatedly during a single projectile traversal without an explicitly designed interval.
- Explode must specify when it fires and avoid double-proccing on the same impact.
- Bounce decrements a fixed bounce counter on each wall collision.
- Damage-over-time stacks and refresh behavior must be explicitly defined and tested.

## Safety, performance, and determinism invariants
- Enforce per-cast caps for spawned projectiles, effect events, trigger depth, and targets visited.
- If budget is exhausted, fail safely and log the originating spell configuration in development builds.
- All combat-affecting randomness comes from a seeded RNG; do not rely on frame scheduling for random ordering.
- Use stable target ordering as tie-breaker for nearest-target selection.
- Performance stress test worst *permitted* combinations, not merely typical builds.
- No infinite recursion, unbounded entity spawning, or cast that permanently traps mana in an unusable state.

## Required automated tests
- Invalid/no-source spell is rejected.
- Resource insufficient => no cast or partial resource consumption.
- Component order changes outcome only where documented.
- Split child inheritance and no recursive Split.
- Pierce deduplicates affected enemies.
- Chain terminates at bound and skips visited targets.
- Bounce stops after limit.
- Explode triggers once per eligible impact.
- Budget exhaustion is safe.
- Given identical seed and inputs, simulation produces the same canonical event log.

## Example spell
`Projectile -> Pierce -> Split -> Fire`: an aimed projectile with piercing, a bounded split trigger, and burning damage on affected hits. Exact behavior of Split relative to Pierce must be chosen during Stage 3 and represented in tests.

## Rejected early complexity
Visual graphs, user-supplied code, deeply nested event scripts, online sharing of builds, and custom physics runtime. These increase test and UX surface without proving the value proposition.
