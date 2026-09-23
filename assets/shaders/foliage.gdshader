shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color;
float hash(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
void fragment() {
    vec2 p = UV*vec2(30.0,18.0);
    float variation = hash(floor(p));
    vec2 leaf = fract(p)-0.5;
    if (dot(leaf,leaf) > 0.22 + variation*0.12) { discard; }
    ALBEDO = leaf_color.rgb * (0.72+variation*0.5);
    ROUGHNESS = 0.9;
    BACKLIGHT = leaf_color.rgb * 0.18;
}
