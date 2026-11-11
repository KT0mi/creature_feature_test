## Adds the palette preview panel at the bottom of the inspector whenever a
## CreaturePalette resource is being edited.
@tool
extends EditorInspectorPlugin

const PalettePreviewPanel := preload("res://addons/creature_tools/palette/palette_preview_panel.gd")

var _context  # ToolsContext (untyped: preloaded scripts can't be used as types here)


func _init(context) -> void:
	_context = context


func _can_handle(object: Object) -> bool:
	return object is CreaturePalette


func _parse_end(object: Object) -> void:
	add_custom_control(PalettePreviewPanel.new(_context, object))
