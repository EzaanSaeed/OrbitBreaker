class_name HealthBooster
extends PowerUp
## Pickup that restores health, capped at max_health.
## Owner: Developer B (proposed). Source: Domain Model V3, §3.

## Health scale is 0–100 (Spaceship.max_health), so 25 = undoes one asteroid hit.
@export var healing_amount: int = 25


func _ready() -> void:
	assert(healing_amount > 0)


## Body as specified in Domain Model V3. Capping at max_health is
## Spaceship.restore_health()'s job.
func apply_effect(player: Spaceship) -> void:
	player.restore_health(healing_amount)
