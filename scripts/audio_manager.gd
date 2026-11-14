extends Node
## Shared audio playback. Audio assets are optional; empty or missing paths are
## ignored so gameplay and web builds continue to run without bundled sounds.

enum SoundEvent {
	LASER,
	LASER_2,
	LASER_3,
	ASTEROID_DESTROYED,
	PLAYER_DAMAGE,
	HEALTH_PICKUP,
	FUEL_PICKUP,
	AMMO_PICKUP,
	GAME_OVER,
	THRUSTER_LOOP,
}

const EVENT_NAMES: Dictionary = {
	SoundEvent.LASER: "laser",
	SoundEvent.LASER_2: "laser_2",
	SoundEvent.LASER_3: "laser_3",
	SoundEvent.ASTEROID_DESTROYED: "asteroid_destroyed",
	SoundEvent.PLAYER_DAMAGE: "player_damage",
	SoundEvent.HEALTH_PICKUP: "health_pickup",
	SoundEvent.FUEL_PICKUP: "fuel_pickup",
	SoundEvent.AMMO_PICKUP: "ammo_pickup",
	SoundEvent.GAME_OVER: "game_over",
	SoundEvent.THRUSTER_LOOP: "thruster_loop",
}

@export_range(-60.0, 6.0, 0.5) var music_volume_db: float = -8.0
@export_range(-60.0, 6.0, 0.5) var sfx_volume_db: float = -10.0
@export_range(1, 16, 1) var max_sfx_voices: int = 4

var _music_player: AudioStreamPlayer
var _music_path: String = ""
var _event_streams: Dictionary = {}
var _active_loops: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _laser_variant_index: int = 0
var _music_fade_tween: Tween
var _music_fading_out: bool = false
var _death_player: AudioStreamPlayer
var _death_sequence_active: bool = false


func _ready() -> void:
	_ensure_buses()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)
	apply_music_volume()
	apply_sfx_volume()
	register_laser_variants([
		"res://audio/sfx/alienshoot1.wav",
		"res://audio/sfx/alienshoot2.wav",
		"res://audio/sfx/alienshoot3.wav",
	])
	register_sound(SoundEvent.ASTEROID_DESTROYED, "res://audio/sfx/asteroid_explosion.ogg")
	register_sound(SoundEvent.PLAYER_DAMAGE, "res://audio/sfx/player_damage.ogg")
	register_sound(SoundEvent.HEALTH_PICKUP, "res://audio/sfx/health_pickup.ogg")
	register_sound(SoundEvent.FUEL_PICKUP, "res://audio/sfx/fuel_pickup.ogg")
	register_sound(SoundEvent.AMMO_PICKUP, "res://audio/sfx/ammo_pickup.ogg")
	register_sound(SoundEvent.GAME_OVER, "res://audio/sfx/gta-v-death-sound-effect-102.mp3")
	register_sound(SoundEvent.THRUSTER_LOOP, "res://audio/sfx/thruster_loop.wav")
	play_default_music()
	get_tree().scene_changed.connect(_on_scene_changed)


## Resource paths are optional. Missing paths clear the event without error.
func register_sound(event: SoundEvent, resource_path: String) -> bool:
	if not EVENT_NAMES.has(event) or resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		_event_streams.erase(event)
		return false
	var stream := load(resource_path) as AudioStream
	if stream == null:
		_event_streams.erase(event)
		return false
	if event == SoundEvent.THRUSTER_LOOP and stream is AudioStreamWAV:
		stream = stream.duplicate() as AudioStreamWAV
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_event_streams[event] = stream
	return true


