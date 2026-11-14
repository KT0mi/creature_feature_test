@tool
extends EditorPlugin

const ToolsContext := preload("res://addons/creature_tools/tools_context.gd")
const PaletteInspectorPlugin := preload("res://addons/creature_tools/palette/palette_inspector_plugin.gd")
const PartEditorScreen := preload("res://addons/creature_tools/part/part_editor_screen.gd")

var _context: ToolsContext
var _palette_inspector: EditorInspectorPlugin
## The "Parts" main screen (tab next to 2D / 3D / Script / AssetLib).
var _part_screen: PartEditorScreen


func _enter_tree() -> void:
	_context = ToolsContext.new()
	_palette_inspector = PaletteInspectorPlugin.new(_context)
	add_inspector_plugin(_palette_inspector)
	_part_screen = PartEditorScreen.new(_context, get_undo_redo())
	EditorInterface.get_editor_main_screen().add_child(_part_screen)
	_make_visible(false)
	# Edits made in the regular inspector (sheet, frame_count, sockets...)
	# should show up in the Parts screen too.
	EditorInterface.get_inspector().property_edited.connect(_on_inspector_edited)
	# Re-scan parts/palettes when files change on disk (new part saved, PNG
	# re-exported...), so previews never show stale data.
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_context.mark_dirty)


func _exit_tree() -> void:
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_context.mark_dirty)
	remove_inspector_plugin(_palette_inspector)
	EditorInterface.get_inspector().property_edited.disconnect(_on_inspector_edited)
	if _part_screen:
		_part_screen.queue_free()
		_part_screen = null
	_context.free_registry()
	_context = null


# ------------------------------------------------- "Parts" main screen hooks

func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Parts"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Skeleton2D", "EditorIcons")


func _make_visible(visible: bool) -> void:
	if _part_screen:
		_part_screen.visible = visible
		if visible:
			_part_screen.refresh_from_data()


func _on_inspector_edited(_property: String) -> void:
	if _part_screen and _part_screen.visible:
		_part_screen.refresh_from_data()


## Selecting a PartDef anywhere in the editor opens it in the Parts screen.
func _handles(object: Object) -> bool:
	return object is PartDef


func _edit(object: Object) -> void:
	# null = the selection was cleared; keep showing the last part.
	if _part_screen and object is PartDef:
		_part_screen.edit(object)
