shader_type spatial;
render_mode cull_disabled;
uniform bool distant = false;
uniform vec4 fine_bounds = vec4(0.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (distant && world.x > fine_bounds.x && world.z > fine_bounds.y && world.x < fine_bounds.z && world.z < fine_bounds.w) discard;
	float hill = smoothstep(90.0, 200.0, world.y);
	float grain = sin(world.x * 0.002) * sin(world.z * 0.003) * 0.006;
	ALBEDO = mix(vec3(0.14, 0.13, 0.10), vec3(0.045, 0.085, 0.027), hill) + grain;
	ALBEDO = mix(ALBEDO, vec3(0.10, 0.16, 0.055) + grain, COLOR.r);
	ROUGHNESS = 0.95;
}
