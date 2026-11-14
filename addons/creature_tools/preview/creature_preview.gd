##Reusable Widget: Shows a row of baked creatures.
@tool
extends HFlowContainer

## Integer zoom (1 = one screen pixel per art pixel).
var zoom: int = 3:
	set(value):
		zoom = maxi(value, 1)
		_resize_all()

# Each entry: [TextureRect, frame size] so zoom changes can resize them.
var _items: Array = []

## Bakes and shows `genomes`. `palettes` (id -> CreaturePalette) and `key`
## are passed straight to CreatureBaker. `captions` is optional, one per
## genome. Only the first animation frame is shown.
func show_genomes(genomes: Array[Genome], palettes: Dictionary, key: CreaturePalette,
		captions: PackedStringArray = PackedStringArray()) -> void:
	for child in get_children():
		child.queue_free()
	_items.clear()
	for i in genomes.size():
		var baked := CreatureBaker.bake(genomes[i], palettes, key)
		var frame := AtlasTexture.new()
		frame.atlas = baked.texture
		frame.region = Rect2(Vector2.ZERO, baked.frame_size)

		var rect := TextureRect.new()
		rect.texture = frame
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Nearest filtering = crisp pixels whatever the editor's settings.
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var box := VBoxContainer.new()
		box.add_child(rect)
		if i < captions.size():
			var label := Label.new()
			label.text = captions[i]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 10)
			box.add_child(label)
		add_child(box)
		_items.append([rect, baked.frame_size])
	_resize_all()


func _resize_all() -> void:
	for item in _items:
		item[0].custom_minimum_size = Vector2(item[1] * zoom)
