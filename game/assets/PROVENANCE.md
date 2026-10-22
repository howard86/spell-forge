# Spellforge presentation provenance

The playable prototype uses original code-rendered artwork and synthesized audio.
No downloaded textures, sprite sheets, music recordings, samples, fonts, or other
third-party media are imported by this presentation layer.

- `game/scripts/presentation.gd`: original pixel silhouettes, wizard, five enemy
  archetypes, Runebound Warden, masonry floor, arcane floor markings, braziers,
  projectiles, attack warnings, and impact-state colors, authored for this project.
  Godot canvas primitives render them directly; no external image asset is needed.
- `game/scripts/game_audio.gd`: original 16-second D-minor ambient arpeggio and
  six synthesized event cues (cast, hit, dodge, reward, death, victory). Mono PCM
  waveforms are generated once in memory from oscillators and deterministic noise,
  then cached and played through a bounded eight-voice pool. No recorded samples
  or quoted melodies are used. Master, music, and effects have independent controls.
- Interface text uses Godot's bundled default font through the engine; this is
  an engine-provided resource rather than a separately imported font asset.

The art direction is a single cool-stone arcane ruin biome with teal player magic,
warm hostile cues, muted floor contrast, and different silhouettes for each enemy.
Enemy bolts are diamonds; player bolts have square cores. Hazard rings include a
progress arc and central cross so warnings do not rely on hue alone.

This record documents provenance only. It does not select or grant a project
license; licensing remains the repository owner's decision. Godot engine and
bundled dependency notices remain subject to the engine distribution's notices.
