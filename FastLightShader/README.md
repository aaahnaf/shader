# FastLight Shader

Ultra-optimized lighting shader for **Minecraft Java Edition**, built for both
**OptiFine** and **Sodium + Iris**.

## The promise: effectively zero FPS loss
FastLight achieves its look **without** the three things that make shaders
expensive:

| Costly feature          | FastLight's answer                                  |
|-------------------------|-----------------------------------------------------|
| Shadow maps             | None. Directional sun/moon shading is analytic, driven by the vanilla sky-light vertex attribute. No extra geometry pass, no depth textures. |
| Post-processing passes  | None. Tone mapping + fog happen inside each fragment program. No composite/, no render targets. |
| Extra buffers / MRT     | None. Single `gl_FragData[0]` write per program.    |

Per-pixel cost: **1 texture fetch + ~45 ALU ops** for terrain/entities,
**0 texture fetches** for water. That is why frame time barely moves.

## What you get
* Day/night cycle: warm sunlight by day, cool moonlight at night, sunset-tinted fog
* Torch / block light with warm tint and boosted falloff (hot core, soft edge)
* Emissive self-glow for lava/glowstone/fire — *without* a bloom pass
* Analytic water waves: normal perturbation only (geometry never moves → no popping / z-fighting)
* Sun glitter specular on wave crests
* Dimension-specific palettes: Overworld (`world-0`), Nether (`world-1`, red fog + lava key light), The End (`world-2`, pale key + purple fog)
* Entities & block entities lit consistently with terrain
* Distance fog matched to the sky colour in display space (no banding)

## Install
1. Zip the **contents** of this folder (so `shaders.properties` sits at the ZIP root).
2. Put the ZIP into your `.minecraft/shaderpacks/` folder.
3. OptiFine: Video Settings → Shaders → select FastLight.
   Iris: Video Settings → Shader Packs → select FastLight.

Works as a plain folder too (Iris ≥1.6 supports unpacked packs; OptiFine needs the ZIP).

## Requirements
* Minecraft 1.16.5 – 1.21.x with OptiFine H1+ **or** Sodium + Iris 1.x
* OpenGL 2.1+ GPU (shaders are `#version 120` — maximum compatibility path)

## Why there are no options/sliders
Every user-facing toggle multiplies driver edge cases. FastLight ships one
code path per stage, identical on both loaders, which is what keeps it
glitch-free. Nothing to mis-configure.

## Development / validation
The repo includes an offline test harness (not part of the pack):
* `dev/validate/prepare.py` — resolves `/*/...*/` includes and injects loader uniforms
* `dev/build/run_validation.sh` — compiles every shader with a real GLSL 1.20 front-end (glslangValidator)
* `dev/validate/check_structure.py` — verifies pack layout, varying vsh↔fsh contracts, attribute rules (e.g. water pass must not sample an atlas), and `shaders.properties` syntax
