@tool
## An authored main name for one head + torso combination, e.g.
## head_catfolk + torso_amphitere -> "Catwurm". Used by CreatureNaming.
class_name FixedName
extends Resource

## Head part id. Leave empty for creatures without a head.
@export var head: StringName
## Torso part id.
@export var torso: StringName
## The main name to use instead of combining radicals.
@export var name: String
