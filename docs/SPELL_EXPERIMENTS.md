# Practice-only spell candidates

Open **Experimental spell lab** from Practice forge. Only the lab opts into these rules. Normal runs, component catalog, saved recipes, unlocks and share codes retain standard rules. These are runnable conditional candidates, not accepted balance changes.

The baseline and prototype use the same selected recipe, fixture and copied terrain. Changing the Frost order switches both recipes together; compare each order against its own baseline. The preview animates the prototype and reports both outcomes. It runs an actual detached runtime cast, collision, effects and delayed-blast simulation for 120 fixed ticks (2 seconds), starting with 100 mana. No enemy attacks or AI, repeat casts, regeneration or profile I/O occurs. Burn after two seconds is excluded. The preview is not a full room rehearsal.

| Candidate | Exact experimental rule | Example |
| --- | --- | --- |
| Frost / Split ordering | Existing root slow and global 15% direct damage penalty stay. Newly spawned children inherit the 1-second slow only when Frost precedes Split. Accepted child hits apply 25% movement slow (10% bosses), without extra damage or triggers. | `projectile → frost → split`, then swap to `projectile → split → frost`; Moving fixture. |
| Split target exclusion | Newly spawned children's hit lists exclude the parent's target. All other damage, angles, count, costs and cooldown remain unchanged. Other targets remain hittable. | `projectile → split`; compare Boss and Cluster. |
| Repulse | Virtual extra slot; +5 mana actually paid. Reject base recipes with five components. An accepted root direct hit pushes a living ordinary target 48 px along the shot direction, or boss/Archivist 12 px, after existing impact triggers. Child and rejected repeat hits do not push. Shared circle movement respects cover and arena bounds. No added damage or procs. | `projectile → explode → delayed_blast`; Cluster, then Moving. |

Frozen runtime measurements on open floor:

- Split boss: standard 54 damage; excluded-parent prototype 18. Prototype cluster still deals 54 across targets. The isolated reduction alone does not establish better balance.
- Repulse with Explode / Delayed Blast: cluster damage remains 78.75 in both versions, despite moving the struck target. Displacement does not guarantee better delayed-blast damage or useful spacing.
- Frost inheritance is verified on separate child targets, including rejected repeat contacts; standard children remain without slow. The order UI makes this rule observable through controlled moving paths.

Acceptance still requires human tests: predictability of the order rule, readable inherited slow, aiming reliability, usefulness across clustered and isolated targets, Repulse disruption of delayed blasts, repeated-cast resource pressure, encounter difficulty, controller navigation and small-window legibility. Compare win rate, damage taken, time-to-kill and player comprehension across ordinary and boss encounters before proposing any standard-engine change. A production decision needs an explicit follow-up; no flags are saved by this lab.

## Integration seam

Inside the Practice-only reward menu branch, connect a button to:

```gdscript
var lab = load("res://scripts/spell_lab.gd").new()
lab.open(self)
```

`open` also rejects non-practice entry. The container lives in the page; rebuilding replaces only its children. Back calls `show_reward`, and exiting the tree frees the detached source proxy. With the input integration available, `back_action` and `finish_menu()` register navigation. The frozen validation snapshot exercises entry, all three selectors, Back, proxy cleanup and unchanged draft/inventory/profile/report/terrain; the integrated suite has now rerun successfully with the Practice entry and input seam. Rebuilds restore focus to the recreated Swap button or preserve the experiment selector after navigation links settle.

## Validation

`test_experiments.gd` exercises real runtime contacts and previews, resource payment, extra slot rejection, unknown IDs, parent exclusion, Frost ordering and standard behavior, child/repeat/capped Repulse rejection, movement against cover, two-second limits, projectile/effect caps and UI cleanup. `test_preview.gd` checks standard preview regression behavior. The integrated suite passed 426 checks, including four real GUI accept/release order swaps and Back navigation; standard preview passed 69. Headless checks cannot establish human balance or visual acceptance. Final rendered evidence is recorded separately.
