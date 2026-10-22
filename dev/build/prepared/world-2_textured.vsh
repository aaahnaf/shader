#version 120
// --- loader-injected preamble (validation simulation) ---
#define gl_projectionMatrix gl_ProjectionMatrix

// ============================================================
//  FastLight - world-2 (END) textured.vsh
//  Same pass-through contract as every other vertex program:
//  shared code path across dimensions = fewer driver edge cases.
// ============================================================

attribute vec4 at_tmc0;   // position in MODEL-VIEW space
attribute vec2 at_tma0;   // texture coord
attribute vec4 at_tva0;   // mid-block offset
attribute vec4 at_tva1;   // vertex light: x = block*15, y = sky*15 (0..240)

varying vec2 texCoord;
varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;
varying vec2 lightAttr;    // raw per-vertex light attribute (x=block, y=sky)
varying vec3 viewPos;      // fragment position in view space

void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;

    texCoord    = at_tma0;
    vertexColor = gl_Color;
    midBlock    = at_tva0;
    lightAttr   = at_tva1.xy;
    viewPos     = at_tmc0.xyz;
}
