extends SceneTree
## Godot --headless --path . --script res://tests/player_contract_test.gd
## Add -- --invalid for expected precondition assertion errors.

class CountingShip extends "res://scripts/player.gd":
	var movement_calls: int = 0
	func update_movement(delta: float) -> void:
		movement_calls += 1
		super.update_movement(delta)

class GravityProducer extends Node:
	var ship: CountingShip
	var ticks: int = 0
	var previous_delta: float = 0.0
	func _physics_process(delta: float) -> void:
		if ticks > 0:
			assert(ship.movement_calls == ticks, "Movement must run once per tick")
			assert(is_equal_approx(ship.vertical_velocity, 120.0 * previous_delta))
			assert(ship.gravity_acceleration == 0.0)
		ship.vertical_velocity = 0.0
		ship.apply_gravity(40.0)
		ship.apply_gravity(80.0)
		previous_delta = delta
		ticks += 1

var deaths: int = 0
var changes: Array = []

func _initialize() -> void:
	# Assertion failures must not leave a headless test running forever.
	create_timer(10.0).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	# Existing project/custom input maps must remain untouched by Player._ready.
	if not InputMap.has_action("thrust_up"):
		InputMap.add_action("thrust_up", 0.35)
	InputMap.action_erase_events("thrust_up")
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_I
	InputMap.action_add_event("thrust_up", custom)
	var before_events: Array[InputEvent] = InputMap.action_get_events("thrust_up")
	var before_deadzone: float = InputMap.action_get_deadzone("thrust_up")
	var player = load("res://scenes/player.tscn").instantiate()
	assert(player.get_script().get_global_name() == "Spaceship")
	player.player_died.connect(func(): deaths += 1)
	player.health_changed.connect(func(h, m): changes.append([h, m]))
	root.add_child(player)
	player.set_physics_process(false)
	assert(InputMap.action_get_events("thrust_up") == before_events)
	assert(InputMap.action_get_deadzone("thrust_up") == before_deadzone)
	_key(KEY_I, true)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, -60.0))
	_key(KEY_I, false)
	print("PASS named input respects existing custom mappings")

	# Remove runtime-only mappings and verify F6 defaults for every requested key.
	InputMap.erase_action("thrust_up")
	InputMap.erase_action("thrust_down")
	player._ensure_input_actions()
	var fixed_x: float = player.position.x
	for code in [KEY_W, KEY_UP, KEY_S, KEY_DOWN]:
		player.vertical_velocity = 0.0
		_key(code, true)
		player._physics_process(0.1)
		assert(is_equal_approx(player.vertical_velocity, -60.0 if code in [KEY_W, KEY_UP] else 60.0))
		_key(code, false)
		var momentum: float = player.vertical_velocity
		player._physics_process(0.1)
		assert(player.vertical_velocity == momentum)
		assert(player.position.x == fixed_x)
		player.validate_state()
	print("PASS W/S/arrows, delta acceleration, momentum, fixed X and invariants")

	player.vertical_velocity = 0.0
	player.apply_thrust(-0.5)
	player.apply_gravity(40.0)
	player.apply_gravity(60.0)
	player.update_movement(0.1)
	assert(is_equal_approx(player.vertical_velocity, -20.0))
	assert(player.gravity_acceleration == 0.0)
	player.apply_thrust(0.0)
	player.update_movement(0.1)
	assert(is_equal_approx(player.vertical_velocity, -20.0))
	player.apply_thrust_boost(1.0, 1.0)
	assert(player.thrust_multiplier == 1.0 and player.boost_time_remaining == 1.0)
	# Shared typed pickup APIs accept our Spaceship without adapters.
	var heal = load("res://scripts/health_booster.gd").new()
	heal.apply_effect(player)
	heal.free()
	var boost = load("res://scripts/thruster_booster.gd").new()
	boost.apply_effect(player)
	assert(player.thrust_multiplier == 1.5)
	boost.free()
	print("PASS public contract methods, boost timer and typed power-up interoperability")

	assert(player.health == player.max_health and player.health == 100)
	player.take_damage(25)
	assert(player.health == 75)
	player.restore_health(20)
	assert(player.health == 95)
	player.restore_health(9223372036854775807)
	assert(player.health == 100)
	player.validate_state()
	if "--invalid" in OS.get_cmdline_user_args():
		player.take_damage(-1)
		player.restore_health(-1)
		assert(player.health == 100)
		player.apply_thrust(2.0)
		player.update_movement(-1.0)
		player.validate_state()
	player.take_damage(9223372036854775807)
	assert(player.health == 0 and not player.is_alive)
	player.die()
	player.take_damage(25)
	player.restore_health(100)
	player.apply_thrust_boost(2.0, 1.0)
	assert(player.health == 0 and deaths == 1)
	assert(player.thrust_multiplier == 1.0 and player.boost_time_remaining == 0.0)
	assert(not player.is_physics_processing())
	assert(changes == [[100, 100], [75, 100], [95, 100], [100, 100], [0, 100]])
	player.validate_state()
	await process_frame
	assert(player.get_node("CollisionShape2D").disabled)
	player.queue_free()
	print("PASS health, clamping, one death signal, boost/movement/collision cleanup")

	var producer := GravityProducer.new()
	producer.process_physics_priority = -1
	root.add_child(producer)
	var ship := CountingShip.new()
	ship.process_physics_priority = 100
	producer.ship = ship
	producer.add_child(ship)
	for i in range(5):
		await physics_frame
	await process_frame
	assert(producer.ticks >= 3)
	assert(ship.movement_calls == producer.ticks)
	ship.validate_state()
	producer.queue_free()
	print("PASS real physics ordering: one movement update per tick; gravity consumed and reset")
	quit()
