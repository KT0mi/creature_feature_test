## "If the creature has exactly `count` parts of `type`, it may be called
## `word`", e.g. type eye, count 3 -> "Three-eyed". Used by CreatureNaming.
## Copies count too (two visible eyes = 2), since this is about looks.
class_name NameCountRule
extends Resource

@export var type: StringName
@export var count: int = 1
@export var word: String
## How likely this word is to be picked, relative to other candidates.
@export var weight: float = 1.0
