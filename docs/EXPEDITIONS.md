# Expeditions and reflector terrain

The run menu selects Forge or Archive, Standard (five slots) or Four-slot,
and Ember (Projectile + Fire) or Frost (Projectile + Frost). Each expedition
contains six authored trials and one 900 HP boss; choosing Archive starts a
separate seven-room run. Legacy direct `start_run(seed)` calls retain the
projectile-only Forge/open baseline.

Forge starts on open floor. Between trials its forge offers **Open floor**
(more room to move) or **Reflector route** (cover and bank shots, narrower paths).
The text map describes the next room's two pillars or horizontal walls. Archive
explicitly uses reflector rooms throughout. Route selection adds no health,
damage, count, timing, or reward bonus. Filled, outlined COVER blocks are actual
terrain; the flat floor texture remains decoration.

Safe-forge checkpoints preserve route selection, expedition, slot limit, starter,
seed, inventory, draft, rewards, and report. Resuming returns to that forge before
entering the next room. Its preview starts on empty floor because the saved route
is the next room's choice, not a record of the cleared room's terrain. Retry keeps
the same starting conditions and seed, starting on Open for Forge or Reflector for
Archive; route and reward decisions are made again. Portable challenge codes share
seed, expedition, slot limit and starter, not subsequent player decisions. There
are no permanent combat bonuses.

## Shared collision contract

`run_director.gd` returns the original `layout`, `roster`, `seed`, `waves`,
`wave_threshold`, and `spawn_warning` fields plus `expedition` and a caller-owned
`obstacles` array. Forge/open preserves its prior wave/layout RNG sequence;
Archive rearranges the six existing normal roles while retaining trial counts of
4/6/8/10/12/14 and the same independent reward draw.

`arena_geometry.gd` supplies deterministic circle projection, circle sweeps with
rounded corner contacts, and sliding motion. Player walking and dodges, enemy
movement, melee lunges and Warden charges sweep their full movement. A visibility
graph with at most ten nodes (source, target and expanded block corners) routes
actors around the two authored blocks. Ranged actors approach until their shot
radius clears cover, avoiding permanent corner firing stalls. Spawns and initial
shots project out of terrain without receiving a free Wall Charge.

Both friendly and hostile projectiles stop at the first terrain contact. Incoming
enemy hits resolve in travel order before reflection; targets beyond cover cannot
be hit. Actual reflections consume Bounce and enable Wall Charge. As before,
remaining travel in that simulation tick is discarded after reflection. Internal
cover uses the shot's radius; the existing outer-wall center contact remains
unchanged for baseline bank-shot compatibility.

Lane/sweep warning endpoints, damaging segments and effects use the same clipped
line. Charges show the body-sized swept endpoint. Chain hops stop at blocked
segments; explosions, delayed blasts and ground marks require line of sight from
their center at detonation. Radial fills, outlines, countdown arcs, detonation
effects and preview boundaries use a shared ray-clipped footprint: cover removes
the shielded part of the visible area as well as blocking its damage. Rays at
obstacle corners and immediately on either side retain sharp cover shadows;
empty-floor previews retain their original circle semantics. Terrain does not destroy already applied Burn or Frost.
Frost retains its one-second 25% normal/10% boss movement reduction; the stationary
Archivist has no locomotion to slow. Dodge immunity applies to every damage source.

## Archivist

Archive's final boss is a stationary floating tome at the clear arena center,
with a distinct procedural robe/page silhouette, title, health bar and phase cue.
The player enters at a separated southern position. The boss alternates:

- **Ring burst:** a 1.1-second windup announces finite radial projectile rays and
  an outlined 72-degree safe angular gap aimed at the player's direction when
  the warning begins. The gap never tracks during the warning. Visible ray
  endpoints use the same projectile-radius terrain sweep as the damaging shots.
- **Ground marks:** locked circular target positions are shown throughout the
  windup, then wait another second before detonating. Moving away or dodging avoids
  the damage. Marks project into clear terrain and cannot reach through cover.

Below half health, the ring also warns one delayed ground mark, and the mark
pattern adds two nearby targets. The gap remains. Recovery is two seconds in phase
one and 1.6 seconds in phase two, always exceeding 1.2 seconds before another
windup. Global projectiles cap at 160, hazards at 64, and cosmetic effects at 64.
The Warden retains its fan/sweep/charge sequence and moving identity.

## Controlled previews

`spell_preview.gd.evaluate(source, components, scenario, terrain_copy = [])` runs a
single detached real-runtime cast over 120 fixed ticks. The optional terrain array
is copied; fixture actors and shots project safely. Moving fixtures use the same
circle movement. Paired equipped/draft comparisons share identical terrain and
show those obstacles in the animation. The text identifies a test scenario with
copied terrain, not an exact room rehearsal. Default evaluation and Practice use
empty floor. Evaluation never changes live combat, profiles or reports and rejects
builds above the active challenge's slot limit.

## Verification and remaining acceptance

The new `test_world_runtime.gd` checks player/dodge/enemy/charge sweeps, route
reachability, friendly/hostile shielding, bounce chronology and Wall Charge,
clipped telegraphs, radial cover, deterministic preview/runtime parity, four-slot
submission, route checkpoints, portable setup, locked boss warnings, both phases,
recovery, hazard capacity, dodge, death and retry. Its invulnerable test pilot also
clears all seven Archive rooms through real traveling spells and navigation,
without changing enemy HP or teleporting damage. This defensive fixture establishes
combat reachability, not balance or human playability.

Run it with Godot 4.7.2 using `--headless --path game --script
res://tests/test_world_runtime.gd`; test saves derive isolated paths from a unique
settings path. Regression suites are `test_run`, `test_balance`, `test_ui`,
`test_preview`, and `test_journey`. Geometry and director suites cover deterministic
terrain and original-field compatibility. Do not invoke editor import while other
validation is running. Graphical capture, controller feel and human balance testing
remain separate acceptance work.
