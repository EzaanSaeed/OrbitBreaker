class_name Bullet
extends Area2D
## One active asteroid per projectile, using Developer A's existing API.

signal asteroid_destroyed(asteroid: Asteroid, score_bonus: int)
const SCORE_BONUS: int = 10

@export var speed: float = 720.0
const _VISUAL_MARGIN: float = 12.0
var _spent: bool = false

func _ready() -> void:
	assert(is_finite(speed) and speed > 0.0)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position.x += speed * delta
	# Canvas coordinates account for viewport stretch and a future camera.
	var screen_position := get_global_transform_with_canvas().origin
	var bounds := get_viewport_rect().grow(_VISUAL_MARGIN)
	if not bounds.has_point(screen_position):
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _spent or is_queued_for_deletion() or not is_instance_valid(area):
		return
	if area is PowerUp:
		return
	if area is Planet:
		_consume()
		return
	if not area is Asteroid or area.is_queued_for_deletion() or not area.is_active or area.is_offscreen():
		return
	# Claim both objects synchronously before any signal listener can reenter.
	_consume()
	area.deactivate()
	asteroid_destroyed.emit(area, SCORE_BONUS)


func _consume() -> void:
	_spent = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	hide()
	queue_free()
