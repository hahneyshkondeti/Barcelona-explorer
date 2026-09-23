shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.18,0.19,0.19,1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float grain = hash(floor(world_position.xz * 80.0));
    float patches = hash(floor(world_position.xz * 0.24));
    ALBEDO = base_color.rgb * (0.84 + grain * 0.22 + patches * 0.12);
    ROUGHNESS = 0.98;
}
