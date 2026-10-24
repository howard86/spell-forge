# Encounter and upgrade validation

Date: 2026-10-25. Engine: Godot 4.7.2 stable (`ed1daf0bf`) on macOS Apple M4 Pro. Baseline: `5479f26ac0b8ba03709a7a4e6e1c789cc4934129` plus the user’s unchanged project configuration and placeholder-player edits. Candidate: the uncommitted encounter/upgrade patch described by [ADR 0002](decisions/0002-encounter-balance.md).

## Observed balance comparison

The same twelve seeds, perfect nearest-target aim, held casting, legal reward choices and 1/60-second simulation steps were used before and after. The patrol policy continually visits four corners. The additional reactive policy is a simple heuristic that changes direction when a marked lane threatens its current or projected position; it is not a model of human skill. It uses the same movement and dodge inputs as the patrol driver. No health, damage, mana, roster or unlocked-component values are changed.

| Version / policy | Victories | Median combat seconds | Median damage taken | Median finishing health |
| --- | --- | --- | --- | --- |
| Baseline / patrol | 12/12 | 111.67 | 44 | 95.5 |
| Candidate / patrol | 12/12 | 104.57 | 74 | 70 |
| Candidate / reactive heuristic | 12/12 | 102.59 | 64.5 | 74.5 |

The unchanged patrol takes more damage and finishes with less health in the candidate, while all runs remain completable by that driver. Median combat duration decreased; this patch does not establish the 10–15-minute human run target. The reactive heuristic reduces median damage relative to patrol, but performs worse on several seeds. These are descriptive results for this fixed seed set, not statistical proof of human difficulty or fairness. Reward pools and encounters both changed, so this comparison does not isolate their individual causal effects.

Damage is accepted health loss measured inside a diagnostic override of `damage_player`, before between-room healing. Mana-limited time counts frames where cooldown is ready but mana is insufficient. Intermissions are instantaneous; both metrics exclude human reading/crafting time. Reaction counts are frames, not distinct attacks.

| Seed | Baseline seconds / damage / HP | Candidate patrol seconds / damage / HP | Candidate reactive seconds / damage / HP |
| --- | --- | --- | --- |
| 4242 | 119.48 / 48 / 91 | 137.97 / 108 / 38 | 134.62 / 85 / 60 |
| 12345 | 111.55 / 32 / 100 | 88.47 / 28 / 88 | 88.48 / 35 / 88 |
| 1 | 112.67 / 32 / 92 | 110.78 / 74 / 71 | 110.97 / 74 / 69 |
| 2 | 104.43 / 52 / 100 | 107.40 / 85 / 75 | 95.68 / 99 / 31 |
| 3 | 109.60 / 80 / 80 | 107.98 / 57 / 73 | 110.17 / 118 / 35 |
| 4 | 86.12 / 31 / 100 | 93.75 / 69 / 54 | 97.52 / 55 / 80 |
| 5 | 112.72 / 52 / 88 | 109.62 / 74 / 69 | 107.67 / 118 / 13 |
| 6 | 88.70 / 79 / 90 | 160.50 / 121 / 40 | 159.72 / 102 / 43 |
| 7 | 124.02 / 64 / 88 | 90.17 / 61 / 76 | 82.20 / 28 / 88 |
| 8 | 92.58 / 39 / 99 | 101.73 / 67 / 71 | 108.13 / 24 / 100 |
| 9 | 111.78 / 39 / 99 | 89.83 / 77 / 68 | 91.75 / 53 / 100 |
| 10 | 118.03 / 40 / 99 | 84.57 / 88 / 62 | 92.55 / 24 / 99 |

## Reproduce

Run the self-contained diagnostic from a disposable checkout. For baseline comparisons, copy only this driver into the baseline checkout; do not copy candidate gameplay code.

```sh
godot --headless --path game --script res://tests/probe_balance.gd
godot --headless --path game --script res://tests/probe_balance.gd -- --reactive
```

The original three-seed `probe_playthrough.gd` remains unchanged. The new driver uses seeds `4242, 12345, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10` and records build/reward history with each outcome. The durable driver exactly reproduced all 12 baseline and all 24 candidate diagnostic records.

## Mechanical and visual validation

- Spell suite: 200 checks, including prerequisite order, prices, damage factors, root-only Frost, noncompounding charge, once-per-cast delayed blast, and existing semantics.
- Director suite: 65,146 checks across seeded encounter cases and all 1,024 ownership subsets, including prerequisite gating and Restore availability.
- Balance integration: 41 checks covering actual collision, frozen aim, swept charge, spawn transitions, pause/reset/death, slow expiry/refresh, boss slow cap, delayed warning lifetime and queue capacity.
- Run integration: 87 checks; controls: 26 checks; UI: 248 checks including new reward cards, longest valid five-slot build, disabled prerequisite actions, delayed preview behavior and correctly mapped blast bounds.
- Stress suite: 10,000 casts / 800,000 contact attempts stayed within execution budgets.
- Controlled Split overlap probe: one head-on root impact dealt 18 damage, followed by two child hits for 54 total. This confirms the previously suspected interaction in that setup; it remains unchanged.
- Main-scene smoke path: 14 checks, including the staged opening. This uses the editor executable, not a newly exported Windows binary.
- Rendered captures inspected at 960×540: locked lane, boss charge, Frost/charge shapes, delayed and spawn markers, new reward cards, and the long-name five-slot editor. UI bounds also pass at that size. This is an author check, not independent player comprehension.
- Repository lint, spelling, workflow syntax, whitespace, and isolated editor import checks passed.
- Independent enforced-read-only review found an obsolete opening-roster smoke assertion and a preview blast-scale mismatch. Both were corrected and have regression checks.

## Environment and remaining limits

Godot was not on PATH or in the usual application directories. A cached matching engine was found at `/private/tmp/spellforge-godot-4.7.2/Godot.app/Contents/MacOS/Godot`. Initial sandbox runs emitted user-log write and macOS certificate-access errors. Approved execution with explicit temporary log paths produced clean combined-suite and matrix logs; no configuration or user settings were changed to work around them.

Human challenge, comprehension, replay motivation, and the 10–15-minute target remain unverified. Windows export/runtime and hosted CI were not executed in this session. Optional challenge modes, slot-order redesign and Split rebalancing remain deferred. Use the existing [playtest protocol](PLAYTEST.md) before broadening content or raising damage.
