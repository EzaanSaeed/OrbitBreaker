class_name BulletPickup
extends PowerUp
## Developer B-owned pickup. Existing PowerUp.collect() enforces one effect.

const AMMO_AMOUNT: int = 15

func apply_effect(player: Spaceship) -> void:
	player.restore_ammo(AMMO_AMOUNT)
