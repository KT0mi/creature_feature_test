@tool
## What a creature is MADE OF (Gold, Slime, Void...), a rare override of
## its colors and, optionally, its battle traits.
##
## A creature with a material (Genome.material) no longer uses its genome's
## palette or patterns for color: the material's palette recolors every
## part instead, the outline can be forced to a color, and the creature's
## sprite gets the material's shader (e.g. a gold glint, stars inside the
## Void). The material's attribute is added to its CombatProfile.
##
## Lives as a .tres in res://creatures/materials/ (any sub-folders).
## Materials come from game effects (roguelike upgrades...), never from
## random generation.
class_name CreatureMaterial
extends Resource

## Stable unique id, stored in genomes.
@export var id: StringName
## Shown in names instead of the palette's color word ("Golden Catfolk").
@export var display_name: String

## The palette every part is recolored with (patterns are ignored).
## Its index 0 is the outline color, unless override_outline is on.
@export var palette: CreaturePalette
## Force the outline to `outline_color` (e.g. Void: white outline around a
## black body, while index 0 of the palette stays black for hard shadows).
@export var override_outline: bool = false
@export var outline_color: Color = Color.WHITE


@export_group("Rim light")
## A 1-pixel edge of reflected light on one side of EVERY PART (e.g. gold
## catching the light): pixels whose neighbor in `rim_direction` is outside
## that part turn `rim_color`. Done per part while baking, before parts are
## stacked and before the outline, so parts in front get a lit edge against
## the parts behind them, and the outline doesn't get in the way.
@export var rim_light: bool = false
@export var rim_color: Color = Color(1.0, 0.95, 0.7)
@export var rim_override_alpha : bool = false
## Which side gets the rim: (1, 0) = right, (1, -1) = top-right...
@export var rim_direction: Vector2i = Vector2i(1, 0)
## Only pixels drawn with this key tone or lighter get the rim (0 = darkest
## ... 3 = lightest). 2 leaves the hard shadows (0) and shadows (1) dark.
@export_range(0, 3) var rim_min_tone: int = 2
@export_group("")


@export_group("Shader")
## Shader for the creature's sprite (canvas_item). Optional.
@export var shader: Shader
## Values for the shader's uniforms: uniform name -> value.
@export var shader_parameters: Dictionary = {}
## Extra transparent pixels baked around every frame, so the shader can
## draw OUTSIDE the creature's outline (e.g. flames rising from Fire).
## 0 = the frame ends right after the outline, as without a material.
## The creature still stands in the same place: views use Baked.ground,
## and Baked.margin when they need the body's own size.
@export_range(0, 32) var effect_margin: int = 0
@export_group("")

## Permanent StatusEffect added to the creature in battle (optional), e.g.
## Slime: def very high, res 0.
@export var attribute: StatusEffect


## A ShaderMaterial for the sprite, or null if there's no shader.
## `frame_size` is passed to the shader as `frame_size` (if it has that
## uniform) so effects can be computed per animation frame.
func make_sprite_material(frame_size: Vector2i) -> ShaderMaterial:
	if shader == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = shader
	for key in shader_parameters:
		m.set_shader_parameter(key, shader_parameters[key])
	m.set_shader_parameter("frame_size", Vector2(frame_size))
	return m
