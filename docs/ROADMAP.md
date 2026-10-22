# MVP Roadmap — Seven Stages / Sixteen Weeks

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
