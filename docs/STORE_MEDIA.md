# Internal gameplay media review

These are genuine game renders from an automated normal-combat run, not approved Steam materials or human playtest evidence. Gameplay source: `ab5a8f3d82c9875790ec0f4e3b057660bda3ca42`; seed 4242; Godot 4.4.1; 1280×720; OpenGL Compatibility on Apple M4 Pro. Original project material uses the MIT License; dependency notices remain in Credits.

## Review stills

The capture driver used legal rewards and default health, damage, mana, rosters and collision. It aimed and moved automatically. It did not unlock content, inject enemies or composite the interface. The stored [capture record](media/review/capture-record.json) identifies the source and PNG hashes.

| Still | Actual event | Limitation |
| --- | --- | --- |
| [Combat](media/review/combat.png) | Second trial with earned Fire modifier, player and hostile projectiles | A still cannot establish attack timing or game feel. |
| [Earned spell edit](media/review/editor.png) | First cleared trial, selected offered reward, normal editor and costs | Script chose the reward; no unaided comprehension claim. |
| [Warden second phase](media/review/boss.png) | Warden second phase after six encounters and legal rewards | A still cannot establish attack timing. |
| [Victory](media/review/victory.png) | Defeated Warden, result and retry UI | Automated victory is not player acceptance. |

## Reproduce the video

Use the matching Godot 4.4.1 executable in place of `godot`. Run from the repository root on a machine with graphical rendering and FFmpeg:

```sh
mkdir -p build/media
godot --path game --script res://tests/probe_playthrough.gd \
  --write-movie "$PWD/build/media/Spellforge-review.avi" \
  --fixed-fps 60 --disable-vsync -- --capture
ffmpeg -i build/media/Spellforge-review.avi \
  -c:v libx264 -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart \
  build/media/Spellforge-review.mp4
```

Capture mode follows the same patrol and reward policy as the [pacing probe](PACING_PROBE.md), renders every simulation step, holds the menu for two seconds, holds each reward-choice/editor screen for two seconds each, and holds the result for three seconds. The complete recording is about 2 minutes 29 seconds at 60 frames per second with game audio. Combat plays at one simulated second per video second; the capture machine may write it faster than real time. It is not a real-time performance measurement. No speed-up, cuts, added effects, voice-over, or replacement soundtrack are applied to the complete review video.

Generated AVI/MP4 files and recording logs stay under ignored `build/media/`; they are review artifacts, not source assets. The video includes normal progression from a basic projectile through the boss and victory. The 119.48-second combat result agrees with the default probe. See the local media manifest for exact duration, dimensions, stream information, checksums and source revision.

## Selection gate

Review readability, audio, framing, claims and captured revision before using any still or video publicly. Final Steam-specific dimensions, capsule/key art, editorial clip selection, storefront approval and publication remain pending. The automated capture must not be presented as an independent human playtest. Keep the 10–15-minute pacing target and blind usability requirements open.
