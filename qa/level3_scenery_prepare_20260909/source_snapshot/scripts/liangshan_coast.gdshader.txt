shader_type canvas_item;
render_mode unshaded;

// R=land, G=artificial-edge protection. The four cardinal neighbours of a
// protected dock/wall cell are protected too, so interpolated material cannot
// bleed across an authored straight structure.
uniform sampler2D land_mask : filter_linear, repeat_disable;
// Grass/dry/wet/hard use RGBA. Field is reconstructed as 1-sum(RGBA),
// allowing five material weights to interpolate in one texture.
uniform sampler2D surface_weights : filter_linear, repeat_disable;
uniform sampler2D terrain_atlas : filter_linear, repeat_disable;
uniform sampler2D terrain_atlas2 : filter_linear, repeat_disable;
uniform sampler2D surface_forest_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_dry_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_wet_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_hard_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_field_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_surface_forest_texture = false;
uniform bool use_surface_dry_texture = false;
uniform bool use_surface_wet_texture = false;
uniform bool use_surface_hard_texture = false;
uniform bool use_surface_field_texture = false;
uniform vec2 map_size;
uniform vec4 water_region;
uniform vec4 shore_region;
uniform vec4 grass_region;
uniform vec4 road_region;
uniform vec4 dry_region;
uniform vec4 field_region;
uniform vec4 grass_tint : source_color = vec4(0.66, 0.74, 0.60, 1.0);
uniform vec4 dry_tint : source_color = vec4(0.84, 0.80, 0.66, 1.0);
uniform vec4 wet_tint : source_color = vec4(0.70, 0.75, 0.62, 1.0);
uniform vec4 hard_tint : source_color = vec4(0.84, 0.80, 0.69, 1.0);
uniform vec4 field_tint : source_color = vec4(0.76, 0.77, 0.59, 1.0);
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform bool height_enabled = false;
uniform bool coast_enabled = true;
uniform bool natural_surface_enabled = false;
uniform float elevation_scale = 48.0;
uniform float natural_blend_min_px = 12.0;
uniform float natural_blend_max_px = 24.0;
uniform float natural_warp_px = 5.0;
uniform float natural_seed = 2648.0;
uniform vec4 scene_tint : source_color = vec4(1.0);
varying vec2 ground_position;
varying float primitive_alpha;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32 + natural_seed * 0.001);
	return fract(p.x * p.y);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}


vec3 sample_primary(vec4 region, vec2 tile_uv) {
	vec2 half_texel = vec2(0.5) / vec2(textureSize(terrain_atlas, 0));
	vec2 uv = region.xy + half_texel + clamp(tile_uv, vec2(0.0), vec2(1.0)) * (region.zw - half_texel * 2.0);
	return texture(terrain_atlas, uv).rgb;
}


vec3 sample_secondary(vec4 region, vec2 tile_uv) {
	vec2 half_texel = vec2(0.5) / vec2(textureSize(terrain_atlas2, 0));
	vec2 uv = region.xy + half_texel + clamp(tile_uv, vec2(0.0), vec2(1.0)) * (region.zw - half_texel * 2.0);
	return texture(terrain_atlas2, uv).rgb;
}


vec2 map_clamped_uv(vec2 map_uv, vec2 texture_size_px) {
	vec2 half_texel = vec2(0.5) / max(texture_size_px, vec2(1.0));
	return clamp(map_uv, half_texel, vec2(1.0) - half_texel);
}


vec3 natural_material(vec2 mask_uv, vec2 tile_uv, vec2 map_uv, float transition_px) {
	vec4 packed = texture(surface_weights, mask_uv);
	float wf = max(0.0, 1.0 - dot(packed, vec4(1.0)));
	float half_width = clamp(transition_px / 64.0, 0.1875, 0.375);
	float lo = 0.5 - half_width;
	float hi = 0.5 + half_width;
	vec4 w = smoothstep(vec4(lo), vec4(hi), packed);
	wf = smoothstep(lo, hi, wf);
	float total = max(0.0001, dot(w, vec4(1.0)) + wf);
	w /= total;
	wf /= total;
	// Smoothstep makes absent classes exactly zero across most pixels. Branching
	// on those weights avoids reading five 2048px sources for a one-class area;
	// every non-zero blend contribution is still sampled and accumulated.
	vec3 result = vec3(0.0);
	if (w.r > 0.0) {
		vec2 uv = map_clamped_uv(map_uv, vec2(textureSize(surface_forest_texture, 0)));
		result += (use_surface_forest_texture ? texture(surface_forest_texture, uv).rgb
			: sample_primary(grass_region, tile_uv)) * grass_tint.rgb * w.r;
	}
	if (w.g > 0.0) {
		vec2 uv = map_clamped_uv(map_uv, vec2(textureSize(surface_dry_texture, 0)));
		result += (use_surface_dry_texture ? texture(surface_dry_texture, uv).rgb
			: sample_secondary(dry_region, tile_uv)) * dry_tint.rgb * w.g;
	}
	if (w.b > 0.0) {
		vec2 uv = map_clamped_uv(map_uv, vec2(textureSize(surface_wet_texture, 0)));
		result += (use_surface_wet_texture ? texture(surface_wet_texture, uv).rgb
			: sample_primary(shore_region, tile_uv)) * wet_tint.rgb * w.b;
	}
	if (w.a > 0.0) {
		vec2 uv = map_clamped_uv(map_uv, vec2(textureSize(surface_hard_texture, 0)));
		result += (use_surface_hard_texture ? texture(surface_hard_texture, uv).rgb
			: sample_primary(road_region, tile_uv)) * hard_tint.rgb * w.a;
	}
	if (wf > 0.0) {
		vec2 uv = map_clamped_uv(map_uv, vec2(textureSize(surface_field_texture, 0)));
		result += (use_surface_field_texture ? texture(surface_field_texture, uv).rgb
			: sample_secondary(field_region, tile_uv)) * field_tint.rgb * wf;
	}
	return result;
}


