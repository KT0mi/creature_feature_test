## A 4-tone color ramp, darkest to lightest.
##
##   index 0  darkest: used for the generated OUTLINE and for hard shadows
##   index 1  shadow
##   index 2  base
##   index 3  light
##
## The same class is used for three things:
##   * res://creatures/palette_key.tres: the 4 colors you DRAW parts and
##     patterns with. They mark which tone each pixel is.
##   * a creature's body palette: every key-colored pixel of every part is
##     replaced by the same index in this ramp, and the outline uses index 0.
##   * a pattern palette: same thing, but for the pixels of a pattern overlay.
##
## Any color that is NOT in the key is an "organic" (teeth, white of the eyes,
## highlights) and is never recolored.
class_name CreaturePalette
extends Resource

## Number of tones every palette must have.
const TONES := 4

## Stable id, stored in genomes (never the file path).
@export var id: StringName

## The ramp, darkest (index 0) to lightest (index 3).
@export var ramp: PackedColorArray = PackedColorArray([
	Color.BLACK, Color(0.25, 0.25, 0.25), Color(0.5, 0.5, 0.5), Color(0.75, 0.75, 0.75)])


## Color for tone `index`, clamped into the ramp (so shade shifts that go
## past the darkest/lightest tone just stay at the end).
func tone(index: int) -> Color:
	if ramp.is_empty():
		return Color.MAGENTA  # loud "this palette is broken" color
	return ramp[clampi(index, 0, ramp.size() - 1)]


## Outline color = the darkest tone.
func outline() -> Color:
	return tone(0)


## True if the ramp has exactly TONES colors.
func is_valid() -> bool:
	return ramp.size() == TONES
