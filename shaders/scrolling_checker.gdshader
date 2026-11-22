// Scrolling checkerboard background, pixel-perfect.
//
// Everything is computed in whole SCREEN pixels of the game's base
// resolution (FRAGCOORD, before the integer upscale), and the scroll
// offset is passed in already floored by ScrollingBackground, so squares
// always line up with the pixel grid and move one whole pixel at a time.
shader_type canvas_item;

// Size of one square, in screen pixels.
uniform int square_size = 16;
// Scroll offset in whole pixels (floored on the CPU side).
uniform vec2 offset = vec2(0.0);
uniform vec4 color_a : source_color = vec4(0.16, 0.17, 0.21, 1.0);
uniform vec4 color_b : source_color = vec4(0.19, 0.20, 0.25, 1.0);

void fragment() {
	// The pixel's integer position (pixel centers are at .5).
	vec2 pixel = floor(FRAGCOORD.xy) + offset;
	vec2 cell = floor(pixel / float(max(square_size, 1)));
	// Checker: even / odd sum of the cell coordinates.
	float odd = mod(cell.x + cell.y, 2.0);
	COLOR = mix(color_a, color_b, odd);
}
