# Spellforge Roadmap

## Current direction — 2026-10-25

Baseline: `ad162de`, Godot 4.7.2. The next iteration should help players make creative spell experiments, learn interactions and retain ownership of their discoveries. Implementation and tests establish behavior; external observations establish whether the result is understandable, useful or worth replaying. Do not assign a numerical motivation or fun score from game events.

The supplied task ZIP is unavailable in this workspace. The available summary identifies **SF-001** documentation, **SF-002** bounded local run report, **SF-003** current-versus-draft forge comparisons, **SF-004** guided first experiment, **SF-005** situational component diagnostics, **SF-006** optional ordering prototype, **SF-007** optional single-variable Split adjustment, and **SF-030** factual debrief. The detailed SF-008–SF-029 mapping is unavailable. The work areas below are a user-authorized reconstruction from the available direction, not recovered original task specifications. No missing task numbers are assigned. [ROADMAP_GAPS.md](ROADMAP_GAPS.md) records the gaps and acceptance evidence still needed.

At the baseline, the source has eleven spell components, a five-slot editor, seeded staged encounters, six trials followed by the Warden, recovery/component rewards, settings and run results. The three upgrades Frost, Wall Charge and Delayed Blast already exist. Historical references to eight components and Godot 4.4.1 below describe the earlier plan or its original evidence, not current scope.

## Integrated candidate and acceptance

The current implementation adds the complete profile/recipe/share/practice/tutorial/debrief journey, Archive terrain and Archivist, and input/accessibility paths to the baseline. [Octalysis research](OCTALYSIS_RESEARCH.md) explains the design hypotheses. [roadmap_queue.json](roadmap_queue.json) groups the user-authorized reconstruction into R01–R12 dependency packages; those IDs do not recover missing original task numbers.

| Work area | Implemented candidate | Remaining acceptance |
| --- | --- | --- |
| Factual report and debrief | Bounded observations wired to actual clamped combat/resource changes; exclusive state time; explicit offered/chosen/owned/equipped; persistent damage/denial aggregates and visible recent-tail limit. | Final integrated data-path checks and human debrief comprehension; no motivation score. |
| Profile, recipes, discoveries and sharing | Versioned validated local saves/backups, protected-file refusal, no-save play, named recipes, component discoveries/milestones, cosmetic palette and manual recipe/challenge codes. | Final-head recovery/relaunch checks and human understanding that recipes are designs, not ownership grants. |
| Guided experimentation | Skippable first experiment, isolated Practice, prospective reward inspection and six paired real-runtime preview fixtures. | Prediction/explanation and self-directed follow-up observations; see [diagnostics](COMPONENT_DIAGNOSTIC.md). |
| Expeditions and terrain | Alternative Forge/Warden and Archive/Archivist runs, six trials each; open/reflector choices, real collision/cover and distinct boss patterns. | Human tactical distinction, readability and balance; see [expedition contract](EXPEDITIONS.md). |
| Checkpoint resume and challenge | Safe-forge suspend/resume preserves reward eligibility, build, route and report; selected four-slot cap across relevant paths. | Final-artifact complete resume/retry and challenge journeys with no duplicated rewards. |
| Controls and accessibility | Controller combat, remaps, focus/Back/scrolling, bounded controller text entry, large menu text, reduced flash and shake/audio options. | Physical devices, reconnect, human keyboard-only traversal and rendered readability; see [input journey](INPUT_JOURNEY.md). |
| Optional rule candidates | Isolated Practice lab implements Frost/Split ordering, Split target exclusion and Repulse comparisons; standard rules/profile/share data stay unchanged. | Candidates remain unaccepted balance; see [experiments](SPELL_EXPERIMENTS.md). Any additional normal enemy remains optional and unimplemented. |
| Verification and delivery | Eighteen suite entry points, expanded CI, fixed packaged smoke/performance hooks and bounded workload harness. | [Consolidated local evidence](ROADMAP_VALIDATION.md) and [performance measurements](PERFORMANCE.md) are recorded; boss frame-budget and human/Windows/Steam gates remain open. |

## Completion boundaries

