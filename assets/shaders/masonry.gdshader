shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.63, 0.58, 0.48, 1.0);
uniform float stone_scale = 1.0;
uniform sampler2D plaster_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_roughness : filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = UV * stone_scale;
    float grain = hash(floor(p * 95.0));
    float weather = hash(floor(p * 0.55));
    float course = smoothstep(0.018, 0.04, abs(fract(p.y / 0.48) - 0.5));
    float block = hash(vec2(floor(p.x / 0.95 + mod(floor(p.y / 0.48),2.0)*0.5), floor(p.y / 0.48)));
    vec3 plaster = texture(plaster_color, p * 0.45).rgb;
    ALBEDO = base_color.rgb * mix(vec3(0.88), plaster, 0.6) * (0.94 + weather * 0.04 + block * 0.025) * (0.96 + course * 0.04);
    NORMAL_MAP = texture(plaster_normal, p * 0.45).rgb;
    NORMAL_MAP_DEPTH = 0.32;
    ROUGHNESS = mix(0.7, 1.0, texture(plaster_roughness, p * 0.45).r);
}
