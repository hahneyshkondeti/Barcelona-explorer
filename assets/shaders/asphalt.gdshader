shader_type spatial;
uniform sampler2D color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normalgl : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness : filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
    vec2 uv = UV / 2.2;
    ALBEDO = mix(texture(color,uv).rgb, vec3(0.16), 0.5) * 0.65;
    NORMAL_MAP = texture(normalgl,uv).rgb;
    NORMAL_MAP_DEPTH = 0.18;
    ROUGHNESS = clamp(texture(roughness,uv).r,0.65,1.0);
}
