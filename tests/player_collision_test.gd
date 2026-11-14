extends SceneTree
## Godot --headless --path . --script res://tests/player_collision_test.gd
## Uses actual physics overlaps, plus duplicate/queued signal delivery checks.

class CountingPickup extends "res://scripts/power_up.gd":
	var collect_calls: int = 0
	var effect_calls: int = 0
	func collect(player: Spaceship) -> void:
		collect_calls += 1
		super.collect(player)
	func apply_effect(player: Spaceship) -> void:
		effect_calls += 1
		player.restore_health(25)

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _player(fixture: Node2D):
	var player = load("res://scenes/player.tscn").instantiate()
	fixture.add_child(player)
	player.set_physics_process(false)
	assert(player.monitoring and player.monitorable)
	assert(player.collision_layer == 1 and player.collision_mask == 1)
	assert(player.get_node("CollisionShape2D").shape.radius == 12.0)
	return player

func _fixture() -> Node2D:
	var fixture := Node2D.new()
	root.add_child(fixture)
	return fixture

func _add_pickup(fixture: Node2D, pickup: Area2D) -> void:
	# No production pickup scenes exist yet. Supply only a test hitbox;
	# actual production PowerUp/booster methods and default layers are used.
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	pickup.add_child(collision)
	fixture.add_child(pickup)

func _settle() -> void:
	for i in range(5):
		await physics_frame
	await process_frame

func _dispose(fixture: Node2D) -> void:
	fixture.queue_free()
	await process_frame

func _run() -> void:
	var fixture := _fixture()
	var player = _player(fixture)
	var deaths: Array = []
	player.player_died.connect(func(): deaths.append(true))
	player.apply_thrust_boost(1.5, 5.0)
	var planet = load("res://scenes/planet.tscn").instantiate()
	fixture.add_child(planet)
	await _settle()
	assert(not player.is_alive and player.health == 0 and deaths.size() == 1)
	assert(player.boost_time_remaining == 0.0 and player.thrust_multiplier == 1.0)
	assert(player.get_node("CollisionShape2D").disabled)
	player.area_entered.emit(planet)
	assert(deaths.size() == 1)
	player.validate_state()
	print("PASS real planet overlap kills full-health Player once and clears boost")

	# Simulate callbacks queued before death; none may consume another object.
	var ignored_asteroid = load("res://scenes/asteroid.tscn").instantiate()
	ignored_asteroid.position = Vector2(400, 0)
	fixture.add_child(ignored_asteroid)
	var ignored_pickup := CountingPickup.new()
	ignored_pickup.position = Vector2(400, 0)
	_add_pickup(fixture, ignored_pickup)
	player.area_entered.emit(ignored_asteroid)
	player.area_entered.emit(ignored_pickup)
	ignored_asteroid.position = Vector2.ZERO
	ignored_pickup.position = Vector2.ZERO
	await _settle()
	assert(ignored_asteroid.is_active)
	assert(not ignored_pickup.is_collected and ignored_pickup.collect_calls == 0)
	assert(player.health == 0 and deaths.size() == 1)
	print("PASS callbacks after death neither damage, consume pickups, nor emit death again")
	await _dispose(fixture)

	fixture = _fixture()
	player = _player(fixture)
	var asteroid = load("res://scenes/asteroid.tscn").instantiate()
	# Deliberately trigger a synchronous duplicate during the damage signal.
	player.health_changed.connect(func(_h, _m): player.area_entered.emit(asteroid))
	fixture.add_child(asteroid)
	await _settle()
	assert(player.health == 75 and player.is_alive and not asteroid.is_active)
	player.area_entered.emit(asteroid)
	player.area_entered.emit(asteroid)
	assert(player.health == 75)
	assert(not asteroid.monitoring and not asteroid.monitorable)
	assert(player._processing_asteroids.is_empty())
	player.validate_state()
	print("PASS real asteroid overlap damages 25 once, including synchronous duplicates")
	await _dispose(fixture)

	fixture = _fixture()
	player = _player(fixture)
	asteroid = load("res://scenes/asteroid.tscn").instantiate()
	fixture.add_child(asteroid)
	asteroid.deactivate()
	player.area_entered.emit(asteroid)
	assert(player.health == 100)
	var fatal_asteroid = load("res://scenes/asteroid.tscn").instantiate()
	fatal_asteroid.collision_damage = 100
	fixture.add_child(fatal_asteroid)
	await _settle()
	assert(player.health == 0 and not player.is_alive and not fatal_asteroid.is_active)
	player.validate_state()
	print("PASS inactive asteroids ignored; fatal asteroid still deactivated")
	await _dispose(fixture)

	fixture = _fixture()
	player = _player(fixture)
	player.take_damage(50)
	var pickup := CountingPickup.new()
	# PowerUp marks is_collected before effect/health_changed callbacks execute.
	player.health_changed.connect(func(_h, _m): player.area_entered.emit(pickup))
	_add_pickup(fixture, pickup)
	await _settle()
	assert(pickup.is_collected and pickup.collect_calls == 1 and pickup.effect_calls == 1)
	assert(player.health == 75)
	player.area_entered.emit(pickup)
	player.area_entered.emit(pickup)
	assert(pickup.collect_calls == 1 and pickup.effect_calls == 1 and player.health == 75)
	assert(not pickup.monitoring and not pickup.monitorable)
	player.validate_state()
	print("PASS real PowerUp overlap collects/applies exactly once, including reentrant callbacks")
	await _dispose(fixture)

	fixture = _fixture()
	player = _player(fixture)
	player.take_damage(50)
	var heal = load("res://scripts/health_booster.gd").new()
	_add_pickup(fixture, heal)
	await _settle()
	assert(heal.is_collected and player.health == 75)
	var boost = load("res://scripts/thruster_booster.gd").new()
	_add_pickup(fixture, boost)
	await _settle()
	assert(boost.is_collected and player.thrust_multiplier == 1.5 and player.boost_time_remaining == 5.0)
	player.area_entered.emit(boost)
	assert(player.thrust_multiplier == 1.5 and player.boost_time_remaining == 5.0)
	var unrelated := Area2D.new()
	fixture.add_child(unrelated)
	player.area_entered.emit(unrelated)
	assert(player.health == 75 and player.is_alive)
	player.validate_state()
	print("PASS real HealthBooster/ThrusterBooster effects; unrelated areas ignored")
	await _dispose(fixture)
	print("PASS all Player collision tests")
	quit()
