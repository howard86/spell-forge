# Runtime performance verification

The comparative measurements below belong to the pre-review source hashes. Subsequent terrain, input, and probe-isolation fixes are recorded in [STACK_REVIEW.md](STACK_REVIEW.md); the old timings do not establish performance acceptance for those changes.

**Status: local measurements recorded; frame-budget acceptance remains open.** Three serialized rendered repeats each of the baseline, candidate editor, and actual macOS debug package completed with zero probe or engine errors. No speedup or Windows/target-hardware acceptance is claimed. Scripted samples do not replace human playtesting.

The yardstick is a 60 fps game with a 16.67 ms frame budget. Observe p50, p95,
p99 and maximum completed wall-frame intervals and simulation duration. Keep
object peaks, cast/error counts, Godot static/peak memory, and render counts
alongside the timing values. A quieter or broken workload must not look faster.

## Workload and upper count

`game.gd` caps all live projectiles at 160. Authored ordinary encounters contain
at most 14 enemies across both waves. A conservative contact-candidate bound is
160 × 14 = **2,240 candidates/tick**, or **134,400 candidates/second** at 60 ticks/s,
before dead-target, hostile-projectile, hit-history and geometry filtering.
This is an operation-count bound, not an estimated cost in nanoseconds. Staging
usually reduces the simultaneous count; the seven-target fixtures imply at most
1,120 candidates/tick. Chain, explosion, geometry, navigation and drawing add
work outside that simple product.

The same `runtime_probe.gd` module drives four bounded scenarios:

| Scenario | Fixture | Equipped build |
| --- | --- | --- |
| `forge_wave` | Seven authored Trial 6 roles | Projectile, Fire, Pierce |
| `max_trigger_build` | Same seven roles | Projectile, Pierce, Split, Chain, Explode |
| `warden` | Phase-two Warden | Projectile, Fire, Pierce, Chain, Explode |
| `archive_archivist` | Candidate Archive terrain and phase-two Archivist | Same boss build |

The trigger build fills the legal five slots and combines the available direct
hit, piercing, split, chain and explosion triggers. It is not a promise that 160
projectiles will be reached during legal mana regeneration and cooldowns. Read
the observed peaks and cast counts. Archive is explicitly skipped when its
properties are absent in an older runtime; it has no comparable base scenario.

Every scenario resets from seed 4242, enters its real encounter, then replaces
its automatic waves with the controlled fixture. Enemy positions/timers and
square-patrol movement are deterministic. Aim selects the nearest target.
Enemies retain their real movement, warning, attack and collision code; spells
retain their real mana costs and cooldowns. Targets receive very large health
and the player receives sustained hurt immunity to prevent fixture attrition;
bosses start in phase two. Those overrides are only for this diagnostic.
Automatic waves/pending spawns are cleared, target counts stay fixed, and no
unbounded replenishment or input/cast spam bypasses the actual cast method.

## Entry points

Use the same engine, resolution, driver, frame limit and host conditions for
all comparative runs. The examples assume `godot` resolves to Godot 4.7.2.
Run one benchmark at a time, with no concurrent tests, editor import, export,
build or other CPU/GPU-heavy work. Capture the full stdout/stderr and exit code.

```sh
# Editor executable, graphical diagnostic (does not start the editor UI):
godot --path game --max-fps 60 --script res://tests/probe_runtime.gd -- --probe-write

# Short integration check only; still includes the 60-frame warmup:
godot --headless --path game --script res://tests/probe_runtime.gd -- --probe-frames=16

# Packaged debug executable: fixed in-package entry, no external script loading.
Spellforge --max-fps 60 -- --performance-probe --probe-write

# Pure nearest-rank helper check, without loading the main scene:
godot --headless --path game --script res://tests/probe_runtime.gd -- --probe-helper-test
```

An exported **debug** main scene recognizes only the fixed `--performance-probe`
hook. A release build ignores that flag. The hook disables profile loading and
sets a fresh `user://runtime-probe-<timestamp>.cfg` before any persistence load.
The editor wrapper does the same, checks optional properties safely, and derives
isolated profile/bindings paths where available. Cleanup removes only matching
probe fixture paths. Existing user settings, bindings and profiles are never
loaded by these entries. Optional `--probe-write` overwrites the fixed
`user://runtime-probe.json`; arbitrary output paths are not accepted. A failed
write or failed audio shutdown produces an error and nonzero exit.

