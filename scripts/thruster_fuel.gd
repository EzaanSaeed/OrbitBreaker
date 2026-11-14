class_name ThrusterFuel
extends Node
## Limited thruster fuel: the rules and tuning for how fuel drains and refills.
## Owner: Developer A. Lives as a child node "ThrusterFuel" of the Player.
##
## Contract (agreed with Developer B, who owns player.gd):
##   - The Player calls drain(delta) only while it is applying controlled thrust
##     (direction != 0; holding W and S together is direction 0 → no drain).
##   - When is_empty(), the Player applies no controlled thrust. Momentum and
##     planetary gravity are not affected by fuel at all.
##   - ThrusterBooster pickups call refill(amount).
##   - fuel_changed is emitted whenever the value actually changes; GameController
##     forwards it to the HUD (Developer C). Fuel resets with the scene on restart.

signal fuel_changed(current: float, maximum: float)

@export var max_fuel: float = 100.0
## Fuel used per second of thrust: a full tank is ~33 s of holding W or S.
## Retuned 2026-11-14 for the stronger pull, ship drag and denser asteroids:
## autopilot (thrusting ~32% of the time, equal pickup weights) keeps fuel above
## ~20% for 150 s runs; at the old 5/s it ran dry at ~65 s, 4/s at ~90-105 s.
@export var drain_per_second: float = 3.0

var fuel: float = 0.0


func _ready() -> void:
	fuel = max_fuel
	validate_state()


func is_empty() -> bool:
	return fuel <= 0.0


## Use fuel for `delta` seconds of thrust. Never goes below 0.
func drain(delta: float) -> void:
	assert(is_finite(delta) and delta >= 0.0)
	if delta <= 0.0 or is_empty():
		return
	fuel = maxf(0.0, fuel - drain_per_second * delta)
	fuel_changed.emit(fuel, max_fuel)


## Add fuel, capped at max_fuel. Refilling a full tank changes nothing.
func refill(amount: float) -> void:
	assert(is_finite(amount) and amount >= 0.0)
	var before := fuel
	fuel = minf(max_fuel, fuel + maxf(0.0, amount))
	if fuel != before:
		fuel_changed.emit(fuel, max_fuel)


func validate_state() -> void:
	assert(max_fuel > 0.0)
	assert(drain_per_second >= 0.0)
	assert(fuel >= 0.0 and fuel <= max_fuel)
