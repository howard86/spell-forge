# Spellforge playable demo

Requires **Godot 4.7.2**. Open `game/project.godot` and run the main scene, or run `godot --path game` from the repository root.

Move with **WASD / arrows**, aim with the mouse, hold left click to cast, press **Space** to dodge, and **Esc** to pause. Controller defaults are left-stick movement, right-stick aim, right trigger/shoulder cast, south-face-button dodge and Start pause. Settings shows current bindings. Menus support focus navigation, Back, scrolling and a controller text-entry modal; physical-device acceptance remains pending. See [input details and limits](../docs/INPUT_JOURNEY.md).

## Choose a journey

The menu selects Forge/Warden or Archive/Archivist, Standard five-slot or Four-slot, and Ember/Fire or Frost/slow. Each is a separate six-trial-plus-boss expedition. Forge starts open and offers open or reflector routes between trials; Archive always uses reflector cover. Cover changes movement, projectiles, warnings and area-effect visibility. Routes add no reward or combat-stat bonus. Retry repeats the starting seed/setup; later choices are made again. See [expeditions](../docs/EXPEDITIONS.md).

Between trials, choose a component or Restore and edit the ordered spell. Projectile stays first, duplicates are forbidden, and upgrade prerequisites must be equipped. Owned components remain available when slots are full. The preview compares equipped and draft builds in six selectable fixtures: Isolated, Armored line, Cluster, Moving, Wall shot and Boss. It observes one real-runtime cast for two seconds with fresh 100 mana, no repeat casts or regeneration; it is a controlled comparison, not sustained DPS or a room simulation. Reward inspection does not commit the reward.

**Practice forge** temporarily supplies all eleven components on empty floor and restores the prior inventory/build on exit. **First experiment** guides a prediction/test/revise exercise and can be skipped. The **Grimoire** saves up to 32 named recipes; recipes remember designs, never grant normal-run ownership. Practice's **Experimental spell lab** compares optional Frost/Split ordering, Split target exclusion and Repulse candidates. Those flags never alter ordinary runs, recipes or share codes. See [diagnostics](../docs/COMPONENT_DIAGNOSTIC.md) and [experiment contracts](../docs/SPELL_EXPERIMENTS.md).

## Keep and share your experiments

Safe-forge checkpoints preserve the unresolved or selected reward, draft, equipment, route, setup and report. **Suspend to menu** saves the safe forge before returning to the menu; resume returns to that forge, not mid-combat. Completing or abandoning a run clears its checkpoint. Workshop discoveries record components owned after a trial/reward or completed run; milestones record first clear and expedition/four-slot wins. Ember/Frost workshop palettes are cosmetic only.

Profile saves validate versioned data, keep a last-good backup and surface failures. An explicit future-version primary is preserved and refused rather than silently downgraded to its older backup. Protected or unreadable files block writes. The menu offers **Play without saving** when needed; this disables profile/recipe/checkpoint writes for the session while audio/input preferences remain separate.

Share/import accepts bounded `SF1:` recipe or challenge codes manually, without accounts or a network service. Recipes do not unlock components. Challenge codes configure the next run's seed, expedition, slot cap and starter; they do not encode future route/reward decisions or replace a live run. Seeds use the inclusive exact-JSON range ±9,007,199,254,740,991.

The run result links to a factual report with exclusive combat/forge/pause/settings time, observed clamped damage/resource changes, damage-source totals, rate-limited blocked-cast observations and offered/chosen/owned/equipped categories. Its event list is only the latest 128 observations; aggregates survive rollover. It never scores enjoyment or motivation.

## Checks and export

See [TESTING.md](../docs/TESTING.md) for all eighteen automated suites and isolation requirements. The [performance harness](../docs/PERFORMANCE.md) is a separate bounded diagnostic; its implementation alone is not a measured frame-time pass. The [evidence ledger](../docs/IMPLEMENTATION_STATUS.md) records observed results and pending final-head checks.

Debug packages support `Spellforge.exe --headless -- --smoke-test`; omit `--headless` for the rendered smoke path. This fixed in-package check uses isolated data and exercises packaged startup, controls, pause, death/retry and cleanup. It loads no external script and is ignored by release builds. Godot 4.7.2 exported templates do not execute editor `--script` suites. CI separately runs all editor regressions and the downloaded Windows package; configured CI is not proof the current head passed.

Install matching templates, then export from the repository root:

```sh
mkdir -p build
godot --headless --path game --export-debug "Windows Desktop" ../build/Spellforge.exe
```

The executable embeds its game data. A macOS/Linux export does not establish Windows runtime acceptance. Human balance, physical controllers, graphical Windows journeys, full-run pacing and target-hardware performance remain separate checks. Use the [playtest protocol](../docs/PLAYTEST.md) and [release checklist](../docs/RELEASE.md).

See [asset provenance](assets/PROVENANCE.md), [MIT license](../LICENSE) and in-game engine/dependency notices.
