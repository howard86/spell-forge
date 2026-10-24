# Spellforge playable demo

Requires **Godot 4.7.2**. Open `game/project.godot` and run the main scene, or run `godot --path game` from the repository root.

Move with **WASD / arrows**, aim with the mouse, hold left click to cast, press **Space** to dodge, and **Esc** to pause. Enter an integer seed to repeat encounters and rewards. Clear six trials, choose components and edit your ordered spell between fights, then defeat the Warden. Encounters now arrive in warned waves; lane archers lock their aim before firing, and the Warden alternates fan, lane, and charge attacks with recovery windows. Settings persist locally; no account or network service is required.

The combat HUD shows health, mana, cast cost, and cast/dodge readiness. Between
trials, compare reward cards and arrange your five spell slots with the arrow and
Remove controls. Projectile stays first. Acquired components remain in your
collection even when every slot is filled. **Test group** previews the draft against
stationary targets; **Wall shot** demonstrates wall interactions such as Bounce.
Frost trades direct damage for a brief movement slow. Wall Charge requires Bounce and rewards reflected shots; Delayed Blast requires Explode and replaces its instant burst with a marked 0.6-second detonation. Rewards offer up to two components or Restore; prerequisite components must be equipped to use their upgrades. Both previews leave the active run unchanged. The result screen reports
combat time, excluding time spent paused or crafting.

## Checks

```sh
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/test_spells.gd
godot --headless --path game --script res://tests/test_run.gd
godot --headless --path game --script res://tests/test_director.gd
godot --headless --path game --script res://tests/test_balance.gd
godot --headless --path game --script res://tests/test_controls.gd
godot --headless --path game --script res://tests/test_ui.gd
godot --headless --path game --script res://tests/test_stress.gd
```

Debug exports support a fixed packaged smoke check: `Spellforge.exe --headless -- --smoke-test` (14 checks); omit `--headless` to also check the rendered viewport. The mode uses isolated settings, tests startup, notices, movement, casting, pause, death/retry and audio cleanup, then exits. It does not load external scripts and is disabled in release builds. Godot 4.7.2 export templates do not support the editor’s `--script` entry point. CI runs all regression/stress scripts with the matching Linux and Windows editors, then checks the downloaded Windows executable through this smoke mode.

The twelve-seed balance comparison is available through `res://tests/probe_balance.gd` (optionally append `-- --reactive`). See [balance validation](../docs/BALANCE_VALIDATION.md) for before/after measurements and limits.

The integration suite uses scripted inputs and isolated settings. It verifies rules and transitions, not human pacing or balance.

Use the [UI playtest checklist](../docs/UI_PLAYTEST.md) to check player
understanding of readiness, enemy cues, rewards, crafting, and run results.

## Windows export

Install matching export templates, then:

```sh
mkdir -p build
godot --headless --path game --export-debug "Windows Desktop" ../build/Spellforge.exe
```

The executable embeds its game data. Test it on Windows separately: exporting on macOS or Linux does not establish Windows runtime acceptance. CI runs the rules and integration suites before exporting. See the evidence ledger for completed workflow runs and their tested revisions.

Original procedural visuals/audio are documented in [asset provenance](assets/PROVENANCE.md). The project is MIT licensed; see [LICENSE](../LICENSE) and the in-game credits for engine and third-party notices. See [implementation evidence](../docs/IMPLEMENTATION_STATUS.md) for release limitations.
