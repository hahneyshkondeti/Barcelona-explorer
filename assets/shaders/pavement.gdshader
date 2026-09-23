shader_type spatial;
varying vec3 position_world;
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 grid = position_world.xz * 5.0;
    vec2 cell = fract(grid);
    vec2 edge = min(cell, 1.0-cell);
    float joint = 1.0-smoothstep(0.012,0.04,min(edge.x,edge.y));
    vec2 p = cell - 0.5;
    float flower = abs(length(p)-0.16);
    flower = min(flower,abs(length(p-vec2(0.17,0.0))-0.14));
    flower = min(flower,abs(length(p+vec2(0.17,0.0))-0.14));
    flower = min(flower,abs(length(p-vec2(0.0,0.17))-0.14));
    flower = min(flower,abs(length(p+vec2(0.0,0.17))-0.14));
    float groove = 1.0-smoothstep(0.006,0.018,flower);
    float variation = fract(sin(dot(floor(grid),vec2(12.98,78.23)))*43758.54);
    ALBEDO = vec3(0.39,0.38,0.34)*(0.92+variation*0.16)*(1.0-joint*0.32-groove*0.15);
    ROUGHNESS = 0.93;
}
