@tool
class_name Asteroid
extends Area2D
## An obstacle that damages the ship's health instead of ending the run outright.
## Owner: Developer A. Source: Domain Model V3, §3.
##
## Collision rule (approved): damage health once per impact, then deactivate.
## Whoever handles the collision should do:
##     if asteroid.is_active:
##         player.take_damage(asteroid.get_collision_damage())
##         asteroid.deactivate()
##
## @tool so asteroids are drawn in the editor too; gameplay code only runs in game.

## Hitbox radius. World randomises this per spawn before adding the asteroid.
@export var radius: float = 14.0:
	set(value):
		radius = value
		_build_outline()
## Health scale is 0–100 (Spaceship.max_health), so 25 = four hits to die.
@export var collision_damage: int = 25
## Fallback look if no meteor texture is available.
@export var color: Color = Color(0.55, 0.52, 0.48):
	set(value):
		color = value
		queue_redraw()
## Maximum spin in radians per second (direction and speed are random).
@export var max_spin: float = 1.5

## False after the first impact. (Not listed in V3, but needed to enforce "a
## single collision must not inflict repeated damage".)
var is_active: bool = true

## Kenney "Space Shooter Remastered" meteors (CC0, assets/kenney/LICENSE-kenney.txt).
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/kenney/meteors/meteorGrey_big1.png"),
	preload("res://assets/kenney/meteors/meteorGrey_big2.png"),
	preload("res://assets/kenney/meteors/meteorGrey_big3.png"),
	preload("res://assets/kenney/meteors/meteorGrey_big4.png"),
	preload("res://assets/kenney/meteors/meteorBrown_big1.png"),
	preload("res://assets/kenney/meteors/meteorBrown_big2.png"),
	preload("res://assets/kenney/meteors/meteorBrown_big3.png"),
	preload("res://assets/kenney/meteors/meteorBrown_big4.png"),
]
## The sprite is drawn this much wider than the hitbox, so the rock's edge
## lines up with where collisions actually happen (meteor art isn't round).
const VISUAL_SCALE: float = 1.15

var _outline: PackedVector2Array = PackedVector2Array()
var _spin: float = 0.0
var _texture: Texture2D = TEXTURES.pick_random()

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_build_outline()
	if Engine.is_editor_hint():
		return
	validate_state()
	# Each asteroid gets its own circle so the hitbox always matches `radius`.
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape
	_spin = randf_range(-max_spin, max_spin)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	rotation += _spin * delta


func _draw() -> void:
	if _texture != null:
		var size := _texture.get_size()
		var fit := radius * 2.0 * VISUAL_SCALE / maxf(size.x, size.y)
		draw_texture_rect(_texture, Rect2(-size * fit / 2.0, size * fit), false)
	elif _outline.size() >= 3:
		draw_colored_polygon(_outline, color)


func get_collision_damage() -> int:
	return collision_damage


## Stop colliding and hide. World removes inactive asteroids on its next cleanup.
func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	# Deferred: collision flags can't change during a physics callback.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()
	# Visual only: a short burst where the asteroid was (shot or rammed).
	if not Engine.is_editor_hint() and is_inside_tree() and get_parent() != null:
		var burst := AsteroidBurst.new()
		burst.position = position
		burst.size = radius
		get_parent().add_child.call_deferred(burst)


## Scroll with the world.
func move_left(distance: float) -> void:
	assert(distance >= 0.0)
	position.x -= distance


func is_offscreen() -> bool:
	return global_position.x + radius < 0.0


func validate_state() -> void:
	assert(radius > 0.0)
	assert(collision_damage >= 0)


## Lumpy outline around the hitbox circle (between 85% and 110% of radius).
func _build_outline() -> void:
	var points := PackedVector2Array()
	var count := 9
	for i in count:
		var angle := TAU * i / count
		points.append(Vector2.from_angle(angle) * radius * randf_range(0.85, 1.1))
	_outline = points
	queue_redraw()
