class_name GameController
extends Node2D
## Owns run state, distance score, difficulty, game over and restart.
## Owner: Developer A. Source: Domain Model V3, §3.
##
## Attached to the root "Main" node of main.tscn. Coordinates World, Spaceship
## and HUD but doesn't do their jobs for them.
##
## Physics order (V3 §5): this node runs BEFORE the Spaceship in every physics
## frame (process_physics_priority = -1), so gravity is applied before the
## Spaceship integrates and clears it.

enum GameState { RUNNING, GAME_OVER }

@export var initial_scroll_speed: float = 180.0
@export var max_scroll_speed: float = 350.0
## Scroll speed gained per pixel travelled. Tunable. At 0.005 the speed goes
## from 180 to 350 over 34 000 px (about 2–3 minutes).
@export var speed_gain_per_distance: float = 0.005
## Once max_scroll_speed is reached, planets and asteroids spawn more often:
## the spawn rate grows by this much per pixel travelled past that point.
## At 0.00003 it doubles over the next ~33 000 px (about 1.5 minutes).
@export var spawn_rate_gain_per_distance: float = 0.00003
## Upper limit on that spawn-rate multiplier (2 = hazards twice as often).
@export var max_spawn_rate_scale: float = 2.0
## Converts pixels travelled into the displayed score.
@export var score_scale: float = 0.1
## The ship dies instantly if its centre leaves [play_area_top, play_area_bottom].
@export var play_area_top: float = 0.0
@export var play_area_bottom: float = 540.0

## Turn off to test against hand-placed planets only.
@export var spawning_enabled: bool = true

## Wired in main.tscn.
@export var world: World
@export var player: Spaceship
@export var hud: HUD
## Optional parallax background; purely visual.
@export var background: Starfield

var game_state: GameState = GameState.RUNNING
## Pixels travelled. Drives difficulty, so bonus points are kept separately.
var distance_score: float = 0.0
## Points from shooting asteroids (Developer B's weapon reports each kill).
var bonus_score: int = 0
var scroll_speed: float = 0.0
## 1.0 until top speed is reached, then rises towards max_spawn_rate_scale.
var spawn_rate_scale: float = 1.0
## Drag on the ship's vertical movement, per second: after letting go, drift
## halves in ~0.35 s instead of sliding forever (0 = no drag). Chosen in playtest
## 2026-11-14. Applied here so Developer B's player.gd stays untouched.
@export var ship_damping: float = 2.0

## Instance ids of asteroids that already earned a bonus this run (never twice).
var _bonus_awarded: Dictionary = {}


func _ready() -> void:
	scroll_speed = initial_scroll_speed
	# Run before the Spaceship each physics frame so gravity lands before it moves.
	process_physics_priority = -1
	validate_state()
	assert(world != null, "GameController.world is not assigned in main.tscn")
	if player != null:
		player.player_died.connect(handle_player_death)
		if hud != null:
			player.health_changed.connect(hud.update_health)
	if hud != null:
		hud.restart_requested.connect(restart_game)
	_connect_weapon_and_fuel()


func _physics_process(delta: float) -> void:
	if game_state != GameState.RUNNING:
		return
	world.update_world(delta, scroll_speed)
	if background != null:
		background.scroll(scroll_speed * delta)
	world.remove_offscreen_objects()
	if spawning_enabled:
		world.update_spawning(delta, spawn_rate_scale)
	if player != null and player.is_alive:
		var drag := -player.vertical_velocity * ship_damping
		player.apply_gravity(world.get_total_gravity_at(player.global_position) + drag)
	update_score(delta)
	update_difficulty(delta)
	check_boundaries()
	if hud != null:
		hud.update_score(get_display_score())


## Advance distance. Has no effect once the run is over.
func update_score(delta: float) -> void:
	assert(delta >= 0.0)
	if game_state != GameState.RUNNING:
		return
	distance_score += scroll_speed * delta


## Raise scroll speed with distance travelled, capped at max_scroll_speed.
## After the cap, keep the pressure rising by spawning hazards more often.
## delta is kept for the V3 signature (and for a time-based curve, if preferred).
func update_difficulty(_delta: float) -> void:
	if game_state != GameState.RUNNING:
		return
	scroll_speed = minf(max_scroll_speed, initial_scroll_speed + distance_score * speed_gain_per_distance)
	var distance_at_max_speed: float = (max_scroll_speed - initial_scroll_speed) / speed_gain_per_distance
	var distance_past_max: float = maxf(0.0, distance_score - distance_at_max_speed)
	spawn_rate_scale = minf(max_spawn_rate_scale, 1.0 + distance_past_max * spawn_rate_gain_per_distance)


## Instant death if the ship leaves the vertical play area.
## (Not listed in V3: the boundary rule needed an owner.)
func check_boundaries() -> void:
	if player == null or not player.is_alive:
		return
	var y: float = player.global_position.y
	if y < play_area_top or y > play_area_bottom:
		player.die()


## Receives Spaceship.player_died.
func handle_player_death() -> void:
	end_game()


## Move to GAME_OVER. Safe to call more than once: only the first call does anything.
func end_game() -> void:
	if game_state == GameState.GAME_OVER:
		return
	game_state = GameState.GAME_OVER
	if hud != null:
		hud.show_game_over(get_display_score())


## Start a fresh run. Reloading the scene resets the world, player, boosts and score.
func restart_game() -> void:
	get_tree().reload_current_scene()


## Score shown to the player: distance points plus asteroid-shooting bonuses.
func get_display_score() -> int:
	return int(distance_score * score_scale) + bonus_score


## Receives Spaceship.asteroid_destroyed(asteroid, score_bonus) from Developer B's
## weapon. Adds the bonus at most once per asteroid, and only while the run is
## active, so the score stays frozen after game over.
func award_asteroid_bonus(asteroid: Node, score_bonus: int) -> void:
	if game_state != GameState.RUNNING or score_bonus <= 0:
		return
	if asteroid != null:
		var id := asteroid.get_instance_id()
		if _bonus_awarded.has(id):
			return
		_bonus_awarded[id] = true
	bonus_score += score_bonus
	if hud != null:
		hud.update_score(get_display_score())


## Hook up the weapon (kill bonuses, ammo display) and the fuel display.
## The HUD parts switch on once Developer C's HUD has update_ammo/update_fuel,
## and fuel once Developer B's Player has its ThrusterFuel node.
func _connect_weapon_and_fuel() -> void:
	if player == null:
		return
	player.asteroid_destroyed.connect(award_asteroid_bonus)
	if hud != null and hud.has_method("update_ammo"):
		player.ammo_changed.connect(Callable(hud, "update_ammo"))
		# The Player emitted its starting ammo before we connected; send it now.
		hud.call("update_ammo", player.ammo)
	var fuel := player.get("fuel") as ThrusterFuel
	if fuel != null and hud != null and hud.has_method("update_fuel"):
		fuel.fuel_changed.connect(Callable(hud, "update_fuel"))
		hud.call("update_fuel", fuel.fuel, fuel.max_fuel)


func validate_state() -> void:
	assert(distance_score >= 0.0)
	assert(bonus_score >= 0)
	assert(scroll_speed > 0.0)
	assert(initial_scroll_speed > 0.0 and initial_scroll_speed <= max_scroll_speed)
	assert(play_area_top < play_area_bottom)
	assert(speed_gain_per_distance > 0.0)
	assert(spawn_rate_gain_per_distance >= 0.0 and max_spawn_rate_scale >= 1.0)
