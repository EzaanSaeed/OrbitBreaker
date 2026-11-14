class_name Spaceship
extends Area2D
## Owns vertical movement and health. The world owns all environmental forces.
## Call apply_gravity() before this player's physics tick; calls accumulate
## for one tick, in pixels/second squared (positive points downward).
## World gravity producers must use process_physics_priority < 100; this scene
## integrates at priority 100. Lower physics priorities execute first.

signal player_died
signal health_changed(current: int, maximum: int)
signal ammo_changed(current: int)
## Developer A can connect this to scoring; emitted only for projectile kills.
signal asteroid_destroyed(asteroid: Asteroid, score_bonus: int)

const STARTING_AMMO: int = 15
@export var shot_interval: float = 0.2
@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var ammo: int = STARTING_AMMO
var _shot_cooldown: float = 0.0
var _is_firing: bool = false

@export var thrust_power: float = 600.0
@export var max_vertical_speed: float = 300.0
@export var max_health: int = 100

var health: int = 100
var is_alive: bool = true
var vertical_velocity: float = 0.0

var gravity_acceleration: float = 0.0
var fuel: ThrusterFuel
var _fixed_x: float
var _standalone: bool = false
var _thrust_direction: float = 0.0
var _processing_asteroids: Array[Asteroid] = []
const _DAMAGE_FLASH_DURATION: float = 0.15
const _PICKUP_PULSE_DURATION: float = 0.4
var _damage_flash_remaining: float = 0.0
var _pickup_pulse_remaining: float = 0.0
var _pickup_pulse_color: Color = Color.GREEN
var _ship_visual: Polygon2D
var _ship_base_color: Color = Color.CYAN
## Kenney "Space Shooter Remastered" ship (CC0). Faces up in the art, so it is
## drawn turned 90 degrees to face the flight direction (right).
const _SHIP_TEXTURE: Texture2D = preload("res://assets/kenney/ship/playerShip1_blue.png")
const _SHIP_SCALE: float = 0.34


func _ready() -> void:
	fuel = get_node_or_null("ThrusterFuel") as ThrusterFuel
	# Also support script-only Player instances used by the public contract tests.
	if fuel == null:
		fuel = ThrusterFuel.new()
		fuel.name = "ThrusterFuel"
		add_child(fuel)
	# Older local Main scenes also draw a child polygon over the scripted ship.
	_ship_visual = get_node_or_null("Ship") as Polygon2D
	if _ship_visual != null:
		_ship_base_color = _ship_visual.color
	_assert_configuration()
	_ensure_input_actions()
	health = max_health
	ammo = STARTING_AMMO
	_shot_cooldown = 0.0
	is_alive = true
	_standalone = get_tree().current_scene == self
	if _standalone:
		position = get_viewport_rect().size * Vector2(0.25, 0.5)
	_fixed_x = position.x
	_assert_state()
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		if not player_died.is_connected(audio_manager.on_player_died):
			player_died.connect(audio_manager.on_player_died)
		if not asteroid_destroyed.is_connected(audio_manager.on_asteroid_destroyed):
			asteroid_destroyed.connect(audio_manager.on_asteroid_destroyed)
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo)
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(_ship_visual):
		_ship_visual.color = _ship_base_color.lerp(
			Color(1.0, 0.15, 0.15), _damage_flash_remaining / _DAMAGE_FLASH_DURATION)
	var flash := Color.WHITE.lerp(Color(1.0, 0.25, 0.25), _damage_flash_remaining / _DAMAGE_FLASH_DURATION)
	var size := _SHIP_TEXTURE.get_size() * _SHIP_SCALE
	draw_set_transform(Vector2.ZERO, PI / 2.0)
	draw_texture_rect(_SHIP_TEXTURE, Rect2(-size / 2.0, size), false, flash)
	draw_set_transform(Vector2.ZERO)
	if _pickup_pulse_remaining > 0.0:
		var progress := 1.0 - _pickup_pulse_remaining / _PICKUP_PULSE_DURATION
		var color := _pickup_pulse_color
		color.a = 1.0 - progress
		draw_arc(Vector2.ZERO, lerpf(18.0, 36.0, progress), 0.0, TAU, 24, color, 2.0, true)


func _process(delta: float) -> void:
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	_pickup_pulse_remaining = maxf(0.0, _pickup_pulse_remaining - delta)
	queue_redraw()
	if _damage_flash_remaining == 0.0 and _pickup_pulse_remaining == 0.0:
		set_process(false)


func _physics_process(delta: float) -> void:
	apply_thrust(Input.get_axis("thrust_up", "thrust_down"))
	update_movement(delta)
	_update_weapon(delta)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("set_thruster_active"):
		audio_manager.set_thruster_active(
			is_alive and _thrust_direction != 0.0 and not fuel.is_empty())