func play_event(event: SoundEvent, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if not _event_streams.has(event):
		return null
	if event == SoundEvent.THRUSTER_LOOP:
		return start_thruster_loop()
	return _play_stream(_event_streams[event], "SFX", pitch_scale)


## Cycles through the registered laser variants. Player can call this at its
## normal shot cadence; the SFX voice cap bounds overlapping tails.
func play_laser() -> AudioStreamPlayer:
	var variants: Array[SoundEvent] = [SoundEvent.LASER, SoundEvent.LASER_2, SoundEvent.LASER_3]
	for offset in variants.size():
		var index := (_laser_variant_index + offset) % variants.size()
		var event: SoundEvent = variants[index]
		if _event_streams.has(event):
			_laser_variant_index = (index + 1) % variants.size()
			return play_event(event)
	return null


func play_health_pickup() -> AudioStreamPlayer:
	return play_event(SoundEvent.HEALTH_PICKUP)


func play_fuel_pickup() -> AudioStreamPlayer:
	return play_event(SoundEvent.FUEL_PICKUP)


func play_ammo_pickup() -> AudioStreamPlayer:
	return play_event(SoundEvent.AMMO_PICKUP)


func register_laser_variants(paths: Array[String]) -> int:
	var events: Array[SoundEvent] = [SoundEvent.LASER, SoundEvent.LASER_2, SoundEvent.LASER_3]
	var registered := 0
	for i in mini(paths.size(), events.size()):
		if register_sound(events[i], paths[i]):
			registered += 1
	return registered


func play_sfx(stream: AudioStream, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	return _play_stream(stream, "SFX", pitch_scale)


func play_music(stream: AudioStream, loop: bool = true) -> bool:
	if stream == null:
		stop_music()
		return false
	_music_player.stop()
	_music_fading_out = false
	if _music_fade_tween != null:
		_music_fade_tween.kill()
	_music_player.stream = _music_loop_stream(stream) if loop else stream
	_music_path = ""
	_music_player.play()
	return true


func play_default_music() -> bool:
	stop_death_sound()
	_death_sequence_active = false
	if _music_fade_tween != null:
		_music_fade_tween.kill()
	_music_fading_out = false
	if is_instance_valid(_music_player):
		_music_player.volume_db = 0.0
	return change_music("res://audio/music/gameplay.ogg", true)


## Loads optional music from a path. A missing or invalid file stops current music.
func change_music(resource_path: String, loop: bool = true) -> bool:
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		stop_music()
		return false
	if resource_path == _music_path and _music_player.playing:
		return true
	var stream := load(resource_path) as AudioStream
	if stream == null:
		stop_music()
		return false
	_music_path = resource_path
	var started := play_music(stream, loop)
	_music_path = resource_path if started else ""
	return started


func stop_music() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	_music_path = ""
	_music_fading_out = false


func set_music_volume_db(value: float) -> void:
	music_volume_db = clampf(value, -60.0, 6.0)
	apply_music_volume()


func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = clampf(value, -60.0, 6.0)
	apply_sfx_volume()


func apply_music_volume() -> void:
	_set_bus_volume("Music", music_volume_db)


func apply_sfx_volume() -> void:
	_set_bus_volume("SFX", sfx_volume_db)


## Thruster sound loops are explicitly started/stopped by future Player wiring.
func start_thruster_loop() -> AudioStreamPlayer:
	if not _event_streams.has(SoundEvent.THRUSTER_LOOP):
		return null
	var existing := _active_loops.get(SoundEvent.THRUSTER_LOOP) as AudioStreamPlayer
	if is_instance_valid(existing):
		if not existing.playing:
			existing.play()
		return existing
	var player := _play_stream(_event_streams[SoundEvent.THRUSTER_LOOP], "SFX", 1.0, true)
	if player != null:
		_active_loops[SoundEvent.THRUSTER_LOOP] = player
	return player


func stop_thruster_loop() -> void:
	var player := _active_loops.get(SoundEvent.THRUSTER_LOOP) as AudioStreamPlayer
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	_active_loops.erase(SoundEvent.THRUSTER_LOOP)


func stop_all_sfx() -> void:
	for player in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_sfx_players.clear()
	stop_thruster_loop()


func on_player_damage() -> void:
	play_event(SoundEvent.PLAYER_DAMAGE)


func on_asteroid_destroyed(_asteroid: Asteroid, _score_bonus: int) -> void:
	play_event(SoundEvent.ASTEROID_DESTROYED)


func on_player_died() -> void:
	# SIGNAL LOST remains the game-over presentation. Play the bundled optional
	# clip immediately while the gameplay track fades independently.
	if _death_sequence_active:
		return
	_death_sequence_active = true
	stop_all_sfx()
	_death_player = play_event(SoundEvent.GAME_OVER)
	fade_music_out(1.0)


func stop_death_sound() -> void:
	if is_instance_valid(_death_player):
		_sfx_players.erase(_death_player)
		_death_player.stop()
		_death_player.queue_free()
	_death_player = null


func set_thruster_active(active: bool) -> void:
	if active:
		start_thruster_loop()
	else:
		stop_thruster_loop()


func fade_music_out(duration: float = 1.0) -> void:
	if not _music_player.playing or _music_fading_out:
		return
	_music_fading_out = true
	if _music_fade_tween != null:
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", -60.0, maxf(0.0, duration))
	_music_fade_tween.tween_callback(func():
		_music_player.stop()
		_music_player.volume_db = 0.0
		_music_fading_out = false)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if not scene is GameController:
		# Leaving a run for the menu also ends any lingering death clip.
		stop_death_sound()
		if not _music_player.playing:
			play_default_music()
		return
	stop_all_sfx()
	if _music_fading_out or not _music_player.playing:
		play_default_music()
	var player := scene.get("player") as Spaceship
	if player == null:
		return
	if not player.player_died.is_connected(on_player_died):
		player.player_died.connect(on_player_died)
	if not player.asteroid_destroyed.is_connected(on_asteroid_destroyed):
		player.asteroid_destroyed.connect(on_asteroid_destroyed)


func _play_stream(stream: AudioStream, bus: String, pitch: float, loop: bool = false) -> AudioStreamPlayer:
	if stream == null or not is_finite(pitch) or pitch <= 0.0:
		return null
	_sfx_players = _sfx_players.filter(func(active): return is_instance_valid(active) and active.playing)
	if not loop and _sfx_players.size() >= max_sfx_voices:
		var oldest: AudioStreamPlayer = _sfx_players.pop_front()
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.queue_free()
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	if loop:
		_sfx_players.erase(player)
	else:
		_sfx_players.append(player)
		player.finished.connect(_on_sfx_finished.bind(player))
	player.play()
	return player


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	_sfx_players.erase(player)
	if player == _death_player:
		_death_player = null
	if is_instance_valid(player):
		player.queue_free()


func _music_loop_stream(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav
	if stream is AudioStreamOggVorbis:
		var ogg := stream.duplicate() as AudioStreamOggVorbis
		ogg.loop = true
		return ogg
	return stream


func _ensure_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, clampf(value, -60.0, 6.0))
