extends SceneTree
## Godot --headless --path . --fixed-fps 60 --script res://tests/weapon_test.gd

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
	call_deferred("_run")

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _frames(count: int = 1) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _fixture() -> Node2D:
	var fixture := Node2D.new()
	root.add_child(fixture)
	current_scene = fixture
	return fixture

func _player(fixture: Node2D, changes: Array) -> Spaceship:
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(180, 300)
	player.ammo_changed.connect(func(current): changes.append(current))
	fixture.add_child(player)
	player.set_physics_process(false)
	return player

func _dispose(fixture: Node) -> void:
	fixture.queue_free()
	await process_frame

func _run() -> void:
	var fixture := _fixture()
	var changes: Array = []
	var player := _player(fixture, changes)
	assert(changes == [15] and player.ammo == 15)
	assert(player.shot_interval == 0.2)
	assert(InputMap.action_get_events("shoot")[0].physical_keycode == KEY_SPACE)
	# Ammo listeners must not permit reentrant shots.
	player.ammo_changed.connect(func(_current): assert(player.try_shoot() == null))
	_key(KEY_SPACE, true)
	player._physics_process(0)
	assert(player.ammo == 14 and get_nodes_in_group("player_bullets").size() == 1)
	player._physics_process(0.1)
	player._physics_process(0.099)
	assert(player.ammo == 14)
	player._physics_process(0.001)
	assert(player.ammo == 13)
	player._physics_process(0)
	assert(player.ammo == 13)
	_key(KEY_SPACE, false)
	player._physics_process(0.2)
	assert(player.ammo == 13)
	_key(KEY_SPACE, true)
	player._physics_process(0)
	assert(player.ammo == 12)
	for i in 12:
		player._physics_process(0.2)
	assert(player.ammo == 0 and get_nodes_in_group("player_bullets").size() == 15)
	for i in 20:
		player._physics_process(0.2)
	assert(player.ammo == 0 and changes == [15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0])
	assert(get_nodes_in_group("player_bullets").size() == 15)
	_key(KEY_SPACE, false)
	print("PASS Space autofire, exact 0.2 s cooldown, release/repress, one round per shot and zero ammo")
	await _dispose(fixture)

	fixture = _fixture()
	changes = []
	player = _player(fixture, changes)
	var valid_scene := player.bullet_scene
	player.bullet_scene = null
	assert(player.try_shoot() == null and player.ammo == 15 and changes == [15])
	var wrong_scene := PackedScene.new()
	var wrong_root := Node2D.new()
	assert(wrong_scene.pack(wrong_root) == OK)
	wrong_root.free()
	player.bullet_scene = wrong_scene
	assert(player.try_shoot() == null and player.ammo == 15 and changes == [15])
	player.bullet_scene = valid_scene
	player.shot_interval = 0.4
	var first := player.try_shoot()
	assert(first != null and player.ammo == 14)
	player._physics_process(0.2)
	assert(player.try_shoot() == null)
	player._physics_process(0.2)
	assert(player.try_shoot() != null and player.ammo == 13)
	print("PASS failed/misconfigured instantiation consumes no ammo; interval is configurable")
	await _dispose(fixture)

	fixture = _fixture()
	changes = []
	player = _player(fixture, changes)
	_key(KEY_SPACE, true)
	_key(KEY_S, true)
	player.apply_gravity(100)
	player._physics_process(0.1)
	assert(is_equal_approx(player.vertical_velocity, 70))
	assert(is_equal_approx(player.position.y, 307) and player.position.x == 180)
	assert(player.health == 100 and player.ammo == 14 and player.gravity_acceleration == 0)
	var bullet := get_nodes_in_group("player_bullets")[0] as Bullet
	assert(bullet.get_parent() == fixture)
	assert(bullet.global_position == player.get_node("Muzzle").global_position)
	var start := bullet.global_position
	_key(KEY_SPACE, false)
	_key(KEY_S, false)
	await _frames(5)
	assert(bullet.global_position.x > start.x and bullet.global_position.y == start.y)
	player.position.y += 50
	assert(bullet.global_position.y == start.y)
	bullet.global_position.x = 1000
	await _frames(2)
	assert(not is_instance_valid(bullet))
	player.die()
	var before := player.ammo
	_key(KEY_SPACE, true)
	player._physics_process(1)
	assert(player.try_shoot() == null and player.ammo == before)
	_key(KEY_SPACE, false)
	print("PASS shooting coexists with movement/gravity; horizontal independent bullets, offscreen cleanup and death")
	await _dispose(fixture)

	# Automatic engine physics without depending on an excluded manual playtest.
	fixture = _fixture()
	player = _player(fixture, [])
	player.set_physics_process(true)
	changes = []
	player.ammo_changed.connect(func(current): changes.append(current))
	_key(KEY_SPACE, true)
	await _frames(200)
	_key(KEY_SPACE, false)
	assert(player.ammo == 0 and changes.size() == 15 and changes.front() == 14 and changes.back() == 0)
	await _frames(90)
	assert(get_nodes_in_group("player_bullets").is_empty())
	await _dispose(fixture)
	print("PASS automatic physics: held Space exhausts exactly 15 rounds and bullets expire")

	# Unmodified actual Main scene receives shooting through its existing Player instance.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	player = main.player
	_key(KEY_SPACE, true)
	await _frames(30)
	_key(KEY_SPACE, false)
	assert(player.is_alive and player.ammo == 12)
	assert(get_nodes_in_group("player_bullets").size() == 3)
	player.die()
	var ammo_at_death := player.ammo
	_key(KEY_SPACE, true)
	await _frames(20)
	assert(player.ammo == ammo_at_death)
	_key(KEY_SPACE, false)
	main.restart_game()
	await scene_changed
	main = current_scene
	assert(main.player.ammo == 15 and main.player.is_alive)
	assert(get_nodes_in_group("player_bullets").is_empty())
	assert(main.game_state == GameController.GameState.RUNNING)
	main.queue_free()
	await process_frame
	print("PASS actual Main autofire, death and scene-reload reset to 15 ammunition")
	print("PASS all Phase 1 weapon tests")
	quit()
