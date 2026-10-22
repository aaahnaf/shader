#version 120

// ============================================================
//  FastLight - world-2 (END) uncolored.fsh
//  Translucent constant-colour pass in the End (portals, slime
//  overlay etc.). No atlas is bound for this draw -> zero texture
//  fetches; analytic wave-free shading keeps it cheap and stable.
// ============================================================

/*/lib/common.glsl*/

varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;
varying vec2 lightAttr;    // x = block*15, y = sky*15 (0..240)
varying vec3 viewPos;

void main() {
    float bakedLum = max(dot(vertexColor.rgb, vec3(0.299, 0.587, 0.114)), 1e-3);
    vec3 albedo = vertexColor.rgb * vertexColor.rgb;   // sRGB -> linear

    float blockLv = clamp(lightAttr.x, 0.0, 240.0) * (1.0 / 240.0);
    float skyLv   = clamp(lightAttr.y, 0.0, 240.0) * (1.0 / 240.0);

    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;
    N = flSnapToAxis(N);

    float upFace = max(N.y, 0.0);
    vec3 light = END_KEY * (0.14 + 0.22 * upFace) * (0.45 + 0.55 * skyLv)
               + TORCH_COLOR * (blockLv * blockLv * 1.4 + blockLv * 0.35)
               + END_AMB * (0.35 + 0.65 * max(skyLv, blockLv));

    light *= mix(1.0, bakedLum * 2.0, 0.35);

    vec3 lit = albedo * light;

    float dist = length(viewPos);
    float fogAmt = clamp(1.0 - exp(-dist * 0.012), 0.0, 1.0);
    vec3 outColor = flEncode(flTonemap(lit));
    outColor = mix(outColor, END_FOG_C, fogAmt);

    gl_FragData[0] = vec4(outColor, vertexColor.a);
}
