extends SceneTree
## Godot --headless --path . --fixed-fps 60 --script res://tests/player_polish_test.gd
## Real Main scene, production spawners and Area2D physics; no production overrides saved.
##
## Updated by Developer C (HUD redesign):
##   - Node paths updated to match the new two-row HUD layout.
##   - "FINAL SCORE" / plain-integer format replaces the old "%d m" format.
##   - BoostIndicator checks removed (countdown widget deleted per HUD contracts).
##     ThrusterBooster will refuel the ship once Developer A lands fuel mechanics;
##     those tests live in a future fuel-integration test.

var main: GameController
var hits: Array[int] = []
var deaths: int = 0
var hit_ids: Array[int] = []

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): quit(1))
	seed(42)
	call_deferred("_run")

func _frames(count: int = 5) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _health_text() -> String:
	return main.hud.get_node("Layout/TopMargin/TopRows/Row1/Health/HealthValue").text

func _bar() -> ProgressBar:
	return main.hud.get_node("Layout/TopMargin/TopRows/Row1/Health/HealthBar")

func _ammo_text() -> String:
	return main.hud.get_node("Layout/TopMargin/TopRows/Row2/Ammo/AmmoValue").text

func _fuel_bar() -> ProgressBar:
	return main.hud.get_node("Layout/TopMargin/TopRows/Row2/Fuel/FuelBar")

func _contact(area: Area2D) -> void:
	assert(area is Asteroid)
	assert(area.get_instance_id() not in hit_ids)
	hit_ids.append(area.get_instance_id())
	hits.append(main.player.health)
	assert(main.player.health == 100 - 25 * hits.size())
	assert(_health_text() == "%d / 100" % main.player.health)
	assert(not area.is_active and not area.visible)
	assert(main.player.is_alive == (hits.size() < 4))
	if main.player.is_alive:
		assert(main.player._damage_flash_remaining > 0.0)
	main.player.area_entered.disconnect(_contact)
	main.player.area_entered.emit(area)
	main.player.area_entered.connect(_contact)
	assert(main.player.health == hits.back())

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	# Health bar should start full; no boost-countdown label exists any more.
	assert(_bar().value == 100)
	main.player.area_entered.connect(_contact)
	main.player.player_died.connect(func(): deaths += 1)
	# Automated vertical steering; Main's normal spawn, scrolling and gravity run.
	for frame in 3600:
		await _frames(1)
		if hits.size() == 4:
			break
		assert(main.player.is_alive)
		var target_y := 40.0
		var closest_x := INF
		for asteroid in main.world.active_asteroids:
			if asteroid.is_active and asteroid.position.x > 140 and asteroid.position.x < 300 and asteroid.position.x < closest_x:
				closest_x = asteroid.position.x
				target_y = asteroid.position.y
		main.player.position.y = target_y
		main.player.vertical_velocity = 0.0
	assert(hits == [75, 50, 25, 0] and deaths == 1)
	await _frames(20)
	assert(_bar().value == 0 and not main.player.visible)
	assert(main.player._damage_flash_remaining == 0 and main.player._pickup_pulse_remaining == 0)
	assert(main.game_state == GameController.GameState.GAME_OVER)
	assert(main.hud.get_node("Layout/GameOverPanel").visible)
	# Score is now a plain integer (no "m" suffix, no "DISTANCE" label).
	assert(main.hud.get_node("Layout/GameOverPanel/Center/Card/Padding/Content/FinalScore").text == "%d" % main.get_display_score())
	main.hud.get_node("Layout/GameOverPanel/Center/Card/Padding/Content/RestartButton").pressed.emit()
	await scene_changed
	main = current_scene as GameController
	assert(_bar().value == 100 and _health_text() == "100 / 100")
	assert(not main.hud.get_node("Layout/GameOverPanel").visible)
	assert(main.player._damage_flash_remaining == 0 and main.player._pickup_pulse_remaining == 0)
	print("PASS actual Main: four naturally spawned hits, flash trigger, HP text, animated bar, death and restart")

	# Pause automatic movement only for deterministic overlap/animation checks.
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	var player := main.player
	var asteroid := main.world.spawn_asteroid()
	assert(asteroid != null)
	asteroid.position = player.position
	await _frames()
	assert(player.health == 75 and player._damage_flash_remaining > 0)
	assert(_bar().value > 75 and _bar().value < 100)
	await _frames(20)
	assert(player._damage_flash_remaining == 0 and not player.is_processing())
	assert(_bar().value == 75)
	main.world.remove_offscreen_objects()
	await process_frame

	for damage in [0, 10, 0]:
		player.take_damage(damage)
		var before := player.health
		var heal = load("res://scenes/health_booster.tscn").instantiate()
		heal.position = player.position
		main.world.add_child(heal)
		await _frames()
		assert(player.health == mini(100, before + 25))
		if before == 75:
			assert(_bar().value > 75 and _bar().value < 100)
		assert(heal.is_collected and not heal.visible and not heal.monitorable)
		assert(player._pickup_pulse_remaining > 0 and player._pickup_pulse_color.g == 1.0)
		var pulse := player._pickup_pulse_remaining
		player.area_entered.emit(heal)
		assert(player._pickup_pulse_remaining == pulse)
		heal.queue_free()
		await _frames(30)
		assert(_bar().value == player.health and player._pickup_pulse_remaining == 0)
	print("PASS damage flash expiry; healing/cap/full-health collection pulse and one-time collection")

	# Rapid health changes replace the tween; numeric text is never delayed.
	player.take_damage(25)
	await _frames(2)
	player.restore_health(25)
	player.take_damage(10)
	assert(_health_text() == "90 / 100")
	await _frames(20)
	assert(_bar().value == 90 and player.health == 90)

	# ThrusterBooster pickup — verify orange pulse fires; fuel/speed effects
	# are tested separately once Developer A lands the fuel system.
	var boost = load("res://scenes/thruster_booster.tscn").instantiate()
	boost.position = player.position
	main.world.add_child(boost)
	await _frames()
	assert(boost.is_collected and not boost.visible and not boost.monitorable)
	assert(player._pickup_pulse_remaining > 0 and player._pickup_pulse_color.r == 1.0)
	player.area_entered.emit(boost)  # second emit must be ignored
	player.validate_state()
	print("PASS rapid health animation; orange pickup pulse on ThrusterBooster")

	var planet := main.world.spawn_planet()
	assert(planet != null)
	planet.position = player.position
	await _frames(20)
	assert(not player.is_alive and player.health == 0 and _bar().value == 0)
	assert(player._pickup_pulse_remaining == 0)
	main.queue_free()
	await process_frame
	print("PASS planet instant death clears visuals; all Player polish tests")
	quit()
