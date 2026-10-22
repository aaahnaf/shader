#version 120
// --- loader-injected preamble (validation simulation) ---
#define gl_projectionMatrix gl_ProjectionMatrix

// ============================================================
//  FastLight - terrain.vsh   (overworld: solid / cutout / plants)
//
//  Pure pass-through of vanilla geometry + light attributes.
//  Extra work per vertex: ONE vec3 copy (view-space position).
//  No wave displacement here -> zero risk of popping / z-fight;
//  water motion is done as a fragment normal perturbation instead.
//
//  NOTE on matrices: at_tmc0 is already in MODEL-VIEW space, so
//  only the projection matrix is needed here (gl_projectionMatrix
//  is the Iris/Sodium name for the classic GL built-in; OptiFine's
//  preprocessor maps it to gl_ProjectionMatrix automatically).
// ============================================================

attribute vec4 at_tmc0;   // position in MODEL-VIEW space (no camera matrix needed!)
attribute vec2 at_tma0;   // texture coord
attribute vec2 at_tma1;   // light coords: x = block*15, y = sky*15 (0..240)
attribute vec4 at_tva0;   // mid-block offset (kept for compatibility/debugging)

varying vec2 texCoord;
varying vec2 lightCoord;
varying vec4 midBlock;
varying vec3 viewPos;     // fragment position in view space (camera = origin)

void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;

    texCoord   = at_tma0;
    lightCoord = at_tma1;
    midBlock   = at_tva0;
    viewPos    = at_tmc0.xyz;
}
