# models/

Place imported 3D assets here (`.glb` / `.gltf` preferred).

Suggested layout:

```
models/
  characters/farmer.glb
  animals/sheep.glb
  props/fence_post.glb, hay_bale.glb, rock_01.glb
  plants/tree_oak.glb, crop_turnip_stage0..3.glb
```

Import tips (Godot):
- Enable **Create Collisions** only when needed; prefer hand-authored CollisionShapes on the gameplay scene.
- For Mixamo humans: rename the root, bake the animation, set loop on idle/walk/run, and map them in `AnimatedModelVisual`.
- Units: 1 unit = 1 meter. Scale the model so a human is ~1.7–1.8 m tall.
