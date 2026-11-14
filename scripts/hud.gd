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

func _ready() -> void:
	_restart.pressed.connect(func(): restart_requested.emit())
	_game_over.hide()
	update_score(0)
	# Main connects health_changed in its _ready(), after Player's initial emit.
	# Read the existing Player state once; subsequent updates use that signal.
	var controller := get_parent() as GameController
	if controller != null and controller.player != null:
		update_health(controller.player.health, controller.player.max_health)


func update_score(score: int) -> void:
	assert(score >= 0)
	_score_value.text = "%d m" % score


func update_health(current: int, maximum: int) -> void:
	assert(maximum > 0 and current >= 0 and current <= maximum)
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_value.text = "%d / %d" % [current, maximum]


func show_game_over(score: int) -> void:
	assert(score >= 0)
	_final_score.text = "%d m" % score
	_game_over.show()
	_restart.grab_focus()
