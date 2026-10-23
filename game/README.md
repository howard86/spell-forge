# Spellforge playable demo

Requires **Godot 4.7.2**. Open `game/project.godot` and run the main scene, or run `godot --path game` from the repository root.

Move with **WASD / arrows**, aim with the mouse, hold left click to cast, press **Space** to dodge, and **Esc** to pause. Enter an integer seed to repeat encounters and rewards. Clear six trials, choose components and edit your ordered spell between fights, then defeat the Warden. Settings persist locally; no account or network service is required.

## Checks

```sh
godot --headless --path game --editor --quit
godot --headless --path game --script res://tests/test_spells.gd
godot --headless --path game --script res://tests/test_run.gd
godot --headless --path game --script res://tests/test_controls.gd
godot --headless --path game --script res://tests/test_stress.gd
```

Debug exports support a fixed packaged smoke check: `Spellforge.exe --headless -- --smoke-test` (12 checks); omit `--headless` to also check the rendered viewport. The mode uses isolated settings, tests startup, notices, movement, casting, pause, death/retry and audio cleanup, then exits. It does not load external scripts and is disabled in release builds. Godot 4.7.2 export templates do not support the editor’s `--script` entry point. CI runs all regression/stress scripts with the matching Linux and Windows editors, then checks the downloaded Windows executable through this smoke mode.

The integration suite uses scripted inputs and isolated settings. It verifies rules and transitions, not human pacing or balance.

## Windows export

Install matching export templates, then:

```sh
mkdir -p build
godot --headless --path game --export-debug "Windows Desktop" ../build/Spellforge.exe
```

The executable embeds its game data. Test it on Windows separately: exporting on macOS or Linux does not establish Windows runtime acceptance. CI runs the rules and integration suites before exporting. See the evidence ledger for completed workflow runs and their tested revisions.

Original procedural visuals/audio are documented in [asset provenance](assets/PROVENANCE.md). The project is MIT licensed; see [LICENSE](../LICENSE) and the in-game credits for engine and third-party notices. See [implementation evidence](../docs/IMPLEMENTATION_STATUS.md) for release limitations.
