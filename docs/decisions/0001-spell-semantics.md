# ADR 0001: Bounded ordered spell impacts

Status: Accepted for the playable prototype; numeric balance remains provisional.

## Context

The proposed spell contract leaves impact ordering, recursive triggers, costs, and status stacking open. The prototype needs reproducible outcomes before adding content or assessing balance.

## Decision

`game/scripts/spell_engine.gd` owns pure compilation and event generation; the world owns movement, collision, mana payment, health, and timed status application. The eight-entry catalog is exposed as fresh dictionaries for the editor. Constants and catalog values are currently code-owned; native Resource authoring is deferred until balance iteration needs an asset workflow.

A build has one to five unique lowercase IDs and starts with `projectile`. Modifiers apply globally regardless of slot position. Base bolt: 18 damage, 390 pixels/second, 1.6 seconds lifetime, 8 mana, 0.5 seconds cooldown. Fire costs 4, Pierce 5, Split 7, Bounce 4, Chain 8, Explode 8, and Cooldown 5 additional mana. Pierce permits two extra contacts; Bounce permits three wall reflections; Cooldown multiplies delay by 0.7 with a 0.18-second floor. Maximum legal cost is 36 mana. The world must check mana/cooldown before creating the cast and deduct the full cost once, never partially.

Each accepted contact emits direct damage first and records the target in the projectile's `hit_ids` and cast's visited set. Repeated contacts by that projectile emit nothing. Separate projectiles may hit the same enemy. Then root triggers execute in component slot order:

- Split: first eligible root contact per cast creates two children rotated ±0.32 radians from the incoming direction. It atomically reserves two projectile slots and two effect slots. Children inherit global damage, burn, pierce, and bounce modifiers. They start with their own empty hit history, but generation 1 disables **all** triggers. Generation greater than 1 is rejected.
- Chain: at most three hops over the entire cast. Each hop selects the nearest as-yet unvisited target within 180 pixels of the previous target (first origin is impact position), breaking exact distance ties by smaller stable integer ID. Direct contacts already visited by any projectile are excluded from chain selection. Chain emits damage at 65% of bolt damage with Fire inheritance and never recursively triggers.
- Explode: once per root projectile, at its first accepted impact for which budget is available, even with Pierce. It emits a 72-pixel radius area effect at 75% of bolt damage. The world applies it once to each enemy currently inside the radius, including the original target. Area damage does not burn or invoke impact resolution.

Fire maintains one burn status per enemy: 4 damage/second for 3 seconds. Reapplication refreshes expiry and keeps the strongest currently active DPS; it never adds stacks. Expired strength is discarded. `refresh_burn(existing, incoming_dps, simulation_time)` encodes that rule. The world advances simulation time only while combat is active and applies burn damage without procs.

Caps are 16 total projectiles (including the initial bolt), 64 emitted effect events (including direct hits and split spawn events), and trigger depth 1. Explosion is one event, not one event per enemy affected; world entity counts bound area application. `new_cast` reserves the first projectile and snapshots the compiled dictionary. `resolve_hit` mutates the cast counters, visited set, and the passed projectile hit/explosion state. It returns plain event dictionaries with `type` tags. Each effect is reserved before state mutation; denied triggers are skipped, and later affordable triggers may still execute. `exhausted` records any denied reservation for caller diagnostics. The world must not independently respawn split events or feed chain/area/burn damage back into the engine.

Ordering changes event order and, near a cap, which triggers fit. It does not change compiled global stats. For example, with three effect slots left, a hit followed by Split consumes all three; Explode then fails. With Explode first, hit plus explosion consume two and the atomic two-child Split cannot fit. No random generator is required by these rules. Identical stable target IDs, positions, projectile state, and cast state produce identical event logs regardless of target-array order.

`consume_bounce(projectile)` decrements a positive `bounces` counter and returns true, authorizing one wall reflection; zero returns false and the caller removes the projectile. Pierce lifetime and wall normals remain world responsibilities.

## Alternatives

Recursive child triggers, duplicate modifiers, and every-pierce-contact explosions were rejected for the prototype because they complicate bounded behavior and readability. Treating every trigger as unordered would remove meaningful composition ordering. A general event scripting runtime is unnecessary for eight fixed components.

## Consequences and verification

Headless tests exercise twelve valid builds, invalid schemas, exact pricing, modifier snapshots, repeated contacts, child inheritance, deterministic chain tie-breaking and range, per-cast hop limits, atomic split reservations, both budget-sensitive orders, depth and event/projectile caps, bounce exhaustion, and burn refresh/expiry. These establish rule correctness, not live collision or game-balance acceptance. Run with `godot --headless --path game --script res://tests/test_spells.gd`.

World integration rejects both Split children if the global projectile cap cannot fit the full pair. The resolver reservation stays consumed; rejection cannot retry the trigger or bypass cast budgets. Swept contacts resolve in first-contact order, with stable target IDs breaking ties, and effects use the incoming direction and actual contact position.
