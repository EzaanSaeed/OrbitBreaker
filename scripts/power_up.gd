class_name PowerUp
extends Area2D
## Base class for collectible pickups. Subclasses override apply_effect().
## Owner: TBD (one owner to be agreed, per Domain Model V3 §9).
## Source: Domain Model V3, §3.
##
## Invariant: an effect is applied at most once; a collected pickup can't be
## collected again.

## How far past the left edge the pickup must travel before it counts as offscreen.
@export var offscreen_margin: float = 50.0

var is_collected: bool = false


## Mark collected, apply the effect once, then make the pickup unavailable.
func collect(player: Spaceship) -> void:
	if is_collected:
		return
	is_collected = true
	apply_effect(player)
	# Deferred: collision flags can't change during a physics callback.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()


## Override in subclasses. Called exactly once, by collect().
func apply_effect(_player: Spaceship) -> void:
	push_error("%s must override PowerUp.apply_effect()" % get_script().resource_path)


## Scroll with the world.
func move_left(distance: float) -> void:
	assert(distance >= 0.0)
	position.x -= distance


func is_offscreen() -> bool:
	return global_position.x < -offscreen_margin
