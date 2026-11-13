extends SceneTree
## Run: Godot --headless --path . --script res://tests/player_boost_test.gd
## Add -- --invalid to exercise precondition rejection (expected assertion errors).

func _initialize() -> void:
	call_deferred("_run")

func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_S
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(player) -> void:
	player._assert_configuration()
	player._assert_state()
	assert(player.thrust_multiplier >= 1.0)
	assert(player.max_vertical_speed == 300.0)

func _run() -> void:
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.apply_thrust_boost(2.0, 0.25)
	assert(player.thrust_multiplier == 2.0)
	assert(player._thrust_boost_remaining == 0.25)
	_key(true)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 120.0))
	assert(is_equal_approx(player._thrust_boost_remaining, 0.15))
	_check(player)
	print("PASS activation and delta countdown")

	player.vertical_velocity = 0.0
	player._physics_process(0.2)
	assert(is_equal_approx(player.vertical_velocity, 210.0))
	assert(player.thrust_multiplier == 1.0 and player._thrust_boost_remaining == 0.0)
	player.vertical_velocity = 0.0
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 60.0))
	_check(player)
	print("PASS partial-frame expiration and normal thrust restoration")

	player.apply_thrust_boost(2.0, 1.0)
	player._physics_process(0.25)
	player.apply_thrust_boost(3.0, 2.0)
	assert(player.thrust_multiplier == 3.0)
	assert(player._thrust_boost_remaining == 2.0)
	player.apply_thrust_boost(3.0, 2.0)
	assert(player.thrust_multiplier == 3.0 and player._thrust_boost_remaining == 2.0)
	_check(player)
	print("PASS repeated pickups replace multiplier and refresh duration without stacking")

	_key(false)
	player.vertical_velocity = 0.0
	player.apply_gravity(100.0)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 10.0))
	_key(true)
	player.vertical_velocity = 0.0
	player.apply_gravity(100.0)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 190.0))
	player._physics_process(0.5)
	assert(player.vertical_velocity == 300.0)
	_key(false)
	_check(player)
	print("PASS independent gravity and unchanged speed cap")

	if "--invalid" in OS.get_cmdline_user_args():
		for args in [[1.0, 1.0], [0.0, 1.0], [-2.0, 1.0], [INF, 1.0], [NAN, 1.0], [2.0, 0.0], [2.0, -1.0], [2.0, INF], [2.0, NAN]]:
			var before_multiplier: float = player.thrust_multiplier
			var before_time: float = player._thrust_boost_remaining
			player.apply_thrust_boost(args[0], args[1])
			assert(player.thrust_multiplier == before_multiplier)
			assert(player._thrust_boost_remaining == before_time)
			_check(player)
		print("PASS invalid inputs rejected without changing active boost (expected assertion errors above)")

	player.take_damage(100)
	assert(not player.is_alive)
	assert(player.thrust_multiplier == 1.0 and player._thrust_boost_remaining == 0.0)
	player.apply_thrust_boost(2.0, 10.0)
	assert(player.thrust_multiplier == 1.0 and player._thrust_boost_remaining == 0.0)
	_check(player)
	print("PASS death cleanup and post-death boost rejection")
	player.queue_free()
	quit()
