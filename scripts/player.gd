class_name Player
extends Area2D
## Owns vertical movement and health. The world owns all environmental forces.
## Call apply_gravity() before this player's physics tick; calls accumulate
## for one tick, in pixels/second squared (positive points downward).
## World gravity producers must use process_physics_priority < 100; this scene
## integrates at priority 100. Lower physics priorities execute first.

signal player_died
signal health_changed(current: int, maximum: int)

@export var thrust_power: float = 600.0
@export var max_vertical_speed: float = 300.0
@export var max_health: int = 100
@export var thrust_multiplier: float = 1.0

var health: int = 100
var is_alive: bool = true
var vertical_velocity: float = 0.0

var gravity_acceleration: float = 0.0
var _thrust_boost_remaining: float = 0.0
var _fixed_x: float
var _standalone: bool = false


func _ready() -> void:
	_assert_configuration()
	health = max_health
	is_alive = true
	_standalone = get_tree().current_scene == self
	if _standalone:
		position = get_viewport_rect().size * Vector2(0.25, 0.5)
	_fixed_x = position.x
	_assert_state()
	health_changed.emit(health, max_health)
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(
		PackedVector2Array([Vector2(16, 0), Vector2(-10, -10), Vector2(-10, 10)]),
		Color.CYAN
	)


func _physics_process(delta: float) -> void:
	_assert_configuration()
	# A runtime speed-limit reduction must clamp before checking the invariant.
	vertical_velocity = clampf(vertical_velocity, -max_vertical_speed, max_vertical_speed)
	_assert_state()
	if not is_alive:
		gravity_acceleration = 0.0
		return

	var thrust: float = float(
		Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	) - float(
		Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	)
	# Integrate only the boosted portion if the timer expires during this tick.
	var boosted_delta: float = minf(delta, _thrust_boost_remaining)
	var thrust_delta: float = delta + (thrust_multiplier - 1.0) * boosted_delta
	vertical_velocity = clampf(
		vertical_velocity + thrust * thrust_power * thrust_delta + gravity_acceleration * delta,
		-max_vertical_speed, max_vertical_speed
	)
	_thrust_boost_remaining = maxf(0.0, _thrust_boost_remaining - delta)
	if _thrust_boost_remaining == 0.0:
		thrust_multiplier = 1.0
	gravity_acceleration = 0.0
	position = Vector2(_fixed_x, position.y + vertical_velocity * delta)

	# Keep F6 testing visible. Embedded players leave world boundaries to the world.
	if _standalone:
		var bottom: float = maxf(12.0, get_viewport_rect().size.y - 12.0)
		var bounded_y: float = clampf(position.y, 12.0, bottom)
		if bounded_y != position.y:
			position.y = bounded_y
			vertical_velocity = 0.0
	_assert_state()


func apply_gravity(acceleration: float) -> void:
	assert(is_finite(acceleration), "Gravity acceleration must be finite.")
	if is_alive:
		gravity_acceleration += acceleration
		assert(is_finite(gravity_acceleration), "Accumulated gravity must be finite.")


func apply_thrust_boost(multiplier: float, duration: float) -> void:
	assert(is_finite(multiplier) and multiplier > 1.0,
		"Boost multiplier must be finite and greater than one.")
	assert(is_finite(duration) and duration > 0.0,
		"Boost duration must be finite and positive.")
	# Assertions are disabled in release builds; reject invalid input there too.
	if not is_finite(multiplier) or multiplier <= 1.0:
		return
	if not is_finite(duration) or duration <= 0.0 or not is_alive:
		return
	thrust_multiplier = multiplier
	_thrust_boost_remaining = duration
	_assert_configuration()
	_assert_state()


func take_damage(amount: int) -> void:
	assert(amount >= 0, "Damage must be nonnegative.")
	if not is_alive or amount <= 0:
		return
	health = maxi(0, health - amount)
	if health == 0:
		die()
	else:
		_assert_state()
		health_changed.emit(health, max_health)


func restore_health(amount: int) -> void:
	assert(amount >= 0, "Healing must be nonnegative.")
	if not is_alive or amount <= 0:
		return
	var previous_health: int = health
	health += mini(amount, max_health - health)
	_assert_state()
	if health != previous_health:
		health_changed.emit(health, max_health)


func die() -> void:
	if not is_alive:
		return
	health = 0
	is_alive = false
	vertical_velocity = 0.0
	gravity_acceleration = 0.0
	_thrust_boost_remaining = 0.0
	thrust_multiplier = 1.0
	set_physics_process(false)
	# Deferred because damage may be delivered from a physics callback.
	$CollisionShape2D.set_deferred("disabled", true)
	hide()
	_assert_state()
	health_changed.emit(health, max_health)
	player_died.emit()


func _assert_configuration() -> void:
	assert(max_health > 0, "Maximum health must be positive.")
	assert(is_finite(max_vertical_speed) and max_vertical_speed > 0.0,
		"Maximum vertical speed must be finite and positive.")
	assert(is_finite(thrust_power) and thrust_power >= 0.0,
		"Thrust power must be finite and nonnegative.")

	assert(is_finite(thrust_multiplier) and thrust_multiplier >= 1.0,
		"Thrust multiplier must be finite and at least one.")


func _assert_state() -> void:
	assert(is_finite(_thrust_boost_remaining) and _thrust_boost_remaining >= 0.0,
		"Boost time must be finite and nonnegative.")
	assert(is_alive or (_thrust_boost_remaining == 0.0 and thrust_multiplier == 1.0),
		"Dead players cannot retain a boost.")
	assert(health >= 0 and health <= max_health, "Health is outside its bounds.")
	assert(health != 0 or not is_alive, "A player with zero health must be dead.")
	assert(is_finite(vertical_velocity), "Velocity must be finite.")
	assert(absf(vertical_velocity) <= max_vertical_speed, "Vertical speed exceeds its limit.")
