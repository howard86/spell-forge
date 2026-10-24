# Spellforge balance research and upgrade proposal

Date: 2026-10-25. Status: original research proposal. Encounter changes 1–4 and the first three upgrades are now implemented; see [validation results](BALANCE_VALIDATION.md) and [ADR 0002](decisions/0002-encounter-balance.md). Other proposals remain deferred. Human balance remains unverified.
Source baseline: `5479f26ac0b8ba03709a7a4e6e1c789cc4934129`, with pre-existing local edits to `game/project.godot` and `game/scripts/player.gd` preserved.

## Recommendation

First make enemies demand changes of route and target priority. Then add three behavioral upgrades that reward those decisions. Keep the five-slot constraint and six encounters while testing. More health, more enemies, and more components alone would not establish a more interesting game.

## What the current game supports

| Finding | Evidence | Design implication |
| --- | --- | --- |
| Perimeter movement has a strong speed advantage | [Combat simulation](../game/scripts/game.gd): player 220 px/s, fastest enemy 135, hostile projectiles 180; enemies stop moving during their warnings | Test enemies that cut off a route, rather than merely chase faster |
| Arenas vary spawn positions and appearance, without interior collision geometry | `start_encounter`, projectile wall handling, and [arena rendering](../game/scripts/presentation.gd) | Spatial variety is currently limited; add one readable arena mechanic before a new biome |
| Normal encounters contain 4, 6, 8, 10, 12, 14 enemies, spawned together | [Director](../game/scripts/run_director.gd), `start_encounter` | Numbers escalate, but encounter structure changes little |
| Boss phase two increases the fan from 5 to 7 bolts and lowers attack recovery from 2.0 to 1.2 seconds | `update_enemies` and `enemy_attack`; both phases also create a delayed ground mark | Give phase two a new positioning problem and an exploitable recovery window |
| Every normal clear restores up to 15 health and refills mana | `encounter_clear` | Room mistakes can be erased; resource pressure resets six times |
| Seven modifiers supply six reward selections, with no duplicates | `Director.rewards`, `start_run` | The final normal offer has only two choices; the empty-pool Restore fallback is unreachable in ordinary progression |
| Slot order has little ordinary tactical significance | [Spell engine](../game/scripts/spell_engine.gd) and [accepted semantics](decisions/0001-spell-semantics.md): global modifiers, ordered triggers, non-triggering children | New order-sensitive behavior needs an explicit design contract and preview, not merely more reorder controls |

The [recorded pacing probe](PACING_PROBE.md) reports three victories in 108.32–119.48 combat seconds with 88–92 final health. Those are historical results from a different revision, with perfect nearest-target aim and instantaneous crafting. They motivate investigation; they are not current human balance measurements. Final health also hides earlier damage because rooms heal the player.

### Resource economics

Analytical steady-state estimates use `casts/sec = min(1 / cooldown, 22 / mana_cost)`. They assume an isolated unarmored target, every bolt hits, no travel/overkill loss, exhausted starting mana, and full burn uptime when present. These are calculations, not simulated measurements.

| Spell | Cost / delay | Mana demand at full rate | Sustained direct + burn DPS |
| --- | --- | --- | --- |
| Projectile | 8 / 0.50 s | 16/s | 36.00 |
| Projectile + Fire | 12 / 0.50 s | 24/s | 37.00 |
| Projectile + Cooldown | 13 / 0.35 s | 37.14/s | 30.46 |
| Projectile + Fire + Pierce + Cooldown + Chain | 30 / 0.35 s | 85.71/s | 17.20 against one target |

The last build has crowd utility that this calculation deliberately excludes. Cooldown is a burst option: it increases initial firing rate but adds mana cost, so it lowers sustained efficiency. Its tooltip should show that trade-off. A 30% shorter delay means about 43% more casts per second before mana limits, so the current “30% faster” wording is ambiguous.

