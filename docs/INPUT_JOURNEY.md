# Keyboard and controller journey

The input package is integrated into `game.gd`: controller gameplay, bounded remap capture, saved bindings, visible menu focus, nested Back, and controller text entry. Gameplay bindings remain separate from audio/accessibility settings.

## Integration

Preload `res://scripts/input_bindings.gd` as `Bindings` and
`res://scripts/menu_navigation.gd` as `Navigation`; retain one `Bindings.new()`
instance for the session. Before constructing menus, call
`bindings.install_defaults()`, then `bindings.load_bindings()`. Surface a failed
load's `bindings.notice` visibly; defaults remain available. Tests and captures
must set `bindings.path` to an isolated fixture before loading or saving. The
production default is `user://bindings.cfg`, separate from existing settings.

After constructing **every** menu, including modal submenus and settings reached
from Pause, call `Navigation.connect_focus_neighbors(content)` followed by
`Navigation.ensure_focus(content)`. Use the modal's own root while it is open.
Call again after adding/removing/hiding/disabling options; `focus_first` is
available for a deliberately fresh screen. Controls must be in the scene tree
with `FOCUS_ALL`. Tree order defines the wrapping chain; hidden ancestors,
disabled buttons, and mouse-only controls are excluded. Existing valid focus is
preserved. Focus reveals enclosing scroll containers immediately when geometry is available, then retries across three layout frames. Deferred callbacks verify the control is still valid, inside the tree and focused; zero-size pre-layout geometry is ignored. The helper owns no input callbacks. Fresh menus settle before restoring the title and focused Begin view.

Keep text editors and sliders' normal Godot input handling. Route menu Back from
`ui_cancel` in `_unhandled_input`, after focused editors have had a chance to
consume events. A focused editor must still accept cursor arrows, typing and
clipboard shortcuts; do not intercept `_input` to navigate menus. At the menu
root, `ui_cancel` closes the current submenu/modal or returns to its parent. In
combat, Escape/Start pauses; from Pause it resumes. Avoid routing a single
Escape event through both menu Back and combat Pause. Mark a handled Back or
Pause event handled and return immediately.

For controller aim, sample `Bindings.controller_aim()` during combat. A nonzero
vector selects stick aiming; retain the previous aim when it returns zero.
Mouse motion should select mouse aiming again. Existing movement/cast/dodge/
pause actions already work through `InputMap`, so they require no raw key or
button checks. The controller mapping is:

| Action | Controller default |
| --- | --- |
| Move | Left stick |
| Aim | Right stick |
| Cast | Right trigger or right shoulder |
| Dodge | South face button (Godot A) |
| Pause/resume | Start |
| Menus | Godot UI directions, accept and cancel defaults |

The settings capture UI owns the pending action, release/echo filtering, cancel,
and visible success/error feedback. Feed one captured event to
`bindings.rebind(action, event)`. On success call `save_bindings()` and refresh
labels with `Bindings.action_label(action)`; on failure display `notice` and
leave capture available. Cancel capture on Escape or `ui_cancel` before calling
`rebind`, and avoid leaving controller/keyboard capture active after Back or a
screen change. The helper does not consume a capture event; the UI must mark it
handled so it cannot also trigger gameplay or a focused button.

Rebindable actions are movement, cast, dodge, and pause. Keyboard, mouse and
controller-button remaps each replace that action's corresponding input family;
other families and analog axes remain. Movement/aim axes cannot be rebound.
Escape and Start remain protected pause exits. Escape is reserved for menu Back
and cannot be captured, and Start cannot be assigned to another action. Gameplay
conflicts are rejected rather than removing another required binding. Modified
keys conflict with the same base key because gameplay queries ignore extra
modifiers. Supported keys are printable ASCII, navigation/editing keys, F1–F12,
and keypad keys; unknown codes, modifier-only keys, echoes, motion events and
modified mouse buttons fail closed. Existing UI action mappings are never removed or rebound. The game appends A/B and D-pad menu defaults idempotently because the tested Godot runtime supplied keyboard-only UI defaults.

Reset calls `reset_defaults()` and then `save_bindings()`; show save failures.
Reset restores project keyboard/mouse defaults and controller defaults, without
resetting unrelated actions. Loading validates the complete candidate map before
committing it. A malformed/conflicting file does not partially alter bindings.
Storage is ConfigFile version 1 with primitive dictionaries, at most 21 family
entries and 16 KiB. A save failure leaves the in-memory remap active for this
session; report that it was not persisted. No per-device controller profiles or
axis calibration are provided.

## Human journey checklist

Every row is pending physical keyboard/controller verification. Synthetic tests
cover the helper behavior, not the complete integrated UI or a physical device.
Run once keyboard-only and once controller-only; use mouse only for the explicit
mouse-aim handoff check.

