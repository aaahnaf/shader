#version 120
// FastLight - world-1 (NETHER) uncolored.vsh (water/lava translucent pass)
// Same pass-through contract as every other vertex program here.
attribute vec4 at_tmc0;   // position in MODEL-VIEW space
attribute vec4 at_tva0;   // mid-block offset
attribute vec4 at_tva1;   // vertex light: x = block*15, y = sky*15 (0..240)
varying vec4 vertexColor;
varying vec4 midBlock;
varying vec2 lightAttr;
varying vec3 viewPos;
void main() {
    gl_Position = gl_projectionMatrix * at_tmc0;
    vertexColor = gl_Color;
    midBlock    = at_tva0;
    lightAttr   = at_tva1.xy;
    viewPos     = at_tmc0.xyz;
}
