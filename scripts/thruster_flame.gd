class_name ThrusterFlame
extends Node2D
## Engine flames for the ship (visual only). Child of the Player in main.tscn,
## so Developer B's player.gd is untouched. Owner: Developer A.
## Art: Kenney "Space Shooter Remastered" fire12/fire13 (CC0).
##
## - A small rear flame always burns (the ship is always flying forward).
## - Thrusting up shows a flame under the ship; thrusting down, one above it.
##   No flame when out of fuel, when both keys are held, or when dead.

const FRAMES: Array[Texture2D] = [
	preload("res://assets/kenney/effects/fire12.png"),
	preload("res://assets/kenney/effects/fire13.png"),
]
## Seconds per flicker frame.
const FLICKER: float = 0.06
## Flame lengths as a fraction of the 40 px art.
const REAR_LENGTH: float = 0.6
const SIDE_LENGTH: float = 0.55

var _ship: Spaceship
var _rear: Sprite2D
var _below: Sprite2D
var _above: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	_ship = get_parent() as Spaceship
	# The flame art points down with its wide end at the top (the nozzle);
	# offset so each sprite's nozzle sits at its node position.
	_rear = _make_flame(Vector2(-12, 0), PI / 2.0, Vector2(0.75, REAR_LENGTH))   # points left
	_below = _make_flame(Vector2(-3, 11), 0.0, Vector2(0.6, SIDE_LENGTH))       # points down
	_above = _make_flame(Vector2(-3, -11), PI, Vector2(0.6, SIDE_LENGTH))       # points up
	z_index = -1   # behind the ship


func _make_flame(at: Vector2, angle: float, size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = FRAMES[0]
	sprite.centered = true
	sprite.offset = Vector2(0, FRAMES[0].get_height() / 2.0)
	sprite.position = at
	sprite.rotation = angle
	sprite.scale = size
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	_time += delta
	var frame: Texture2D = FRAMES[int(_time / FLICKER) % FRAMES.size()]
	var alive := _ship == null or _ship.is_alive
	var can_thrust := alive and (_ship == null or _ship.fuel == null or not _ship.fuel.is_empty())
	var direction := Input.get_axis("thrust_up", "thrust_down") if can_thrust else 0.0
	_rear.visible = alive
	_below.visible = direction < 0.0   # thrusting up pushes exhaust downward
	_above.visible = direction > 0.0
	for sprite in [_rear, _below, _above]:
		sprite.texture = frame
	# Slight size wobble so the flame looks alive.
	var wobble := 1.0 + 0.12 * sin(_time * 40.0)
	_rear.scale.y = REAR_LENGTH * wobble
	_below.scale.y = SIDE_LENGTH * wobble
	_above.scale.y = SIDE_LENGTH * wobble
