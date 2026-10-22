#version 120

// ============================================================
//  FastLight - uncolored.vsh   (water, translucent solids)
//
//  IMPORTANT: in vanilla GLSL 1.20 forward rendering, the water
//  program draws with CONSTANT COLOR (gl_Color set by the game),
//  NOT texture coordinates. There is no usable at_tma0 here, so
//  this shader must never sample an atlas - it would read garbage.
//  All motion comes from analytic waves computed per fragment.
// ============================================================

attribute vec4 at_tmc0;   // position in MODEL-VIEW space
attribute vec4 at_tva0;   // mid-block offset (block pos relative to player)
attribute vec4 at_tva1;   // vertex light: x = block*15, y = sky*15 (0..240)

varying vec4 vertexColor;  // gl_Color: RGBA = tint * baked light
varying vec4 midBlock;     // xyz = block centre relative to player (w unused)
varying vec2 lightAttr;    // raw per-vertex light attribute (x=block, y=sky)
varying vec3 viewPos;      // fragment position in view space

void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;

    vertexColor = gl_Color;
    midBlock    = at_tva0;
    lightAttr   = at_tva1.xy;
    viewPos     = at_tmc0.xyz;
}
