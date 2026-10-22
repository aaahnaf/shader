#version 120
// ============================================================
//  FastLight - world-1 (NETHER) uncolored.fsh
//  Lava/water surface: analytic wave normals + strong self-glow
//  for lava (detected from the constant colour's warmth).
// ============================================================
/*/lib/common.glsl*/
varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;
varying vec2 lightAttr;    // x = block*15, y = sky*15 (0..240)
varying vec3 viewPos;
void main() {
    vec3 albedo = vertexColor.rgb * vertexColor.rgb;   // sRGB -> linear
    float blockLv = clamp(lightAttr.x, 0.0, 240.0) * (1.0 / 240.0);
    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;
    N = flSnapToAxis(N);
    // Waves: gentle normal perturbation only (no displacement -> no popping)
    float t = frameTimeCounter;
    vec2 p = viewPos.xz;
    vec3 waveN = flSafeNormalize(N + vec3(
        cos(p.x * 1.4 + t * 1.1) * 0.05,
        0.0,
        sin(p.y * 1.2 - t * 0.8) * 0.05));
    // Lava detection: very red constant colour => self-lit, ignore lights
    float isLava = step(0.45, albedo.r) * step(albedo.r * 0.45, 1.0 - albedo.g) * step(albedo.b, albedo.g);
    vec3 light = mix(NETHER_KEY * 0.25 + TORCH_COLOR * (blockLv * blockLv * 1.5 + blockLv * 0.4) + NETHER_AMB,
                     albedo * 2.2,                                   // lava emits its own light
                     isLava);
    vec3 lit = albedo * light;
    float dist = length(viewPos);
    float fogAmt = clamp(1.0 - exp(-dist * 0.035), 0.0, 1.0);
    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, NETHER_FOG_C, fogAmt * (1.0 - isLava * 0.6));
    gl_FragData[0] = vec4(outColor, vertexColor.a);
}
