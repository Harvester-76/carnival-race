# Karnaval atmosphere

## Fog profile

Edit `materials/karnaval_fog_profile.tres` in the Godot Inspector to tune the distant terrain haze. The main game and the sky preview both copy their fog settings from this resource through `KarnavalSkyController.apply_fog_profile()`.

The most useful property is **Fog Light Color**. Choose a color close to the sky near the horizon; darker or less saturated colors make the distant terrain blend in more gently. `Fog Density` controls how quickly terrain fades into that color, while `Fog Sky Affect` controls how much the fog is applied to the sky itself.

The game may change fog density during intro camera shots. The fog color still comes from the shared profile.
