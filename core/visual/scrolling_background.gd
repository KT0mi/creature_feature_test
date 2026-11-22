## Full-screen scrolling checkerboard (shaders/scrolling_checker.gdshader).
## Put it in a CanvasLayer behind everything (e.g. layer -10) so cameras
## don't move it; it covers the whole viewport.
##
## Pixel-perfect: the scroll position is kept as a float (so slow speeds
## still move) but only its WHOLE-pixel part is sent to the shader, so the
## pattern moves in 1-pixel steps on the game's pixel grid.
@tool
class_name ScrollingBackground
extends ColorRect

const SHADER := preload("res://assets/shaders/scrolling_checker.gdshader")

## Size of one square, in screen pixels.
@export_range(1, 256) var square_size: int = 16:
	set(value):
		square_size = value
		_update_params()
## Scroll speed in pixels per second (0 = still).
@export var scroll_speed: float = 12.0
## Scroll direction in degrees: 0 = right, 90 = down, 45 = down-right...
@export_range(-180.0, 180.0, 1.0) var scroll_angle: float = 30.0
@export var color_a: Color = Color(0.16, 0.17, 0.21):
	set(value):
		color_a = value
		_update_params()
@export var color_b: Color = Color(0.19, 0.20, 0.25):
	set(value):
		color_b = value
		_update_params()

var _scroll := Vector2.ZERO


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # never steals clicks


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	_update_params()


func _process(delta: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(scroll_angle))
	# Wrap around one full checker period (2 squares) so the float never
	# grows large and loses precision in long sessions.
	var period := float(square_size * 2)
	_scroll = (_scroll + dir * scroll_speed * delta).posmod(period)
	if material:
		material.set_shader_parameter("offset", _scroll.floor())


func _update_params() -> void:
	if material == null:
		return
	material.set_shader_parameter("square_size", square_size)
	material.set_shader_parameter("color_a", color_a)
	material.set_shader_parameter("color_b", color_b)
