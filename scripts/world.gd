class_name World
extends Node2D
## Owns active planets, asteroids and power-ups: spawning, scrolling, cleanup.
## Owner: Developer A. Source: Domain Model V3, §3.
##
## Lives as the "World" child of the Main scene. GameController drives it each
## physics step; World never reads input or touches the HUD.
##
## Invariant: once an object is removed from these arrays it no longer affects
## gravity or collision.

@export var planet_scene: PackedScene
@export var asteroid_scene: PackedScene
@export var health_booster_scene: PackedScene
@export var thruster_booster_scene: PackedScene

## Seconds between spawn attempts. Tunable.
@export var spawn_interval: float = 3.0
## Spawn just past the right edge of the 960 px viewport.
@export var spawn_x: float = 1050.0
@export var spawn_y_min: float = 90.0
@export var spawn_y_max: float = 450.0

var active_planets: Array[Planet] = []
var active_asteroids: Array[Asteroid] = []
var active_powerups: Array[PowerUp] = []


func _ready() -> void:
	validate_state()


func spawn_planet() -> Planet:
	# TODO(Dev A, Logic stage): instantiate planet_scene at (spawn_x, random y in
	# [spawn_y_min, spawn_y_max]), add_child, append to active_planets.
	return null


func spawn_asteroid() -> Asteroid:
	# TODO(Dev A, Logic stage)
	return null


func spawn_powerup() -> PowerUp:
	# TODO(Dev A, Logic stage): choose a HealthBooster or ThrusterBooster scene.
	return null


## Scroll every active object left. scroll_speed comes from GameController,
## which owns difficulty. (V3 lists update_world(delta); scroll_speed was added
## so World doesn't keep a second copy of it.)
func update_world(delta: float, scroll_speed: float) -> void:
	assert(delta >= 0.0)
	assert(scroll_speed > 0.0)
	var distance: float = scroll_speed * delta
	for planet in active_planets:
		planet.move_left(distance)
	for asteroid in active_asteroids:
		asteroid.move_left(distance)
	for powerup in active_powerups:
		powerup.move_left(distance)


## Free objects that are offscreen or used up (hit asteroids, collected pickups).
func remove_offscreen_objects() -> void:
	for i in range(active_planets.size() - 1, -1, -1):
		var planet: Planet = active_planets[i]
		if planet.is_offscreen():
			active_planets.remove_at(i)
			planet.queue_free()
	for i in range(active_asteroids.size() - 1, -1, -1):
		var asteroid: Asteroid = active_asteroids[i]
		if asteroid.is_offscreen() or not asteroid.is_active:
			active_asteroids.remove_at(i)
			asteroid.queue_free()
	for i in range(active_powerups.size() - 1, -1, -1):
		var powerup: PowerUp = active_powerups[i]
		if powerup.is_offscreen() or powerup.is_collected:
			active_powerups.remove_at(i)
			powerup.queue_free()


## Sum of every active planet's vertical gravity at ship_position.
## (Not listed in V3: it's the "Main sums contributions" step from §5.)
func get_total_gravity_at(ship_position: Vector2) -> float:
	var total: float = 0.0
	for planet in active_planets:
		total += planet.get_gravity_at(ship_position)
	return total


func validate_state() -> void:
	assert(spawn_interval > 0.0)
	assert(spawn_y_min < spawn_y_max)
