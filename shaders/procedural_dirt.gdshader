shader_type canvas_item;

uniform vec3 land_color : source_color;
uniform vec3 grass_color : source_color;
uniform float ocean_depth = 2400.0;
uniform float land_top_y = 50.0; // Otomatis tersinkronisasi dari WaterSystem Anda
uniform float pixel_size = 10.0; // Mengikuti global_pixel_size = 10.0 game Anda

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// 1. Kunci posisi render ke grid pixel art global (Sesuai setelan 10.0 piksel Anda)
	vec2 pixel_grid = floor(world_pos / pixel_size) * pixel_size;
	
	// 2. DETEKSI ANGLE LERENG (Sinkronisasi Sempurna dengan ContinentalSlopeCollision)
	// Lereng dimulai dari X = 0 (Awal laut) sampai X = 3000 (Awal DirtBackground datar di dasar laut)
	float slope_start_x = 0.0;
	float slope_end_x = 3000.0;
	float slope_start_y = land_top_y; // Berada tepat di permukaan atas tanah rata (-50 hingga 50)
	float slope_end_y = 2368.0;       // Mengikuti titik vertex pertama DirtBackground Anda di scene (.tscn)
	
	if (pixel_grid.x >= slope_start_x && pixel_grid.x <= slope_end_x) {
		// Hitung perkembangan kemiringan linier (Interpolasi t) dari X awal ke X akhir tebing
		float t = (pixel_grid.x - slope_start_x) / (slope_end_x - slope_start_x);
		float exact_slope_y = mix(slope_start_y, slope_end_y, t);
		
		// CRITICAL FIX: Jika pixel berada di atas garis miring lereng, potong habis (discard)!
		// Ini memotong sudut kotak LandBackground dan meratakan angle ContinentalSlopeVisual agar 100% presisi
		if (pixel_grid.y < exact_slope_y) {
			discard;
		}
	} else if (pixel_grid.x < slope_start_x) {
		// Batasan untuk area tanah kering (LandBackground sebelah kiri)
		if (pixel_grid.y < land_top_y) {
			discard;
		}
	}
	
	// 3. TEKSTUR GRAIN DAN PEWARNAAN PIXEL ART
	float noise = hash(pixel_grid);
	float gradient_factor = smoothstep(-100.0, ocean_depth + 400.0, pixel_grid.y);
	float vertical_darkening = mix(1.0, 0.40, gradient_factor);
	
	vec3 final_color = land_color * vertical_darkening;
	final_color += (noise - 0.5) * 0.06; // Efek bintik tanah retro lembut
	
	// 4. AUTOMATED FLAT GRASS LAYER (Hanya digambar pada daratan rata kiri, sebelum tebing turun)
	if (pixel_grid.x < slope_start_x) {
		float grass_edge_noise = hash(vec2(floor(pixel_grid.x / 10.0), 94.21)) * 14.0;
		// Rumput setebal 24 piksel dari permukaan atas
		if (pixel_grid.y < land_top_y + 24.0 + floor(grass_edge_noise / pixel_size) * pixel_size) {
			float grass_darkening = mix(1.0, 0.85, smoothstep(land_top_y, land_top_y + 30.0, pixel_grid.y));
			final_color = grass_color * grass_darkening;
			final_color += (noise - 0.5) * 0.04;
		}
	}
	
	COLOR = vec4(final_color, 1.0);
}