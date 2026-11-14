@tool
class_name Planet
extends Area2D
## A gravity source and instant-death collision hazard.
## Owner: Developer A. Source: Domain Model V3, §3.
##
## Collision rule (approved): touching a planet kills the ship regardless of health.
##
## @tool so planets are drawn in the editor too; gameplay code only runs in game.

@export var radius: float = 35.0:
	set(value):
		radius = value
		queue_redraw()
## Default pull. 2 250 000 (x1.5 of the original 1 500 000, chosen in playtest
## 2026-11-14 together with ship drag 2.0 / thrust 750 / top speed 320) gives
## ~225 px/s² at 100 px against 750 px/s² of thrust.
const DEFAULT_GRAVITY_STRENGTH := 2250000.0
@export var gravity_strength: float = DEFAULT_GRAVITY_STRENGTH
## Floor on distance² so gravity stays finite when the ship is very close.
@export var min_distance_squared: float = 2500.0
## Placeholder look until real art exists.
@export var color: Color = Color(0.55, 0.35, 0.85):
	set(value):
		color = value
		queue_redraw()

## Multiplies every planet's pull. 1.0 in normal play; the debug-only tuning
## presets (scripts/tuning_presets.gd) change it while playtesting.
static var gravity_scale: float = 1.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	validate_state()
	# Each planet gets its own circle so the hitbox always matches `radius`.
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)


## Signed vertical acceleration this planet applies to a ship at ship_position.
## Negative pulls up, positive pulls down (screen space). Inverse-square
## magnitude, vertical component only — not a full orbital simulation.
func get_gravity_at(ship_position: Vector2) -> float:
	var offset: Vector2 = global_position - ship_position
	var distance_squared: float = maxf(offset.length_squared(), min_distance_squared)
	var gravity_accel: float = offset.normalized().y * gravity_strength * gravity_scale / distance_squared
	assert(is_finite(gravity_accel))
	return gravity_accel


## Scroll with the world.
func move_left(distance: float) -> void:
	assert(distance >= 0.0)
	position.x -= distance


## True once the whole planet has left the screen on the left side.
func is_offscreen() -> bool:
	return global_position.x + radius < 0.0


func validate_state() -> void:
	assert(radius > 0.0)
	assert(gravity_strength >= 0.0)
	assert(min_distance_squared > 0.0)
