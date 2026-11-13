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
## Converts pixels travelled into the displayed score.
@export var score_scale: float = 0.1
## The ship dies instantly if its centre leaves [play_area_top, play_area_bottom].
@export var play_area_top: float = 0.0
@export var play_area_bottom: float = 540.0

## Turn off to test against hand-placed planets only.
@export var spawning_enabled: bool = true

## Wired in main.tscn. player and hud may be null until Developer B's scenes land.
@export var world: World
@export var player: Spaceship
@export var hud: HUD
## TEMPORARY: on-screen readout for testing until the HUD exists. Delete with the node.
@export var debug_label: Label

var game_state: GameState = GameState.RUNNING
var distance_score: float = 0.0
var scroll_speed: float = 0.0

var _last_gravity: float = 0.0


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


func _physics_process(delta: float) -> void:
	if game_state != GameState.RUNNING:
		return
	world.update_world(delta, scroll_speed)
	world.remove_offscreen_objects()
	if spawning_enabled:
		world.update_spawning(delta)
	if player != null and player.is_alive:
		_last_gravity = world.get_total_gravity_at(player.global_position)
		player.apply_gravity(_last_gravity)
	update_score(delta)
	update_difficulty(delta)
	check_boundaries()
	if hud != null:
		hud.update_score(get_display_score())
	_update_debug_label()
	# Collision handling (planet/asteroid/power-up) is still to be agreed — see docs/domain-model.md.


func _update_debug_label() -> void:
	if debug_label == null:
		return
	debug_label.text = "score %d   speed %.0f   planets %d   asteroids %d   power-ups %d   gravity on ship %+.1f px/s²" % [
		get_display_score(), scroll_speed, world.active_planets.size(),
		world.active_asteroids.size(), world.active_powerups.size(), _last_gravity]


## Advance distance. Has no effect once the run is over.
func update_score(delta: float) -> void:
	assert(delta >= 0.0)
	if game_state != GameState.RUNNING:
		return
	distance_score += scroll_speed * delta


## Raise scroll speed with distance travelled, capped at max_scroll_speed.
## delta is kept for the V3 signature (and for a time-based curve, if preferred).
func update_difficulty(_delta: float) -> void:
	if game_state != GameState.RUNNING:
		return
	scroll_speed = minf(max_scroll_speed, initial_scroll_speed + distance_score * speed_gain_per_distance)


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


## Score shown to the player (whole number, scaled from pixels).
func get_display_score() -> int:
	return int(distance_score * score_scale)


func validate_state() -> void:
	assert(distance_score >= 0.0)
	assert(scroll_speed > 0.0)
	assert(initial_scroll_speed > 0.0 and initial_scroll_speed <= max_scroll_speed)
	assert(play_area_top < play_area_bottom)
