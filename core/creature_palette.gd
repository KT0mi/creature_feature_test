## A set of color ramps, one per palette REGION.
##
## Parts are drawn with a fixed set of "key" colors (see
## res://creatures/palette_key.tres, which is itself a CreaturePalette).
## When baking, every pixel whose color is in the key is replaced by the color
## at the same region + tone in the creature's palette. Pixels whose color is
## NOT in the key (eyes, teeth...) are left untouched: those are "fixed" colors.
##
## Ramps go from darkest (index 0) to lightest.
class_name CreaturePalette
extends Resource

## Region indices. Every part says "this pixel is primary/secondary/accent"
## through the key color it was drawn with; the GENOME decides the actual
## colors, which is what makes different parts look like the same creature.
enum Region { PRIMARY, SECONDARY, ACCENT }

## Stable id, stored in genomes (never the file path).
@export var id: StringName

## Main body color ramp, dark -> light.
@export var primary: PackedColorArray

## Secondary color ramp (belly, stripes...), dark -> light.
@export var secondary: PackedColorArray

## Accent ramp (small details: horns, spots...), dark -> light.
@export var accent: PackedColorArray

## Color of the 1px outline generated around the finished creature.
@export var outline: Color = Color.BLACK


## Returns the ramp for a Region.
func get_ramp(region: int) -> PackedColorArray:
	match region:
		Region.PRIMARY:
			return primary
		Region.SECONDARY:
			return secondary
		Region.ACCENT:
			return accent
	return PackedColorArray()