func _update_weapon(delta: float) -> void:
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	# Avoid an extra physics tick from floating-point residue at 0.2 seconds.
	if _shot_cooldown < 0.000001:
		_shot_cooldown = 0.0
	if Input.is_action_pressed("shoot"):
		try_shoot()


## Successful shots consume one round and emit ammo_changed once.
## Bullets belong to the scene, independently of Player movement and death.
func try_shoot() -> Bullet:
	if not is_alive or ammo <= 0 or _shot_cooldown > 0.0 or _is_firing:
		return null
	if not is_inside_tree() or bullet_scene == null or not bullet_scene.can_instantiate():
		return null
	if not is_finite(shot_interval) or shot_interval <= 0.0:
		return null
	var parent := get_tree().current_scene
	if parent == null or parent == self:
		parent = get_parent()
	if parent == null or parent.is_queued_for_deletion():
		return null
	_is_firing = true
	var instance := bullet_scene.instantiate()
	var bullet := instance as Bullet
	if bullet == null:
		instance.free()
		_is_firing = false
		return null
	bullet.asteroid_destroyed.connect(_on_bullet_asteroid_destroyed)
	parent.add_child(bullet)
	if not is_instance_valid(bullet) or bullet.is_queued_for_deletion() or not bullet.is_inside_tree():
		_is_firing = false
		return null
	var muzzle := get_node_or_null("Muzzle") as Node2D
	bullet.global_position = muzzle.global_position if muzzle != null else global_position + Vector2(22.0, 0.0)
	ammo -= 1
	_shot_cooldown = shot_interval
	ammo_changed.emit(ammo)
	_is_firing = false
	# Audio is optional; a missing AudioManager or unregistered clip is silent.
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_laser"):
		audio_manager.play_laser()
	return bullet


func _on_bullet_asteroid_destroyed(asteroid: Asteroid, score_bonus: int) -> void:
	asteroid_destroyed.emit(asteroid, score_bonus)


## Add ammunition without an arbitrary cap. Used by BulletPickup and future HUD.
func restore_ammo(amount: int) -> void:
	assert(amount >= 0, "Restored ammunition must be nonnegative.")
	if not is_alive or amount <= 0:
		return
	ammo += amount
	ammo_changed.emit(ammo)


## Set signed thrust for subsequent movement: -1 up, +1 down.
func apply_thrust(direction: float) -> void:
	assert(is_finite(direction) and direction >= -1.0 and direction <= 1.0)
	if not is_finite(direction) or direction < -1.0 or direction > 1.0:
		return
	_thrust_direction = direction if is_alive else 0.0


## The Player's physics callback is the sole automatic caller of this method.
## Consume accumulated gravity once, then clear it for the next physics tick.
func update_movement(delta: float) -> void:
	assert(is_finite(delta) and delta >= 0.0)
	if not is_finite(delta) or delta < 0.0:
		return
	_assert_configuration()
	# A runtime speed-limit reduction must clamp before checking the invariant.
	vertical_velocity = clampf(vertical_velocity, -max_vertical_speed, max_vertical_speed)
	validate_state()
	if not is_alive:
		gravity_acceleration = 0.0
		return

	# Accelerate only for the portion of this tick covered by remaining fuel.
	var powered_delta: float = 0.0
	if _thrust_direction != 0.0 and not fuel.is_empty():
		powered_delta = delta
		if fuel.drain_per_second > 0.0:
			powered_delta = minf(delta, fuel.fuel / fuel.drain_per_second)
		fuel.drain(powered_delta)
		if not is_alive:
			gravity_acceleration = 0.0
			return
	vertical_velocity = clampf(
		vertical_velocity + _thrust_direction * thrust_power * powered_delta + gravity_acceleration * delta,
		-max_vertical_speed, max_vertical_speed
	)
	gravity_acceleration = 0.0
	position = Vector2(_fixed_x, position.y + vertical_velocity * delta)

	# Keep F6 testing visible. Embedded players leave world boundaries to the world.
	if _standalone:
		var bottom: float = maxf(12.0, get_viewport_rect().size.y - 12.0)
		var bounded_y: float = clampf(position.y, 12.0, bottom)
		if bounded_y != position.y:
			position.y = bounded_y
			vertical_velocity = 0.0
	_assert_state()


func apply_gravity(acceleration: float) -> void:
	assert(is_finite(acceleration), "Gravity acceleration must be finite.")
	if is_alive and is_finite(acceleration):
		gravity_acceleration += acceleration
		assert(is_finite(gravity_acceleration), "Accumulated gravity must be finite.")


