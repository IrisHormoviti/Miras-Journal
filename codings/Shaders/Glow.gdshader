shader_type canvas_item;

uniform float bloomRadius = 1.0;
uniform float bloomThreshold = 1.0;
uniform float bloomIntensity = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 bloom = vec3(0.0);
	// Built-ins such as TEXTURE are only visible inside fragment(), so the
	// bloom kernel is inlined instead of passing TEXTURE into a helper.
	vec2 sample_pixel_size = TEXTURE_PIXEL_SIZE * bloomRadius;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 sample_uv = UV + vec2(float(x), float(y)) * sample_pixel_size;
			vec2 uv2 = floor(sample_uv / sample_pixel_size) * sample_pixel_size;
			uv2 += sample_pixel_size * .001;

			vec3 tl = max(texture(TEXTURE, uv2).rgb - bloomThreshold, 0.0);
			vec3 tr = max(texture(TEXTURE, uv2 + vec2(sample_pixel_size.x, 0.0)).rgb - bloomThreshold, 0.0);
			vec3 bl = max(texture(TEXTURE, uv2 + vec2(0.0, sample_pixel_size.y)).rgb - bloomThreshold, 0.0);
			vec3 br = max(texture(TEXTURE, uv2 + vec2(sample_pixel_size.x, sample_pixel_size.y)).rgb - bloomThreshold, 0.0);
			vec2 f = fract(sample_uv / sample_pixel_size);

			vec3 tA = mix(tl, tr, f.x);
			vec3 tB = mix(bl, br, f.x);
			float weight = 1.0;

			if (x != 0 || y != 0) {
				weight = (x == 0 || y == 0) ? 0.5 : 0.292893;
			}

			bloom += mix(tA, tB, f.y) * weight;
		}
	}

	bloom /= 4.171573;

	col.rgb += bloom * bloomIntensity;
	COLOR = col;
}
