# Milestone Register — Spellforge MVP

**Tracking policy:** This file defines acceptance gates; the [GitHub milestone objects](https://github.com/howard86/spell-forge/milestones) track delivery. Milestones were created on 2026-10-23 without due dates. Issue state alone is not acceptance evidence.

| Milestone | Week | Goal | Tracking issue | Release gate |
| --- | --- | --- | --- | --- |
| M1 Foundation | 1 | Launchable and repeatable project | [#2](https://github.com/howard86/spell-forge/issues/2) | Downloaded Windows build runs |
| M2 Combat prototype | 2–3 | Satisfying 3–5-minute combat sandbox | [#3](https://github.com/howard86/spell-forge/issues/3) | Movement/casting/dodge/death/restart functional |
| M3 Spell engine | 4–5 | Eight composable components | [#4](https://github.com/howard86/spell-forge/issues/4) | Ten meaningful builds + bounded deterministic tests |
| M4 Full run | 6–8 | Six fights + boss | [#5](https://github.com/howard86/spell-forge/issues/5) | End-to-end 10–15-minute run |
| M5 Polish | 9–12 | Feature-complete, understandable demo | [#6](https://github.com/howard86/spell-forge/issues/6) | Blind-user validation |
| M6 Release candidate | 13–14 | Stable validated demo build | [#7](https://github.com/howard86/spell-forge/issues/7) | No blocking defects; Steam reviews |
| M7 Public demo | 15–16 | Release and commercial signal | [#8](https://github.com/howard86/spell-forge/issues/8) | Live demo + decision report |

The week numbers are relative to a development start date yet to be chosen; no milestone due dates are committed.

## Gate procedure
1. Complete linked issue acceptance checklist.
2. Record evidence: artifact, tested revision, replay seed/log, external playtest notes.
3. Identify known blockers and defer noncritical items explicitly.
4. Close a milestone issue only after the exit gate is met.
5. Do not advance scope merely because the calendar period has ended.

## GitHub milestones

- [M1 — Foundation](https://github.com/howard86/spell-forge/milestone/1): #2.
- [M2 — Combat Prototype](https://github.com/howard86/spell-forge/milestone/2): #3.
- [M3 — Spell System](https://github.com/howard86/spell-forge/milestone/3): #4 and semantics #9.
- [M4 — Roguelite Loop](https://github.com/howard86/spell-forge/milestone/4): #5.
- [M5 — Content & Polish](https://github.com/howard86/spell-forge/milestone/5): #6 and licensing #10.
- [M6 — QA & RC](https://github.com/howard86/spell-forge/milestone/6): #7 and Steamworks #11.
- [M7 — Demo Launch](https://github.com/howard86/spell-forge/milestone/7): #8.

## Current reality
- M1 foundation files were merged by PR #12, and local imports/exports are now checked; **fresh Windows execution remains unverified by this implementation effort**. Live GitHub issue #2 is already closed; its existing state is preserved, and missing acceptance evidence is tracked separately.
- Local M2–M5 gameplay implementation and automated checks are tracked in [the evidence ledger](IMPLEMENTATION_STATUS.md). External playtesting, pacing, fresh Windows acceptance, and Steam gates remain open; no stage issue is closed on code presence alone.
