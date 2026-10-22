#version 120

// ============================================================
//  FastLight - uncolored.fsh   (water & translucent constant-color passes)
//
//  WATER WAVES WITHOUT ANY TEXTURE OR DISPLACEMENT:
//  two summed sine waves perturb the face normal per fragment.
//  Geometry never moves -> zero popping, zero z-fighting, and the
//  effect survives reloads because everything is time-analytic.
//  Cost: 2 sin + 2 cos + ~45 ALU, ZERO texture fetches.
// ============================================================

/*/lib/common.glsl*/

varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;     // xyz = block centre relative to player (w unused)
varying vec2 lightAttr;    // x = block*15, y = sky*15 (0..240)
varying vec3 viewPos;      // fragment position, view space (camera at origin)

void main() {
    // ---- Base colour from the game's constant colour (tint * baked light) ----
    // NOTE: vertexColor already multiplies in the vanilla baked light level,
    // so albedo carries brightness; we must NOT multiply by full flLight()
    // again or caves would double-darken to invisible black water. The
    // re-light term below is therefore a modulation around 1.0.
    float bakedLum = max(dot(vertexColor.rgb, vec3(0.299, 0.587, 0.114)), 1e-3);
    vec3 albedo = vertexColor.rgb * vertexColor.rgb;   // sRGB -> linear

    float blockLv = clamp(lightAttr.x, 0.0, 240.0) * (1.0 / 240.0);
    float skyLv   = clamp(lightAttr.y, 0.0, 240.0) * (1.0 / 240.0);

    // ---- Face normal from derivatives (water quads are axis-aligned) ----
    vec3 N = flSafeNormalize(cross(dFdx(viewPos), dFdy(viewPos)));
    if (!gl_FrontFacing) N = -N;
    N = flSnapToAxis(N);

    // ---- Analytic wave perturbation ----
    // Reconstruct a stable world-ish XZ phase from view-space position.
    // The camera rotation only shifts the whole pattern slightly; using
    // frameTimeCounter keeps it perfectly smooth across reloads.
    float t = frameTimeCounter;
    vec2 p  = viewPos.xz;                              // horizontal plane in view space
    float w1 = sin(p.x * 1.6 + t * 1.3) * cos(p.y * 1.1 - t * 0.9);
    float w2 = sin(p.x * 0.7 - p.y * 1.3 + t * 0.6);
    // Gradient of (w1 + 0.5*w2) scaled to gentle slopes (amp ~0.06)
    vec3 waveN = normalize(N + vec3(
        -(cos(p.x * 1.6 + t * 1.3) * 1.6 * cos(p.y * 1.1 - t * 0.9)
          + 0.5 * cos(p.x * 0.7 - p.y * 1.3 + t * 0.6) * 0.7) * 0.06,
         0.0,
        -(sin(p.x * 1.6 + t * 1.3) * (-1.1) * sin(p.y * 1.1 - t * 0.9)
          - 0.5 * cos(p.x * 0.7 - p.y * 1.3 + t * 0.6) * 1.3) * 0.06));

    float dayFactor = flRamp(0.0, 0.25, sunAngle.y);
    vec3 light = flLight(waveN, skyLv, blockLv, sunAngle, dayFactor, 0.0);

    // Specular sun/moon glitter on the wave crests (Blinn, V = up):
    vec3 Lsun = sunAngle.y > 0.0 ? sunAngle : -sunAngle;
    vec3 H = normalize(Lsun + vec3(0.0, 1.0, 0.0));
    float spec = flPow6(max(dot(waveN, H), 0.0)) * skyLv * dayFactor;
    light += mix(MOON_COLOR, SUN_COLOR, dayFactor) * spec * 0.5;

    // Keep some baked shading cue so caves under water still darken.
    light *= mix(1.0, bakedLum * 2.0, 0.35);

    vec3 lit = albedo * light;

    float dist = length(viewPos);
    vec3 fogCol = flSkyFogColor(sunAngle, dayFactor);

    vec3 outColor = flEncode(flTonemap(lit));
    outColor = flFog(outColor, dist, fogCol);

    gl_FragData[0] = vec4(outColor, vertexColor.a);
}
