// Void material: the creature's dark body is a window onto a starry
// night. Stars drift slowly across it and twinkle; the light outline
// (from the material: white) is left untouched. Pixel-perfect: stars sit
// on whole pixels and drift one pixel at a time.
shader_type canvas_item;

// Size of one animation frame of the sprite sheet (set by the game).
uniform vec2 frame_size = vec2(64.0, 64.0);

uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dim_star_color : source_color = vec4(0.45, 0.5, 0.85, 1.0);
// Chance per pixel to hold a star.
uniform float star_density : hint_range(0.0, 0.3) = 0.05;
// How fast the starfield drifts, in pixels per second (x, y).
uniform vec2 drift = vec2(3.0, 1.0);
// How often each star's brightness changes, per second.
uniform float twinkle_rate = 2.0;
// Animation steps per second.
uniform float fps = 12.0;
// Only pixels darker than this are "space" (so the outline stays clean).
uniform float space_luma : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;  // texture x modulate
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (c.a > 0.0 && luma < space_luma) {
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		vec2 local = vec2(mod(texel.x, frame_size.x), texel.y);
		float t = floor(TIME * fps) / fps;
		// The starfield moves under the body in whole pixels.
		vec2 p = local - floor(drift * t);
		if (hash(p) < star_density) {
			// Each star twinkles: bright, dim, or off for a moment.
			float tw = hash(p + floor(t * twinkle_rate) * 31.0);
			if (tw > 0.65) {
				c.rgb = star_color.rgb;
			} else if (tw > 0.25) {
				c.rgb = dim_star_color.rgb;
			}
		}
	}
	COLOR = c;
}
