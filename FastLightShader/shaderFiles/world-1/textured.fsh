#version 120
// ============================================================
//  FastLight - world-1 (NETHER) textured.fsh
//  Mobs & block entities lit by torch light + warm ambient.
//  Derivative normals are stable across frames -> no flicker
//  even on rotating mobs (rotation lives in the modelview).
// ============================================================
/*/lib/common.glsl*/
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
    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;
    float upFace = max(N.y, 0.0);
    vec3 light = NETHER_KEY * (0.10 + 0.18 * upFace)
               + TORCH_COLOR * (blockLv * blockLv * 1.6 + blockLv * 0.45)
               + NETHER_AMB * (0.3 + 0.7 * blockLv);
    light *= mix(1.0, bakedLum * 2.0, 0.35);          // keep vanilla tint cues
    vec3 lit = albedo * light;
    float dist = length(viewPos);
    float fogAmt = clamp(1.0 - exp(-dist * 0.035), 0.0, 1.0);
    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, NETHER_FOG_C, fogAmt);
    gl_FragData[0] = vec4(outColor, base.a * vertexColor.a);
}
