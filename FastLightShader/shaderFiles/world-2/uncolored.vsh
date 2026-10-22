#version 120

// ============================================================
//  FastLight - world-2 (END) uncolored.vsh
//  Constant-colour translucent pass: NO texcoords exist here,
//  so this program must never sample an atlas (see world-0 note).
// ============================================================

attribute vec4 at_tmc0;   // position in MODEL-VIEW space
attribute vec4 at_tva0;   // mid-block offset
attribute vec4 at_tva1;   // vertex light: x = block*15, y = sky*15 (0..240)

varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;
varying vec2 lightAttr;    // raw per-vertex light attribute (x=block, y=sky)
varying vec3 viewPos;      // fragment position in view space

void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;

    vertexColor = gl_Color;
    midBlock    = at_tva0;
    lightAttr   = at_tva1.xy;
    viewPos     = at_tmc0.xyz;
}
