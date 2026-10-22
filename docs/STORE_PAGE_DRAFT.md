# Spellforge Store Copy and Capture Brief

**Internal draft — pending owner approval, captured-build verification, and Steam review.** This document prepares material for issues #6 and #11; it does not establish store readiness or authorize publication. Copy describes the implemented demo scope. It is not a promise of additional full-game content. No screenshots or video are attached to this document.

## Short description

Build your spell, then fight your way through six arena encounters and the Runebound Warden. Combine eight spell components in up to five ordered slots, choose rewards between fights, and dodge through a top-down arena gauntlet with keyboard and mouse.

## Long description

### Forge a spell between fights

Start with a projectile and shape one active spell as you advance. Choose component rewards and arrange up to five slots in the spell editor. Add Fire, Pierce, Split, Bounce, Chain, Explode, or Cooldown to change how your attacks behave. Check the mana cost and cast delay before returning to combat.

### Survive the runic trials

Move, aim, cast, and dodge through six encounters in one runic arena biome. Pursuers close the distance, Archers fire from range, Swarms rush you, Bulwarks resist frontal attacks, and Channelers threaten your position with area hazards. Survive the trials to face the Runebound Warden and its second combat phase.

### Try another approach

Review your result and retry the same seed, or begin a new run. Seeds repeat encounter and reward selections so you can try different choices along a familiar route.

The demo includes one wizard, one active spell, eight components, a five-slot spell editor, five regular enemy roles, and one boss. Play with keyboard and mouse. Pause when needed and adjust master, music, and effects volume, camera shake, and reduced-flash settings.

## Gameplay capture shot list

Capture the actual candidate build with its normal rendering, interface, sound, and gameplay. Record revision, artifact, seed, resolution, settings, and raw capture filename for every selected shot. Select gameplay with visible cause and effect. Do not composite enemies, fabricate UI, accelerate footage without labeling it, or use debug-unlocked content to imply normal progression. If an internal staged capture is useful for review, label it as such and keep it separate from public candidates.

| Shot | Implemented feature to show | Capture direction | Evidence / selection status |
| --- | --- | --- | --- |
| S01: Arena combat | Movement, aiming, casting and dodge | Show the wizard firing while avoiding a visible enemy warning; retain health, mana and trial HUD. | Pending actual capture and review. |
| S02: Spell crafting | Reward choice and ordered editor | Capture an intermission with naturally earned components, slot order, mana cost and cast delay readable. Do not imply all eight components fit at once. | Pending actual capture and review. |
| S03: Spell interaction | Pierce, split, chain, burn or explosion | Capture a legally equipped spell hitting enemies; choose a frame where an effect is legible and use video for behavior that cannot be established by a still. | Pending actual capture and review. |
| S04: Enemy variety | Five normal roles across the run | Select actual encounters showing different roles and their telegraphs. Use separate real shots if they are not all present together. | Pending actual capture and review. |
| S05: Warden | Boss projectiles, area hazards and phase change | Capture a reached boss fight, then a second-phase moment below half health. Keep the wizard and dangerous area readable. | Pending actual capture and review. |
| S06: Result and retry | Victory/death summary and same-seed retry | Record the real result, visible seed, and retry transition. Keep this as supporting footage if it is less visually useful than combat. | Pending actual capture and review. |

Suggested gameplay video sequence: open with a readable combat moment, show a reward choice and spell edit, return to combat to show the resulting behavior, introduce a different enemy pattern, and finish with Warden gameplay. Use captured game audio. Any editorial text should describe the visible feature; do not add release dates, reception quotes, performance claims, or availability calls to action until verified and approved. Duration and delivery format remain editorial decisions after footage review.

## Claim-to-source review

These are source checks, not interactive acceptance results. Recheck them against the captured revision before selecting public copy.

| Draft claim | Implementation basis |
| --- | --- |
| Six encounters followed by Warden | `game/scripts/run_director.gd`: `encounter()` selects boss at index 6; `game/scripts/game.gd`: `encounter_clear()` and `apply_reward()` advance the run. |
| Eight components, maximum five slots | `game/scripts/spell_engine.gd`: `catalog()`, `MAX_SLOTS`, and `compile()`. |
| Rewards, editor and costs | `game/scripts/run_director.gd`: `rewards()`; `game/scripts/game.gd`: `show_reward()` and `apply_reward()`. |
| Five enemy roles and Warden phase | `game/scripts/game.gd`: `spawn_enemy()`, `update_enemies()` and `enemy_attack()`; boss phase changes below half health. |
| Keyboard/mouse, pause and settings | `game/scripts/game.gd`: menu controls, input handlers, `toggle_pause()` and `show_settings()`. |
| Same-seed retry | `game/scripts/game.gd`: `finish_run()`; seeded encounter/reward selection in `run_director.gd`. This does not promise identical outcomes from different player inputs. |
| One biome | One arena presentation used by `game/scripts/game.gd`: `_draw()` with three layout selections from `run_director.gd`; consistent with MVP scope in `GAME_DESIGN.md`. |

## Fields requiring owner or release evidence

- Confirm final product/demo display names, developer/publisher attribution, brand rights, and whether this copy belongs on a demo page or a full-game page. A full-game page needs an owner-approved scope beyond this demo copy.
- Original source, documentation, artwork and audio use the MIT License. Preserve the project and engine/dependency notices; review any new imported assets before publication. See [provenance](../game/assets/PROVENANCE.md).
- Supply approved capsule/key art and select genuine screenshots/video from the candidate build. Track filenames, rights review, and captured revision; this document supplies no finished media.
- Confirm supported interface languages, measured Windows system requirements, supported OS versions, and any accessibility/store feature claims after testing.
- Choose accurate genres/tags, content disclosures, contact/support route, and privacy wording based on the final build and owner decisions.
- Complete Steamworks account and app setup, demo association, current platform requirements review, and necessary approvals through the authorized owner process. Platform fields and dates remain unset here.

Use [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md), [PLAYTEST.md](PLAYTEST.md), and [RELEASE.md](RELEASE.md) for acceptance evidence. Run duration, blind-player success, performance targets, platform approval, and public availability remain outside the claims in this draft.
