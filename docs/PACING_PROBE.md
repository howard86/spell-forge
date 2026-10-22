# Scripted progression and pacing probe

This is diagnostic evidence, not a human playtest, target-hardware benchmark, or proof of viable-build balance. Gameplay revision: `fcb1977233ccad9274124bfbb6338d3ae64e5edc`. Observed on 2026-10-23 using Godot 4.4.1 on macOS Apple M4 Pro.

## Reproduce

```sh
godot --headless --path game --script res://tests/probe_playthrough.gd
```

The driver executes the actual game simulation in fixed 1/60-second steps. It supplies movement/cast actions, nearest-target aim, dodge requests, and legal reward choices. It never changes health, damage, mana, enemy rosters, collision rules, or unlocked components. It patrols four corners, chooses a preferred offered component, and accepts the normal editor draft. Intermission decisions are immediate; no player reading or thinking time is included. Output includes seed, terminal state, simulated combat time, health, kills, reward history and equipped components. A 900-second simulation bound prevents an endless diagnostic run. A death or timeout is a recorded outcome, not automatically a code failure.

## Observed continuous-patrol results

| Seed | Result | Combat seconds | Health | Kills | Final spell |
| --- | --- | --- | --- | --- | --- |
| 4242 | Victory | 119.48 | 91 | 55 | Projectile, Fire, Pierce, Cooldown, Chain |
| 12345 | Victory | 112.92 | 88 | 55 | Projectile, Fire, Cooldown, Pierce, Explode |
| 1 | Victory | 108.32 | 92 | 55 | Projectile, Fire, Chain, Cooldown, Pierce |

All six encounters, normal reward transitions, both boss phases, and victory ran with default combat values. The driver uses direct game methods for reward selection/transition and aim positioning; it does not validate discovering or clicking those UI controls. Existing controls tests cover synthetic device input separately.

An exploratory predecessor changed its patrol destination every three simulated seconds, causing it to cross the arena. It reached the boss and died on all three seeds (87.65, 111.10 and 68.95 combat seconds respectively). This demonstrates sensitivity to the driver policy; it is not evidence that human players will find the game easy or hard.

## Interpretation and next acceptance

The 10–15-minute human run target remains **unverified**, and these sub-two-minute automated victories are a concrete pacing concern. Perfect aim and instantaneous choices favor this driver. Do not multiply enemy health or repeat encounters solely to force this script into a desired duration: that would not establish engaging human pacing. Collect blind and directed run times, reward/edit time, damage sources and player feedback using [PLAYTEST.md](PLAYTEST.md), then tune encounter content and resource pressure against those observations. Preserve this probe as a repeatable comparison when tuning.

The three equipped spells share several components; these results do not satisfy the ten mechanically distinct viable-build gate. The probe also excludes rendering performance, audio perception, Windows graphical acceptance and independent tester comprehension.
