// Fire material: flames rise from the creature's top edges into the empty
// space around it, plus embers flickering on the body.
//
// The flames are drawn OUTSIDE the creature, so the material needs room
// around each frame: set the material's `effect_margin` (in pixels) to at
// least `max_height`, or the tallest flames get cut at the frame's edge.
//
// How a flame pixel is decided (pixel-perfect, all in whole texture pixels):
//   1. only EMPTY pixels can hold flame;
//   2. look straight down (with a little side-to-side wobble) for the
//      creature, at most max_height pixels: `d` = how far above it we are;
//   3. each column has its own flame height (`reach`, flickering between
//      ~35% and 100% of max_height), so the flames form tongues;
//      heat = 1 - d / reach, plus some rising noise (turbulence);
//   4. hot -> core color, warm -> mid color, cooling -> tip color, cold ->
//      nothing. So flames are bright at their base and red at their tips,
//      and their tongues change shape as the noise rises.
shader_type canvas_item;

// Size of one animation frame of the sprite sheet (set by the game).
uniform vec2 frame_size = vec2(64.0, 64.0);

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.62, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.68, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(0.9, 0.3, 0.1, 1.0);
// Tallest flame, in pixels above the creature (max 16). Keep it at or
// below the material's effect_margin.
uniform int max_height : hint_range(1, 16) = 10;
// How fast the flame pattern rises, in pixels per second.
uniform float rise_speed = 14.0;
// How ragged the flames are: 0 = smooth even layers, 1+ = wild tongues.
uniform float turbulence : hint_range(0.0, 2.0) = 0.5;
// Heat needed for each color (higher = less of that color).
uniform float core_heat : hint_range(0.0, 1.0) = 0.8;
uniform float mid_heat : hint_range(0.0, 1.0) = 0.5;
uniform float tip_heat : hint_range(0.0, 1.0) = 0.15;
// How fast each column's flame height flickers.
uniform float flicker_speed = 3.0;
// Side-to-side wobble of the flames, in pixels.
uniform float sway : hint_range(0.0, 3.0) = 1.0;
// Embers on the body: how much the brightest flickers lean towards the
// core color (0 = no embers).
uniform float ember_strength : hint_range(0.0, 1.0) = 0.35;
// Pixels darker than this (outline, hard shadows) get no embers.
uniform float min_luma : hint_range(0.0, 1.0) = 0.15;
// Animation steps per second (lower = choppier, more "pixel art").
uniform float fps = 12.0;

// The sprite's modulate (flashes, fades), captured in vertex() because the
// flames are drawn on empty pixels, where COLOR (texture x modulate) is 0.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise (0..1): random values on a grid, blended between.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 sheet_size = 1.0 / TEXTURE_PIXEL_SIZE;
	// Position inside the current frame (sheets hold frames side by side).
	vec2 local = vec2(mod(texel.x, frame_size.x), texel.y);
	float frame_left = texel.x - local.x;
	float t = floor(TIME * fps) / fps;
	// The noise pattern, sampled lower as time goes on, so it moves UP.
	float rising = noise(vec2(local.x * 0.45, (local.y + t * rise_speed) * 0.3));

	vec4 c = COLOR;
	if (c.a > 0.0) {
		// Body: embers, a rising flicker on the lit tones.
		float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		if (luma > min_luma && rising > 0.72) {
			c.rgb = mix(c.rgb, core_color.rgb, ember_strength);
		}
	} else {
		// Empty pixel: is the creature somewhere below, close enough?
		// The column we look down wobbles a little, row by row, so the
		// flames sway. Clamped to this frame so we never read the next one.
		float wobble = floor(sway * (noise(vec2(local.y * 0.3, t * 2.0)) * 2.0 - 1.0) + 0.5);
		float x = clamp(texel.x + wobble, frame_left, frame_left + frame_size.x - 1.0);
		int d = 0;
		for (int i = 1; i <= 16; i++) {
			if (i > max_height || texel.y + float(i) >= sheet_size.y) {
				break;
			}
			if (texelFetch(TEXTURE, ivec2(int(x), int(texel.y) + i), 0).a > 0.0) {
				d = i;
				break;
			}
		}
		if (d > 0) {
			// This column's flame height right now (tongues of fire).
			float reach = float(max_height) * (0.35 + 0.65 * noise(vec2(local.x * 0.5, t * flicker_speed)));
			float heat = 1.0 - float(d) / (reach + 1.0) + (rising - 0.5) * turbulence;
			if (heat > core_heat) {
				c = vec4(core_color.rgb, 1.0) * tint;
			} else if (heat > mid_heat) {
				c = vec4(mid_color.rgb, 1.0) * tint;
			} else if (heat > tip_heat) {
				c = vec4(tip_color.rgb, 1.0) * tint;
			}
		}
	}
	COLOR = c;
}
