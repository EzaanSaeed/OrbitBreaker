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
@export var asteroid_scene: PackedScene = preload("res://scenes/asteroid.tscn")
## Developer B's booster scenes. While both are empty, no power-ups spawn.
@export var health_booster_scene: PackedScene
@export var thruster_booster_scene: PackedScene

@export_group("Spawn timing")
## Seconds between planet spawn attempts. Tunable.
@export var spawn_interval: float = 3.0
## Seconds between asteroid spawn attempts. Tunable.
@export var asteroid_spawn_interval: float = 1.5
## Seconds between power-up spawn attempts. Tunable.
@export var powerup_spawn_interval: float = 8.0

@export_group("Spawn area")
## Spawn just past the right edge of the 960 px viewport.
@export var spawn_x: float = 1050.0
## Planets and power-ups spawn between these heights.
@export var spawn_y_min: float = 90.0
@export var spawn_y_max: float = 450.0
## Asteroids use a taller band so hugging the top/bottom edge isn't a free ride.
@export var asteroid_spawn_y_min: float = 20.0
@export var asteroid_spawn_y_max: float = 520.0
@export var asteroid_radius_min: float = 10.0
@export var asteroid_radius_max: float = 18.0

@export_group("Fairness")
## Free space kept between a new object and every existing one, so there is
## always room for the ship (24 px wide) to pass. Tunable.
@export var min_spawn_gap: float = 60.0
## Random heights tried before a spawn is skipped for this tick.
@export var spawn_attempts: int = 8
## Treated as the pickup's size for spacing purposes (PowerUp has no radius).
@export var powerup_clearance_radius: float = 16.0

var active_planets: Array[Planet] = []
var active_asteroids: Array[Asteroid] = []
var active_powerups: Array[PowerUp] = []

var _planet_timer: float = 0.0
var _asteroid_timer: float = 0.0
var _powerup_timer: float = 0.0


func _ready() -> void:
	validate_state()
	# Track objects placed in the editor (e.g. a test planet) like spawned ones.
	for child in get_children():
		if child is Planet:
			active_planets.append(child)
		elif child is Asteroid:
			active_asteroids.append(child)
		elif child is PowerUp:
			active_powerups.append(child)


## Advance the spawn timers and spawn whatever is due. Called by GameController
## each physics step while the run is active. (Not listed in V3: World owns
## spawning, so it also owns the timers.)
## hazard_rate_scale (>= 1, from GameController's difficulty) makes planets and
## asteroids come more often; power-ups keep their own rate.
func update_spawning(delta: float, hazard_rate_scale: float = 1.0) -> void:
	assert(delta >= 0.0)
	assert(hazard_rate_scale >= 1.0)
	var planet_interval := spawn_interval / hazard_rate_scale
	var asteroid_interval := asteroid_spawn_interval / hazard_rate_scale
	_planet_timer += delta
	if _planet_timer >= planet_interval:
		_planet_timer -= planet_interval
		spawn_planet()
	_asteroid_timer += delta
	if _asteroid_timer >= asteroid_interval:
		_asteroid_timer -= asteroid_interval
		spawn_asteroid()
	_powerup_timer += delta
	if _powerup_timer >= powerup_spawn_interval:
		_powerup_timer -= powerup_spawn_interval
		spawn_powerup()


## Spawn a planet just off the right edge at a free height in the play area.
## Returns null (and spawns nothing) if no fair spot was found this time.
func spawn_planet() -> Planet:
	if planet_scene == null:
		push_error("World.planet_scene is not set")
		return null
	var planet := planet_scene.instantiate() as Planet
	var y := _find_free_spawn_y(planet.radius, spawn_y_min, spawn_y_max)
	if is_nan(y):
		planet.free()
		return null
	planet.position = Vector2(spawn_x, y)
	add_child(planet)
	active_planets.append(planet)
	return planet


## Spawn an asteroid of random size at a free height. Returns null if no fair spot.
func spawn_asteroid() -> Asteroid:
	if asteroid_scene == null:
		push_error("World.asteroid_scene is not set")
		return null
	var radius := randf_range(asteroid_radius_min, asteroid_radius_max)
	var y := _find_free_spawn_y(radius, asteroid_spawn_y_min, asteroid_spawn_y_max)
	if is_nan(y):
		return null
	var asteroid := asteroid_scene.instantiate() as Asteroid
	asteroid.radius = radius
	asteroid.position = Vector2(spawn_x, y)
	add_child(asteroid)
	active_asteroids.append(asteroid)
	return asteroid


## Spawn a random booster at a free height. Returns null if Developer B's
## booster scenes aren't assigned yet, or if no fair spot was found.
func spawn_powerup() -> PowerUp:
	var choices: Array[PackedScene] = []
	if health_booster_scene != null:
		choices.append(health_booster_scene)
	if thruster_booster_scene != null:
		choices.append(thruster_booster_scene)
	if choices.is_empty():
		return null
	var y := _find_free_spawn_y(powerup_clearance_radius, spawn_y_min, spawn_y_max)
	if is_nan(y):
		return null
	var powerup := choices.pick_random().instantiate() as PowerUp
	powerup.position = Vector2(spawn_x, y)
	add_child(powerup)
	active_powerups.append(powerup)
	return powerup


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
	assert(asteroid_spawn_interval > 0.0)
	assert(powerup_spawn_interval > 0.0)
	assert(spawn_y_min < spawn_y_max)
	assert(asteroid_spawn_y_min < asteroid_spawn_y_max)
	assert(asteroid_radius_min > 0.0 and asteroid_radius_min <= asteroid_radius_max)
	assert(min_spawn_gap >= 0.0)
	assert(spawn_attempts > 0)


## Try a few random heights in [y_min, y_max] and return the first one where an
## object of this radius keeps min_spawn_gap from everything active.
## Returns NAN if none of the attempts was clear.
func _find_free_spawn_y(radius: float, y_min: float, y_max: float) -> float:
	for _attempt in spawn_attempts:
		var y := randf_range(y_min, y_max)
		if _is_spawn_point_clear(Vector2(spawn_x, y), radius):
			return y
	return NAN


func _is_spawn_point_clear(point: Vector2, radius: float) -> bool:
	for planet in active_planets:
		if point.distance_to(planet.position) < radius + planet.radius + min_spawn_gap:
			return false
	for asteroid in active_asteroids:
		if point.distance_to(asteroid.position) < radius + asteroid.radius + min_spawn_gap:
			return false
	for powerup in active_powerups:
		if point.distance_to(powerup.position) < radius + powerup_clearance_radius + min_spawn_gap:
			return false
	return true
