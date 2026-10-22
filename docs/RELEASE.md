# Steam Demo Release Plan

**Release target:** Windows-first **free demo**, conditional on external playtest validation and Steam approvals. No public date is committed; the 16-week plan is a target.

## Release strategy
1. Prototype privately before marketing commitments.
2. Prepare an accurate Coming Soon page for the *planned full game* if a commercial project remains viable.
3. Use Steam Playtest or direct invited distribution for limited testing.
4. Release a free demo with a focused playable run and clear feedback path.
5. Decide whether to pursue a paid game based on engagement and production viability.

## Platform operations
- Create and verify Steamworks partner details (tax, bank and account requirements).
- Reserve time for Steam Direct fee, waiting periods, store review and build review.
- Create/configure appropriate store app and associated demo app.
- Prepare capsule art, screenshots, description, genre tags, and true gameplay video.
- Review platform requirements **directly in Steamworks** before selecting a date; policies and timelines can change.
- Test Steam build install/uninstall and launching outside the editor.

Official references:
- https://partner.steamgames.com/doc/gettingstarted
- https://partner.steamgames.com/doc/store/coming_soon
- https://partner.steamgames.com/doc/store/application/demos
- https://partner.steamgames.com/doc/features/playtest

## Candidate freeze and shipping checklist
- [ ] A complete start-to-victory and start-to-death path works.
- [ ] All eight MVP spell components have documented/tested semantics.
- [ ] No known P0/P1 defect or unbounded effect chain.
- [ ] Stable performance with worst permitted spell combination on target hardware.
- [ ] Readable UI, settings, pause, audio control, tutorial/help, restart.
- [ ] Fresh Windows machine validates downloaded build.
- [ ] Third-party visual/audio licenses reviewed.
- [ ] Store materials accurately represent implemented gameplay.
- [ ] Feedback/support channel and crash triage owner are established.
- [ ] Required Steam review approvals received.

## Launch-week operating plan
- Publish approved build and verify install/public store visibility.
- Monitor incoming bug reports and categorize by severity.
- Prioritize hotfixes to crashes, softlocks, progression and critical spell behavior.
- Review completion/restart behavior from appropriately collected data and voluntary feedback.
- Publish a short post-launch retrospective and decide continue/pivot/stop.

## Commercial decision criteria
A technically shipped demo is not proof of product-market fit. Consider gameplay comprehension, replay motivation, organic interest, estimated cost of a paid 1.0, and realistic scope. Do not treat wishlists or tiny test samples as guaranteed revenue.
