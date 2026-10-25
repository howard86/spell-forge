# Spellforge — Current Game Design

**Status:** Integrated local demo candidate, subject to human validation. This describes implemented scope; desired comprehension, balance, pacing and replay outcomes remain hypotheses.

## Product thesis

Build one active spell from ordered components, observe its behavior, revise an experiment and keep useful designs. Creative experimentation, mastery and ownership guide the reconstructed direction. [Octalysis research](OCTALYSIS_RESEARCH.md) supplies questions and evidence boundaries, not a numerical fun score.

## Implemented scope

| Area | Current behavior |
| --- | --- |
| Platform/input | Windows-first target; Godot 4.7.2; keyboard/mouse and controller paths with remapping and menu text entry. Physical-device and graphical Windows acceptance remain open. |
| Player | One wizard; movement, aim, casting, dodge, mana regeneration and one active spell. |
| Runs | Choose Forge/Warden or Archive/Archivist; each is six staged trials plus one boss. |
| Starting setup | Ember: Projectile + Fire; Frost: Projectile + Frost. Standard five slots or optional four-slot challenge. |
| Standard components | Projectile, Fire, Pierce, Split, Bounce, Chain, Explode, Cooldown, Frost, Wall Charge and Delayed Blast. |
| Threats | Pursuer, Archer, Lane Archer, Bulwark, Swarm and Channeler; moving Warden and stationary Archivist bosses. |
| Terrain | Open floor or authored reflector cover with shared movement/projectile/visibility rules; route choices have no stat/reward bonus. |
| Experimentation | Ordered forge, reward inspection, six paired-preview scenarios, unrestricted standard practice and a skippable first experiment. |
| Persistence | Recoverable local profile, named recipe grimoire, safe-forge resume, component discoveries, milestone lore and cosmetic workshop palette. |
| Sharing/debrief | Manual versioned recipe/challenge codes; factual run report with bounded observations and retained aggregates. |
| Accessibility | Scrollable focused menus, nested Back, controller text entry, large menu text, audio controls, reduced flashing and optional camera shake. |

Menu-configured starters differ from legacy direct `start_run(seed)` calls, which retain the projectile-only Forge/open baseline for compatibility. The default engine still permits five components; the four-slot rule is a selected run constraint. Practice supplies all components temporarily and cannot unlock run ownership. No permanent combat-stat tree, multiplayer, account service, online leaderboard or full graph-based programming is implemented.

## Player loop

1. Choose expedition, starter, cap and seed, or resume a saved safe forge.
2. Fight warned waves using movement, cover, casting and dodge.
3. Choose a component or recovery; inspect an offered component without committing it.
4. Compare equipped and draft spells in the same labeled fixture, edit slots, or revisit a named recipe.
5. Select the next Forge route, continue, or suspend at the forge.
6. Defeat the expedition's boss or die, inspect factual results, and choose whether to retry or try another experiment.

The Forge Warden moves and alternates fan/sweep/charge attacks. Archive uses reflector rooms and a stationary Archivist with fixed-gap ring bursts, delayed ground marks and a second phase. Cover has real collision and line-of-sight consequences. [EXPEDITIONS.md](EXPEDITIONS.md) records attack timing and geometry; no component is intended as a mandatory win key.

## Learning and ownership

The first experiment asks the player to choose, predict, test and revise a Fire change. Practice offers all standard components on empty floor, while normal recipes can only equip owned components within the selected cap. Previews observe one actual cast for two seconds with explicit assumptions; their damage/kill output does not rank overall effectiveness or sustained DPS. See [diagnostics](COMPONENT_DIAGNOSTIC.md).

Discoveries record component ownership after a cleared trial/reward or completed run, rather than proving tactical understanding. Milestones record first clear, Forge victory, Archive victory and four-slot victory. Workshop palettes change accent color only. Recipes persist an authored design, and portable challenges repeat the starting setup rather than all later route/reward decisions. The debrief suggests a next experiment without guessing death causes or enjoyment.

## Optional experiments

The isolated Practice lab contains Frost-before-Split child slow, Split children excluding the parent's target, and a virtual-slot Repulse push candidate. They are implemented comparisons and remain unaccepted balance changes. Ordinary catalog/rules, profiles and share codes are unchanged. Any additional normal enemy remains an unimplemented optional candidate. See [SPELL_EXPERIMENTS.md](SPELL_EXPERIMENTS.md) for exact conditional rules and human acceptance work.

## Acceptance questions

Can an unfamiliar player predict one changed slot, explain the observation, deliberately revisit a saved recipe and identify a useful next experiment after failure? Can players navigate each supported journey without assistance and describe the difference between the expeditions and terrain choices? Do they voluntarily replay, and why do they continue or stop?

The 10–15-minute run target, ten situationally viable builds and comprehension/replay thresholds remain design hypotheses. Automated full-run pilots, test counts and exports do not establish them. Use [PLAYTEST.md](PLAYTEST.md), [INPUT_JOURNEY.md](INPUT_JOURNEY.md) and [PERFORMANCE.md](PERFORMANCE.md) to collect the missing human/hardware evidence. Final-head correctness, rendered capture, downloaded Windows behavior and Steam approvals are distinct [release gates](RELEASE.md).

The [roadmap](ROADMAP.md) and [R01–R12 queue](roadmap_queue.json) are user-authorized reconstructions. The original ZIP is unavailable; detailed original SF-008–SF-029 requirements remain unknown in [ROADMAP_GAPS.md](ROADMAP_GAPS.md).
