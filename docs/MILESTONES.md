# Milestone Register — Spellforge MVP

**Tracking policy:** This file and the linked stage issues are the canonical milestone register until actual GitHub milestone objects can be created. The connected GitHub interface used for setup did not expose create/list milestone operations. **Do not mistake these for GitHub milestone objects.**

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

## GitHub milestone objects to create when supported
Create seven milestones named **M1 — Foundation**, **M2 — Combat Prototype**, **M3 — Spell System**, **M4 — Roguelite Loop**, **M5 — Content & Polish**, **M6 — QA & RC**, **M7 — Demo Launch**. Associate the corresponding issue #2–#8 respectively. Assign cross-stage issues #9–#11 where appropriate. Do not guess due dates.

## Current reality
- M1 foundation files were merged by PR #12, but **the build has not been independently validated**; issue #2 remains open.
- M2–M7 have not been implemented.
