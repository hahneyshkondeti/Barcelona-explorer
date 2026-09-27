shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float wave = sin(world.x * 0.21 + TIME * 0.9) * sin(world.z * 0.16 - TIME * 0.6);
	ALBEDO = mix(vec3(0.008, 0.05, 0.08), vec3(0.016, 0.095, 0.13), wave * 0.5 + 0.5);
	ROUGHNESS = 0.24;
	METALLIC = 0.25;
	NORMAL_MAP = vec3(0.5 + wave * 0.035, 0.5 + cos(world.x * 0.16 + TIME) * 0.035, 1.0);
}
