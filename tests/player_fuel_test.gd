extends SceneTree
## Godot --headless --path . --fixed-fps 60 --script res://tests/player_fuel_test.gd

## ThrusterBooster now refills fuel (Developer A); pass --legacy-boost to test the old 1.5x boost.
var fuel_pickup_integration := not ("--legacy-boost" in OS.get_cmdline_user_args())

func _initialize() -> void:
	create_timer(180.0).timeout.connect(func(): quit(1))
	seed(42)
	call_deferred("_run")

func _frames(count: int = 1) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	current_scene = fixture
	var player: Spaceship = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(180, 270)
	fixture.add_child(player)
	player.set_physics_process(false)
	assert(player.fuel == player.get_node("ThrusterFuel"))
	assert(player.fuel.fuel == 100 and player.fuel.drain_per_second == 5)
	var fuel_events: Array = []
	player.fuel.fuel_changed.connect(func(value, maximum): fuel_events.append([value, maximum]))
	_key(KEY_S, true)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 60) and player.fuel.fuel == 99.5)
	_key(KEY_W, true)
	player.apply_gravity(40)
	player._physics_process(0.5)
	assert(is_equal_approx(player.vertical_velocity, 80) and player.fuel.fuel == 99.5)
	assert(fuel_events.size() == 1)
	_key(KEY_S, false)
	_key(KEY_W, false)
	for code in [KEY_W, KEY_S, KEY_UP, KEY_DOWN]:
		var before := player.fuel.fuel
		player.vertical_velocity = 0
		_key(code, true)
		player._physics_process(0.1)
		_key(code, false)
		assert(is_equal_approx(player.fuel.fuel, before - 0.5))
		assert(is_equal_approx(player.vertical_velocity, -60 if code in [KEY_W, KEY_UP] else 60))
	print("PASS fuel starts at 100, W/S/arrows drain configured rate, W+S consumes none and gravity still acts")

	player.fuel.drain(1000)
	player.vertical_velocity = 60
	_key(KEY_S, true)
	player._physics_process(0.1)
	assert(player.vertical_velocity == 60 and player.fuel.fuel == 0)
	player.apply_gravity(100)
	player._physics_process(0.1)
	assert(player.vertical_velocity == 70 and player.gravity_acceleration == 0)
	player.apply_thrust_boost(1.5, 5)
	player._physics_process(0.1)
	assert(player.vertical_velocity == 70)
	_key(KEY_SPACE, true)
	player._physics_process(0)
	_key(KEY_SPACE, false)
	assert(player.ammo == 14)
	# Only the fuel-powered portion accelerates on the final depletion tick.
	player.apply_thrust_boost(1, 0.1)
	player.restore_fuel(0.25)
	player.vertical_velocity = 0
	player.apply_gravity(100)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 40) and player.fuel.fuel == 0)
	player.restore_fuel(1)
	player.fuel.drain_per_second = 0
	player.vertical_velocity = 0
	player._physics_process(0.1)
	assert(player.vertical_velocity == 60 and player.fuel.fuel == 1)
	player.fuel.drain_per_second = 10
	player.restore_fuel(100)
	player._physics_process(0.5)
	assert(player.fuel.fuel == 95)
	_key(KEY_S, false)
	if not fuel_pickup_integration:
		player.restore_fuel(50)
	var capped_pickup = load("res://scenes/thruster_booster.tscn").instantiate()
	capped_pickup.position = player.position
	fixture.add_child(capped_pickup)
	await _frames(5)
	assert(capped_pickup.is_collected and player.fuel.fuel == 100)
	player.area_entered.emit(capped_pickup)
	assert(player.fuel.fuel == 100)
	player.die()
	player.restore_fuel(50)
	player._physics_process(1)
	assert(player.fuel.fuel == 100 and player.ammo == 14 and player.health == 0)
	fixture.queue_free()
	await process_frame
	print("PASS empty fuel blocks thrust/legacy boost but preserves momentum, gravity and shooting; partial depletion and death")

	# Actual Main, unchanged World/Main/GameController and natural pickup timers.
	var main: GameController = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	player = main.player
	assert(player.health == 100 and player.fuel.fuel == 100 and player.ammo == 15)
	assert(main.world.health_booster_scene != null and main.world.thruster_booster_scene != null and main.world.bullet_pickup_scene != null)
	player.take_damage(50)
	player.fuel.drain(16)
	Input.action_press("shoot")
	for i in 20:
		player._physics_process(0.2)
	Input.action_release("shoot")
	assert(player.ammo == 0)
	var seen: Dictionary = {}
	var previous: Array = [player.health, player.fuel.fuel, player.ammo]
	player.area_entered.connect(func(area):
		if area is HealthBooster:
			assert(player.health == mini(100, previous[0] + 25))
			seen["health"] = true
		elif area is ThrusterBooster:
			if fuel_pickup_integration:
				assert(is_equal_approx(player.fuel.fuel, minf(100, previous[1] + 50)))
				assert(player.thrust_multiplier == 1 and player.boost_time_remaining == 0)
			else:
				assert(is_equal_approx(player.fuel.fuel, previous[1]))
				assert(player.thrust_multiplier == 1.5 and player.boost_time_remaining > 0)
			seen["fuel"] = true
		elif area is BulletPickup:
			assert(player.ammo == previous[2] + 15)
			seen["ammo"] = true
		previous.assign([player.health, player.fuel.fuel, player.ammo]))
	for frame in 10800:
		await _frames()
		assert(player.is_alive)
		if seen.size() == 3:
			break
		var candidates: Array = [40.0, 100.0, 180.0, 260.0, 340.0, 420.0, 500.0]
		for pickup in main.world.active_powerups:
			if pickup.position.x > 145 and pickup.position.x < 300:
				candidates.push_front(pickup.position.y)
		var hazards: Array = []
		hazards.append_array(main.world.active_planets)
		hazards.append_array(main.world.active_asteroids)
		for y in candidates:
			var clear := true
			for hazard in hazards:
				if absf(hazard.position.x - player.position.x) < hazard.radius + 100 and absf(hazard.position.y - y) < hazard.radius + 35:
					clear = false
					break
			if clear:
				player.position.y = y
				break
		player.vertical_velocity = 0
	assert(seen.size() == 3)
	assert(main.get_display_score() > 0)
	print("PASS actual Main: natural physics pickups (+25 HP, +15 ammo); thruster mode: ", "integrated +50 fuel" if fuel_pickup_integration else "legacy boost; Developer A refill hook pending")
	player.die()
	var stopped_fuel := player.fuel.fuel
	var stopped_ammo := player.ammo
	await _frames(20)
	assert(player.fuel.fuel == stopped_fuel and player.ammo == stopped_ammo)
	main.restart_game()
	await scene_changed
	main = current_scene as GameController
	assert(main.player.health == 100 and main.player.fuel.fuel == 100 and main.player.ammo == 15)
	assert(main.bonus_score == 0 and main.distance_score == 0)
	main.queue_free()
	await process_frame
	print("PASS actual Main death/restart resets health=100, fuel=100, ammo=15 and score=0")
	quit()
