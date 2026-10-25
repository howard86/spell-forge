# Spellforge Playtest Protocol

Use this sheet for a named build. Blank fields mean **not measured**, never a pass. The ten spells below are test candidates, not claims of viability. See [TESTING.md](TESTING.md) for severity and [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for release gates.

## Current candidate scope

The local candidate implements Forge/Warden and Archive/Archivist, each six trials plus its boss; optional four-slot setup, Ember/Frost starters, real reflector terrain, practice/comparisons/guide, recipes/profile recovery, safe-forge resume, workshop, manual codes, factual report and controller/accessibility paths. The isolated lab implements optional Frost/Split/Repulse prototypes; ordinary rules remain unchanged. The journeys below are acceptance procedures, not evidence they have passed.

Contracts: [research hypotheses](OCTALYSIS_RESEARCH.md), [expeditions](EXPEDITIONS.md), [input journey](INPUT_JOURNEY.md), [diagnostics](COMPONENT_DIAGNOSTIC.md), [experiments](SPELL_EXPERIMENTS.md), [performance](PERFORMANCE.md), [roadmap queue](roadmap_queue.json) and [remaining gaps](ROADMAP_GAPS.md). Root records final automated/rendered/package results separately; human observations remain pending until a session is recorded.

## Session record

| Field | Value to record |
| --- | --- |
| Session / anonymous participant ID | |
| Date / observer | |
| Build revision / artifact filename / checksum | |
| OS version / fresh machine or development machine | |
| CPU / GPU / RAM / display resolution / scaling | |
| Input / audio device / settings | |
| Run seed / expedition / slot cap / starting spell / route and reward choices in order | |
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
| Start to victory | For each expedition separately: six trials, rewards/edits, boss phase transition, victory summary/report and retry work. Record starter, cap and route. | |
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

## Roadmap iteration — experimentation, mastery and ownership

Apply these checks only to a build that actually includes the relevant feature. Use `not implemented` or `not run` explicitly; a proposed journey is not a recorded pass. Record build/content version, expedition, selected route, challenge slot cap, recipe/checkpoint ID and whether a practice/unlocked setup was used. The two expeditions are alternative six-trial-plus-boss runs, not a twelve-trial run. Keep original baseline observations separate from a changed build.

During blind play, record self-initiated edits, distinct legal spells actually equipped, practice entry/exit, recipe saves/revisits, route choices and voluntary replay. A reward being offered or owned does not establish that it was equipped or understood. Ask after play: “What did you try to change?”, “What happened?”, “What would you try next?”, and “Is there anything you would want to keep for another run?” Retain participant explanations and stop/continue reasons rather than inferring them from counts. Do not compute a motivation or fun score.

| Directed journey | Observable pass criterion | Result / revision / evidence |
| --- | --- | --- |
| Named recipe and relaunch | Save a legal ordered recipe, relaunch and reopen its exact components/name; loading grants no unavailable normal-run components. | |
| Corrupt/incompatible profile | With a separate test profile, truncate or alter its version/content IDs. Show honest feedback and preserve originals: supported corruption may recover a valid backup; an explicit future-version primary refuses downgrade and blocks writes. Verify no-save play remains available; never touch the participant's real profile. | |
| Practice and order comparison | Enter labeled practice, compare the same target setup with an order-swapped valid pair, observe actual resolver behavior, reset resources and return without expedition rewards. | |
| Alternative expeditions | Choose each expedition separately; complete six trials and its boss, including death/retry and distinct route/terrain/boss cues. | |
| Checkpoint resume | Stop at a documented safe boundary, relaunch and resume the same expedition, seed, encounter, inventory, spell and report; rewards cannot be taken twice. Complete the resumed run. | |
| Four-slot challenge | Opt in explicitly; editor, recipe import, preview and resumed run all enforce four slots; a five-slot recipe gives clear feedback. Verify ordinary five-slot mode separately. | |
| Workshop discovery | Trigger the documented observed condition once, revisit after relaunch and verify it persists; unrelated/practice actions do not award expedition-only progress. | |
| Recipe sharing | Export and import a valid recipe with the same ordered IDs; reject unknown versions, unknown IDs, oversized content and invalid dependencies clearly, without changing the prior recipe or inventory. | |
| Controls and accessibility | Rebind a control, handle a conflict, relaunch and verify persistence. Test supported display scaling/readability and reduced-motion/audio choices on named hardware and devices. | |
| Factual debrief | Independently compare a short controlled run to offered/chosen/owned/equipped data, actual damage/resource changes and exclusive combat/reward/pause/settings time; stop/finish freezes the report. Show the recent-event cap honestly. | |
| Balance experiment comparison | Label Frost/Split, Split balance, Repulse or an additional enemy experimental; use the same recorded setup and all attempts for comparison, then record actual tactical trade-offs and player explanations. | |

For report checks, deliberately over-damage a nearly defeated enemy and over-heal a nearly full player: recorded amounts must match the actual clamped changes. Pause and enter settings for known intervals; neither interval may inflate combat time. Make a reward offer, choose recovery and leave an owned component unequipped to confirm all four categories remain distinguishable. Exceed 128 events to verify the visible report identifies the bounded recent tail and does not claim a complete replay.

Report each proposed outcome with evidence and uncertainty: what experiments participants attempted, which interactions they could explain accurately, which saved builds they revisited, what they chose to keep, and why they continued or stopped. Automated checks remain correctness evidence; participant observations support design decisions without establishing broad commercial demand.

## Final candidate evidence boundaries

Repeat the two expeditions and complete supported input paths on the actual accepted artifact. Record physical controller model and reconnect behavior, keyboard-only operation, 960×540/1280×720 display conditions, normal/large menu text and any dense HUD/slot labels. Synthetic focus checks and screenshots corroborate implementation; they do not replace a person completing the journey.

Performance uses the separate serialized workload and environment record in [PERFORMANCE.md](PERFORMANCE.md). Do not record a frame-time pass from headless resolver stress or an invulnerable completion pilot. The original task ZIP remains unavailable; this sheet validates the user-approved reconstruction, not invented SF-008–SF-029 criteria.
