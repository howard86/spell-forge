# ADR 0002: Readable encounter pressure and three behavioral upgrades

Status: Implemented prototype; numeric balance remains provisional. Supersedes ADR 0001 only where explicitly described below. See [balance validation](../BALANCE_VALIDATION.md) for observed checks and limitations.

## Encounters

Six normal encounters retain totals of 4, 6, 8, 10, 12 and 14 enemies, followed by the 900-health Warden. Seeded authored templates split normal encounters into two waves. The first introduces one lane archer alone; its three pursuers are queued only after that archer dies. Later waves are queued when at most one enemy remains. A room cannot clear with unstarted waves or pending spawns. Reinforcements have a one-second visible warning and materialize only when at least 100 pixels from the player.

Lane archers predict 0.3 seconds of player movement, then lock their lane for a 0.9-second warning. Their 16-pixel half-width lane deals 22 damage; ordinary dodge and hit invulnerability still apply. The Warden warns for one second, alternating fan, 30-pixel half-width lane, and charge. Phase two changes the sequence. Recovery is 2 seconds in phase one and 1.2 in phase two. Warnings use the same endpoints and width as collision; charges check the swept segment rather than only their destination. Enemy health is unchanged.

Every clear still restores up to 15 health and all mana. Rewards now offer up to two eligible unowned components plus Restore, which heals up to 25 more health. Restore displays the actual amount, including zero at full health. Wall Charge is offered only after acquiring Bounce; Delayed Blast only after acquiring Explode. Owning the prerequisite allows acquisition; equipping it is required to use the upgrade. The editor prevents invalid dependency changes.

## Spell rules

The catalog now contains eleven components. Five unique slots, Projectile first, no recursive child triggers, and existing cast/event budgets remain unchanged. These upgrades do not introduce positional slot semantics: prerequisites may appear before or after their dependent upgrade.

| Component | Additional mana | Exact behavior |
| --- | --- | --- |
| Frost | 5 | All bolt direct hits deal 85% normal direct damage. Root direct hits refresh a one-second movement slow of 25%, capped at 10% for the boss. Children do not apply slow. Attack timers, Chain, explosion and burn damage are unaffected. Slow duration and strength do not stack. |
| Wall Charge | 4 | Requires Bounce equipped. Bolts deal 85% direct damage before their first successful reflection, then 150% after it. Each additional reflection retains the same bonus. New Split children begin uncharged. Chain, explosion and burn damage are unaffected. |
| Delayed Blast | 3 | Requires Explode equipped. Replaces the instant explosion with one fixed-position, 72-pixel-radius blast after 0.6 seconds, at 20.25 damage. It does not burn or trigger other effects. Targets may leave before detonation. |

Frost and Wall Charge direct damage factors multiply when combined. Compilation retains the original base damage for derived Chain/explosion effects. Cooldown's wording now describes a 30% shorter cast delay and its mana-efficiency trade-off.

Delayed Blast consumes the normal explosion event reservation and a once-per-cast flag. The world owns a separate queue capped at 64; full queues discard the already-reserved effect rather than refunding/retrying it. Queued blasts outlive projectile/cast cleanup, stop while paused, and clear on room/run/menu/death transitions. Newly created blasts receive the complete warning interval. Preview simulation advances the same delayed-effect code without mutating the live run.

## Deferred decisions

Optional challenge modifiers and revised slot-order inheritance are separate future experiments. This change does not rebalance Split's accepted same-target child hits. No permanent power progression, larger slot cap, or enemy-health inflation was added. Headless tests establish mechanics and reproducibility; human challenge, readability, and the 10–15-minute run target still require playtests.
