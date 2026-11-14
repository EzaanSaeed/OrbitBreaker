extends SceneTree
## Historical suite name retained: fuel pickups must never boost acceleration.
## Run: Godot --headless --path . --script res://tests/player_boost_test.gd

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _run() -> void:
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	assert(not player.has_method("apply_thrust_boost"))
	for property in player.get_property_list():
		assert(property.name not in ["thrust_multiplier", "boost_time_remaining"])
	var pickup = load("res://scripts/thruster_booster.gd").new()
	player.fuel.drain(14.0)
	assert(player.fuel.fuel == 30.0)
	pickup.apply_effect(player)
	assert(player.fuel.fuel == 80.0)
	player.apply_thrust(1.0)
	player.update_movement(0.1)
	assert(is_equal_approx(player.vertical_velocity, 60.0))
	pickup.apply_effect(player)
	assert(player.fuel.fuel == 100.0)
	player.vertical_velocity = 0.0
	player.apply_gravity(100.0)
	player.update_movement(0.1)
	assert(is_equal_approx(player.vertical_velocity, 70.0))
	player.update_movement(1.0)
	assert(player.vertical_velocity == 300.0)
	print("PASS removed legacy APIs; repeated fuel pickups preserve normal acceleration, gravity and speed cap")
	player.fuel.drain(1000.0)
	player.vertical_velocity = 60.0
	player.apply_gravity(100.0)
	player.update_movement(0.1)
	assert(player.vertical_velocity == 70.0)
	player.die()
	pickup.apply_effect(player)
	assert(player.fuel.fuel == 0.0)
	player.validate_state()
	print("PASS empty fuel preserves momentum/gravity; dead Player rejects refill")
	pickup.free()
	player.queue_free()
	quit()