`--probe-frames=N` accepts only 16–600 measured frames (default 180). Every
scenario always warms up for 60 frames. These bounds also bound samples and
runtime; the default runs 960 simulation frames when all four scenarios exist.
Physics automation is disabled and exactly one real `simulate(1/60)` call is
made per observed frame. Explicit `cast_spell()` calls are made when cooldown
allows, with successful and failed casts counted. HUD updates and drawing use
the real game paths. There is no variable-delta catchup after a slow frame.

## Baseline and comparison protocol

1. Preserve an untouched base checkout of `ad162de` in a separate temporary
   worktree. Copy only `game/scripts/runtime_probe.gd` and its UID plus
   `game/tests/probe_runtime.gd` and its UID into the same relative locations.
   Do not copy candidate game/runtime dependencies or modify the base game.
   The module deliberately does not preload `game.gd`; the wrapper loads that
   checkout's own main scene. A baseline without Archive prints `PERF_SKIP`.
2. Run the untouched base twice, serially, with identical settings (**A/A**).
   Record per-scenario metric drift before making any comparison. Prefer at
   least three repeats per build and preserve every result; report the range
   or uncertainty rather than choosing a convenient fastest run. Two A/A runs
   establish only a small observed noise sample, not a confidence interval.
3. Run the candidate using the same harness and settings. Then run the candidate
   debug package through its fixed entry. Keep editor and package build-mode
   differences explicit. No headless-versus-rendered or base-versus-Archive
   timing comparison is valid.
4. Record host model/OS, Godot version, debug/release/editor binary, render
   driver, resolution, vsync/frame limit, and material host activity externally
   with the captured JSON. The harness reports safe engine/CPU/OS details,
   omitting device serials and user paths. It does not pin CPUs or monitor
   concurrent host processes. Record inability to control those factors.
5. Separate startup/cold effects from warmed samples. Asset import, shader/audio
   startup, OS caches, thermal state and prior scenarios can affect results.
   Use the identical scenario order on both sides. Engine peak static memory
   accumulates over the process, so it is not a scenario-local allocation peak.
6. Inspect the workload and errors before timings: sample/tick counts must match,
   successful casts and projectile observations must be nonzero, enemy peaks
   must match the fixture, the cap must hold, and at least one hit must occur
   across warmup and measured frames. Scan logs for engine/script
   errors too; the probe's error counter covers its own invariants only. Inspect
   target health loss and object peaks to identify empty or obstructed combat.
7. Compare each scenario's p50/p95/p99 and peaks against A/A drift and the frame
   budget. Changes within observed drift are inconclusive/flat. Do not claim a
   speedup without this baseline. A repeatable regression requires investigation
   before delivery even if another isolated metric improves.

A second cold run is not automatically a warm run. Label what was actually
controlled. A probe-only fixture or scenario change requires fresh A/A and base
runs; never compare different workload versions as an optimization result.

## Output and limits

Each `PERF_RESULT <JSON>` line has schema version 1, scenario, seed/build,
entry mode/environment, sample/warmup counts, metric definitions, distributions,
workload counts, peaks and an invariant error count. `PERF_COMPLETE` reports the
final scenario/error totals. Optional output wraps the same results in one JSON
object. Percentiles use nearest rank over all measured observations.

- `wall_frame_interval_ms` measures elapsed monotonic time between successive
  completed frame observations. It includes explicit cast/probe/input work,
  simulation, HUD updates, scheduling and rendered work. A graphical run awaits
  both `process_frame` and `RenderingServer.frame_post_draw` once per tick. This
  is a completed-frame interval, not GPU timing or display presentation latency.
- `simulation_ms` times only `simulate(1/60)` with microsecond ticks. Explicit
  casting, HUD work and probe bookkeeping are excluded; wall intervals cover
  those costs. Small samples near timer resolution need cautious interpretation.
- Headless runs await `process_frame` without rendering. Uncapped headless frame
  rates measure neither 60 fps pacing nor graphical acceptance. Their output
  explicitly records zero `rendered_frames_observed`. They are integration diagnostics.
- Static/peak memory are Godot `Performance` monitors, not total process RSS,
  GPU memory or allocations. Debug monitor availability and backend reporting
  can vary; zeros alone are not proof that resource use is zero. Render-object,
  primitive and draw-call counts are sampled after rendering.
