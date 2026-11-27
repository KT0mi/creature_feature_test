// Water material: a net of light lines (caustics) drifting slowly over the
// body, like light through a rippling surface.
//
// The lines are the EDGES of a Voronoi pattern: points scattered one per
// grid cell, each pixel belongs to its nearest point, and pixels about as
// close to two points (F2 - F1 small) sit on an edge. The points wander
// a little over time, so the net slowly reshapes.
// Two nets of different sizes are layered: the big one gives bright lines,
// the small one fainter lines, and where they cross you get a sparkle.
// The lines LIGHT UP the pixel under them instead of replacing it (a
// "screen" blend): over a dark pixel the line stays darkish, over a light
// pixel it gets close to white, so the net follows the body's shading.
// Pixel-perfect: computed per texture pixel, time advances in steps.
shader_type canvas_item;

// Size of one animation frame of the sprite sheet (set by the game).
uniform vec2 frame_size = vec2(64.0, 64.0);

// Color of the light in the lines (it brightens the body towards it).
uniform vec4 line_color : source_color = vec4(0.54, 1.0, 1.0, 1.0);
// How much light each kind of line adds (0 = none, 1 = full light_color:
// even the darkest pixels turn line_color). Lower = softer lines.
uniform float line_strength : hint_range(0.0, 1.0) = 0.55;
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.85;
// Size of the ripple cells, in pixels (bright net, faint net).
uniform float cell_size = 11.0;
uniform float small_cell_size = 6.0;
// How thick the lines are (in cell units, ~0.05 thin .. 0.25 thick).
uniform float line_width : hint_range(0.0, 0.5) = 0.08;
uniform float faint_strength : hint_range(0.0, 1.0) = 0.25;
// How far (in cells) each point wanders, and how fast.
uniform float wander : hint_range(0.0, 0.5) = 0.35;
uniform float speed = 0.6;
// The whole net drifts in this direction, in pixels per second.
uniform vec2 drift = vec2(1.0, 0.5);
// Pixels darker than this (the outline, hard shadows) stay untouched.
uniform float min_luma : hint_range(0.0, 1.0) = 0.15;
// Animation steps per second (lower = choppier, more "pixel art").
uniform float fps = 8.0;

// Lights `base` with `light` x `strength` ("screen" blend): never darker
// than base, never brighter than white, and a lighter base stays lighter.
vec3 lighten(vec3 base, vec3 light, float strength) {
	return 1.0 - (1.0 - base) * (1.0 - light * strength);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Distance from p to the nearest edge of the Voronoi pattern (F2 - F1),
// in cell units. 0 = right on an edge.
float edge_distance(vec2 p, float t) {
	vec2 cell = floor(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = cell + vec2(float(x), float(y));
			vec2 h = hash2(n);
			// The cell's point: random spot, wandering in a small circle.
			vec2 point = n + 0.5 + wander * sin(t * speed + 6.2831 * h);
			float d = length(p - point);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

void fragment() {
	vec4 c = COLOR;  // texture x modulate
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (c.a > 0.0 && luma > min_luma) {
		vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
		// Position inside the current frame (sheets hold frames side by side).
		vec2 local = vec2(mod(texel.x, frame_size.x), texel.y);
		float t = floor(TIME * fps) / fps;
		// Pixel center, drifting in whole pixels.
		vec2 p = local + 0.5 - floor(drift * t);
		bool bright = edge_distance(p / cell_size, t) < line_width;
		bool faint = edge_distance(p / small_cell_size + 17.0, t * 1.3) < line_width;
		if (bright && faint) {
			c.rgb = lighten(c.rgb, line_color.rgb, sparkle_strength);
		} else if (bright) {
			c.rgb = lighten(c.rgb, line_color.rgb, line_strength);
		} else if (faint) {
			c.rgb = lighten(c.rgb, line_color.rgb, faint_strength);
		}
	}
	COLOR = c;
}
