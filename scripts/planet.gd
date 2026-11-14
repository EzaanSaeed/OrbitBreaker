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
## Base colour. Each spawned planet picks one from PALETTE unless set in the editor.
@export var color: Color = Color(0.55, 0.35, 0.85):
	set(value):
		color = value
		queue_redraw()

const PALETTE: Array[Color] = [
	Color(0.55, 0.35, 0.85),   # violet
	Color(0.85, 0.45, 0.3),    # rust
	Color(0.3, 0.6, 0.85),     # ocean blue
	Color(0.4, 0.7, 0.45),     # moss green
	Color(0.8, 0.65, 0.35),    # sand
]
## Chance that a planet has a thin ring (visual only; the hitbox stays round).
const RING_CHANCE: float = 0.35

var _has_ring: bool = false
var _ring_tilt: float = 0.0

## Multiplies every planet's pull. 1.0 in normal play; the debug-only tuning
## presets (scripts/tuning_presets.gd) change it while playtesting.
static var gravity_scale: float = 1.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	validate_state()
	color = PALETTE.pick_random()
	_has_ring = randf() < RING_CHANCE
	_ring_tilt = randf_range(-0.5, 0.5)
	# Each planet gets its own circle so the hitbox always matches `radius`.
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape


func _draw() -> void:
	if _has_ring:
		_draw_ring(PI, TAU)          # back half of the ring, behind the planet
	# Shaded sphere: dark rim, lit body offset toward the light (upper left), highlight.
	draw_circle(Vector2.ZERO, radius, color.darkened(0.45))
	draw_circle(Vector2(-radius, -radius) * 0.12, radius * 0.82, color)
	draw_circle(Vector2(-radius, -radius) * 0.3, radius * 0.45, color.lightened(0.18))
	draw_circle(Vector2(-radius, -radius) * 0.42, radius * 0.16, Color(1, 1, 1, 0.35))
	if _has_ring:
		_draw_ring(0.0, PI)          # front half, over the planet


func _draw_ring(from_angle: float, to_angle: float) -> void:
	draw_set_transform(Vector2.ZERO, _ring_tilt, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, radius * 1.55, from_angle, to_angle, 32, Color(color.lightened(0.4), 0.55), 3.0, true)
	draw_set_transform(Vector2.ZERO)


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
