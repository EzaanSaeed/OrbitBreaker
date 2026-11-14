extends SceneTree
## Godot --headless --path . --fixed-fps 60 --script res://tests/weapon_collision_test.gd
## Actual Main and World-spawned asteroid instances; integration gaps asserted explicitly.

var main: GameController
var kills: Array = []

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
	seed(42)
	call_deferred("_run")

func _frames(count: int = 5) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _asteroid(at: Vector2) -> Asteroid:
	var asteroid := main.world.spawn_asteroid()
	assert(asteroid != null)
	asteroid.position = at
	return asteroid

func _bullet(at: Vector2) -> Bullet:
	var bullet = load("res://scenes/bullet.tscn").instantiate()
	bullet.position = at
	bullet.asteroid_destroyed.connect(main.player._on_bullet_asteroid_destroyed)
	main.add_child(bullet)
	return bullet

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	var player := main.player
	player.asteroid_destroyed.connect(func(asteroid, points): kills.append([asteroid.get_instance_id(), points]))
	var asteroid := _asteroid(player.position + Vector2(100, 0))
	var asteroid_id := asteroid.get_instance_id()
	var bullet := player.try_shoot()
	assert(bullet != null and bullet.monitoring and not bullet.monitorable)
	assert(bullet.get_parent() == main)
	assert(bullet.collision_layer == 0 and bullet.collision_mask == 1)
	await _frames(15)
	assert(not is_instance_valid(bullet))
	assert(not asteroid.is_active and not asteroid.monitorable and not asteroid.visible)
	assert(kills == [[asteroid_id, 10]])
	assert(player.ammo == 14 and player.health == 100)
	asteroid.position = player.position
	await _frames()
	assert(player.health == 100)
	main.world.remove_offscreen_objects()
	await process_frame
	assert(not is_instance_valid(asteroid))
	print("PASS Main projectile real overlap: active asteroid deactivated, bullet consumed, one 10-point event, no later contact damage")

	# Two bullets cannot claim the same asteroid.
	asteroid = _asteroid(Vector2(500, 300))
	_bullet(asteroid.position)
	_bullet(asteroid.position)
	await _frames()
	assert(kills.size() == 2 and kills.back()[1] == 10)
	main.world.remove_offscreen_objects()
	await _frames()
	# One bullet overlapping two asteroids can claim only one of them.
	var first := _asteroid(Vector2(500, 400))
	var second := _asteroid(Vector2(500, 400))
	_bullet(first.position)
	await _frames()
	assert(kills.size() == 3)
	assert(int(first.is_active) + int(second.is_active) == 1)
	first.deactivate()
	second.deactivate()
	main.world.remove_offscreen_objects()
	await _frames()
	print("PASS simultaneous bullets/asteroids cannot duplicate destruction or reward events")

	# Planet hits consume bullets without any planet modification or reward.
	var planet := main.world.spawn_planet()
	assert(planet != null)
	planet.position = Vector2(400, 180)
	var planet_state := [planet.position, planet.radius, planet.gravity_strength,
		planet.monitoring, planet.monitorable, planet.visible,
		planet.get_node("CollisionShape2D").disabled]
	bullet = _bullet(planet.position)
	await _frames()
	assert(not is_instance_valid(bullet) and kills.size() == 3)
	assert(planet_state == [planet.position, planet.radius, planet.gravity_strength,
		planet.monitoring, planet.monitorable, planet.visible,
		planet.get_node("CollisionShape2D").disabled])
	print("PASS planet physics hit consumes bullet without changing planet or emitting a reward")

	for kind in ["health_booster", "thruster_booster", "bullet_pickup"]:
		var pickup = load("res://scenes/%s.tscn" % kind).instantiate()
		pickup.position = Vector2(500, 420)
		main.world.add_child(pickup)
		var before := [player.health, player.ammo, player.thrust_multiplier, player.boost_time_remaining]
		bullet = _bullet(pickup.position)
		await _frames()
		assert(is_instance_valid(bullet) and not bullet._spent)
		assert(not pickup.is_collected and pickup.visible and pickup.monitorable and pickup.monitoring)
		assert(before == [player.health, player.ammo, player.thrust_multiplier, player.boost_time_remaining])
		assert(kills.size() == 3)
		bullet.queue_free()
		pickup.queue_free()
		await process_frame
	print("PASS bullets ignore HealthBooster, ThrusterBooster and BulletPickup without effects or consumption")

	# Player collision deactivation must never produce a projectile reward.
	asteroid = _asteroid(player.position)
	await _frames()
	assert(player.health == 75 and not asteroid.is_active)
	_bullet(asteroid.position)
	await _frames()
	assert(kills.size() == 3 and player.health == 75)
	main.world.remove_offscreen_objects()
	asteroid = _asteroid(Vector2(-100, 300))
	_bullet(asteroid.position)
	await _frames()
	assert(kills.size() == 3)
	main.world.remove_offscreen_objects()
	await _frames()
	print("PASS player-contact and offscreen asteroids do not emit destruction rewards")

	# Set up empty ammo using the existing Phase 1 shooting/cooldown loop.
	Input.action_press("shoot")
	for i in 20:
		player._physics_process(0.2)
	Input.action_release("shoot")
	assert(player.ammo == 0)
	var changes: Array = []
	player.ammo_changed.connect(func(ammo): changes.append(ammo))
	for expected in [15, 30, 45]:
		var pickup = load("res://scenes/bullet_pickup.tscn").instantiate()
		assert(pickup is PowerUp and pickup.monitorable and pickup.monitoring)
		assert(not pickup.get_node("CollisionShape2D").disabled)
		pickup.position = player.position + Vector2(100, 0)
		main.world.add_child(pickup)
		# Test-only registration: World has no BulletPickup spawn slot yet.
		main.world.active_powerups.append(pickup)
		await _frames()
		assert(not pickup.is_collected)
		main.world.update_world(1.0, 100.0)
		await _frames()
		assert(pickup.is_collected and not pickup.visible and not pickup.monitorable)
		assert(player.ammo == expected)
		var events := changes.size()
		player.area_entered.emit(pickup)
		pickup.collect(player)
		assert(player.ammo == expected and changes.size() == events)
		main.world.remove_offscreen_objects()
		await process_frame
		assert(not is_instance_valid(pickup))
	assert(changes == [15,30,45])
	print("PASS BulletPickup physics collection, +15 exactly once, no cap, World scroll and cleanup")

	# Weapon events must never modify the distance used to calculate difficulty.
	assert(main.distance_score == 0)
	main.update_score(1.0)
	assert(main.distance_score == main.scroll_speed)
	if main.has_method("award_asteroid_bonus"):
		assert(main.get_display_score() == int(main.distance_score * main.score_scale) + 30)
		print("PASS Developer A integration: three valid projectile kills add exactly 30 unscaled score points")
	else:
		assert(main.get_display_score() == int(main.distance_score * main.score_scale))
		print("VERIFIED GAP: 10-point events are emitted; GameController bonus scoring is not connected")
	player.die()
	var ignored = load("res://scenes/bullet_pickup.tscn").instantiate()
	ignored.position = player.position
	main.world.add_child(ignored)
	await _frames()
	assert(not ignored.is_collected and player.ammo == 45)
	main.restart_game()
	await scene_changed
	main = current_scene as GameController
	assert(main.player.ammo == 15 and main.player.health == 100)
	var natural_kills: Array = []
	main.player.asteroid_destroyed.connect(func(_asteroid, points): natural_kills.append(points))
	Input.action_press("shoot")
	for frame in 600:
		await _frames(1)
		if not natural_kills.is_empty():
			break
		assert(main.player.is_alive)
		var target_y := 40.0
		var closest_x := INF
		for target in main.world.active_asteroids:
			if target.is_active and target.position.x > 350 and target.position.x < closest_x:
				closest_x = target.position.x
				target_y = target.position.y
		# Test-only steering. Production spawning, scrolling and shooting stay live.
		main.player.position.y = target_y
		main.player.vertical_velocity = 0.0
	Input.action_release("shoot")
	assert(not natural_kills.is_empty() and natural_kills[0] == 10)
	if main.has_method("award_asteroid_bonus"):
		assert(main.get_display_score() == int(main.distance_score * main.score_scale) + 10 * natural_kills.size())
	else:
		assert(main.get_display_score() == int(main.distance_score * main.score_scale))
	print("PASS unchanged Main: held shooting destroys a naturally timed/scrolled asteroid; distance scoring continues")
	main.queue_free()
	await process_frame
	print("PASS death blocks collection; actual Main restart resets ammo and health")
	quit()
