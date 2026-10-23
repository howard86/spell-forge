# Combat and spell-forging UI playtest

Use a fresh run and record the seed, viewport size, and selected components. These
tasks measure player understanding; automated UI checks do not replace them.

## Combat readability

- Without opening help, identify current health, mana, the cost of one cast, and
  whether casting and dodging are ready.
- Hold cast until mana runs low. Confirm the equipped spell remains visible.
- During the Warden's second phase, check that the phase warning and low-mana
  feedback remain readable together.
- Identify a burning enemy and the protected side of a Bulwark. Approach its
  unprotected side and explain the difference.
- Distinguish melee, ranged, and area-attack warnings before each attack fires.

## Rewards and crafting

- Compare the offered rewards without hovering. Explain a chosen component's
  effect and added mana cost.
- Build a spell, change the order of two modifiers, remove one, and add it back.
  Confirm the required Projectile component remains first.
- Test the draft spell safely, then confirm that health, mana, kills, elapsed
  combat time, and the active run's equipped spell have not changed.
- Acquire a new component with all five slots filled. Find it in the collection
  and equip it by replacing a modifier.
- Explain the final spell's behavior and cost before entering the next trial.

## Progression and results

- Identify completed trials, the current encounter, and the remaining enemies.
- After victory or death, read the number of cleared trials, combat time, and
  final build. Retry the same seed and check that the run starts fresh.

## Record

Record task completion without assistance, misread cues, accidental clicks,
unreadable or clipped text, and whether the player can describe two tactically
different builds. Check at the 960 × 540 logical viewport and the default
1280 × 720 window. Keep scripted/rendered evidence separate from human results.

## Automated validation and rendered evidence — 2026-10-23

Godot 4.7.2 on macOS passed 319 assertions: 94 spell, 87 run, 26 controls,
and 112 UI checks, with zero failures. The stress check completed 10,000
maximum-trigger casts and 800,000 contact attempts with all budgets bounded.
Import and rendering completed without reported errors or leaked instances.

The input-only three-seed probe produced byte-identical result JSON to the
pre-change baseline at `18711266c5117affd5e77297b6d5bea9d66887cc`:

| Seed | Result | Combat seconds | Final health | Enemies defeated |
| --- | --- | --- | --- | --- |
| 4242 | Victory | 119.483333 | 91 | 55 |
| 12345 | Victory | 111.550000 | 100 | 55 |
| 1 | Victory | 112.666667 | 92 | 55 |

Controlled fixtures were rendered and inspected at 960 × 540 and 1280 × 720.
The checked-in 1280 × 720 captures show [combat](media/ui/combat.png),
[simultaneous boss and low-mana warnings](media/ui/boss-low-mana.png),
[enemy cues](media/ui/enemy-cues.png), [reward cards](media/ui/rewards.png),
[the full forge](media/ui/forge-full.png), and [results](media/ui/victory.png).
These are controlled UI fixtures, not normal gameplay captures, a human
playtest, or marketing approval. Fixture counters and encounters are arranged
independently to exercise specific UI states.

Reproduce with Godot 4.7.2 from the repository root on a machine with a display:

```sh
godot --path game --script res://tests/capture_ui.gd -- /absolute/output-directory 1280x720
```

Omit the final size argument to render 960 × 540. The
[capture record](media/ui/capture-record.json) records the engine, base commit,
capture date, and SHA-256 hashes of the relevant scripts and image files.
Validation logs for this run are in `/private/tmp/spellforge-ui-validation`.

Windows execution and human playtesting were not run. Automated assertions,
scripted survival, and rendered inspection do not establish player understanding;
the tasks above remain the human acceptance checklist.