The dependency order in the queue runs from research/identity/report foundations through persistent journeys, expeditions and controls to verification, human acceptance and release. Playable work is integrated; R10's local artifact/measurement evidence is recorded in [ROADMAP_VALIDATION.md](ROADMAP_VALIDATION.md), with boss frame-budget acceptance still open, R11 requires people and intended hardware, and R12 requires the owner’s release decision. These are distinct gates, not promised dates.

Use [PLAYTEST.md](PLAYTEST.md) to observe creative comprehension, mastery, recipe ownership and voluntary replay. Update [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) with the actual final revision and outcomes. Automated behavior, configured CI, screenshots, exports and scripted invulnerable pilots do not establish fun or balance. [ROADMAP_GAPS.md](ROADMAP_GAPS.md) records remaining uncertainty.

## Historical MVP plan — retained unchanged below

The following seven-stage / sixteen-week plan predates the current source baseline. Its dates, scope counts and conditional beyond-MVP list are historical planning assumptions, not a current acceptance report.

### MVP Roadmap — Seven Stages / Sixteen Weeks

**Planning baseline:** Solo developer, 15–20 hours/week (240–320 hours). **Target outcome:** Public free Windows Steam demo, *not* a paid full release. All dates are relative; schedule begins when development starts.

| Stage | Weeks | Goal | Primary focus | Exit gate |
| --- | --- | --- | --- | --- |
| 1. Foundation | 1 | Repeatable playable project | Godot project, inputs, camera, CI, export, basic architecture | Fresh Windows build launches |
| 2. Combat prototype | 2–3 | Responsive core combat | Move, aim, dodge, cast, damage, two enemies, death/restart | 3–5 minutes of functional combat |
| 3. Programmable magic | 4–5 | Validate defining mechanic | Eight components, ordered editor, event resolver, limits, tests | >=10 distinct viable builds; testers understand interactions |
| 4. Roguelite loop | 6–8 | End-to-end run | Six encounters, boss, rewards, seed, restart, run results | 10–15 minute target run can be completed |
| 5. Content and game feel | 9–12 | Accessible and engaging demo | Final MVP visuals/audio, five enemies, balance, onboarding, blind playtests, store assets | Feature complete; major usability issues resolved |
| 6. QA and candidate | 13–14 | Stable launch build | Stress/regression tests, freeze, fresh-PC test, packaging, Steam review | No known critical blockers; required review approvals |
| 7. Ship and validate | 15–16 | Public demo and learnings | Release, crash triage, feedback, next-step assessment | Stable public build and post-launch decision |

## Gate reviews
### Gate A — after Stage 3
**Go** only if modular spell building produces distinct tactical outcomes and is easy to understand. Otherwise revise the core interaction before adding more enemies.

### Gate B — after Stage 4
**Go** only if full-run pacing, reward choices, and replay motivation are credible in external playtests.

### Gate C — after Stage 5/6
**Go** only if unfamiliar players can finish/restart a run without assistance and no critical bugs remain.

## Cross-stage parallel tracks
- **Steam onboarding:** Start early, ideally by Weeks 7–10; account/store/build reviews are external dependencies.
- **Player research:** Begin with quick mechanic playtests, then blind external tests.
- **Asset licenses:** Record source, author, license, and proof of purchase before redistribution.
- **Documentation:** Update GDD, spell semantics, and ADRs when design decisions change.

## Scope control
- Freeze core MVP at 1 wizard, 1 active spell, 8 components, 5 enemy archetypes, 1 boss, 1 biome.
- Prefer curated modular arenas over building a general procedural level generator.
- New feature requests must demonstrate impact on experimentation, comprehension, or replayability.
- A gate failure changes schedule and/or scope; it does not trigger rushing through polish.
- Treat all numerical validation targets as hypotheses, not guarantees.

## Suggested work tracking
Create seven GitHub milestones when useful; label implementation issues `stage:1` through `stage:7` only after those labels exist. Use bug/feature/design/test/docs categorization. Track blockers against the relevant exit gate rather than counting completed tasks alone.

## Beyond MVP (conditional)
Only after demo validation: additional components, second biome, more bosses, controller support, accessibility enhancements, Steam achievements, and monetized full-game planning.
