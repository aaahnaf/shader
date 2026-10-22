#version 120

// ============================================================
//  FastLight - terrain.fsh   (solid blocks, cutouts, plants)
//
//  Complete lighting in ONE pass, ZERO extra buffers:
//   * Sky light   -> analytic directional sun/moon shading
//   * Block light -> warm point-light term from vanilla value
//   * Emissive    -> glow boost for lava/glowstone (no bloom pass!)
//   * Fog         -> exponential distance fog matched to sky
//  Per-pixel cost: 1 texture fetch + ~45 ALU. The only branch is
//  the standard alpha discard. This is why FPS stays where it is.
// ============================================================

/*/lib/common.glsl*/

varying vec2 texCoord;
varying vec2 lightCoord;   // x = block*15, y = sky*15  (0..240)
varying vec4 midBlock;     // xyz = player-relative block centre (w unused)
varying vec3 viewPos;      // fragment position, view space (camera at origin)

uniform sampler2D texture0; // terrain atlas
uniform vec3 sunAngle;      // world-space direction TOWARD the sun, normalized
                            // (y > 0 : day, y < 0 : night — Iris & OptiFine agree)

void main() {
    // ---- Albedo (single texture fetch — the only memory read we do) ----
    vec4 base = texture2D(texture0, texCoord);
    if (base.a < 0.1) discard;                       // cutout leaves/grass
    vec3 albedo = base.rgb * base.rgb;               // sRGB -> linear (gamma 2)

    // ---- Vanilla light levels, already baked per-vertex by the game ----
    float blockLv = clamp(lightCoord.x, 0.0, 240.0) * (1.0 / 240.0);
    float skyLv   = clamp(lightCoord.y, 0.0, 240.0) * (1.0 / 240.0);

    // ---- Face normal, reconstructed exactly (no normal map needed) ----
    // Screen-space derivatives give the true plane of every quad.
    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;

    // Snap to dominant axis: keeps flat cubes perfectly flat and kills
    // any derivative noise on thin/distant quads -> zero shimmer glitches.
    vec3 aN = abs(N);
    if (aN.x >= aN.y && aN.x >= aN.z)      N = vec3(sign(N.x), 0.0, 0.0);
    else if (aN.y >= aN.z)                 N = vec3(0.0, sign(N.y), 0.0);
    else                                   N = vec3(0.0, 0.0, sign(N.z));

    // ---- Sun / Moon directional light ----
    float dayFactor = flRamp(0.0, 0.25, sunAngle.y);            // sun altitude
    vec3  Lsun      = sunAngle.y > 0.0 ? sunAngle : -sunAngle;  // moon at night
    vec3  sunCol    = mix(MOON_COLOR, SUN_COLOR, dayFactor);
    float nDotL     = max(dot(N, Lsun), 0.0);
    float diff      = flWrapDiffuse(nDotL);

    // skyLv gates it so caves/roofed areas stay properly dark.
    vec3 sunTerm = sunCol * diff * skyLv * mix(0.35, 1.0, dayFactor);

    // ---- Block light (torch/furnace/lava...) ----
    // The vanilla value already encodes distance falloff — reuse it,
    // don't recompute. Quadratic boost gives a hot core + soft edge.
    vec3 torchTerm = TORCH_COLOR * (blockLv * blockLv * 1.15 + blockLv * 0.25);

    // ---- Ambient sky bounce (up-facing faces get more) ----
    float upFace   = max(N.y, 0.0);
    vec3  ambient  = mix(NIGHT_AMBIENT,
                         vec3(0.22, 0.28, 0.38) * (0.25 + 0.75 * skyLv),
                         0.5 + 0.5 * upFace) * (0.35 + 0.65 * skyLv);

    // ---- Emissive detection (lava, glowstone, magma, fire...) ----
    // Max block light + bright/warm albedo => boost without any bloom pass.
    float lum      = dot(albedo, vec3(0.299, 0.587, 0.114));
    float warmBias = albedo.r - albedo.b;               // filters out white blocks
    float emissive = step(0.95, blockLv) * step(0.30, lum) * step(0.05, warmBias);
    vec3  emissiveTerm = albedo * emissive * 0.6;

    // ---- Combine ----
    vec3 lit = albedo * (sunTerm + torchTerm + ambient) + emissiveTerm;

    // ---- Distance fog matched to time of day ----
    // NOTE: fog colour must be in the SAME space as the output, so we
    // tonemap+encode first, then blend raw sRGB fog over it. No banding.
    float dist    = length(viewPos);
    float fogAmt  = clamp(1.0 - exp(-dist * 0.0075), 0.0, 1.0);
    float duskAmt = clamp(1.0 - abs(sunAngle.y) * 3.0, 0.0, 1.0) * dayFactor;
    vec3 fogCol = mix(vec3(0.02, 0.03, 0.06),                        // night
                      mix(vec3(0.62, 0.72, 0.88),                    // day
                          vec3(0.95, 0.55, 0.30), duskAmt),          // sunset
                      dayFactor);

    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, fogCol, fogAmt);

    // ---- Output ----
    gl_FragData[0] = vec4(outColor, base.a);
}
