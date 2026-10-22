# Contributor Onboarding

## Requirements
- Git and a compatible Godot 4 editor (initial project/CI assumes Godot 4.4.1).
- Windows for target build smoke tests, or another development OS with export templates installed.
- No proprietary assets are required for the current placeholder scene.
- [Bun](https://bun.sh) for the repo tooling; optionally `brew install gitleaks typos-cli actionlint` for the local pre-commit scans (skipped with a warning when missing).

## First steps
```sh
git clone https://github.com/howard86/spell-forge.git
cd spell-forge
bun install   # installs git hooks: biome via lint-staged, conventional commitlint, gitleaks/typos/actionlint
godot --headless --path game --editor --quit
godot --path game
```

Move the placeholder character with WASD/arrow keys. Spell casting and enemies are **not yet implemented**.

## Build smoke test
```sh
mkdir -p build
godot --headless --path game --export-debug "Windows Desktop" ../build/Spellforge.exe
```
Export requires matching templates; an exported executable must additionally be tested on Windows. Treat a successful import/export as only partial completion of Stage 1.

## Development workflow
Read [GDD](GAME_DESIGN.md), [milestone register](MILESTONES.md), and [spell contract](SPELL_SYSTEM.md). Pick an open scoped issue; propose semantic changes before coding. Submit PR with reproducible testing instructions.

Commit messages follow conventional commitlint, e.g. `✨ feat(spells): add chain component`. Run `bun run check` (or `bun run fix`) before pushing; CI runs the same lint plus typos, gitleaks and actionlint.

## Current blockers
Actual GitHub milestone objects were not available through the connected integration at setup time. See [MILESTONES.md](MILESTONES.md) for the authoritative issue-linked substitute.
