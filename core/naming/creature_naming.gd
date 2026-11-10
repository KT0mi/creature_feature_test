@tool
## Global naming settings, loaded from res://creatures/naming.tres if it
## exists (otherwise these defaults are used). See CreatureNamer.
class_name CreatureNaming
extends Resource

## Most adjectives in one name.
@export_range(0, 6) var max_words: int = 3

@export_group("Fixed names")
## Authored main names for specific head + torso pairs. Checked before the
## radicals are combined.
@export var fixed_names: Array[FixedName] = []

@export_group("Size")
## Creatures this tall (in pixels, without outline) or shorter get small_word.
@export var small_height: int = 32
## e.g. "Tiny". Leave empty to never use a small-size word.
@export var small_word: String = ""
## Creatures this tall or taller get large_word.
@export var large_height: int = 100
## e.g. "Giant". Leave empty to never use a large-size word.
@export var large_word: String = ""
## How likely a size word is to be picked, relative to other candidates.
@export var size_weight: float = 1.0

@export_group("Color")
## How likely the palette's display_name is to be picked.
@export var color_weight: float = 1.0

@export_group("Patterns")
## Pattern name (its file name) -> word, e.g. stripped -> "Striped".
## Patterns not listed use their file name, capitalized.
@export var pattern_words: Dictionary[StringName, String] = {}
## How likely a pattern word is to be picked.
@export var pattern_weight: float = 1.0

@export_group("Counts")
## Words for unusual counts of a part type, e.g. 3 eyes -> "Three-eyed".
@export var count_rules: Array[NameCountRule] = []


## The authored name for this head + torso, or "" if none.
## Use an empty head in a FixedName for headless creatures.
func fixed_name_for(head_id: StringName, torso_id: StringName) -> String:
	for f in fixed_names:
		if f != null and f.head == head_id and f.torso == torso_id:
			return f.name
	return ""


## Word for a pattern name.
func pattern_word(pattern_name: StringName) -> String:
	return pattern_words.get(pattern_name, String(pattern_name).capitalize())
