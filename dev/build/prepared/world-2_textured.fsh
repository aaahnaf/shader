#version 120
// --- loader-injected preamble (validation simulation) ---


// ============================================================
//  FastLight - world-2 (END) textured.fsh
//  Mobs / block entities in the End: cool pale key light +
//  warm torch term from the vanilla vertex light attribute.
//  Derivative normals are stable across frames -> no flicker.
// ============================================================


// ============================================================
//  FastLight - lib/common.glsl   (include via /*/lib/common.glsl*/)
//
//  Shared lighting core. Built for MAXIMUM speed:
//   * NO shadow maps, NO deferred buffers, NO post/composite passes
//     -> zero extra draw calls, zero extra render targets, so the FPS
//        impact stays inside the noise margin of vanilla rendering.
//   * All light data comes from vanilla vertex attributes
//     (at_tma1) which the game uploads anyway -> free bandwidth.
//   * Branchless scalar-first math, cheap approximations, exactly ONE
//     texture fetch per fragment for terrain.
//   * Identical code path on OptiFine and Iris/Sodium (#version 120).
// ============================================================

#ifndef FASTLIGHT_COMMON_GLSL
#define FASTLIGHT_COMMON_GLSL

// ---------- Light colours (compile-time constants: cost nothing) ----------
const vec3 SUN_COLOR       = vec3(1.00, 0.97, 0.88);  // warm daylight
const vec3 MOON_COLOR      = vec3(0.55, 0.62, 0.85);  // cool moonlight
const vec3 TORCH_COLOR     = vec3(1.00, 0.72, 0.40);  // block-light tint
const vec3 SKY_DAY_AMBIENT = vec3(0.22, 0.28, 0.38);  // hemisphere bounce
const vec3 NIGHT_AMBIENT   = vec3(0.030, 0.040, 0.075);

// Dimension palettes (selected by a UNIFORM branch in main(): compiled
// once, coherent across whole draws -> effectively free).
const vec3 NETHER_KEY    = vec3(0.85, 0.35, 0.22);    // lava-glow key light
const vec3 NETHER_AMB    = vec3(0.24, 0.09, 0.07);    // red ambient haze
const vec3 NETHER_FOG_C  = vec3(0.26, 0.06, 0.05);
const vec3 END_KEY       = vec3(0.75, 0.72, 0.85);    // pale end-stone key
const vec3 END_AMB       = vec3(0.10, 0.09, 0.14);
const vec3 END_FOG_C     = vec3(0.05, 0.03, 0.08);

// ---------- Cheap helpers ----------
// Guarded normalize: never NaN/Inf even on degenerate triangles (no glitches).
vec3 flSafeNormalize(vec3 v) {
    float l2 = dot(v, v);
    float ok = step(1e-8, l2);                       // 1 if normal-length
    vec3 r = v * inversesqrt(max(l2, 1e-8));         // clamped: never NaN/Inf
    return mix(vec3(0.0, 1.0, 0.0), r, ok);          // fallback +Y for degenerates
}

// Reinhard tone curve: one add + one reciprocal per channel.
vec3 flTonemap(vec3 c) {
    return c / (c + vec3(1.0));
}

// sRGB-ish encode without pow(): sqrt == gamma 2.0 exactly,
// so with GAMMA==2.0 the round-trip is algebraically clean.
vec3 flEncode(vec3 c) {
    return sqrt(clamp(c, 0.0, 1.0));
}

// x^6 by squaring (cheaper than pow on most drivers).
float flPow6(float x) {
    float x2 = x * x;
    return x2 * x2 * x2;
}

// Wrapped Lambert: keeps back faces softly lit instead of pitch black,
// which removes the harsh "vanilla banding" look at near-zero cost.
float flWrapDiffuse(float nDotL) { return nDotL * 0.75 + 0.25; }

