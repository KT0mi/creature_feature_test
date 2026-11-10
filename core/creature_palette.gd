@tool
##4-tone color ramp, darkest to lightest.
##
##Parts are drawn with a fixed set of "key" colors
##When baking, every pixel whose color is in the key is replaced.
class_name CreaturePalette
extends Resource

#Number of tones every palette must have
const TONES := 4

@export var id: StringName

##Name used when naming a creature after generation
@export var display_name: String = ""

## The ramp, darkest (index 0) to lightest (index 3).
## The setter emits `changed`, so the palette preview in the editor updates
## live while you pick colors.
@export var ramp: PackedColorArray = PackedColorArray([
	Color.BLACK, Color(0.25, 0.25, 0.25), Color(0.5, 0.5, 0.5), Color(0.75, 0.75, 0.75)]):
	set(value):
		ramp = value
		emit_changed()

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
