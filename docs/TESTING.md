# Testing and Validation

Godot **4.7.2** parses and tests gameplay. Bun checks supported repository tooling; it does not validate GDScript or establish player acceptance. Run from the repository root with a matching editor binary and export templates. Record final revision, engine, command, environment, exit result and evidence for every acceptance claim in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

## Automated suites

Import serially before validation; never run editor import concurrently with tests, exports or benchmarks:

```sh
godot --headless --path game --editor --quit
for suite in spells run director balance controls ui stress report registry profile sharing preview geometry journey bindings world_runtime input_journey experiments controls_regressions probe; do
  godot --headless --path game --script "res://tests/test_$suite.gd" || exit 1
done
bun run check
```

| Suites | Coverage |
| --- | --- |
| `spells`, `run`, `director`, `balance`, `stress` | Standard spell semantics, staged seeded progression/rewards, upgrade integration and bounded resolver stress. |
| `report`, `registry` | Stable IDs, strict restore, JSON boundaries, bounded event history, coherent/reconstructed aggregates, saturation and final state at the event ceiling. |
| `profile`, `sharing` | Validated recipes/checkpoints, backup/write protection, report/run identity, exact-range seeds and malformed/oversized/versioned portable codes. |
| `preview` | Paired real-runtime single-cast fixtures, overkill, defenses, moving targets, resource assumptions and detached-state isolation. |
| `geometry`, `world_runtime` | Terrain sweeps, safe spawns, cover visibility, reflection chronology, routes, Archivist patterns/phases, and Archive combat reachability. |
| `journey` | Practice/guide, inventory boundaries, recipes, discoveries, safe-forge resume, portable setup and factual report screens. |
| `bindings`, `controls`, `ui`, `input_journey`, `controls_regressions` | Remap persistence/conflicts, synthetic gameplay input, focus/Back/scrolling, controller text entry, held-confirm suppression and normal/large menu bounds. |
| `probe` | Invalid-cast side effects, hazard capacity, physical input-map isolation/restoration, and legacy action maps. |
| `experiments` | Practice-only Frost/Split/Repulse candidate behavior and normal-rule/profile isolation. |

A zero exit and expected success marker are necessary; also inspect logs for script/runtime errors and leaked objects. Test counts change with regressions, so use the final run's recorded results rather than copying older package totals. CI configures all twenty suites on matching Linux/Windows editors and separately downloads/executes the Windows debug artifact. Configuration is not current-head CI evidence.

## User-data isolation

Set a unique `settings_path` before adding a game instance to the tree. The runtime derives corresponding profile/bindings paths when their defaults remain unchanged. Tests must clean only their own fixture files and restore global InputMap state. Previews remain detached and perform no profile/settings loading. Never validate a corrupt-save scenario against a real player profile.

On this macOS environment, restricted execution cannot create Godot fixtures under `~/Library/Application Support/Godot/app_userdata/`, so profile startup may refuse a run. Approved execution of isolated fixtures is the established workaround. Report the actual failing error and rerun result; this is an environment constraint, not an automatic gameplay failure. The engine may also print a certificate-store diagnostic on startup; do not hide or misclassify it as gameplay evidence. Hosted logs remain subject to their stricter error scan.

## Diagnostics, performance and packages

- `probe_components.gd` emits deterministic twelve-build/six-scenario observations; see [COMPONENT_DIAGNOSTIC.md](COMPONENT_DIAGNOSTIC.md). It establishes fixture behavior, not viability or universal rankings.
- `probe_balance.gd` and `probe_playthrough.gd` are scripted diagnostic pilots, not human pacing/comprehension evidence. Preserve their setup and revision labels.
- `probe_runtime.gd` drives bounded real-runtime workloads and reports frame/simulation distributions and workload peaks. A short headless integration run checks harness behavior only. Run measured graphical/base/candidate/package comparisons serially using [PERFORMANCE.md](PERFORMANCE.md); measurements and target-hardware acceptance must be recorded separately.
- Debug packages support the fixed `-- --smoke-test` entry point; omit `--headless` to exercise rendered smoke. Debug `-- --performance-probe` uses the fixed in-package probe. Both hooks are ignored in release builds; neither loads arbitrary external scripts. Godot 4.7.2 export templates do not run editor `--script` suites.
- `capture_ui.gd` and rendered journey captures provide screenshots for an identified revision. Older media is historical until recaptured; screenshots alone do not establish human usability or physical-controller behavior.

## Required human and target-platform acceptance

Use [PLAYTEST.md](PLAYTEST.md) for complete Forge and Archive victory/death/retry/resume, first-experiment predictions, recipe recovery/sharing, optional-cap constraints and factual debrief checks. Use [INPUT_JOURNEY.md](INPUT_JOURNEY.md) for physical keyboard/controller traversal, text entry, reconnect and readability. Record assistance, failures, named hardware and all attempts.

The 10–15-minute pacing target, ten viable builds, 80% unaided construction, 70% interaction comprehension and 60% voluntary replay are hypotheses. Report participant counts, denominators, replay opportunities, interruptions and stated stop/continue reasons. Do not derive fun or motivation from tests, profile entries or run-report counts. [OCTALYSIS_RESEARCH.md](OCTALYSIS_RESEARCH.md) records the research boundaries.

## Defects and release gates

- **P0:** Crash, data corruption or security issue; stop release.
- **P1:** Softlock, critical combat exploit or inability to finish a run; stop release.
- **P2:** Major balance, usability or performance regression; fix or explicitly resolve before release.
- **P3:** Minor or cosmetic issue; triage by impact.

Add a meaningful regression for a reproduced defect and rerun its originally failing scenario before closing it. Keep correctness, rendered validation, physical devices, graphical downloaded-Windows journeys, frame-time measurements, human experience and Steam approval separate. Local reports are bounded offline observations, not an analytics service. See [RELEASE.md](RELEASE.md), [ROADMAP_GAPS.md](ROADMAP_GAPS.md) and the [reconstructed queue](roadmap_queue.json).