Split needs a focused runtime investigation before pricing new damage effects. Children spawn at the root contact with fresh hit histories; swept collision includes initial overlap. They may immediately hit the original target, making a nominal spread effect a strong single-target multiplier. Separate-projectile hits are allowed by the current contract, so this is a balance hypothesis, not a confirmed bug.

## Encounter changes, in priority order

1. **Make movement reactive.** Give an archer variant a marked lane aimed at a short prediction of the player's path. Lock that lane when the warning starts; never keep tracking through the warning. Start with a 0.9-second warning and one lane. The player can turn, stop, cross behind it, or dodge. Introduce it alone before pairing it with a pursuer.
2. **Build encounters around complementary roles.** Replace some random rosters with seeded templates: pursuer plus lane archer; bulwark plus vulnerable channeler; swarm plus one area-denial caster. Preserve randomized positions and variants within a threat budget. Later rooms can use two small waves, spawning the second after a survivor threshold with a visible spawn warning. Avoid empty timed waiting and unchecked reinforcement stacking.
3. **Make the Warden alternate problems.** Use separate fan, marked sweep, and charge attacks, followed by a short punish window. Phase two combines already-taught mechanics in a new sequence. Do not stack unavoidable overlapping hazards, and preserve at least one reachable escape route. Prototype behavior before increasing its 900 health.
4. **Create an explicit recovery decision.** Trial a fixed small automatic heal plus a choice of one of two components or a larger heal. Compare against the existing +15 baseline; do not simultaneously reduce healing and increase damage in the first experiment. Recovery must be visible and available while components remain, rather than waiting for the unreachable fallback.
5. **Add optional challenge modifiers after baseline tuning.** Examples: an elite in selected rooms, changed boss patterns, or less recovery. Display all rules before the run and record them with its seed. Keep rewards cosmetic or score-based initially, consistent with the game's exclusion of permanent power progression.

Prototype warning times and healing amounts are tuning hypotheses. Never require a particular spell component to solve an encounter. Add danger through understandable counterplay, then check novice readability separately from expert difficulty.

## Upgrade candidates

These are proposed mechanics, not existing behavior. Prices are starting experiments and must be tested alongside encounter changes. Introduce only the first three initially; the remainder are a backlog.

| Upgrade | Initial experiment | Decision and drawback | Interaction constraints |
| --- | --- | --- | --- |
| **Frost** | +5 mana; root hits slow movement by 25% for 1 s; direct damage ×0.85 | Buy time to reposition at lower killing power | Refresh, never stack; boss slow capped at 10%; no attack-timer freeze or child/area propagation initially |
| **Wall Charge** | +4 mana; after the first actual wall reflection, that bolt's direct damage ×1.5; pre-reflection damage ×0.85 | Bank shots trade reliability and time for damage | Explicitly requires Bounce; show prerequisite before acquisition; bonus once per bolt, no compounding across bounces, no scaling of burn/Chain/Explode |
| **Delayed Blast** | +3 mana; modifies Explode into a fixed-location blast after 0.6 s at ×1.5 explosion damage | Predict movement or slow a group; moving targets can escape | Requires Explode; replaces its immediate explosion, never adds another; one queued blast per cast with a visible marker |
| **Siphon** | +3 mana; first root contact returns 4 mana, direct damage ×0.8 | Accurate low-damage shots support expensive builds; misses pay full cost | One refund per cast, no refund from burn/Chain/children/area; mana remains capped at 100 |
| **Heavy Bolt** | +4 mana; direct damage ×1.5, projectile speed ×0.75, delay +0.15 s | Commit to a slower aimed shot and punish an opening | Initially root-only bonus; specify how it combines with Cooldown; no automatic amplification of trigger damage |
| **Knockback** | +4 mana; root impact pushes normal targets 35 px, direct damage ×0.9 | Create an escape lane, but potentially scatter a useful cluster | No wall damage or recursive contact; bosses resist displacement; collision-safe destinations required |
| **Return Bolt** | +5 mana; one return leg toward the cast origin after 0.45 s, direct damage ×0.8 | Cast across a route and reposition to exploit the return | Shared hit history across both legs; no repeat damage on a previously hit target, no lifetime reset or extra trigger allowance |
| **Aftercast** | +7 mana; one delayed unmodified bolt after 0.25 s along the original aim, at half direct damage | Predict where a target will move; delayed damage can miss | Reserve projectile budget on cast; no modifiers or triggers on the extra bolt; no recursive copying |

