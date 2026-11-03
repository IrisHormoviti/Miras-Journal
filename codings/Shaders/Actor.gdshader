shader_type canvas_item;

uniform vec4 outline_color : source_color;
uniform bool outline_enabled;

// Texture must have 'Filter'-flag enabled!

void fragment() {
	// Built-ins such as TEXTURE are only visible inside fragment(), so the
	// smoothing loop is inlined instead of passing TEXTURE into a helper.
	vec4 sprite_color;
	{
		vec2 uv = UV;
		vec2 pixel_size = TEXTURE_PIXEL_SIZE;
		vec2 ddx = dFdx(uv);
		vec2 ddy = dFdy(uv);
		vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
		vec2 uv_pixels = uv / pixel_size;
		vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
		vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
		uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
		uv = uv_pixels_floor * pixel_size;
		sprite_color = textureGrad(TEXTURE, uv + uv_dxy_pixels * pixel_size, ddx, ddy);
	}

	if (outline_enabled == true){
		float size_x = 1.0/float(textureSize(TEXTURE, 0).x);
		float size_y = 1.0/float(textureSize(TEXTURE, 0).y);
		float alpha = -4.0 * sprite_color.a;

		{
			vec2 uv = UV + vec2(size_x, 0);
			vec2 pixel_size = TEXTURE_PIXEL_SIZE;
			vec2 ddx = dFdx(uv);
			vec2 ddy = dFdy(uv);
			vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
			vec2 uv_pixels = uv / pixel_size;
			vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
			vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
			uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
			uv = uv_pixels_floor * pixel_size;
			alpha += textureGrad(TEXTURE, uv + uv_dxy_pixels * pixel_size, ddx, ddy).a;
		}

		{
			vec2 uv = UV + vec2(-size_x, 0);
			vec2 pixel_size = TEXTURE_PIXEL_SIZE;
			vec2 ddx = dFdx(uv);
			vec2 ddy = dFdy(uv);
			vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
			vec2 uv_pixels = uv / pixel_size;
			vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
			vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
			uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
			uv = uv_pixels_floor * pixel_size;
			alpha += textureGrad(TEXTURE, uv + uv_dxy_pixels * pixel_size, ddx, ddy).a;
		}

		{
			vec2 uv = UV + vec2(0, size_y);
			vec2 pixel_size = TEXTURE_PIXEL_SIZE;
			vec2 ddx = dFdx(uv);
			vec2 ddy = dFdy(uv);
			vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
			vec2 uv_pixels = uv / pixel_size;
			vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
			vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
			uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
			uv = uv_pixels_floor * pixel_size;
			alpha += textureGrad(TEXTURE, uv + uv_dxy_pixels * pixel_size, ddx, ddy).a;
		}

		{
			vec2 uv = UV + vec2(0, -size_y);
			vec2 pixel_size = TEXTURE_PIXEL_SIZE;
			vec2 ddx = dFdx(uv);
			vec2 ddy = dFdy(uv);
			vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
			vec2 uv_pixels = uv / pixel_size;
			vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
			vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
			uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
			uv = uv_pixels_floor * pixel_size;
			alpha += textureGrad(TEXTURE, uv + uv_dxy_pixels * pixel_size, ddx, ddy).a;
		}

		vec4 final_color = mix(sprite_color, outline_color , clamp(alpha, 0.0, 1.0));
		sprite_color = vec4(final_color.rgb, clamp((abs(alpha)*outline_color.a) + sprite_color.a , 0.0, 1.0));
	}
	COLOR = sprite_color;
}