func restore_fuel(amount: float) -> void:
	assert(is_finite(amount) and amount >= 0.0, "Fuel refill must be finite and nonnegative.")
	if is_alive and is_finite(amount) and amount > 0.0:
		fuel.refill(amount)


func take_damage(amount: int) -> void:
	assert(amount >= 0, "Damage must be nonnegative.")
	if not is_alive or amount <= 0:
		return
	health = maxi(0, health - amount)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("on_player_damage"):
		audio_manager.on_player_damage()
	if health == 0:
		die()
	else:
		_assert_state()
		health_changed.emit(health, max_health)


func restore_health(amount: int) -> void:
	assert(amount >= 0, "Healing must be nonnegative.")
	if not is_alive or amount <= 0:
		return
	var previous_health: int = health
	health += mini(amount, max_health - health)
	_assert_state()
	if health != previous_health:
		health_changed.emit(health, max_health)


func die() -> void:
	if not is_alive:
		return
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("set_thruster_active"):
		audio_manager.set_thruster_active(false)
	health = 0
	is_alive = false
	vertical_velocity = 0.0
	_thrust_direction = 0.0
	gravity_acceleration = 0.0
	_damage_flash_remaining = 0.0
	_pickup_pulse_remaining = 0.0
	set_process(false)
	set_physics_process(false)
	# Deferred because damage may be delivered from a physics callback.
	$CollisionShape2D.set_deferred("disabled", true)
	hide()
	_assert_state()
	health_changed.emit(health, max_health)
	player_died.emit()


func _assert_configuration() -> void:
	assert(is_finite(shot_interval) and shot_interval > 0.0, "Shot interval must be finite and positive.")
	assert(max_health > 0, "Maximum health must be positive.")
	assert(is_finite(max_vertical_speed) and max_vertical_speed > 0.0,
		"Maximum vertical speed must be finite and positive.")
	assert(is_finite(thrust_power) and thrust_power >= 0.0,
		"Thrust power must be finite and nonnegative.")


func _assert_state() -> void:
	assert(ammo >= 0, "Ammunition cannot be negative.")
	assert(health >= 0 and health <= max_health, "Health is outside its bounds.")
	assert(health != 0 or not is_alive, "A player with zero health must be dead.")
	assert(is_finite(vertical_velocity), "Velocity must be finite.")
	assert(absf(vertical_velocity) <= max_vertical_speed, "Vertical speed exceeds its limit.")


## Public V3 invariant check; private checks remain available to existing tests.
func validate_state() -> void:
	_assert_configuration()
	_assert_state()


func _ensure_input_actions() -> void:
	# Latest main has no mappings yet. Preserve any shared project mappings;
	# provide runtime-only defaults for missing actions so F6 works independently.
	var defaults: Dictionary = {
		"thrust_up": [KEY_W, KEY_UP],
		"thrust_down": [KEY_S, KEY_DOWN],
		"shoot": [KEY_SPACE],
	}
	for action: String in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: int in defaults[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _on_area_entered(area: Area2D) -> void:
	# Deferred shape changes can leave already queued callbacks after death.
	if not is_alive or not is_instance_valid(area):
		return
	if area is Planet:
		die()
	elif area is Asteroid:
		if not area.is_active or area in _processing_asteroids:
			return
		# health_changed/player_died listeners may synchronously trigger another
		# callback before deactivate() runs. Guard that reentrant interval too.
		_processing_asteroids.append(area)
		if area.get_collision_damage() > 0:
			_damage_flash_remaining = _DAMAGE_FLASH_DURATION
			set_process(true)
			queue_redraw()
		take_damage(area.get_collision_damage())
		if is_instance_valid(area):
			area.deactivate()
		_processing_asteroids.erase(area)
	elif area is PowerUp and not area.is_collected:
		# collect() marks the pickup collected before applying its effect.
		var is_health_pickup := area is HealthBooster
		var is_thruster_pickup := area is ThrusterBooster
		area.collect(self)
		var audio_manager := get_node_or_null("/root/AudioManager")
		if audio_manager != null:
			if is_health_pickup:
				audio_manager.play_health_pickup()
			elif is_thruster_pickup:
				audio_manager.play_fuel_pickup()
			elif area is BulletPickup:
				audio_manager.play_ammo_pickup()
		if is_alive and (is_health_pickup or is_thruster_pickup):
			_pickup_pulse_color = Color(0.15, 1.0, 0.3) if is_health_pickup else Color(1.0, 0.65, 0.05)
			_pickup_pulse_remaining = _PICKUP_PULSE_DURATION
			set_process(true)
			queue_redraw()
