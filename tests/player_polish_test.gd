extends SceneTree
## Godot --headless --path . --fixed-fps 60 --script res://tests/player_polish_test.gd
## Real Main scene, production spawners and Area2D physics; no production overrides saved.

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
	return main.hud.get_node("Layout/TopMargin/TopRow/Health/HealthValue").text

func _bar() -> ProgressBar:
	return main.hud.get_node("Layout/TopMargin/TopRow/Health/HealthBar")

func _boost() -> Label:
	return main.hud.get_node("Layout/TopMargin/TopRow/Health/BoostIndicator")

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
	assert(_bar().value == 100 and not _boost().visible)
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
	assert(main.hud.get_node("Layout/GameOverPanel/Center/Card/Padding/Content/FinalScore").text == "%d m" % main.get_display_score())
	main.hud.get_node("Layout/GameOverPanel/Center/Card/Padding/Content/RestartButton").pressed.emit()
	await scene_changed
	main = current_scene as GameController
	assert(_bar().value == 100 and _health_text() == "100 / 100")
	assert(not _boost().visible and not main.hud.get_node("Layout/GameOverPanel").visible)
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

	var boost = load("res://scenes/thruster_booster.tscn").instantiate()
	boost.position = player.position
	main.world.add_child(boost)
	await _frames()
	assert(boost.is_collected and not boost.visible and not boost.monitorable)
	assert(player.thrust_multiplier == 1.5 and player.boost_time_remaining == 5.0)
	assert(player._pickup_pulse_remaining > 0 and player._pickup_pulse_color.r == 1.0)
	assert(_boost().visible and "5.0 s" in _boost().text)
	player.apply_thrust(1.0)
	player.update_movement(0.1)
	assert(is_equal_approx(player.vertical_velocity, 90.0))
	await _frames(1)
	assert("4.9 s" in _boost().text)
	player.area_entered.emit(boost)
	assert(is_equal_approx(player.boost_time_remaining, 4.9))
	player.apply_thrust(0)
	player.vertical_velocity = 0
	player.update_movement(4.9)
	await _frames(1)
	assert(player.thrust_multiplier == 1 and not _boost().visible)
	# A fresh pickup refreshes, rather than stacks, the boost.
	for i in 2:
		var refresh = load("res://scenes/thruster_booster.tscn").instantiate()
		refresh.position = player.position
		main.world.add_child(refresh)
		await _frames()
		assert(player.thrust_multiplier == 1.5 and player.boost_time_remaining == 5.0)
		player.update_movement(1.0)
	await _frames(1)
	assert(_boost().visible and "4.0 s" in _boost().text)
	player.set_physics_process(true)
	await _frames(250)
	player.set_physics_process(false)
	assert(player.thrust_multiplier == 1.0 and player.boost_time_remaining == 0.0)
	assert(not _boost().visible)
	print("PASS rapid health animation; orange pickup pulse; boost countdown, expiry and refresh")
	player.apply_thrust_boost(1.5, 5.0)
	var planet := main.world.spawn_planet()
	assert(planet != null)
	planet.position = player.position
	await _frames(20)
	assert(not player.is_alive and player.health == 0 and _bar().value == 0)
	assert(not _boost().visible and player._pickup_pulse_remaining == 0)
	main.queue_free()
	await process_frame
	print("PASS planet instant death clears boost/visuals; all Player polish tests")
	quit()
