extends SceneTree
## Focused infrastructure checks for bundled events and missing optional paths.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node("AudioManager")
	assert(AudioServer.get_bus_index("Music") >= 0)
	assert(AudioServer.get_bus_index("SFX") >= 0)
	assert(manager._event_streams.size() == 10)
	for event in [manager.SoundEvent.LASER, manager.SoundEvent.LASER_2, manager.SoundEvent.LASER_3]:
		assert(manager._event_streams.has(event))
	for event in [3, 4, 5, 6, 7, 8, 9]:
		assert(manager._event_streams.has(event))
	assert(manager._event_streams[manager.SoundEvent.GAME_OVER] is AudioStreamMP3)
	assert(manager._music_player.playing)
	var music_player_id: int = manager._music_player.get_instance_id()
	assert(manager.play_default_music())
	assert(manager._music_player.get_instance_id() == music_player_id)
	assert(manager._music_player.stream is AudioStreamOggVorbis)
	assert((manager._music_player.stream as AudioStreamOggVorbis).loop)
	var thruster_a = manager.start_thruster_loop()
	var thruster_b = manager.start_thruster_loop()
	assert(thruster_a == thruster_b and thruster_a.stream is AudioStreamWAV)
	assert((thruster_a.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	manager.stop_thruster_loop()
	assert(manager.register_sound(manager.SoundEvent.GAME_OVER, "res://audio/missing.wav") == false)
	assert(manager.play_event(manager.SoundEvent.GAME_OVER) == null)
	assert(manager.register_sound(manager.SoundEvent.GAME_OVER, "res://audio/sfx/gta-v-death-sound-effect-102.mp3"))
	assert(manager.change_music("res://audio/missing.ogg") == false)
	assert(not manager._music_player.playing)
	manager.set_music_volume_db(-12.0)
	manager.set_sfx_volume_db(-18.0)
	assert(is_equal_approx(manager.music_volume_db, -12.0))
	assert(is_equal_approx(manager.sfx_volume_db, -18.0))
	manager.stop_music()
	manager.stop_all_sfx()
	assert(manager.play_default_music())
	# Exercise the real menu -> gameplay route before exercising death and restart.
	var menu: MainMenu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._on_play_pressed()
	await scene_changed
	var main := current_scene as GameController
	assert(main != null)
	var music_id: int = manager._music_player.get_instance_id()
	var player := main.player
	player.take_damage(1)
	assert(manager._sfx_players.back().stream == manager._event_streams[4])
	var health_pickup: Area2D = load("res://scenes/health_booster.tscn").instantiate()
	main.add_child(health_pickup)
	player._on_area_entered(health_pickup)
	assert(manager._sfx_players.back().stream == manager._event_streams[5])
	var fuel_pickup: Area2D = load("res://scenes/thruster_booster.tscn").instantiate()
	main.add_child(fuel_pickup)
	player._on_area_entered(fuel_pickup)
	assert(manager._sfx_players.back().stream == manager._event_streams[6])
	var ammo_pickup: Area2D = load("res://scenes/bullet_pickup.tscn").instantiate()
	main.add_child(ammo_pickup)
	player._on_area_entered(ammo_pickup)
	assert(manager._sfx_players.back().stream == manager._event_streams[7])
	var rock: Asteroid = load("res://scenes/asteroid.tscn").instantiate()
	main.add_child(rock)
	player.asteroid_destroyed.emit(rock, 10)
	assert(manager._sfx_players.back().stream == manager._event_streams[3])
	Input.action_press("thrust_down")
	player._physics_process(0.01)
	var thruster = manager._active_loops[manager.SoundEvent.THRUSTER_LOOP]
	assert(is_instance_valid(thruster) and thruster.playing)
	Input.action_release("thrust_down")
	player._physics_process(0.01)
	assert(not manager._active_loops.has(manager.SoundEvent.THRUSTER_LOOP))
	var before_voices: int = manager._sfx_players.size()
	var ammo_before_shoot: int = player.ammo
	var laser_before: int = manager._laser_variant_index
	assert(player.try_shoot() != null)
	assert(player.ammo == ammo_before_shoot - 1 and manager._laser_variant_index != laser_before)
	assert(manager._sfx_players.size() <= manager.max_sfx_voices)
	var after_success: int = manager._sfx_players.size()
	var laser_after_success: int = manager._laser_variant_index
	assert(player.try_shoot() == null)
	assert(manager._laser_variant_index == laser_after_success and manager._sfx_players.size() == after_success)
	for event in [manager.SoundEvent.LASER_2, manager.SoundEvent.LASER_3]:
		player._shot_cooldown = 0.0
		assert(player.try_shoot() != null)
		assert(manager._sfx_players.back().stream == manager._event_streams[event])
	player.ammo = 0
	var laser_at_empty: int = manager._laser_variant_index
	var voices_at_empty: int = manager._sfx_players.size()
	assert(player.try_shoot() == null)
	assert(manager._laser_variant_index == laser_at_empty)
	assert(manager._sfx_players.size() == voices_at_empty)
	assert(manager._sfx_players.size() <= manager.max_sfx_voices)
	main.restart_game()
	await scene_changed
	main = current_scene as GameController
	assert(main.player.ammo == 15)
	assert(manager._music_player.get_instance_id() == music_id and manager._music_player.playing)
	main.player.die()
	assert(is_instance_valid(manager._death_player) and manager._death_player.playing)
	assert(manager._music_fading_out)
	assert(manager._music_player.playing)
	var death_player_id: int = manager._death_player.get_instance_id()
	var death_voice_count: int = manager._sfx_players.size()
	manager.on_player_died()
	assert(manager._death_player.get_instance_id() == death_player_id)
	assert(manager._sfx_players.size() == death_voice_count)
	assert(main.hud.get_node("Layout/GameOverPanel").visible)
	await create_timer(HUD.RESTART_LOCKOUT_DURATION + 0.05).timeout
	(main.hud.get_node("Layout/GameOverPanel/Center/Card/Padding/Content/RestartButton") as Button).pressed.emit()
	await scene_changed
	main = current_scene as GameController
	assert(manager._death_player == null)
	assert(not manager._death_sequence_active)
	assert(manager._music_player.playing)
	main.queue_free()
	await process_frame
	current_scene = null
	manager.stop_all_sfx()
	manager.stop_music()
	for child in manager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.free()
	manager._sfx_players.clear()
	manager._active_loops.clear()
	manager._event_streams.clear()
	manager.free()
	await create_timer(0.25).timeout
	print("PASS Main Menu -> gameplay -> SIGNAL LOST -> Restart, immediate/unique death audio concurrent with BGM fade, event registration, buses, loops, shots and voice cap")
	quit()
