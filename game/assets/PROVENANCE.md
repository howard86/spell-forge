# Spellforge presentation provenance

The playable prototype uses original code-rendered artwork and synthesized audio.
No downloaded textures, sprite sheets, music recordings, samples, fonts, or other
third-party media are imported by this presentation layer.

- `game/scripts/presentation.gd`: original pixel silhouettes, wizard, five enemy
  archetypes, Runebound Warden, floating-tome Archivist, reflector cover,
  masonry floor, arcane floor markings, braziers,
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
The Archive reuses this original ruin vocabulary with reflector layouts and the
Archivist's page/tome silhouette. Cover-clipped warnings, recipe/workshop screens
and paired spell-lab previews also use engine primitives; this expansion adds no
external media. Workshop palettes change presentation only.

## License and redistribution

On 2026-10-23 the repository owner delegated the license choice. The original
source, documentation, procedural visuals and synthesized audio are released
under the repository's [MIT License](../../LICENSE), copyright 2026 Spellforge
contributors. Original media produced by the presentation/audio code is included
in that grant. Retain the copyright and permission notice when redistributing
copies or substantial portions of these materials.

The packaged game includes an identical `assets/LICENSE.txt` and displays its
full text in Credits. CI compares that copy with the repository license; packaged
Windows controls checks verify that the license is available and displayed.

Godot Engine, bundled fonts and other engine dependencies keep their own licenses.
Credits obtains the engine license, copyright inventory and dependency license
texts from the running engine binary, following the [Godot 4.7 attribution
guidance](https://docs.godotengine.org/en/4.7/about/complying_with_licenses.html).
No engine or third-party material is relicensed by the project's MIT grant.
Development-only Bun packages are not included in the game export; their upstream
licenses remain applicable when those packages are redistributed.

Inventory review found only the listed code-rendered artwork and synthesized
sound layer, plus the engine-provided default font. No purchased or downloaded
third-party media, recorded samples, external melodies or custom fonts are in the
game project. Recheck this inventory before importing future assets. The standard
license text is published by the [Open Source Initiative](https://opensource.org/license/mit).
