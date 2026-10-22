# Spellforge

**Spellforge** is a single-player, top-down pixel-art action roguelite about programming spells from modular magical components.

> **Project status:** Local demo implementation in development. Release gates, Windows acceptance, external playtests, and Steam publication remain pending. See [implementation status](docs/IMPLEMENTATION_STATUS.md) for evidence and limitations.

## Vision

Compose a spell, fight through compact randomized encounters, earn new components, and revise your build between battles. Each run should reward meaningful experimentation rather than repetitive stat grinding.

**MVP target:** A Windows-first, 10–15-minute playable run with one wizard, one biome, six encounters, a final boss, eight spell components, five normal enemy archetypes, and a simple ordered-slot spell editor.

## Development

The initial plan assumes a solo developer working roughly 15–20 hours per week, with a **16-week target for a public free demo**. This is a planning estimate, not a confirmed release date. Proposed engine: Godot 4, with GDScript for gameplay.

## Project documentation

- [Game design and MVP scope](docs/GAME_DESIGN.md)
- [Spell components and execution rules](docs/SPELL_SYSTEM.md)
- [Seven-stage development roadmap](docs/ROADMAP.md)
- [Technical architecture](docs/ARCHITECTURE.md)
- [Test strategy and validation gates](docs/TESTING.md)
- [Steam demo release plan](docs/RELEASE.md)
- [Contribution guidelines](CONTRIBUTING.md)
- [Milestone register and exit gates](docs/MILESTONES.md)
- [Decision log](docs/DECISIONS.md)
- [Getting started](docs/GETTING_STARTED.md)

**Current first priority:** Validate combat and ordered spell construction with players before expanding content. See the [playtest protocol](docs/PLAYTEST.md) and [roadmap](docs/ROADMAP.md).

Design targets and measured acceptance are distinct; a working implementation does not establish pacing, usability, or release readiness.

## Tracking status

Seven [GitHub milestones](https://github.com/howard86/spell-forge/milestones) track the stage issues #2–#8. Cross-stage design, licensing and Steamworks issues are assigned to their relevant milestones. The local playable implementation and verification are tracked in [the evidence ledger](docs/IMPLEMENTATION_STATUS.md); external release gates remain open.

## Links

- [Issues](https://github.com/howard86/spell-forge/issues)
- [Pull requests](https://github.com/howard86/spell-forge/pulls)

## License

No license has been selected. All rights reserved unless a license is added explicitly. Do not assume that third-party game assets may be redistributed.
