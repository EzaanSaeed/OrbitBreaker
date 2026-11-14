extends SceneTree
## Developer A: thruster fuel rules, asteroid bonus scoring, ammo-pickup spawning.
## Run: Godot --headless --path . --script res://tests/fuel_and_score_test.gd

func _initialize() -> void:
	# Assertion failures must not leave a headless test running forever.
	create_timer(10.0).timeout.connect(func(): quit(1))
	call_deferred("_run")


func _run() -> void:
	_test_fuel()
	await _test_bonus_scoring()
	_test_ammo_pickup_spawning()
	quit(0)


func _test_fuel() -> void:
	var fuel := ThrusterFuel.new()
	root.add_child(fuel)
	fuel.drain_per_second = 5.0                       # fixed rate: tests mechanics, not tuning
	var events: Array = []
	fuel.fuel_changed.connect(func(c, m): events.append([c, m]))
	assert(fuel.fuel == 100.0 and fuel.max_fuel == 100.0 and not fuel.is_empty())
	fuel.drain(2.0)                                   # 5 %/s
	assert(is_equal_approx(fuel.fuel, 90.0) and events.size() == 1 and events[0] == [90.0, 100.0])
	fuel.drain(0.0)
	assert(events.size() == 1)                        # no change, no signal
	fuel.drain(100.0)
	assert(fuel.fuel == 0.0 and fuel.is_empty())      # never negative
	fuel.drain(1.0)
	assert(events.size() == 2)                        # empty tank: nothing to report
	fuel.refill(50.0)
	assert(fuel.fuel == 50.0)
	fuel.refill(80.0)
	assert(fuel.fuel == 100.0)                        # capped at max
	var before := events.size()
	fuel.refill(25.0)
	assert(events.size() == before)                   # full tank: no change
	fuel.validate_state()
	fuel.free()
	print("PASS fuel starts full, drains by time, clamps at 0 and max, signals only on change")


func _test_bonus_scoring() -> void:
	var main: GameController = load("res://scenes/main.tscn").instantiate()
	main.spawning_enabled = false
	root.add_child(main)
	await process_frame
	main.distance_score = 5000.0                      # 500 distance points
	var a: Asteroid = load("res://scenes/asteroid.tscn").instantiate()
	var b: Asteroid = load("res://scenes/asteroid.tscn").instantiate()
	main.world.add_child(a)
	main.world.add_child(b)
	assert(main.get_display_score() == 500)
	main.award_asteroid_bonus(a, 10)
	main.award_asteroid_bonus(a, 10)                  # same asteroid again: ignored
	assert(main.bonus_score == 10 and main.get_display_score() == 510)
	main.award_asteroid_bonus(b, 10)
	main.award_asteroid_bonus(null, 0)                # no bonus: ignored
	assert(main.bonus_score == 20 and main.get_display_score() == 520)
	# Bonus points never feed difficulty.
	main.update_difficulty(0.0)
	assert(main.distance_score == 5000.0)
	# Score is frozen after game over.
	main.end_game()
	var c: Asteroid = load("res://scenes/asteroid.tscn").instantiate()
	main.world.add_child(c)
	main.award_asteroid_bonus(c, 10)
	main.update_score(1.0)
	assert(main.get_display_score() == 520)
	main.queue_free()
	await process_frame
	print("PASS +bonus once per asteroid, added on top of distance, frozen on game over")


func _test_ammo_pickup_spawning() -> void:
	var world: World = World.new()
	world.planet_scene = load("res://scenes/planet.tscn")
	# Stand-in for Developer B's bullet_pickup.tscn: any PowerUp scene.
	var stand_in := PowerUp.new()
	stand_in.name = "AmmoStandIn"
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	stand_in.add_child(shape)
	shape.owner = stand_in
	var packed := PackedScene.new()
	packed.pack(stand_in)
	stand_in.free()
	world.bullet_pickup_scene = packed
	root.add_child(world)
	var spawned := world.spawn_powerup()
	assert(spawned != null and spawned.name.begins_with("AmmoStandIn"))
	assert(world.active_powerups.has(spawned))
	world.queue_free()
	print("PASS World spawns the ammo pickup when its scene is assigned")
