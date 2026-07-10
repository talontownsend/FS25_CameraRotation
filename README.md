# Trailing Camera (Farming Simulator 25)

A trailing chase camera for vehicles — the camera lags behind through turns and then eases back
into place, the way the chase cameras in **GTA V** or **Forza Horizon** behave.

The stock FS25 vehicle camera is rigidly parented to the chassis: it yaws 1:1 with the vehicle, so
it snaps around instantly the moment the vehicle turns. This mod decouples it and springs it back,
giving a smooth, weighted follow instead.

> **Important:** the camera reacts to the vehicle's **actual heading through the world**, not to the
> steering-wheel angle. It never swings while you are stationary, and it never leans into a corner
> merely because you turned the wheel — it trails because you actually changed direction.

## Features

- Camera trails the vehicle's real heading with spring damping
- Lags into turns, eases back to centre on the straights
- Fades in with speed — no swinging while parking or pivoting in place
- Optional automatic 180° flip when reversing
- Works with the outside camera and the cab camera
- Manual mouse-look still works; trailing rides on top of wherever you pan
- Quick toggle keybind (default: numpad `.`)

## Settings

All settings live in the vanilla **Settings** menu, under **Trailing Camera**.

| Setting | What it does |
| --- | --- |
| **Enable Trailing Camera** | Master on/off |
| **Trail Outside Camera** | Apply trailing to the outside (third-person) camera |
| **Swing Amount** | How far the camera drifts out of centre during a turn |
| **Return Smoothness** | How the camera settles back — snappy vs floaty |
| **Swing Limit** | Hard cap on the maximum drift angle |
| **Flip When Reversing** | Rotate the camera 180° when driving in reverse |

## Installation

Download `FS25_CameraRotation.zip` from the [Releases](../../releases) page and drop it into your
mods folder:

```
Documents\My Games\FarmingSimulator2025\mods\
```

Then enable **Trailing Camera** in the mod list when you load a savegame.

## Compatibility

- **PC / Mac only.** This is a Lua script mod, so it will not run on consoles.
- Singleplayer and multiplayer (`multiplayer supported="true"`). Camera behaviour is client-side.
- Stores nothing in your savegame — safe to add or remove at any time.

## Localization

The settings UI is translated into all 23 languages Farming Simulator ships with.

Known limitation: the preset values inside the dropdowns (e.g. *Normal*, *Snappy*, *Floaty*) are
still hardcoded in English, even though the setting names themselves are fully localized. PRs
welcome.

## Credits & licence

This is a continuation of the **Camera Rotation** mod by **uprior**
([umbraprior/FS25_CameraRotation](https://github.com/umbraprior/FS25_CameraRotation)), which its
author archived with the note:

> I no longer have interest in continuing this mod as I no longer play FS25 frequently. Anyone is
> allowed to fork this repository and develop this mod further.

All credit for the original mod, its settings framework and its localization scaffolding goes to
uprior.

**What changed in this fork:** the camera rotation model was rewritten. The original rotated the
camera as a function of the *steering angle* — which meant it swung whenever you turned the wheel,
even at a standstill, and could not be tuned into a natural chase camera. This version instead
samples the vehicle's *world heading* every frame and applies a critically-damped spring, so the
camera trails the direction of travel and recovers smoothly. The three numeric settings were
repurposed and renamed accordingly, and a speed fade was added so low-speed manoeuvring stays still.

Licensed under the **GNU General Public License v3.0**, the same licence as the original.
See [LICENSE](LICENSE).
