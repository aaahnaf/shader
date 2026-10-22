#version 120

// ============================================================
//  FastLight - world-2 (END) terrain.fsh
//
//  The End has no sun cycle: sky light is a flat, cold ambient.
//  Lighting = pale directional key (fake "end sky" bounce) +
//  vanilla block light for torches/end rods + heavy purple fog.
//  Cost: 1 texture fetch + ~40 ALU. Still zero extra passes.
// ============================================================

/*/lib/common.glsl*/

varying vec2 texCoord;
varying vec2 lightCoord;   // x = block*15, y = sky*15  (0..240)
varying vec4 midBlock;
varying vec3 viewPos;      // fragment position, view space

uniform sampler2D texture0;

void main() {
    vec4 base = texture2D(texture0, texCoord);
    if (base.a < 0.1) discard;
    vec3 albedo = base.rgb * base.rgb;               // sRGB -> linear (gamma 2)

    float blockLv = clamp(lightCoord.x, 0.0, 240.0) * (1.0 / 240.0);
    // End sky light is constant 15 everywhere -> treat as fixed ambient,
    // but still read it so dark areas inside obsidian boxes behave right.
    float skyLv   = clamp(lightCoord.y, 0.0, 240.0) * (1.0 / 240.0);

    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;
    N = flSnapToAxis(N);

    // Fixed cool key light from above: end-stone keeps face contrast
    // instead of the flat grey vanilla look. Up-facing faces catch more.
    float upFace = max(N.y, 0.0);
    vec3 key = END_KEY * (0.14 + 0.22 * upFace) * (0.45 + 0.55 * skyLv);

    // End rods / shulker boxes / torches: same warm boost as overworld.
    vec3 torch = TORCH_COLOR * (blockLv * blockLv * 1.4 + blockLv * 0.35);

    vec3 light = key + torch + END_AMB * (0.35 + 0.65 * max(skyLv, blockLv));

    // Emissive self-lift (no bloom pass): bright + cool-white core blocks.
    float lum = dot(albedo, vec3(0.299, 0.587, 0.114));
    float emissive = step(0.95, blockLv) * step(0.35, lum);
    light += vec3(emissive * 0.5);

    vec3 lit = albedo * light;

    // Deep purple exponential End fog (shorter range than overworld).
    float dist = length(viewPos);
    float fogAmt = clamp(1.0 - exp(-dist * 0.012), 0.0, 1.0);
    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, END_FOG_C, fogAmt);

    gl_FragData[0] = vec4(outColor, base.a);
}