With Projectile mandatory, paired upgrades consume scarce slots: Projectile + Bounce + Wall Charge leaves two free; Projectile + Explode + Delayed Blast also leaves two. That is intentional opportunity cost. If prerequisite rewards feel too restrictive, prototype Wall Charge and Delayed Blast as mutually exclusive specializations of their parent component instead of increasing the slot cap.

### Make ordering a separate, testable feature

Do not silently change the current global-modifier rules while adding the above upgrades. As a separate prototype, test one explicit directional rule: `Frost → Split` makes Split children inherit Frost; `Split → Frost` leaves children unslowed and grants the root a stronger slow. This would replace Frost's initial root-only rule, so it needs a visible before/after preview and exact documented inheritance. Keep all children non-triggering and preserve bounded execution. Proceed only if players can predict and explain the difference.

## Lessons from primary design sources

- Anthony Giovannetti's [Slay the Spire balance talk](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf) emphasizes giving each card a use, iterative changes, playtester feedback, and treating metrics as evidence rather than conclusions. Application here: evaluate a component in the situation it serves; do not balance solely by aggregate win rate or raw DPS.
- Matthew Davis's [Into the Breach postmortem](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf) describes readability, short experiences, visible attacks, and how those constraints shaped combat. Application here: clearly telegraph route-denial attacks and make positioning effects useful. This is an adaptation to real-time combat, not proof that turn-based tuning transfers.
- Supergiant's [Hades FAQ](https://www.supergiantgames.com/blog/hades-faq/) describes different difficulty modifiers and the Pact of Punishment as ways to accommodate different players. Application here: offer explicit optional challenge rules after establishing a fair baseline; do not assume one difficulty serves everyone.

## Validation and delivery sequence

1. **Establish the baseline.** Rerun the existing probe on a named current build in an isolated copy. Add policy comparisons: perimeter patrol, direction changes, and priority-target behavior. Reproduce the suspected Split overlap interaction on one durable target. Preserve outcomes including failures; do not tune just to defeat the bot.
2. **Test one encounter change.** Introduce lane denial in an early teaching room, then one mixed-role encounter. Compare the same seeds and player cohorts. Record raw damage taken by source, near misses, route changes, room time, and whether players understood each hit.
3. **Test three upgrades.** Add Frost, Wall Charge, and Delayed Blast individually. Compare baseline builds, prerequisite-only builds, and upgraded builds against isolated targets, lines, clusters, and the boss. Verify costs, refunds, damage provenance, target deduplication, delayed-effect cleanup, and capacity limits.
4. **Test rewards and run pacing.** Record offered/chosen/equipped components separately, swaps after rooms, mana-starved time, and recovery selected. Track combat and crafting time separately. Use the existing [blind playtest protocol](PLAYTEST.md), including its ten candidate builds and replay/comprehension measures. Keep novice and experienced results separate, with counts and denominators.
5. **Decide before expanding.** Continue when players demonstrate multiple useful builds, change tactics in response to readable threats, and understand why they took damage. A longer run or lower win rate alone is insufficient. Treat the 10–15-minute run target as a hypothesis to evaluate, not a reason to inflate enemy health.

Research validation: source inspection and independent arithmetic only. Godot was absent from PATH and the checked common application locations, so the current pacing probe, suspected Split interaction, and proposed balance values were not runtime-tested. Two native research workers examined combat and upgrade design; routing requested GPT-6.1 Sol/high for both, but the available worker status interface did not expose effective model/effort. No gameplay changes or commits were made.
