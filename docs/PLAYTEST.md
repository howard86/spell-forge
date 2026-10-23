# Spellforge Playtest Protocol

Use this sheet for a named build. Blank fields mean **not measured**, never a pass. The ten spells below are test candidates, not claims of viability. See [TESTING.md](TESTING.md) for severity and [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for release gates.

## Session record

| Field | Value to record |
| --- | --- |
| Session / anonymous participant ID | |
| Date / observer | |
| Build revision / artifact filename / checksum | |
| OS version / fresh machine or development machine | |
| CPU / GPU / RAM / display resolution / scaling | |
| Input / audio device / settings | |
| Run seed / starting spell / reward choices in order | |
| Experience with action games / prior Spellforge exposure | |
| Recording consent / recording or observation-note location | |
| Start / end / interruptions | |

Use anonymous IDs and voluntary feedback. Ask consent before recording. A fresh-machine check requires a downloaded export on Windows without the editor or project dependencies installed; editor play on a development machine does not satisfy it.

## Facilitator procedure

1. For blind usability sessions recruit 10–15 unfamiliar participants. Exclude prior participants from the blind denominator; retain their feedback separately. Do not teach spell interactions or explain controls beyond what the shipped game supplies.
2. Give this neutral prompt: “Play this game as you normally would. You can stop whenever you like. Please say what you are thinking.” Let the participant discover the interface. Record every hint, intervention, and blocker with a timestamp.
3. Observe launch, movement, casting, dodge, rewards, spell edits, death or victory, and restart. Do not require a second run before observing whether one starts voluntarily. Offer a consistent 30-minute session window; record if time or an interruption prevents a replay opportunity.
4. After unaided play, ask: “What did your spell do?”, “What changed when you changed its components?”, “When would you choose another combination?”, and “What made you continue or stop?” Record responses verbatim where consent permits. Avoid suggesting the desired answer.
5. Run directed checks only after the blind portion; label them directed. A repaired or coached attempt does not replace the original unaided result.

## Observation sheet

| Event / measure | Result or timestamp | Assistance / evidence |
| --- | --- | --- |
| Launch reaches usable menu | | |
| First movement / cast / dodge | | |
| First valid self-built spell equipped | | |
| First cost, cooldown, or order confusion | | |
| Explains one interaction accurately against current semantics | | |
| First reward selected / reason given | | |
| Encounters cleared (0–6) / boss reached | | |
| Boss phase transition understood / attack avoided | | |
| Death or victory / elapsed run time | | |
| Voluntary second run started before replay prompt | | |
| Stop reason / confusing moment / preferred build | | |
| Crash / softlock / severe readability problem | | |

Report counts and denominators alongside percentages. Proposed decision thresholds remain hypotheses: at least 80% build a valid spell unaided, 70% correctly describe one meaningful interaction, and 60% voluntarily start a second run. Report both all eligible blind participants and the subset with a replay opportunity; list exclusions and reasons rather than silently removing failures. Record median and range of completed-run times against the 10–15-minute target, plus deaths and unfinished runs separately. Small samples do not establish commercial demand.

## Ten tactical spell candidates

Each candidate uses lowercase component IDs, starts with `projectile`, has no duplicates, and fits the five-slot cap. Use a clearly labeled unlocked test setup if normal rewards do not provide a candidate. Never count an unlocked test as normal progression acceptance. Confirm the current documented trigger order before judging results.

| ID | Ordered components | Tactical hypothesis to test | Comparison / observable result |
| --- | --- | --- | --- |
| B01 | `projectile` | Cheap precise single-target baseline | Record casts, mana recovery, and time to kill an isolated enemy. |
| B02 | `projectile, fire` | Apply damage then reposition | Observe burn ticks while no longer casting; compare B01. |
| B03 | `projectile, pierce` | Line up enemies | Count distinct targets hit by one traversal in a line. |
| B04 | `projectile, split` | Cover separated targets | Observe bounded child creation and hit coverage versus B01. |
| B05 | `projectile, bounce` | Attack using walls | Record reflected trajectories and useful hits after reflection. |
| B06 | `projectile, chain` | Connect nearby enemies | Record hops, distinct targets, and isolated-target trade-off. |
| B07 | `projectile, explode` | Punish clusters | Compare one impact on clustered versus separated targets. |
| B08 | `projectile, cooldown` | Sustain rapid simple casts | Measure cast interval and mana-limited downtime versus B01. |
| B09 | `projectile, pierce, fire, cooldown` | Pressure a line while moving | Compare damage coverage, resource cost, and survival with B03. |
| B10 | `projectile, split, chain, explode, fire` | Dense-pack burst with bounded effects | Record event/projectile caps, frame times, and recovery after firing. |

For each candidate record seed, arena, enemy setup, revision, costs shown, casts, hits, clear time, remaining health, mana downtime, effect counts where instrumented, and observer notes. Use the same setup for comparisons and repeat at least three times; record all attempts. A candidate qualifies as viable only with observed usefulness in a documented situation, recoverable resource use, and no correctness blocker. Ten listed candidates alone do not meet the ten-build gate. Include an order-swapped pair in directed tests using the current contract and assert its specified difference; do not infer order semantics from the list above.

## Directed acceptance journeys

Record pass/fail/not run, artifact revision, seed, evidence, and defect link for every row.

| Journey | Observable pass criterion | Result / evidence |
| --- | --- | --- |
| Start to victory | Six encounters, rewards and edits, boss phase transition, victory summary, restart all work. | |
| Start to death | Zero health ends combat, result screen is usable, restart resets run state. | |
| Editor validation | Missing source, bad order, duplicate or excess slots are rejected according to the contract; prior valid spell remains usable. | |
| Low mana | Denied cast gives feedback, spends no partial cost, regeneration permits recovery. | |
| Pause and settings | Combat stops while paused; resume works; audio/display options work and selected settings persist after relaunch. | |
| Stress | Worst permitted composition terminates within configured budgets, leaves no stuck effects, and meets a declared frame-time target on recorded hardware. | |
| Repeatability | Same seed and scripted inputs produce the same canonical event log in the automated harness; manual play is separate evidence. | |
| Downloaded Windows export | Fresh machine launches without editor, completes death/restart and victory paths, handles supported scaling and audio. | |

## Defect and gate report

For each defect capture severity, revision, seed, reproduction steps, expected/actual result, recording/log, owner, and retest result. P0/P1 defects stop release. A fix is accepted only after rerunning its failing scenario where feasible.

Finish with: participant counts, unaided successes, interaction comprehension, replay opportunities and starts, run-time distribution, viable-build evidence, open defects, and **go / revise / blocked** with reasons. Keep blind usability, automated correctness, local manual play, Windows export, and Steam acceptance evidence separate.
