# Situational spell diagnostic

The detached reward preview compares the equipped spell with the draft using the
same fixture and the game's actual projectile, swept collision, shield, impact,
burn and delayed-blast code. The animation shows the draft. Neither evaluation
enters the scene tree, runs `_ready`, reads settings/profiles, accepts input,
advances a run, or shares mutable combat state with the source game.

Each result observes **one cast at time zero for two seconds**, at 60 fixed steps
per second (120 frames). Each cast starts from a fresh 100-mana budget and pays
the compiled cost through the runtime cast function, independent of live mana.
Mana cost and cast delay are compiled resource costs;
there are no repeated casts or mana regeneration. Cooldown therefore changes the
shown delay/cost but cannot increase the single-cast damage. This is not sustained
DPS, a mana-efficiency ranking, a player simulation, or a human balance test.
Burn damage after the two-second cutoff is excluded. Damage totals are capped at
each target's starting HP, and each dead target counts as one kill even if the
actual combat dictionary records negative HP from overkill.

## Reproducible fixtures

| Scenario | Setup | What it exposes |
| --- | --- | --- |
| Isolated | One stationary pursuer, 42 HP | Single-target damage, overkill and kills |
| Armored line | Four stationary 100 HP bulwarks, 85px apart, facing the incoming shot | Pierce, chain reach and actual frontal shield reduction |
| Cluster (`group` alias) | Four stationary 100 HP bulwarks, facing away | Area effects, nearby targets and component combinations |
| Moving | The same cluster retreating horizontally at 52px/s, facing away | Travel time, burn observation time, delayed-blast escape and Frost movement slow |
| Wall shot | Fire right from x=850; four stationary 100 HP bulwarks wait behind the origin | Bounce and Wall Charge; left-facing shields do not reduce the returning leftward shot |
| Boss | One stationary Warden, 900 HP and 27px collision radius | Durable single-target contacts; **no invented armor or frontal shield** |

`preview_scenarios.gd` owns exact coordinates and velocities. Controlled moving
paths advance before projectile/effect simulation, like enemy movement in combat.
An active Frost status multiplies moving bulwark speed by 0.75 until its runtime
expiry. The stationary boss does not demonstrate movement slow; its description
states that runtime boss slow would be 10%. Default fixtures have no AI, attacks, combat
RNG or new combat mechanics, and use open floor. Integrated comparisons can copy
a caller-provided terrain array, labeled as a controlled test rather than a room
rehearsal; both builds receive identical terrain. Practice remains on empty floor.
Fixed fixtures cannot establish whether a
component is broadly useful across real encounters.

## Run it

From the repository root, using the project's Godot version:

```sh
godot --headless --path game --script res://tests/test_preview.gd
godot --headless --path game --script res://tests/probe_components.gd -- --output /tmp/components.json
```

The probe prints one text row per build/scenario and a complete
`COMPONENT_DIAGNOSTIC_JSON` record. The optional `--output` writes formatted JSON
to the explicit path. It evaluates twelve stable builds in all six fixtures,
including every current component and a five-slot combination. JSON includes
fixture descriptions, assumptions, target HP/damage, kills, mana cost and cast
delay. It excludes animation frames, timestamps and ranking scores, so repeated
runs with the same game code produce the same JSON.

The focused suite checks deterministic frames, untouched source properties,
equipped/draft equality for identical builds, invalid inputs, actual target
movement and Frost slow, frontal shields, bounce charging, burn cutoff, capped
kills/damage, and differences between stationary and moving area-effect results.

## Observed evidence and Split hypothesis

The Godot 4.7.2 diagnostic produced these single-cast results:

| Controlled observation | Damage |
| --- | ---: |
| Projectile → isolated pursuer | 18 |
| Projectile + Split → isolated pursuer | 42 (HP cap), one kill |
| Projectile → stationary boss | 18 |
| Projectile + Split → stationary boss | 54 |
| Projectile + Pierce → armored line | 29.7 (base: 9.9) |
| Projectile + Explode + Delayed Blast → stationary cluster | 78.75 |
| Same delayed build → moving cluster | 38.25 |
| Projectile + Bounce → wall fixture | 18 (base: 0) |
| Projectile + Bounce + Wall Charge → wall fixture | 27 |

The **same-target Split hypothesis is confirmed in these fixtures**: the only
boss receives three direct 18-damage hits. Child bolts are created at the root
impact with fresh hit lists. The next swept collision step accepts their initial
overlap with that same surviving enemy. This gives Split single-target damage as
well as any spread utility; it is not evidence that the children reached three
different targets. The isolated pursuer's raw potential overkill is deliberately
reported as 42 actual HP removed, not 54.

An optional design adjustment would seed each child's hit history with its
parent's impacted target if Split is intended to reward spreading exclusively.
**That adjustment remains unaccepted for ordinary runs.** It is now implemented
as an opt-in Practice lab candidate alongside Frost/Split ordering and Repulse;
see [SPELL_EXPERIMENTS.md](SPELL_EXPERIMENTS.md). The measurements above describe
the standard mechanism, not accepted balance or full-encounter usefulness. Normal
Split/Frost rules, catalog values, profiles and share codes remain unchanged.

## Reward UI integration

The existing `SpellPreview` control still fits its 740×76 minimum area. Its
internal six-item selector reruns both builds; two compact text lines show
Equipped and Draft damage, kills, mana and cast delay. A visible `1 cast · 2s`
label states the observation scope. Hovering the selector or preview explains
target defenses, fixture motion, burn horizon and the draft-only animation.

The integrated forge, prospective reward inspection and first-experiment guide
use this comparison control through `game.gd` and `journey_ui.gd`. Existing
`restart("group")` and `restart("wall")` calls remain compatible shortcuts. Practice
restores the prior build/inventory on exit; prospective inspection never commits
a reward. Optional candidates use a separate detached experimental runtime and
are not recipe/profile/share flags. See [architecture](ARCHITECTURE.md),
[expedition preview parity](EXPEDITIONS.md) and [input navigation](INPUT_JOURNEY.md).
