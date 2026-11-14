class_name HUD
extends CanvasLayer
## Presentation only: distance, health, game-over panel, restart control.
## Owner: Developer B. Source: Domain Model V3, §4.
##
## Does NOT calculate score, health or physics. GameController calls the
## methods below and listens for restart_requested.
##

signal restart_requested

@onready var _health_bar: ProgressBar = $Layout/TopMargin/TopRow/Health/HealthBar
@onready var _health_value: Label = $Layout/TopMargin/TopRow/Health/HealthValue
@onready var _score_value: Label = $Layout/TopMargin/TopRow/Score/ScoreValue
@onready var _game_over: Control = $Layout/GameOverPanel
@onready var _final_score: Label = $Layout/GameOverPanel/Center/Card/Padding/Content/FinalScore
@onready var _restart: Button = $Layout/GameOverPanel/Center/Card/Padding/Content/RestartButton
@onready var _boost_indicator: Label = $Layout/TopMargin/TopRow/Health/BoostIndicator
var _player: Spaceship
var _health_tween: Tween
var _health_initialized: bool = false

func _ready() -> void:
	_restart.pressed.connect(func(): restart_requested.emit())
	_game_over.hide()
	update_score(0)
	# Main connects health_changed in its _ready(), after Player's initial emit.
	# Read the existing Player state once; subsequent updates use that signal.
	var controller := get_parent() as GameController
	if controller != null and controller.player != null:
		_player = controller.player
		update_health(controller.player.health, controller.player.max_health)
	_update_boost_indicator()


func _process(_delta: float) -> void:
	_update_boost_indicator()


func _update_boost_indicator() -> void:
	var active := is_instance_valid(_player) and _player.is_alive \
		and _player.thrust_multiplier > 1.0 and _player.boost_time_remaining > 0.0
	_boost_indicator.visible = active
	if active:
		var text := "THRUST x%.1f  |  %.1f s" % [
			_player.thrust_multiplier, ceilf(_player.boost_time_remaining * 10.0) / 10.0]
		if _boost_indicator.text != text:
			_boost_indicator.text = text


func update_score(score: int) -> void:
	assert(score >= 0)
	_score_value.text = "%d m" % score


func update_health(current: int, maximum: int) -> void:
	assert(maximum > 0 and current >= 0 and current <= maximum)
	if _health_tween != null:
		_health_tween.kill()
	_health_bar.max_value = maximum
	_health_value.text = "%d / %d" % [current, maximum]
	if not _health_initialized:
		_health_bar.value = current
		_health_initialized = true
	else:
		_health_tween = create_tween()
		_health_tween.tween_property(_health_bar, "value", float(current), 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func show_game_over(score: int) -> void:
	assert(score >= 0)
	_final_score.text = "%d m" % score
	_game_over.show()
	_boost_indicator.hide()
	_restart.grab_focus()
