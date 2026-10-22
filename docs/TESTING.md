# Testing and MVP Validation Plan

## Test layers
1. **Unit tests:** Spell validation, pricing, cooldown bounds, chain/trigger eligibility, encounter reward constraints.
2. **Deterministic simulation tests:** Same seed and scripted inputs => identical combat event output.
3. **Integration tests:** Spell UI -> compiled spell -> runtime -> damage and results.
4. **Manual gameplay tests:** Controls, telegraph readability, hit reactions, pausing, death, restart.
5. **Stress tests:** Worst allowed Split + Chain + Explode combinations; projectile/event caps.
6. **Release smoke tests:** Fresh Windows install, no editor dependencies, graphics scaling, audio controls, expected content.

## Required acceptance journeys
- Launch -> new run -> clear encounter -> choose modifier -> edit spell -> fight boss -> win -> restart.
- Launch -> run -> die -> results -> restart.
- Invalid component order -> clear feedback -> cannot equip broken spell.
- Low mana -> cast denied with feedback, no incorrect mana consumption.
- Event cap reached -> orderly termination without crash, lockup, or persistent invisible effect.
- Close/relaunch -> chosen settings persist.

## Structured external playtests
- Stage 3: Small mechanic sessions, recording comprehension issues and interesting combinations.
- Stage 4: Full-run tests, observing choice points and replay behavior.
- Stage 5: At least 10–15 **blind** testers who receive no developer explanation.
- Record task success, confusion moments, run completion, self-selected restart, and qualitative feedback.

## Hypothesis-based thresholds
- >=80% can build a valid spell without direct assistance.
- >=60% voluntarily start a second run during a test session.
- >=70% can name at least one meaningful component interaction.
- Zero known critical crashes or softlocks at release.

These are proposed *decision heuristics*, not statistically reliable market benchmarks. Report sample sizes and test conditions alongside percentages.

## Defect severity
- **P0:** Crash/data corruption/security issue; stop release.
- **P1:** Softlock, critical combat exploit, cannot finish a run; stop release.
- **P2:** Major balance, usability, or performance regression; fix or document before release decision.
- **P3:** Cosmetic or minor issue; defer if low impact.

## Telemetry and privacy
Prefer manual playtest observations early. If shipping analytics, disclose collection and request appropriate consent; collect minimal aggregated gameplay data, not personally identifying data. A public demo does not require an external analytics backend.

## Regression gate
Every fixed spell interaction bug should add an automated test that reproduces the issue before the fix.
