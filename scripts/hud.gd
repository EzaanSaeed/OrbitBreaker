class_name HUD
extends CanvasLayer
## Presentation only: distance, health, game-over panel, restart control.
## Owner: Developer B. Source: Domain Model V3, §4.
##
## Does NOT calculate score, health or physics. GameController calls the
## methods below and listens for restart_requested.
##
## DOMAIN CONTRACT. Bodies marked TODO(Dev B) are filled in during the UI stage.

signal restart_requested


func update_score(score: int) -> void:
	assert(score >= 0)
	# TODO(Dev B)


func update_health(current: int, maximum: int) -> void:
	assert(maximum > 0 and current >= 0 and current <= maximum)
	# TODO(Dev B)


func show_game_over(score: int) -> void:
	assert(score >= 0)
	# TODO(Dev B)
