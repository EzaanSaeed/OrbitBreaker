class_name ThrusterBooster
extends PowerUp
## Pickup that refills thruster fuel. Does not affect world scrolling speed.
## Effect owner: Developer A (fuel rules).
##
## Changed for the fuel update: this used to give a temporary 1.5× thrust boost.
## Collecting it at full fuel still uses the pickup up (same as HealthBooster).

## Fuel restored per pickup (max_fuel is 100). Tuned with drain 5/s; see thruster_fuel.gd.
@export var fuel_amount: float = 50.0


func _ready() -> void:
	assert(fuel_amount > 0.0)


func apply_effect(player: Spaceship) -> void:
	player.restore_fuel(fuel_amount)
