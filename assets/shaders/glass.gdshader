shader_type spatial;
void fragment() {
    float facing = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)),0.0,1.0), 3.0);
    ALBEDO = mix(vec3(0.035,0.05,0.052),vec3(0.16,0.23,0.28),facing);
    METALLIC = 0.65;
    ROUGHNESS = 0.24;
}
