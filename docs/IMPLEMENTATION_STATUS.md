# Implementation and Release Evidence Ledger

This ledger tracks issue acceptance, not development effort. **No runtime, playtest, platform, or release gate is verified by the presence of this document.** The isolated local implementation is assembled; local verification below does not close external release gates. The foundation baseline was `2a5710117eba92e8838c393d51ca8ad5dabf7873`.

## Evidence rules

- Record revision, command or procedure, environment, observed result, and artifact/log location for each claim.
- Keep source inspection, automated tests, local gameplay, downloaded Windows checks, blind playtests, and platform approvals distinct.
- Use `pending`, `verified`, `failed`, or `external dependency` for individual gates. Mark an issue complete only after every applicable acceptance criterion has evidence; a local implementation does not close an external gate.
- Test duration, ten viable builds, player comprehension, replay motivation, and commercial interest are measured outcomes, not features that can be declared implemented.

## Issue-by-issue gates

| Issue / scope | Locally deliverable work | Required completion evidence | Current gate / evidence |
| --- | --- | --- | --- |
| [#2 Foundation](https://github.com/howard86/spell-forge/issues/2) | Godot project, inputs, camera, architecture, CI and Windows export configuration. | Final revision imports/tests successfully; CI artifact exists; downloaded export runs on a fresh Windows machine. | InputMap actions configured. Hosted import, tests, export and downloaded executable checks passed on a fresh Windows runner at `bf00ea7`; graphical Windows playtest pending. |
| [#3 Combat prototype](https://github.com/howard86/spell-forge/issues/3) | Movement, aim, casting, dodge, damage, two enemies, death and restart. | Recorded 3–5-minute sandbox demonstrates all controls, enemy telegraphs, damage, death and restart without a blocker. | Mechanics and synthetic input tests pass; human 3–5-minute combat acceptance pending. |
| [#4 Spell engine](https://github.com/howard86/spell-forge/issues/4) | All eight components, ordered editor, pricing, bounded resolver, deterministic tests. | Tests exercise documented semantics and limits; at least ten distinct viable builds have observed tactical results. | 94 rule checks pass across 12 legal builds; editor and integration checked. B01–B10 external viability sheets pending. |
| [#5 Full run](https://github.com/howard86/spell-forge/issues/5) | Six encounters, boss, rewards, seeded run, result screen, restart. | Start-to-victory and start-to-death journeys; seed/log evidence; measured run duration and replay observations. | Scripted six-encounter/boss victory, death and restart pass. Input-only scripted patrol won three seeds in 108–119 combat seconds; this flags pacing risk, not human acceptance. See [pacing probe](PACING_PROBE.md). Human full-run pacing/replay evidence pending. |
| [#6 Content and polish](https://github.com/howard86/spell-forge/issues/6) | Five enemy archetypes, biome, visuals/audio, balance, onboarding, settings and accurate store-material drafts. | Readability/settings checks; asset provenance; 10–15 blind testers with comprehension/replay counts and resolved major usability defects. | Original pixel rendering/audio, settings and credits implemented; rendered screens inspected; store-copy and capture brief prepared. Perceived audio, balance and blind tests pending. |
| [#7 Release candidate](https://github.com/howard86/spell-forge/issues/7) | Regression/stress suite, frozen candidate, packaging, known-defect list. | Exact candidate passes regression and target-hardware stress checks; no open P0/P1; fresh Windows validation; required platform reviews approved. | Local regression and bounded stress pass; build source hashes recorded. Downloaded Windows executable passed headless checks at `bf00ea7`. Target-hardware frame-time, graphical Windows playtest and platform approval pending. |
| [#8 Public demo](https://github.com/howard86/spell-forge/issues/8) | Launch checklist, support/triage plan and post-launch decision-report template. | Approved demo publicly available and installable; launch monitoring and actual player evidence support a dated continue/pivot/stop report. | External dependency: no public-release or post-launch evidence recorded. |
| [#9 Spell semantics](https://github.com/howard86/spell-forge/issues/9) | Explicit order, inheritance, trigger, deduplication, burn, budget and deterministic tie-break rules with examples. | Documentation matches final implementation; tests cover each rule, order-sensitive examples, and safe exhaustion. | Locally verified: ADR 0001, independent source review and 94 spell assertions; integrated burn/Chain regressions pass. |
| [#10 Licensing](https://github.com/howard86/spell-forge/issues/10) | Inventory code/assets, origins, authors, licenses and redistribution evidence; document generated assets and dependencies. | Owner chooses repository license; authorized license text and asset rights review are complete. | Owner delegated the decision on 2026-10-23. MIT covers original code/docs/art/audio; original-media inventory reviewed, project license bundled, engine/dependency notices retained. See provenance. |
| [#11 Steamworks / Coming Soon](https://github.com/howard86/spell-forge/issues/11) | Prepare truthful copy, legitimate gameplay captures and demo-association checklist. | Owner completes partner onboarding, fee/tax/bank requirements; current rules checked in Steamworks; store/demo association and required reviews confirmed. | Store copy and six-shot capture brief prepared in STORE_PAGE_DRAFT.md. External dependency: no account, payment, legal, store or approval evidence available; no release date committed. |

## Validation record

Append one row per actual check. `Not run` is intentional until an observer records a result. Failed checks remain visible with links to their later retest.

| Check | Revision / artifact | Environment / seed | Procedure / command | Observed result | Evidence location |
| --- | --- | --- | --- | --- | --- |
| Source/contract review | Local working tree from baseline above | Independent read-only reviewer | Source/ADR/test review and fix rounds | Burn damage/death ordering, seeded composition, audio cues and Chain feedback corrected | ADR 0001; regression tests |
| Automated tests | `build/source-sha256.json` | Godot 4.4.1, macOS Apple M4 Pro | `test_spells.gd`, `test_run.gd`, `test_controls.gd` | 94 spell + 87 run + 26 input/credits checks pass (207 total, PR #18 review fixes) | `build/spells.log`, `build/run.log`, `build/controls.log` |
| Headless import | Same source snapshot | Godot 4.4.1 | `godot --headless --path game --editor --quit` | Passed | `build/import.log` |
| Rendered screens / synthetic controls | Local working tree | Seed 4242; 1280×720 window | Scene rendering and synthetic mouse/keyboard events | Menu, combat and editor rendered; controls/death/retry pass. Human playtest not run | `build/screenshots/`; `test_controls.gd` |
| Worst-trigger spell stress | Same source snapshot | Godot 4.4.1 | `test_stress.gd` | 10,000 casts, 800,000 contact attempts; limits respected. This is not target-hardware frame-time measurement | `build/stress.log` |
| Windows artifact / fresh-machine check | `build/Spellforge.exe` | macOS cross-export, official matching templates | Windows Desktop debug export | Export passed; Windows execution NOT tested | `build/windows-export.log` |
| Hosted Linux and Windows | `bf00ea7e06fce78131f20056faee71d7edc803d9` | GitHub Ubuntu container and fresh windows-latest runner | Import, regression, stress, export, download, execute packaged game | Both jobs passed; Windows logged 94 spell + 61 run + 13 controls checks. Later InputMap additions require a new head run. This is headless automation, not human graphical acceptance | [Actions run](https://github.com/howard86/spell-forge/actions/runs/39838986110) |
| Blind usability / replay | Pending | Pending | [PLAYTEST.md](PLAYTEST.md) | Not run | Pending |
| Asset inventory | Local source | Original procedural art/audio | Provenance and in-game engine credits | Inventory reviewed; owner-authorized MIT license added for original materials; engine/dependency notices retained | `game/assets/PROVENANCE.md` |
| Steam review / public install | Pending | Pending | Authorized platform process | Not run | Pending |

## Handoff boundary

Repository work can implement gameplay, produce testable exports, and prepare review materials. Automated Windows execution does not substitute for a human graphical Windows playtest, independent blind testers, Steamworks account/fee/tax/bank actions, platform approval, or an authorized public release. Keep those gates open until the corresponding evidence exists. Consult [RELEASE.md](RELEASE.md) for the release checklist; verify current platform rules in Steamworks before making date commitments.

## Local artifacts and limitations

`build/Spellforge.exe` is the Windows debug playtest build. `build/Spellforge-macOS.zip` is an unsigned local macOS convenience build; it is not a notarized distribution release. Generated artifacts/logs are ignored by Git. `build/source-sha256.json` identifies the game source used for exports. Commit identity, draft PR and hosted CI status are recorded in the accompanying delivery. No Steam publication has been performed.

`bun run check` passed (three supported tooling files); it does not validate GDScript. Godot performs the script parsing and runtime checks. Hosted GitHub Actions results must be checked against the published PR head; local results alone do not establish CI acceptance.

The macOS engine exited 134 inside the filesystem sandbox. The same official 4.4.1 binary ran successfully with approved execution outside it; a sandbox-extension diagnostic remains at startup but the tests exit 0. Templates were used from temporary storage. The Windows export disables optional resource modification because no custom icon/version resources are supplied and the local machine has no `rcedit`. The local Mac packaging copy enables the required ETC2/ASTC import option.

The arena pool shares rectangular collision geometry and varies visual layout, seeded composition and tactical spawn formations. Cast rules are deterministic; no claim is made of cross-platform bitwise full-input replay. Numeric balance and 10–15-minute pacing remain unvalidated. No human playtest results, performance acceptance, store imagery approval or launch outcomes have been invented.

Final macOS package rendered using OpenGL on Apple M4 Pro and exited through the normal window-close notification with exit 0 and no ObjectDB warning (`build/macos-launch-close.log`). Normal Quit/window-close now awaits bounded audio cleanup. Godot's forced `--quit-after` bypasses this lifecycle and still reports an engine ObjectDB warning; it is not used as the clean-close acceptance path.

GitHub status refresh on 2026-10-23: issue #2 was already closed before this delivery. This effort preserves that state and does not infer fresh-Windows acceptance from it. Issues #3–#11 were open at refresh.


## PR #18 independent review follow-up (2026-10-23)

Three independent read-only reviewers examined gameplay, spell integration and release readiness at `1ba8a6bcb29ef46ad2ce4f4e49c71705ebaba916`. Ten unique findings were reproduced or confirmed; all were corrected. Confidence was high for every finding.

| Severity | Finding | Fix and verification |
| --- | --- | --- |
| P2 | Swept bolts hit enemies in insertion order | Sort circle-entry contacts by travel fraction, then stable ID; reversed-order regressions pass. |
| P2 | Chain, Split and Explode originate beyond the impact | Resolve at actual swept contact; origin and backward Chain-range regressions pass. |
| P2 | Wall reflection changes inbound armor and Split direction | Resolve incoming contacts before reflection; armor and direction regressions pass. |
| P3 | Combat continues after death and invalidates the summary | Stop remaining enemy/projectile/hazard updates; contact and projectile death regressions pass. |
| P3 | Global cap emits only half a Split pair | Reject the entire pair while retaining its consumed reservation; cap regression and ADR updated. |
| P3 | Final partial projectile lifetime is discarded | Resolve remaining movement before expiry; final-slice regression passes. |
| P3 | Exact right/bottom wall contact consumes a bounce without reflecting | Inclusive boundary checks; both edges and following ticks pass. |
| P3 | Capture and controls read real settings before isolation | Assign unique settings paths before scene insertion; controls and three-seed probe pass with an isolated default profile muted, while the profile remains unchanged. |
| P3 | Game README says licensing is undecided | Corrected to adopted MIT license and notices. |
| P3 | Milestone summary omits recorded Windows execution | Distinguish prior headless automation from current-candidate checks and external graphical acceptance. |

The root reran import, all 207 assertions, and the 10,000-cast / 800,000-contact bounded resolver stress test with Godot 4.4.1. Windows and macOS debug exports succeeded. The rebuilt macOS package rendered with OpenGL on Apple M4 Pro and exited through normal window close with code 0 and no ObjectDB warning. Logs and source hashes remain in ignored `build/`. The spell reviewer independently rechecked the fix diff and found no remaining actionable blocker; this follow-up was static, while runtime validation was performed by the root.

The normal-rules scripted probe won seeds 4242, 12345 and 1 in 119.48, 111.55 and 112.67 combat seconds respectively (`build/review-pacing.log`). These are diagnostic scripted outcomes, not human pacing acceptance. Existing review media remains explicitly tied to its earlier recorded revision; it was not recaptured in this review. Bounce still clips movement at the first wall in each tick, discarding the remaining fraction of movement; this pre-existing approximation was noted by the reviewer. Human graphical testing, blind playtests, target-hardware performance and Steamworks remain external gates. No merge or public release is authorized by this review.
