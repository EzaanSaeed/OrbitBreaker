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

@export var radius: float = 14.0
@export var collision_damage: int = 1

## False after the first impact. (Not listed in V3, but needed to enforce "a
## single collision must not inflict repeated damage".)
var is_active: bool = true


func _ready() -> void:
	validate_state()


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


## Scroll with the world.
func move_left(distance: float) -> void:
	assert(distance >= 0.0)
	position.x -= distance


func is_offscreen() -> bool:
	return global_position.x + radius < 0.0


func validate_state() -> void:
	assert(radius > 0.0)
	assert(collision_damage >= 0)
