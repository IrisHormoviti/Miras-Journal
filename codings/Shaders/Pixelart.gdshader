shader_type canvas_item;

//// Texture must have 'Filter'-flag enabled!
//
//// Automatic smoothing
//// independent of geometry and perspective
//
// Built-ins such as TEXTURE are only visible inside fragment(), so the
// smoothing loop is inlined instead of passing TEXTURE into a helper.
void fragment()
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
	COLOR = textureGrad(TEXTURE, uv + uv_dxy_pixels * pixel_size, ddx, ddy);
}
