class_name Spaceship
extends Area2D
## The player-controlled spaceship.
## Owner: Developer B. Source: Domain Model V3, §3 and §5.
##
## DOMAIN CONTRACT. Properties, signals, method signatures and invariants are
## agreed. Bodies marked TODO(Dev B) are filled in during the Logic stage.
##
## Sign convention (shared with Planet.get_gravity_at): screen space, so
## NEGATIVE = up and POSITIVE = down for thrust direction, gravity and velocity.
##
## Update order: GameController applies gravity BEFORE this node's
## _physics_process runs (GameController uses process_physics_priority = -1).
## update_movement() consumes gravity_acceleration and then resets it to 0.

signal player_died
signal health_changed(current: int, maximum: int)

@export var thrust_power: float = 650.0
@export var max_vertical_speed: float = 350.0
@export var max_health: int = 3

var vertical_velocity: float = 0.0
## External acceleration accumulated during the current physics step.
var gravity_acceleration: float = 0.0
var health: int = 0
var is_alive: bool = true
## 1.0 = no boost. Always >= 1.0 (boost-only system).
var thrust_multiplier: float = 1.0
## Seconds left on the active thrust boost; 0 when none is active.
## (Not listed in V3, but needed so boosts can expire.)
var boost_time_remaining: float = 0.0


func _ready() -> void:
	health = max_health
	validate_state()


## Set thrust from input. direction is in [-1, 1]: -1 = full up, +1 = full down.
func apply_thrust(direction: float) -> void:
	assert(direction >= -1.0 and direction <= 1.0)
	# TODO(Dev B)


## Add a signed vertical acceleration contribution for this physics step.
func apply_gravity(acceleration: float) -> void:
	assert(is_finite(acceleration))
	# TODO(Dev B)


## Advance velocity and position using frame-independent timing, clamp
## velocity to max_vertical_speed, tick the boost timer, then reset gravity.
func update_movement(delta: float) -> void:
	assert(delta >= 0.0)
	# TODO(Dev B)


## Body as written in Domain Model V3 §6.
func take_damage(amount: int) -> void:
	assert(amount >= 0)
	if not is_alive:
		return
	health = clampi(health - amount, 0, max_health)
	assert(health >= 0 and health <= max_health)
	health_changed.emit(health, max_health)
	if health == 0:
		die()


## Heal without exceeding max_health. Emits health_changed.
func restore_health(amount: int) -> void:
	assert(amount >= 0)
	# TODO(Dev B)


## Start or refresh a temporary thrust boost. Refreshes the timer rather than
## stacking (approved in §9).
func apply_thrust_boost(multiplier: float, duration: float) -> void:
	assert(multiplier >= 1.0)
	assert(duration > 0.0)
	# TODO(Dev B)


## Mark the ship dead and emit player_died AT MOST ONCE. Used for planet hits
## and boundary exits (instant death), and for health reaching 0.
func die() -> void:
	# TODO(Dev B)
	pass


## Body as written in Domain Model V3 §6. Asserts run in debug builds only.
func validate_state() -> void:
	assert(max_health > 0)
	assert(health >= 0 and health <= max_health)
	assert(thrust_power >= 0.0)
	assert(max_vertical_speed > 0.0)
	assert(abs(vertical_velocity) <= max_vertical_speed + 0.001)
	assert(thrust_multiplier >= 1.0)
	assert(health > 0 or not is_alive)
