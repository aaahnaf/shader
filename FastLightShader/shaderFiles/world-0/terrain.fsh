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
    N = flSnapToAxis(N);

    // ---- Sun / Moon directional light + torch + ambient (shared core) ----
    float dayFactor = flRamp(0.0, 0.25, sunAngle.y);          // sun altitude
    vec3  light     = flLight(N, skyLv, blockLv, sunAngle, dayFactor, 0.0);

    // ---- Emissive detection (lava, glowstone, magma, fire...) ----
    // Max block light + bright/warm albedo => self-lift WITHOUT a bloom pass.
    float lum      = dot(albedo, vec3(0.299, 0.587, 0.114));
    float warmBias = albedo.r - albedo.b;               // filters out white blocks
    float emissive = step(0.95, blockLv) * step(0.30, lum) * step(0.05, warmBias);
    light += vec3(emissive * 0.6);                      // additive self-glow

    vec3 lit = albedo * light;

    // ---- Distance fog matched to time of day ----
    // NOTE: fog colour must be in the SAME space as the output, so we
    // tonemap+encode first, then blend raw sRGB fog over it. No banding.
    float dist    = length(viewPos);
    vec3  fogCol  = flSkyFogColor(sunAngle, dayFactor);

    vec3 outColor = flEncode(flTonemap(lit));
    outColor = flFog(outColor, dist, fogCol);

    // ---- Output ----
    gl_FragData[0] = vec4(outColor, base.a);
}
