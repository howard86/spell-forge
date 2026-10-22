# Spellforge — MVP Game Design Document

**Status:** Proposal, subject to prototype validation. **Audience:** Developer, testers, collaborators.

## Product thesis

Spellforge is a real-time, top-down pixel-art roguelite in which players build a single active spell from ordered modular components. The differentiator is **behavioral spell composition**: every component should change tactics, not just increase damage.

### Player experience pillars
1. **Experimentation:** Every run offers interesting spell interactions.
2. **Readability:** Powerful effects remain understandable on screen.
3. **Short runs:** Aim for 10–15 minutes, restart quickly after death.
4. **Meaningful trade-offs:** Power competes with mana cost, cooldown, positioning, and safety.

## MVP scope

| Area | Scope |
| --- | --- |
| Platform | Windows PC; keyboard + mouse |
| Core play | Move, aim, dodge, cast; combat in discrete arenas |
| Run | Six encounters followed by one boss |
| Player | One wizard, one active spell |
| Spell crafting | Ordered-slot editor; eight components |
| Enemies | Five normal archetypes; one boss |
| Level | One visual biome; small curated arena pool with randomized sequences |
| Progression | Between-encounter component rewards; no permanent power tree |
| Meta | Menu, settings, run summary, restart |
| Run length | Target 10–15 minutes; to be verified |

### Excluded from MVP
Multiplayer, controller support, procedural open-world layouts, skill trees, online leaderboards, achievements, multiple characters/biomes, full graph-based spell programming, large narrative campaign, and live services.

## Core gameplay loop
1. Start a seeded run with a basic projectile spell.
2. Survive an arena against telegraphed enemy patterns.
3. Choose one offered component/reward.
4. Edit the ordered spell configuration between encounters.
5. Balance damage/control against mana consumption, cooldown, and reliability.
6. Defeat the boss or die, review results, and retry with new choices.

**Core mechanic test:** Can an unfamiliar player make two tactically different spells and explain when each is useful?

## Initial combat mechanics
- Eight-direction movement with mouse aim, dodge with a short cooldown, and cast with left mouse button.
- Enemy attacks use visible warnings and readable hit confirmation.
- Health reaches zero => run ends; no mid-run revival for MVP.
- Dodge grants a short, tuned defensive window; exact milliseconds are balance parameters, not promises.
- Pause and modify spell only during safe reward/intermission scenes.
- A limited resource model (mana and regeneration) discourages indiscriminate maximum-power casting.

## Enemy and encounter roster (proposed)
1. **Pursuer:** Melee chaser; pressures movement.
2. **Archer:** Slow telegraphed ranged projectiles.
3. **Bulwark:** High frontal durability; encourages positioning.
4. **Swarm:** Fragile, numerous; rewards AoE.
5. **Channeler:** Wind-up area hazard; rewards interrupts or speed.
6. **Boss — Runebound Warden:** Multiple clearly telegraphed attacks and at least one phase transition.

These are gameplay roles, not committed art or lore.

## Content design constraints
- Curated reusable arena layouts, with randomized enemy/reward combinations.
- Every encounter must have sufficient safe space and a survivable pattern.
- Random selections use a seed for reproducibility.
- New spell rewards should offer a genuine decision, not strictly dominated choices.
- Avoid requirements that force a specific component to win.

## UX and accessibility baseline
- Clear tooltips describing component effects, costs, and incompatibilities.
- Distinguishable projectile/hazard silhouettes; do not depend on color alone.
- Adjustable master/music/SFX volume, camera shake, and flashing effect intensity if implemented.
- Readable pixel UI at intended display sizes; keyboard/mouse help in-game.
- Fast restart and pause accessible without a tutorial.

## MVP success signals (hypotheses)
- At least 10 mechanically distinct *viable* spell combinations.
- In a small external playtest, aim for >=80% of testers to build spells unaided and >=60% to voluntarily replay.
- Treat small-sample figures as directional usability evidence, not market conversion forecasts.

## Open design decisions
- Are duplicate modifiers allowed? Default recommendation: no, until balancing supports them.
- Does Split fire on impact, expiry, or both? Document exact behavior before code.
- How many component slots unlock per run? Start with a fixed small cap.
- How is mana restored, and can a high-cost spell softlock a run?
- Does Pierce trigger Explode on every contact? Explicitly constrain proc semantics.
