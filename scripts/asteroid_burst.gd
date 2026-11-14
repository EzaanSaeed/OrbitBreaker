class_name AsteroidBurst
extends Node2D
## Short visual burst when an asteroid is destroyed: a bright flash plus a few
## tiny rock fragments flying apart. Purely visual, frees itself after ~0.4 s.
## Owner: Developer A. Art: Kenney "Space Shooter Remastered" (CC0).

const FLASH: Texture2D = preload("res://assets/kenney/effects/star2.png")
const FRAGMENTS: Array[Texture2D] = [
	preload("res://assets/kenney/meteors/meteorGrey_tiny1.png"),
	preload("res://assets/kenney/meteors/meteorGrey_tiny2.png"),
	preload("res://assets/kenney/meteors/meteorBrown_tiny1.png"),
	preload("res://assets/kenney/meteors/meteorBrown_tiny2.png"),
]
const DURATION: float = 0.4

## Radius of the destroyed asteroid; scales the effect.
var size: float = 14.0


func _ready() -> void:
	var flash := Sprite2D.new()
	flash.texture = FLASH
	flash.modulate = Color(1.0, 0.85, 0.5)
	flash.scale = Vector2.ONE * size / 20.0
	add_child(flash)
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector2.ONE * size / 7.0, DURATION * 0.6)
	tween.tween_property(flash, "modulate:a", 0.0, DURATION * 0.6)
	tween.tween_property(flash, "rotation", PI / 4.0, DURATION * 0.6)
	for i in 4:
		var piece := Sprite2D.new()
		piece.texture = FRAGMENTS.pick_random()
		piece.scale = Vector2.ONE * clampf(size / 18.0, 0.5, 1.0)
		add_child(piece)
		var direction := Vector2.from_angle(TAU * i / 4.0 + randf_range(-0.5, 0.5))
		tween.tween_property(piece, "position", direction * size * 2.2, DURATION)
		tween.tween_property(piece, "rotation", randf_range(-3.0, 3.0), DURATION)
		tween.tween_property(piece, "modulate:a", 0.0, DURATION)
	tween.chain().tween_callback(queue_free)
