class_name ThrusterBooster
extends PowerUp
## Pickup that temporarily strengthens vertical thrust. Does not affect world
## scrolling speed.
## Owner: Developer B (proposed). Source: Domain Model V3, §3.
##
## Approved: 1.5x thrust; picking up another refreshes the duration instead of
## stacking; the boost resets on death/restart (automatic with a scene reload).

@export var thrust_multiplier: float = 1.5
@export var duration: float = 5.0


func _ready() -> void:
	assert(thrust_multiplier > 1.0)
	assert(duration > 0.0)


## Body as specified in Domain Model V3.
func apply_effect(player: Spaceship) -> void:
	player.apply_thrust_boost(thrust_multiplier, duration)