void vertex() {
	ground_position = VERTEX;
	primitive_alpha = COLOR.a;
	if (height_enabled) {
		vec2 uv = (ground_position / 32.0 + vec2(0.5)) / (map_size + vec2(1.0));
		float h = texture(height_map, uv).r * elevation_scale;
		VERTEX -= vec2(h);
	}
}


void fragment() {
	// Natural terrain owns the full ground quad. The legacy atlas is only a
	// fallback color source: its transparent gutters must not cut holes in a
	// routed surface. Keep primitive/CanvasItem opacity, including actual fades.
	if (natural_surface_enabled) {
		COLOR.a = primitive_alpha;
	}
	vec2 cell = ground_position / 32.0;
	vec2 world_size = map_size * 32.0;
	vec2 center_uv = (floor(cell) + vec2(0.5)) / map_size;
	vec4 center = texture(land_mask, center_uv);
	float broad_a = value_noise(ground_position / 224.0 + vec2(11.7, 3.1));
	float broad_b = value_noise(ground_position / 256.0 + vec2(2.3, 19.4));
	vec2 warp = (vec2(broad_a, broad_b) - vec2(0.5)) * natural_warp_px * 2.0;
	bool protected_cell = center.g > 0.5;
	vec2 map_margin = vec2(0.5) / map_size;
	vec2 mask_uv = protected_cell ? center_uv : clamp((ground_position + warp) / world_size,
		map_margin, vec2(1.0) - map_margin);
	vec2 coast_offset = natural_surface_enabled && !protected_cell ? warp : vec2(0.0);
	vec2 coast_uv = clamp((ground_position + coast_offset) / world_size,
		map_margin, vec2(1.0) - map_margin);
	float width_noise = value_noise(ground_position / 320.0 + vec2(27.0, 6.0));
	float transition_px = mix(natural_blend_min_px, natural_blend_max_px, width_noise);
	vec2 detail_noise = vec2(value_noise(ground_position / 112.0 + vec2(4.0, 31.0)),
		value_noise(ground_position / 128.0 + vec2(39.0, 8.0)));
	// Legacy atlas fallback keeps its original repeating 256px UV. Routed Web
	// surfaces use one map-wide UV with only a centered +/-2px detail offset.
	vec2 tile_detail_warp = detail_noise * 5.0;
	vec2 map_detail_warp = (detail_noise - vec2(0.5)) * 4.0;
	vec2 tile_uv = fract((ground_position + (natural_surface_enabled ? tile_detail_warp : vec2(0.0))) / 256.0);
	vec2 surface_map_uv = (ground_position + (natural_surface_enabled ? map_detail_warp : vec2(0.0)))
		/ max(world_size, vec2(1.0));

	vec3 land_rgb = COLOR.rgb;
	if (natural_surface_enabled && center.r > 0.5 && COLOR.a > 0.99) {
		land_rgb = natural_material(mask_uv, tile_uv, surface_map_uv, transition_px);
		float tone = mix(0.94, 1.045, value_noise(ground_position / 180.0 + vec2(7.0, 23.0)));
		land_rgb *= tone;
		COLOR.rgb = land_rgb;
	}

	vec4 nearby = texture(land_mask, coast_uv);
	// Docks, bridge decks and registered wall bases keep hard edges. Natural
	// banks use the same deterministic low-frequency displacement as the land.
	if (coast_enabled && nearby.r > 0.001 && nearby.r < 0.999 && nearby.g < 0.01) {
		float ripple = natural_surface_enabled
			? (value_noise(ground_position / 96.0 + vec2(17.0, 41.0)) - 0.5) * 0.10
			: sin(cell.x * 5.3 + cell.y * 2.1) * sin(cell.y * 4.7 - cell.x) * 0.035;
		float edge = smoothstep(0.31, 0.69, nearby.r + ripple);
		if (COLOR.a > 0.99) {
			vec3 water = natural_surface_enabled ? sample_primary(water_region, tile_uv)
				: texture(terrain_atlas, water_region.xy + tile_uv * water_region.zw).rgb;
			vec3 shore = natural_surface_enabled ? (use_surface_wet_texture
				? texture(surface_wet_texture, map_clamped_uv(surface_map_uv,
					vec2(textureSize(surface_wet_texture, 0)))).rgb
				: sample_primary(shore_region, tile_uv)) * wet_tint.rgb
				: texture(terrain_atlas, shore_region.xy + tile_uv * shore_region.zw).rgb * vec3(0.72, 0.77, 0.65);
			vec3 land = center.r > 0.5 ? land_rgb : shore;
			COLOR.rgb = mix(water, land, edge);
		} else if (center.r > 0.5) {
			COLOR.a *= edge;
		}
	}

	if (height_enabled && COLOR.a > 0.99) {
		vec2 h_uv = (ground_position / 32.0 + vec2(0.5)) / (map_size + vec2(1.0));
		vec2 texel = vec2(1.0) / (map_size + vec2(1.0));
		float dx = (texture(height_map, h_uv + vec2(texel.x, 0.0)).r - texture(height_map, h_uv - vec2(texel.x, 0.0)).r) * elevation_scale / 64.0;
		float dy = (texture(height_map, h_uv + vec2(0.0, texel.y)).r - texture(height_map, h_uv - vec2(0.0, texel.y)).r) * elevation_scale / 64.0;
		COLOR.rgb *= clamp(1.0 + dx * 0.22 + dy * 0.34, 0.74, 1.10);
	}
	COLOR.rgb *= scene_tint.rgb;
}
