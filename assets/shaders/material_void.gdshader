//Void Material: stars that burst like a small ring travelling outward.
shader_type canvas_item;

uniform vec2 frame_size = vec2(64.0, 64.0);

uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 dim_star_color : source_color = vec4(0.45, 0.5, 0.85, 1.0);
// Animation steps per second (your template: 100 ms per frame).
uniform float fps = 7.0;
// The creature is split into square cells of this many pixels, and each
// cell holds ONE star. Smaller cells = more stars.
uniform float cell_size = 8.0;
// Length of each star's cycle in steps: the 5-step burst, then darkness.
// Longer = stars are rarer, so fewer are lit at once.
uniform float cycle_steps = 24.0;
// Only pixels darker than this are "space" (so the outline stays clean).
uniform float space_luma : hint_range(0.0, 1.0) = 0.5;

// How far the ring travels from the star's center (in pixels).
const float MAX_RADIUS = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The burst from the template, given the star's step (k) and the pixel's
// distance from the center along a cross arm (d).
// Returns 0 = nothing, 1 = dim color, 2 = bright color.
//   k 0:     center dim
//   k 1:     center bright
//   k 2..4:  bright ring at d = k-1, dim pixel just behind it (d = k-2)
int burst(float k, float d) {
	if (d > MAX_RADIUS) return 0;
	if (k == 0.0 && d == 0.0) return 1;
	if (d == k - 1.0) return 2;
	if (d == k - 2.0) return 1;
	return 0;
}

void fragment() {
	vec4 c = COLOR;  // texture x modulate
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (c.a > 0.0 && luma < space_luma) {
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		vec2 local = vec2(mod(texel.x, frame_size.x), texel.y);
		// Which cell this pixel is in, and where that cell's star sits.
		// The star is kept MAX_RADIUS away from the cell's edges, so its
		// cross never spills into the next cell: each pixel only has to
		// check one star.
		vec2 cell = floor(local / cell_size);
		float room = cell_size - 2.0 * MAX_RADIUS;
		vec2 star = cell * cell_size + MAX_RADIUS
				+ floor(vec2(hash(cell), hash(cell + 17.0)) * room);
		vec2 off = abs(local - star);
		// On the cross only (one of the offsets is 0): no diagonals.
		if (min(off.x, off.y) == 0.0) {
			float d = max(off.x, off.y);
			// Each star's cycle starts at a different step, so they burst
			// one after another instead of all together.
			float s = floor(TIME * fps) + floor(hash(cell + 41.0) * cycle_steps);
			int b = burst(mod(s, cycle_steps), d);
			if (b == 2) {
				c.rgb = star_color.rgb;
			} else if (b == 1) {
				c.rgb = dim_star_color.rgb;
			}
		}
	}
	COLOR = c;
}