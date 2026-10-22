#version 120
// --- loader-injected preamble (validation simulation) ---
#define gl_projectionMatrix gl_ProjectionMatrix

// FastLight - world-1 (NETHER) textured.vsh (entities, block entities)
attribute vec4 at_tmc0;   // position in MODEL-VIEW space
attribute vec2 at_tma0;   // texture coord
attribute vec4 at_tva0;   // mid-block offset
attribute vec4 at_tva1;   // vertex light: x = block*15, y = sky*15 (0..240)
varying vec2 texCoord;
varying vec4 vertexColor;
varying vec4 midBlock;
varying vec2 lightAttr;
varying vec3 viewPos;
void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;
    texCoord    = at_tma0;
    vertexColor = gl_Color;
    midBlock    = at_tva0;
    lightAttr   = at_tva1.xy;
    viewPos     = at_tmc0.xyz;
}