- Failed casts during mana recovery are expected and counted separately from
  invariant errors. `target_hp_loss` records aggregate accepted target health
  reduction, with warmup loss recorded separately, not the number of damage callbacks. Peaks are sampled at frame
  boundaries; they do not capture a transient allocation inside one method.
- This script is a fixed-timestep, bounded, invulnerable combat sample. It does
  not establish human balance, input responsiveness, long-run stability,
  save/profile behavior, Windows behavior, or full release acceptance.

## Recorded checks

An isolated helper run on Godot 4.7.2 passed nearest-rank p50/p95/p99/max,
singleton and empty samples, and input-array preservation. It did not load or
measure the game. The restricted environment could not create a new app's
user-data directory under `~/Library/Application Support/Godot/app_userdata/`
and printed a macOS certificate-store warning; the helper still printed PASS
and exited zero. The later main-scene/rendered/package series is recorded below; this earlier helper run remains an isolated historical check.


## Recorded rendered comparison — 2026-10-25

The full results, including every repeat, cast/damage counts, object peaks,
engine memory and environment, are in [the machine-readable evidence](validation/roadmap-performance-20261025.json).
Godot 4.7.2, Apple M4 Pro (14 CPU cores), macOS 27.0.1, OpenGL compatibility,
960×540, requested max FPS 60 and vsync enabled were used throughout. Each
scenario had 60 warmup and 180 measured frames. Runs were serialized with no
owned tests/builds running concurrently; desktop background load, thermal state
and OS scheduling were not controlled. These are completed-frame observations,
not direct GPU or display presentation timings. Do not invert these percentiles
into a claimed delivered FPS.

Ranges below cover all three repeats; units are milliseconds.

| Build | Scenario | Wall p50 range | Wall p95 range | Wall p99 range | Simulation p99 range |
| --- | --- | --- | --- | --- | --- |
| baseline | forge_wave | 8.296–8.363 | 13.534–13.851 | 14.435–14.745 | 0.078–0.081 |
| baseline | max_trigger_build | 8.098–8.302 | 13.653–14.268 | 15.023–15.167 | 0.126–0.129 |
| baseline | warden | 20.704–22.184 | 25.357–25.961 | 27.550–28.104 | 0.076–0.086 |
| candidate | forge_wave | 8.015–8.321 | 13.503–14.349 | 14.847–17.216 | 0.203–0.220 |
| candidate | max_trigger_build | 8.109–8.270 | 13.610–13.959 | 14.694–15.109 | 0.263–0.280 |
| candidate | warden | 12.983–21.521 | 25.258–26.226 | 28.519–29.823 | 0.190–0.260 |
| candidate | archive_archivist | 22.608–23.492 | 27.461–28.241 | 28.954–31.795 | 0.302–0.378 |
| package | forge_wave | 8.199–8.362 | 13.760–14.777 | 15.067–15.588 | 0.202–0.226 |
| package | max_trigger_build | 8.182–8.353 | 13.660–14.726 | 14.866–16.735 | 0.257–0.294 |
| package | warden | 13.080–13.191 | 25.344–26.076 | 26.724–29.582 | 0.185–0.218 |
| package | archive_archivist | 22.667–23.455 | 26.329–27.615 | 29.778–30.889 | 0.308–0.357 |

All comparable scenarios preserved successful cast counts and exact observed
health loss across builds: Forge 6 casts / 341.6000 damage, trigger build 3 /
748.0350, Warden 3 / 75.0000 in the measured period. Candidate and package Archive
both observed 3 casts / 106.5000 damage. All projectile peaks stayed within 160,
and every scenario rendered 180 measured frames with zero invariant errors.

Simulation time increased beyond the small baseline A/A drift. Source inspection
confirms new report observation/validation and shared geometric collision work
on the simulation path; no profiler attribution or speedup is claimed. The
largest candidate editor simulation sample was 1.066 ms, while the largest
package sample was 1.000 ms. Common-scenario wall p95 ranges overlap substantially;
Warden p99 shifts and outliers remain observable rather than being discarded.
Archive has no comparable baseline fixture.

The Warden already exceeded the 16.67 ms completed-frame yardstick in the base;
the candidate and package Warden/Archivist also exceed it. Consequently **60 fps
frame-budget acceptance is not established**. More sustained profiling on named
target hardware, with controlled presentation and scheduling, remains a release
gate. Small simulation times alone do not close that end-to-end gap.
