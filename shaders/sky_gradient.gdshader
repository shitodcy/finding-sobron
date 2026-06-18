shader_type canvas_item;

uniform vec3 sky_top : source_color;
uniform vec3 sky_bottom : source_color;
uniform float cloud_altitude = -400.0;
uniform float cloud_speed = 12.0;
uniform float cloud_threshold = 0.43;
uniform float pixel_size = 4.0;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
	           mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise2d(p);
		p = p * 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 sky = mix(sky_top, sky_bottom, UV.y);
	
	// Quantum grid pixelation tracking variables
	vec2 cloud_uv = floor((world_pos + vec2(TIME * cloud_speed, 0.0)) / pixel_size) * pixel_size;
	
	// REVISED: Multi-layered noise destruction to break the long train effect into separated fluffy islands
	float n_base = fbm(cloud_uv * 0.0035);
	float n_cutter = noise2d(cloud_uv * 0.018 - vec2(TIME * (cloud_speed * 0.3), 0.0));
	
	// The subtraction and step method forces dead zones, tearing the long horizontal line apart
	float combined_noise = clamp(n_base - (1.0 - n_cutter) * 0.28, 0.0, 1.0);
	
	// Altitude band mask
	float dist = world_pos.y - cloud_altitude;
	float mask = smoothstep(240.0, 0.0, abs(dist));
	float cloud_density = combined_noise * mask;
	
	vec3 final_color = sky;
	
	if (cloud_density > cloud_threshold) {
		float vertical_factor = clamp((dist + 240.0) / 480.0, 0.0, 1.0);
		float quantized_gradient = floor(vertical_factor * 5.0) / 5.0;
		
		vec3 cloud_body_top = vec3(1.0, 1.0, 1.0);
		vec3 cloud_body_bottom = vec3(0.76, 0.81, 0.88);
		
		final_color = mix(cloud_body_top, cloud_body_bottom, quantized_gradient);
	}
	
	COLOR = vec4(final_color, 1.0);
}