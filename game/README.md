# Stage 1 Godot Foundation

Requires **Godot 4.4.1** (chosen provisional pin for the first CI workflow; change consistently when upgrading). Open `game/project.godot` in Godot and run the main scene.

Current behavior: placeholder square character moves with **WASD / arrow keys**. This is deliberately not a combat prototype.

## Local smoke check
```sh
godot --headless --path game --editor --quit
godot --path game
```

Windows export requires matching export templates:
```sh
mkdir -p build
godot --headless --path game --export-debug "Windows Desktop" ../build/Spellforge.exe
```

The associated GitHub Actions workflow is a **first-pass, unverified** CI configuration. Confirm action availability, template compatibility, import success, and Windows runtime behavior before marking [Stage 1](https://github.com/howard86/spell-forge/issues/2) complete.

## Scope
Next stage will add action-based inputs, collisions, mouse aim, casting, dodge, enemy behavior, damage and restart. The current direct key polling is intentionally temporary.

Asset licensing remains undecided; only built-in vector placeholder visuals are included.
