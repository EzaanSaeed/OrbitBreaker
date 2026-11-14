@tool
class_name Starfield
extends Node2D
## Parallax star background: three layers of stars that drift left at a
## fraction of the world's scroll speed. Purely visual — no gameplay effect.
## Owner: Developer A.
##
## GameController calls scroll(distance) each physics step with the distance
## the world moved, so the stars speed up with the game and stop on game over.

## Size of the area the stars wrap around in. Grows to the real window size at
## start, so wide browser windows have stars all the way to the right edge.
@export var area: Vector2 = Vector2(960, 540)
## Fixed seed so the sky looks the same every run.
@export var star_seed: int = 7

## One entry per layer: how many stars, how fast relative to the world,
## star radius and brightness. Far layers are slow, small and dim.
const LAYERS := [
	{"count": 90, "speed": 0.08, "size": 0.8, "alpha": 0.35},
	{"count": 45, "speed": 0.2, "size": 1.2, "alpha": 0.6},
	{"count": 18, "speed": 0.45, "size": 1.7, "alpha": 0.9},
]

var _stars: Array[PackedVector2Array] = []
var _offsets: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	if not Engine.is_editor_hint() and is_inside_tree():
		var visible_size := get_viewport_rect().size
		area = Vector2(maxf(area.x, visible_size.x), maxf(area.y, visible_size.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	_stars.clear()
	_offsets.clear()
	for layer in LAYERS:
		var points := PackedVector2Array()
		for i in layer.count:
			points.append(Vector2(rng.randf() * area.x, rng.randf() * area.y))
		_stars.append(points)
		_offsets.append(0.0)
	queue_redraw()


## Move the sky by the distance the world scrolled this step.
func scroll(distance: float) -> void:
	for i in _offsets.size():
		_offsets[i] = fposmod(_offsets[i] + distance * LAYERS[i].speed, area.x)
	queue_redraw()


func _draw() -> void:
	for i in _stars.size():
		var layer: Dictionary = LAYERS[i]
		var color := Color(0.85, 0.9, 1.0, layer.alpha)
		for star in _stars[i]:
			var x := fposmod(star.x - _offsets[i], area.x)
			draw_circle(Vector2(x, star.y), layer.size, color)
