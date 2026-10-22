#version 120

// ============================================================
//  FastLight - world-1 (NETHER) terrain.fsh
//
//  No sun here -> lighting is driven by block light only, plus a
//  fixed warm "lava glow" key light so geometry keeps readable
//  face contrast instead of the flat vanilla orange mush.
//  Dense red exponential fog gives the dimension its depth back.
//  Cost: 1 texture fetch + ~40 ALU. Still zero extra passes.
// ============================================================

/*/lib/common.glsl*/

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec4 midBlock;
varying vec3 viewPos;

uniform sampler2D texture0;

void main() {
    vec4 base = texture2D(texture0, texCoord);
    if (base.a < 0.1) discard;
    vec3 albedo = base.rgb * base.rgb;

    float blockLv = clamp(lightCoord.x, 0.0, 240.0) * (1.0 / 240.0);
    // Nether sky light attribute is unreliable (often 0 or stale after
    // reloads) -> ignore it completely; torches are the only real source.

    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;
    N = flSnapToAxis(N);

    // Fixed warm key light from above (fake ambient occlusion feel):
    // faces pointing up catch more "heat glow" than side faces.
    float upFace = max(N.y, 0.0);
    vec3 key = NETHER_KEY * (0.10 + 0.18 * upFace);

    // Torch light: same boosted vanilla falloff as the overworld.
    vec3 torch = TORCH_COLOR * (blockLv * blockLv * 1.6 + blockLv * 0.45);

    vec3 light = key + torch + NETHER_AMB * (0.3 + 0.7 * blockLv);

    // Emissive blocks (lava, glowstone, fire...) self-lift, no bloom pass.
    float lum = dot(albedo, vec3(0.299, 0.587, 0.114));
    float emissive = step(0.35, lum) * step(albedo.r, albedo.g * 0.0 + albedo.r) * smoothstep(0.4, 0.8, albedo.r - albedo.b);
    light += vec3(emissive * 0.5);

    vec3 lit = albedo * light;

    // Heavy red Nether fog (shorter range than the overworld).
    float dist = length(viewPos);
    float fogAmt = clamp(1.0 - exp(-dist * 0.035), 0.0, 1.0);
    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, NETHER_FOG_C, fogAmt);

    gl_FragData[0] = vec4(outColor, base.a);
}
