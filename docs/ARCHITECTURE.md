# Architecture and Engineering Guidelines

**Stack:** Godot 4.7.2 + GDScript, Git/GitHub. The local implementation uses original code-rendered pixel art and synthesized audio. See [asset provenance](../game/assets/PROVENANCE.md) and [implementation status](IMPLEMENTATION_STATUS.md).

## Guiding constraints
- Prioritize iteration speed over abstraction.
- Prefer data-driven enemy and spell definitions.
- Keep deterministic game rules distinct from visuals, UI, and audio.
- Instrument and test high-risk combinatorial spell behaviors.
- Build Windows first; avoid unsupported multi-platform promises.

## Proposed module boundaries
- **PlayerController:** Input, movement, dodge, action requests.
- **CombatWorld:** Physics contacts, health, status conditions, damage application.
- **SpellDefinition / Compiler:** Validate component chains and derive immutable cast settings.
- **SpellRuntime:** Bounded event dispatch, spawn lifecycle, trigger processing.
- **EnemyAI:** Telegraph and simple state-machine behavior.
- **RunDirector:** Seed, encounter ordering, rewards, victory/death, run stats.
- **Presentation:** HUD, spell editor, VFX, audio, menus.

Do not tightly couple the UI editor to projectile nodes; the editor emits validated data, and the runtime interprets it.

## Candidate repository layout
```text
README.md
docs/
  GAME_DESIGN.md
  SPELL_SYSTEM.md
  ARCHITECTURE.md
  ROADMAP.md
  TESTING.md
  RELEASE.md
  CONTRIBUTING.md
  decisions/
game/                 # Godot project; created in Stage 1
  project.godot
  scenes/
  scripts/
  resources/
  assets/
tests/                # If test tooling supports an external suite
```
This tree is a **target**, not a claim these directories already exist.

## Architecture decision records
For material architectural choices add `docs/decisions/NNNN-title.md`: Context, Decision, Alternatives, Consequences, Status. First suggested ADR: Godot/GDScript vs alternatives.

## Development quality bar
- Seedable and replayable encounter generation.
- Clear component ownership, stable interfaces, minimal autoload/singleton usage.
- Avoid brittle scene-node path dependencies between unrelated systems.
- Inspect frame-time, collision processing, and active projectile counts before optimizing.
- Asset imports and CI builds should remain reproducible.
- No secrets, paid source artwork without redistribution rights, or platform credentials in git.