| Screen or transition | Required checks |
| --- | --- |
| Title/menu | Visible initial focus; directions and Tab cycle; accept opens every destination; no mouse needed |
| Expedition/challenge/starting choice | Reach every choice, read description and locked state, accept selection, Back restores parent focus |
| Continue run | Select saved run, recover valid checkpoint, Back returns without starting |
| Compendium/discoveries | Navigate entries and scroll the focused item into view; Back returns |
| Recipe library/import/export | Navigate list and save/load/delete controls; edit names/codes with arrows and typing; cancel editor then Back |
| Credits | Reach scrollable license text and Back; no focus trap |
| Settings from title | Navigate volume, shake, reduced flash, scale/readable focus and bindings; edit values and return |
| Binding capture | Remap key/mouse/button; conflict feedback; Escape/controller Back cancels; reset works; restart retains saved remaps |
| Combat | Move, aim, cast, dodge, pause with each device; neutral stick keeps aim; mouse motion retakes aim; no accidental cast from menu acceptance |
| Pause | Resume, settings and menu exit reachable; Escape/Start resumes; no combat advances while paused |
| Settings from Pause | Return to Pause, preserve run and focused control; Back/capture cancel does not also resume |
| Reward/crafting | Navigate offers, recipes, slots and diagnostics; invalid/disabled controls skipped; scroll focus visible; confirm next encounter |
| Preview | Navigate scenarios/components and play/reset controls; Back restores crafting focus |
| Victory/death/report | Reach all report sections, retry/replay/share/export/menu controls; report scrolling follows focus |
| Narrow window and increased UI scale | All destinations reachable, readable focus, text and state cues; no clipped Back control or trapped focus |
| Controller disconnect/reconnect | Keyboard fallback and Pause remain available; reconnect restores controller navigation and combat |

Shake/reduced-flash and audio controls are preserved. Large menu text increases reading text and the menu theme; dense forge-slot labels and the fixed-layout combat HUD retain their measured sizes. The main panel has bounded vertical scrolling and focus reveals nested scroll panels. White three-pixel focus borders and textual READY/cooldown indicators complement color cues. Physical readability still needs human review.

## Integrated runtime seam

`game.clear_panel()` resets `back_action` and schedules `game.finish_menu()` after the page is built. For custom pages, set `game.back_action = your_callback`; `game.button("Back …", callback)` also registers it. Call `finish_menu()` explicitly after dynamically changing available controls. It reconnects directional and Tab neighbors and restores a matching button label where possible. Back is consumed once in `_unhandled_input`; OptionButton and editor GUI handling runs first. At a reward root, Back does not choose a reward or abandon the run. Practice Back restores its saved inventory and returns to the menu.

`game.open_entry(line_edit, "seed" | "recipe" | "share")` opens a reusable local entry modal. Done commits; Cancel/Back preserves the original field and returns to the previous page. It provides digits/signs for seeds and letters, case, digits, punctuation, space, erase, clear, Done and Cancel for names/codes. Limits are 32/40/4096 characters. The first focus is Done, and recipes default to “My spell”. There is no implicit clipboard read or network operation.

Right-stick aim retains its last direction at neutral; mouse motion retakes aim. Menus and resume suppress cast/dodge until confirm and gameplay buttons are released. HUD dodge/pause hints follow the last input device and current mapping; full labels are in Settings. Capture conflicts keep capture active, Back cancels, and save errors remain visible while the current-session binding stays active.

The existing derived `bindings_path` filename ends in `.bindings.json` for compatibility with fixture isolation; its content is strictly validated primitive ConfigFile data, not JSON. Settings validate booleans and clamp numeric audio values. Playing without saving continues to disable profile writes; settings/bindings are independent preferences.

## Integrated automated evidence

Godot 4.7.2 headless, isolated checkout, final package results:

- `test_input_journey.gd`: **324 checks, 0 failures**. Actual GUI D-pad movement/accept, modal key activation, nested Back, retained stick aim/mouse handoff, controller dodge/pause, held-confirm suppression, remap save/load/conflict/cancel/reset, bounded entry/punctuation, normal/large page bounds at 960 and 1280, focused controls inside every clipping ancestor, readable shortcut widths, nested lab selector/Back visibility, pending-seed navigation/export, focus chains, settings validation, practice restore (including offline nondefault spell/inventory/challenge/terrain through modal Back and Return), report navigation, input-map restoration and fixture cleanup.
- `test_bindings.gd`: **86 checks, 0 failures**.
- `test_controls.gd`: **26 checks, 0 failures**.
- `test_ui.gd`: **301 checks, 0 failures**.
- `test_journey.gd`: **57 checks, 0 failures**.

Run the integrated test with the same command as below, replacing `test_bindings.gd` with `test_input_journey.gd`. It derives unique `user://input-journey-*` sibling fixtures and removes them; it shuts down audio and restores InputMap on completion. Restricted macOS execution cannot create the Godot user-folder fixture, causing profile startup to refuse a run. Elevated execution of these isolated fixtures is the verified workaround. No real user profile or settings are read by these tests.

Physical controllers, reconnect behavior, human keyboard-only traversal, human text/readability acceptance and tactile usability remain pending. Root rendered captures at both target sizes are recorded separately; they do not replace participant testing. Synthetic coverage is not a hardware playtest.

## Automated evidence

Run from the isolated checkout:

```sh
/private/tmp/spellforge-godot-4.7.2/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_bindings.gd --log-file /private/tmp/spellforge-roadmap-evidence/bindings.log
```

The test uses only `/private/tmp/spellforge-roadmap-evidence/bindings-test.cfg`,
snapshots/restores affected InputMap actions and deadzones, and removes its
configuration fixture. It checks defaults/idempotence, remapping and reset,
primitive round trips, conflicts and malformed/oversized/future schemas,
synthetic controller mapping/aim, hidden/disabled focus exclusion, editor arrows,
scroll reveal and safe detached/freed menus. The latest bounded package run
reported **86 checks, 0 failures** on Godot 4.7.2. The runner also emitted a macOS
certificate-store startup error; no network operation is needed by these tests.
