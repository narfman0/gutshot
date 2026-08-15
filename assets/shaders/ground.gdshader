// Procedural ground — every walkable surface in the district runs this one
// shader with different uniforms, so each site's floor has its own material
// identity without a single texture asset.
//
// Everything keys off WORLD position, not UV, so tiling is consistent across
// sites of different sizes and never stretches. Four layers stack up:
//   1. tiles      — slab grid with grout, plus per-slab tone variation
//   2. grime      — fbm noise darkening, heavier in the grout
//   3. cracks     — thin ridged-noise fractures (dry, old surfaces)
//   4. wet        — puddle mask that drops roughness and lifts specular, so
//                   neon actually reflects in the street (needs SSR on)
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.2, 0.2, 0.22);
uniform vec3 grout_color : source_color = vec3(0.05, 0.05, 0.06);
uniform float tile_size = 4.0;        // metres per slab
uniform float grout_width = 0.02;     // fraction of a tile
uniform float tile_variation = 0.08;  // per-slab brightness spread
uniform float grime_amount = 0.5;
uniform float grime_scale = 0.15;
uniform float crack_amount = 0.0;
uniform float wet_amount = 0.0;
uniform float puddle_scale = 0.09;
uniform float base_roughness = 0.7;
uniform float wet_roughness = 0.06;
uniform float metallic_amount = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.02;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;

	// ── slabs ────────────────────────────────────────────────────────────
	vec2 cell = p / tile_size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float grout = 1.0 - smoothstep(grout_width, grout_width * 2.2, edge);
	float slab_tone = (hash21(id) - 0.5) * 2.0 * tile_variation;

	// ── grime ────────────────────────────────────────────────────────────
	float grime = fbm(p * grime_scale);
	float dirt = mix(1.0, 0.5 + 0.5 * grime, grime_amount);

	vec3 col = base_color * (1.0 + slab_tone) * dirt;
	// Grout collects everything that ever spilled.
	col = mix(col, grout_color * (0.85 + 0.3 * grime), grout);

	// ── cracks ───────────────────────────────────────────────────────────
	if (crack_amount > 0.001) {
		float ridge = abs(fbm(p * 0.42) - 0.5);
		float crack = 1.0 - smoothstep(0.0, 0.035, ridge);
		col = mix(col, grout_color * 0.7, crack * crack_amount);
	}

	// ── standing water ───────────────────────────────────────────────────
	float wet = 0.0;
	if (wet_amount > 0.001) {
		float pool = fbm(p * puddle_scale + 11.7);
		wet = smoothstep(0.46, 0.60, pool) * wet_amount;
		// Water pools in the grout first.
		wet = clamp(wet + grout * wet_amount * 0.35, 0.0, 1.0);
	}

	ALBEDO = mix(col, col * 0.6, wet);
	ROUGHNESS = mix(mix(base_roughness, base_roughness * 0.82, grime),
			wet_roughness, wet);
	METALLIC = metallic_amount;
	SPECULAR = mix(0.5, 0.9, wet);
}
