// ============================================================
//  FastLight - lib/common.glsl   (include via /*/ */ directive)
//
//  Shared lighting core. Built for MAXIMUM speed:
//   * NO shadow maps, NO deferred buffers, NO post passes
//     -> zero extra draw calls, so FPS impact stays negligible
//   * All light data comes from vanilla vertex attributes
//     (at_tma1) which the game uploads anyway -> free
//   * Scalar-first math, cheap approximations, no dependent
//     texture reads except the single terrain atlas fetch
//   * Identical code path on OptiFine and Iris/Sodium (#version 120)
// ============================================================

#ifndef FASTLIGHT_COMMON_GLSL
#define FASTLIGHT_COMMON_GLSL

// ---------- Light colours (compile-time constants: cost nothing) ----------
const vec3 SUN_COLOR     = vec3(1.00, 0.97, 0.88);  // warm daylight
const vec3 MOON_COLOR    = vec3(0.55, 0.62, 0.85);  // cool moonlight
const vec3 TORCH_COLOR   = vec3(1.00, 0.72, 0.40);  // block-light tint
const vec3 NIGHT_AMBIENT = vec3(0.030, 0.040, 0.075);
const float GAMMA        = 2.0;                     // display gamma (sqrt = fast)

// ---------- Cheap helpers ----------
// Guarded normalize: avoids NaN on degenerate triangles (no glitches).
// Fully branchless (step/mix) -> valid & fast on every GLSL 1.20 driver.
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

// Smooth 0..1 ramp (matches GLSL smoothstep but inlined for clarity).
float flRamp(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

#endif // FASTLIGHT_COMMON_GLSL
