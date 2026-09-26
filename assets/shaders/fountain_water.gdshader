shader_type spatial;
render_mode cull_disabled;
uniform vec3 water_color : source_color = vec3(0.10, 0.37, 0.39);
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float waves = (sin(world_point.x * 0.65 + world_point.z * 0.31 + TIME * 1.4) + cos(world_point.z * 0.81 - world_point.x * 0.22 - TIME * 1.1)) * 0.5;
	ALBEDO = water_color + vec3(0.02, 0.035, 0.035) * waves;
	ROUGHNESS = 0.18;
	METALLIC = 0.25;
	NORMAL = normalize(NORMAL + vec3(waves * 0.03, 0.0, cos(world_point.x * 0.8 - TIME) * 0.025));
}
