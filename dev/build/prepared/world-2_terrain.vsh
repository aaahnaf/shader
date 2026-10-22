#version 120
// --- loader-injected preamble (validation simulation) ---
#define gl_projectionMatrix gl_ProjectionMatrix

// ============================================================
//  FastLight - world-2 (END) terrain.vsh
//
//  Identical pass-through contract as the other worlds:
//  one shared vertex code path across all dimensions keeps
//  driver behaviour predictable -> fewer edge-case bugs.
// ============================================================

attribute vec4 at_tmc0;   // position in MODEL-VIEW space
attribute vec2 at_tma0;   // texture coord
attribute vec2 at_tma1;   // light coords: x = block*15, y = sky*15 (0..240)
attribute vec4 at_tva0;   // mid-block offset

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec4 midBlock;
varying vec3 viewPos;

void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;

    texCoord   = at_tma0;
    lightCoord = at_tma1;
    midBlock   = at_tva0;
    viewPos    = at_tmc0.xyz;
}
