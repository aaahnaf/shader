#version 120

// ============================================================
//  FastLight - textured.fsh   (entities, block entities, items)
//
//  Lighting identical in spirit to terrain but driven by the
//  entity light attribute (at_tva1). Face normals come from the
//  modelview-space derivatives of the interpolated position, so
//  rotation and sneak/view bob are handled automatically and the
//  normal stays stable across frames -> no flickering.
//  Cost: 1 texture fetch + ~45 ALU. No extra buffers anywhere.
// ============================================================

/*/lib/common.glsl*/

varying vec2 texCoord;
varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;     // xyz = block centre relative to player (w unused)
varying vec2 lightAttr;    // x = block*15, y = sky*15 (0..240)
varying vec3 viewPos;      // fragment position, view space (camera at origin)

uniform sampler2D texture0; // entity / block-entity atlas

void main() {
    // ---- Albedo (single texture fetch) ----
    vec4 base = texture2D(texture0, texCoord);
    if (base.a < 0.1) discard;                       // cutout parts (ears etc.)

    // gl_Color already contains the vanilla baked light multiplier, so we
    // take only the TINT out of it (normalized luminance) and re-light with
    // our own terms from the raw attribute -> consistent look with terrain.
    float bakedLum = max(dot(vertexColor.rgb, vec3(0.299, 0.587, 0.114)), 1e-3);
    vec3 albedo = base.rgb * base.rgb * (vertexColor.rgb / bakedLum);
    albedo = min(albedo, vec3(1.0));

    float blockLv = clamp(lightAttr.x, 0.0, 240.0) * (1.0 / 240.0);
    float skyLv   = clamp(lightAttr.y, 0.0, 240.0) * (1.0 / 240.0);

    // ---- Normal from screen-space derivatives ----
    // viewPos is interpolated in MODELVIEW space, so the reconstructed
    // plane already follows the entity's current rotation. Stable frame
    // to frame -> no shimmer/flicker on mobs or held items.
    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;

    float dayFactor = flRamp(0.0, 0.25, sunAngle.y);
    vec3 light = flLight(N, skyLv, blockLv, sunAngle, dayFactor, 0.0);

    // Re-add the baked component we divided out, scaled down, so vanilla
    // shading cues (e.g. villager tints) survive without double-darkening.
    light *= mix(1.0, bakedLum * 2.0, 0.35);

    vec3 lit = albedo * light;

    // ---- Fog matched to time of day (display space -> no banding) ----
    float dist = length(viewPos);
    vec3 fogCol = flSkyFogColor(sunAngle, dayFactor);

    vec3 outColor = flEncode(flTonemap(lit));
    outColor = flFog(outColor, dist, fogCol);

    gl_FragData[0] = vec4(outColor, base.a * vertexColor.a);
}
