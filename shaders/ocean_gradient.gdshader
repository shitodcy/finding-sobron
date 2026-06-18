shader_type canvas_item;

uniform vec3 sky_top : source_color;
uniform vec3 sky_bottom : source_color;
uniform vec3 sea_shallow : source_color;
uniform vec3 sea_deep : source_color;
uniform float ray_intensity = 0.22;
uniform float ray_absorption_depth = 0.6;
uniform float ocean_depth = 1000.0;
uniform float pixel_size = 4.0; // Synced automatically via water_system.gd

varying vec2 world_pos;
varying float custom_depth;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (VERTEX.y > ocean_depth - 10.0) {
		custom_depth = 1.0;
	} else {
		custom_depth = 0.0;
	}
}

void fragment() {
	// REVISED: Lock entire ocean shader illumination data directly onto the pixel art matrix
	vec2 pixel_grid = floor(world_pos / pixel_size) * pixel_size;
	
	float tilted_x = pixel_grid.x + pixel_grid.y * 0.55;
	
	float beam1 = sin(tilted_x * 0.008 + TIME * 0.6) * cos(tilted_x * 0.013 - TIME * 0.4);
	float beam2 = sin(tilted_x * 0.022 + TIME * 1.1) * sin(tilted_x * 0.005 + TIME * 0.2);
	float combined_beams = (beam1 + beam2) * 0.5;
	
	float ray_mask = smoothstep(0.25, 0.75, combined_beams) * ray_intensity;
	
	float depth_factor = smoothstep(0.0, 1.0, custom_depth);
	vec3 water_color = mix(sea_shallow, sea_deep, depth_factor);
	
	float ray_absorption = 1.0 - smoothstep(0.0, ray_absorption_depth, custom_depth);
	water_color += vec3(ray_mask * ray_absorption);
	
	COLOR = vec4(water_color, 1.0);
}