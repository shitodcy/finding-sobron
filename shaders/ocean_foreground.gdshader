shader_type canvas_item;

uniform vec4 foam_color : source_color = vec4(1.0);
uniform float foam_thickness = 0.08; // Sesuai dengan WaterSystem Inspector (bisa diatur ketebalannya)
uniform float ocean_depth = 1000.0;
uniform float pixel_size = 10.0; // Otomatis membaca global_pixel_size = 10.0 dari scene Anda

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
	// Membulatkan koordinat vertikal murni ke ukuran block pixel art game Anda
	float snapped_depth = floor(custom_depth / foam_thickness) * foam_thickness;
	
	// RENDER UTAMA: Solid block padding. Tidak ada bintik noise berpencar!
	if (custom_depth < foam_thickness) {
		COLOR = foam_color;
	} else {
		discard; // Potong area bawah agar transparan sempurna mengikuti lekuk air
	}
}