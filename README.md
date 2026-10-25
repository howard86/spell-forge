# Spellforge

Spellforge is a single-player, top-down pixel-art action roguelite about composing one active spell from ordered magical components.

**Status:** Integrated local demo candidate on Godot 4.7.2. The playable roadmap features are integrated for review; human balance/usability, physical controllers, graphical Windows acceptance, target-hardware performance and Steam publication remain separate gates. See the [evidence ledger](docs/IMPLEMENTATION_STATUS.md).

## Play and experiment

Choose **Forge** or **Archive**, a five-slot or optional four-slot run, and an Ember or Frost starting spell. Each expedition has six trials followed by its own boss: the moving Warden or stationary Archivist. Component rewards, recovery and real reflector terrain give you opportunities to revise a build between fights.

Practice provides all eleven standard components without granting run inventory. Compare equipped and draft spells in six controlled situations, follow a skippable first experiment, save named recipes, resume at a safe forge, revisit workshop discoveries and exchange recipe/challenge codes manually. The factual debrief separates resources, damage sources, reward choices and time spent fighting, crafting, paused or in settings. Optional Frost/Split and Repulse candidates live in the isolated practice lab; ordinary runs keep standard spell rules.

Keyboard/mouse and controller paths, remapping, menu focus, local controller text entry, large menu text, reduced flashing and camera-shake controls are implemented. Device feel and human readability still need playtesting.

## Start development

Open `game/project.godot` with **Godot 4.7.2**, or run `godot --path game` from this repository. See [game instructions](game/README.md), [getting started](docs/GETTING_STARTED.md), and the [test commands](docs/TESTING.md). The Bun tools check repository tooling; Godot parses and tests gameplay.

## Documentation

- [Current roadmap](docs/ROADMAP.md), [reconstructed dependency queue](docs/roadmap_queue.json), and [remaining gaps](docs/ROADMAP_GAPS.md)
- [Design](docs/GAME_DESIGN.md), [architecture](docs/ARCHITECTURE.md), and [standard spell rules](docs/SPELL_SYSTEM.md)
- [Research and design hypotheses](docs/OCTALYSIS_RESEARCH.md), [expeditions and terrain](docs/EXPEDITIONS.md), and [input journey](docs/INPUT_JOURNEY.md)
- [Situational diagnostics](docs/COMPONENT_DIAGNOSTIC.md), [practice-only experiments](docs/SPELL_EXPERIMENTS.md), and [performance protocol](docs/PERFORMANCE.md)
- [Playtests](docs/PLAYTEST.md), [UI checklist](docs/UI_PLAYTEST.md), [release gates](docs/RELEASE.md), and [implementation evidence](docs/IMPLEMENTATION_STATUS.md)
- [Contributing](CONTRIBUTING.md), [decisions](docs/DECISIONS.md), [issues](https://github.com/howard86/spell-forge/issues), and [pull requests](https://github.com/howard86/spell-forge/pulls)

The original 30-task ZIP is unavailable. The user authorized reconstruction from its available summary; only SF-001–SF-007 and SF-030 have identified descriptions. The R01–R12 queue is a new dependency grouping, not recovered SF-008–SF-029 specifications. The older sixteen-week schedule is historical planning, not a release promise. No automated check establishes fun, replay motivation or commercial demand.

## License

Original source, documentation, procedural artwork and synthesized audio use the [MIT License](LICENSE). Godot and development dependencies retain their own notices; see [provenance](game/assets/PROVENANCE.md) and in-game credits.
