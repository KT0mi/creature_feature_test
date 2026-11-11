@tool
extends EditorPlugin

const ToolsContext := preload("res://addons/creature_tools/tools_context.gd")
const PaletteInspectorPlugin := preload("res://addons/creature_tools/palette/palette_inspector_plugin.gd")

var _context: ToolsContext
var _palette_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_context = ToolsContext.new()
	_palette_inspector = PaletteInspectorPlugin.new(_context)
	add_inspector_plugin(_palette_inspector)
	# Re-scan parts/palettes when files change on disk (new part saved, PNG
	# re-exported...), so previews never show stale data.
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_context.mark_dirty)


func _exit_tree() -> void:
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_context.mark_dirty)
	remove_inspector_plugin(_palette_inspector)
	_context.free_registry()
	_context = null
