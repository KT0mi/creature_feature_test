## Adds the card preview panel at the TOP of the inspector whenever a
## BattleCard resource is being edited (on top so the board stays in view
## while you change the card's other properties below it).
@tool
extends EditorInspectorPlugin

const CardPreviewPanel := preload("res://addons/creature_tools/card/card_preview_panel.gd")

var _undo: EditorUndoRedoManager


func _init(undo: EditorUndoRedoManager) -> void:
	_undo = undo


func _can_handle(object: Object) -> bool:
	return object is BattleCard


func _parse_begin(object: Object) -> void:
	add_custom_control(CardPreviewPanel.new(object, _undo))