// Smooth 0..1 ramp (same curve as smoothstep, inlined for clarity).
float flRamp(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// Snap a derivative-reconstructed plane normal to its dominant axis.
// Keeps flat cubes perfectly flat and kills derivative noise on thin or
// distant quads -> zero shimmer / zero banding glitches.
vec3 flSnapToAxis(vec3 n) {
    vec3 a = abs(n);
    if (a.x >= a.y && a.x >= a.z) return vec3(sign(n.x), 0.0, 0.0);
    else if (a.y >= a.z)          return vec3(0.0, sign(n.y), 0.0);
    return                        vec3(0.0, 0.0, sign(n.z));
}

// ---------- Core additive lighting ----------
// Returns the ADDITIVE light contribution (linear space) for a surface.
//   N        : shading normal
//   skyLv    : 0..1 sky light level (vanilla vertex attribute - free)
//   blockLv  : 0..1 block light level (vanilla vertex attribute - free)
//   sunDir   : world-space direction toward sun/moon (normalized)
//   dayFactor: 0..1 sun altitude factor (caller computes once per frame)
//   heldLv   : 0..1 handheld torch glow (0 when not holding a light)
vec3 flLight(vec3 N, float skyLv, float blockLv,
             vec3 sunDir, float dayFactor, float heldLv) {
    // Sun / Moon directional light (gated by sky light -> caves stay dark)
    vec3 Lsun    = sunDir.y > 0.0 ? sunDir : -sunDir;   // moon at night
    vec3 sunCol  = mix(MOON_COLOR, SUN_COLOR, dayFactor);
    float diff   = flWrapDiffuse(max(dot(N, Lsun), 0.0));
    vec3 sunTerm = sunCol * diff * skyLv * mix(0.35, 1.0, dayFactor);

    // Block light: the vanilla value already encodes distance falloff -
    // reuse it, don't recompute. Quadratic boost = hot core + soft edge.
    float bl = min(blockLv + heldLv * 0.35, 1.0);
    vec3 torchTerm = TORCH_COLOR * (bl * bl * 1.15 + bl * 0.25);

    // Ambient sky bounce (up-facing faces get more)
    float upFace  = max(N.y, 0.0);
    vec3 ambient  = mix(NIGHT_AMBIENT,
                        SKY_DAY_AMBIENT * (0.25 + 0.75 * skyLv),
                        0.5 + 0.5 * upFace) * (0.35 + 0.65 * skyLv);

    return sunTerm + torchTerm + ambient;
}

// ---------- Fog ----------
// Blend in DISPLAY space (after tonemap+encode) so fog colour matches the
// sky/horizon exactly and never bands. Exponential falloff, no table needed.
vec3 flFog(vec3 displayColor, float dist, vec3 fogCol) {
    float fogAmt = clamp(1.0 - exp(-dist * 0.0075), 0.0, 1.0);
    return mix(displayColor, fogCol, fogAmt);
}

// Display-space overworld fog colour matched to time of day.
vec3 flSkyFogColor(vec3 sunDir, float dayFactor) {
    float duskAmt = clamp(1.0 - abs(sunDir.y) * 3.0, 0.0, 1.0) * dayFactor;
    return mix(vec3(0.02, 0.03, 0.06),                    // night
               mix(vec3(0.62, 0.72, 0.88),                // day
                   vec3(0.95, 0.55, 0.30), duskAmt),      // sunset/sunrise
               dayFactor);
}

#endif // FASTLIGHT_COMMON_GLSL



varying vec2 texCoord;
varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;
varying vec2 lightAttr;    // x = block*15, y = sky*15 (0..240)
varying vec3 viewPos;

uniform sampler2D texture0;

void main() {
    vec4 base = texture2D(texture0, texCoord);
    if (base.a < 0.1) discard;

    float bakedLum = max(dot(vertexColor.rgb, vec3(0.299, 0.587, 0.114)), 1e-3);
    vec3 albedo = min(base.rgb * base.rgb * (vertexColor.rgb / bakedLum), vec3(1.0));

    float blockLv = clamp(lightAttr.x, 0.0, 240.0) * (1.0 / 240.0);
    float skyLv   = clamp(lightAttr.y, 0.0, 240.0) * (1.0 / 240.0);

    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;

    float upFace = max(N.y, 0.0);
    vec3 light = END_KEY * (0.14 + 0.22 * upFace) * (0.45 + 0.55 * skyLv)
               + TORCH_COLOR * (blockLv * blockLv * 1.4 + blockLv * 0.35)
               + END_AMB * (0.35 + 0.65 * max(skyLv, blockLv));

    light *= mix(1.0, bakedLum * 2.0, 0.35);          // keep vanilla tint cues
    vec3 lit = albedo * light;

    float dist = length(viewPos);
    float fogAmt = clamp(1.0 - exp(-dist * 0.012), 0.0, 1.0);
    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, END_FOG_C, fogAmt);

    gl_FragData[0] = vec4(outColor, base.a * vertexColor.a);
}
