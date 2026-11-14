class_name TuningPresets
extends Node
## DEBUG-ONLY playtest tool: press 0-5 during a run to switch how heavy planets
## pull and how tight the ship handles. Removes itself in release/web builds.
## Owner: Developer A. Lives as a child of Main.
##
## 0 is the baseline the game shipped with (git tag tuning-baseline-2026-11-14).
## The chosen preset is kept across restarts (static) and shown in a corner label.

const PRESETS := [
	# name,        planet pull ×, ship thrust, ship top speed, ship drag /s
	{"name": "Baseline", "gravity": 1.0, "thrust": 600.0, "max_speed": 300.0, "drag": 0.0},
	{"name": "Light",    "gravity": 1.0, "thrust": 650.0, "max_speed": 300.0, "drag": 1.0},
	{"name": "Medium",   "gravity": 1.3, "thrust": 750.0, "max_speed": 320.0, "drag": 2.0},
	{"name": "Strong",   "gravity": 1.7, "thrust": 900.0, "max_speed": 340.0, "drag": 3.0},
	{"name": "Heavy",    "gravity": 2.2, "thrust": 1100.0, "max_speed": 360.0, "drag": 4.5},
	{"name": "Extreme",  "gravity": 3.0, "thrust": 1400.0, "max_speed": 380.0, "drag": 6.0},
]

static var current: int = 0

var _label: Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 512)
	_label.add_theme_font_size_override("font_size", 13)
	_label.modulate = Color(1, 1, 1, 0.75)
	layer.add_child(_label)
	# Wait one frame so the Player has finished its own _ready.
	apply_preset.call_deferred(current)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index := key.physical_keycode - KEY_0
	if index >= 0 and index < PRESETS.size():
		apply_preset(index)
		get_viewport().set_input_as_handled()


func apply_preset(index: int) -> void:
	current = index
	var p: Dictionary = PRESETS[index]
	Planet.gravity_scale = p.gravity
	var controller := get_parent() as GameController
	if controller != null:
		controller.ship_damping = p.drag
		if controller.player != null:
			controller.player.thrust_power = p.thrust
			controller.player.max_vertical_speed = p.max_speed
	if _label != null:
		_label.text = "TUNING [%d] %s   pull x%.1f  thrust %d  top speed %d  drag %.1f   (keys 0-5)" % [
			index, p.name, p.gravity, p.thrust, p.max_speed, p.drag]
	print("Tuning preset %d (%s): %s" % [index, p.name, p])
