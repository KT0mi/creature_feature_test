// Gold material: a diagonal glint that sweeps across the creature every
// few seconds, plus a few sparkle pixels. Pixel-perfect: everything is in
// whole texture pixels and time advances in steps (fps), so the glint
// moves one pixel at a time.
shader_type canvas_item;

// Size of one animation frame of the sprite sheet (set by the game).
uniform vec2 frame_size = vec2(64.0, 64.0);

uniform vec4 glint_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);
uniform float glint_strength : hint_range(0.0, 1.0) = 0.85;
// Width of the glint band, in pixels.
uniform int glint_width = 3;
// Tilt of the band: 1.0 = 45 degrees, 0.0 = vertical.
uniform float slope = 1.0;
// Seconds for the band to cross the creature, then seconds of pause.
uniform float sweep_time = 0.6;
uniform float pause_time = 1.8;
// Sparkles: chance per pixel to be a sparkle, and how often they change.
uniform float sparkle_density : hint_range(0.0, 0.2) = 0.012;
uniform float sparkle_rate = 3.0;
// Animation steps per second (lower = choppier, more "pixel art").
uniform float fps = 24.0;
// Pixels darker than this (the outline, hard shadows) stay untouched.
uniform float min_luma : hint_range(0.0, 1.0) = 0.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// COLOR already holds the texture x the sprite's modulate (flashes,
	// fades still work).
	vec4 c = COLOR;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (c.a > 0.0 && luma > min_luma) {
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		// Position inside the current frame (sheets hold frames side by side).
		vec2 local = vec2(mod(texel.x, frame_size.x), texel.y);
		float t = floor(TIME * fps) / fps;

		// Glint: a band along x + slope * y that travels over the frame.
		float cycle = sweep_time + pause_time;
		float phase = mod(t, cycle) / sweep_time;      // 0..1 while sweeping
		float w = float(glint_width);
		float span = frame_size.x + slope * frame_size.y + 2.0 * w;
		float band = floor(phase * span) - w;
		float d = local.x + slope * local.y - band;
		if (phase <= 1.0 && d >= 0.0 && d < w) {
			c.rgb = mix(c.rgb, glint_color.rgb, glint_strength);
		}

		// Sparkles: a few random pixels light up, changing sparkle_rate
		// times per second.
		float s = hash(local + floor(t * sparkle_rate) * 17.0);
		if (s < sparkle_density) {
			c.rgb = glint_color.rgb;
		}
	}
	COLOR = c;
}
