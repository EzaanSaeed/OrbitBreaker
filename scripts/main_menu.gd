class_name MainMenu
extends Control
## Presentation & Navigation: Main Menu for Orbit Breaker.
## Owner: Developer C. Source: Developer C Handoff, §5.
##
## Provides title display, mission launch, how-to-play controls guide,
## web export handling, and an atmospheric scrolling starfield.

@onready var _play_button: Button = $UI/Center/Card/Padding/Content/Buttons/PlayButton
@onready var _controls_button: Button = $UI/Center/Card/Padding/Content/Buttons/ControlsButton
@onready var _quit_button: Button = $UI/Center/Card/Padding/Content/Buttons/QuitButton
@onready var _controls_overlay: Control = $UI/ControlsOverlay
@onready var _close_controls_button: Button = $UI/ControlsOverlay/Center/Card/Padding/Content/CloseButton
@onready var _starfield: Starfield = $Background/Starfield

## Gentle horizontal drift speed for menu background stars
const MENU_SCROLL_SPEED: float = 35.0


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_controls_button.pressed.connect(_on_controls_pressed)
	_close_controls_button.pressed.connect(_on_close_controls_pressed)
	_controls_overlay.hide()

	# Quitting is not supported in Web/HTML5 exports
	if OS.has_feature("web"):
		_quit_button.hide()
	else:
		_quit_button.pressed.connect(func(): get_tree().quit())

	_play_button.grab_focus()


func _process(delta: float) -> void:
	if _starfield != null:
		_starfield.scroll(MENU_SCROLL_SPEED * delta)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_controls_pressed() -> void:
	_controls_overlay.show()
	_close_controls_button.grab_focus()


func _on_close_controls_pressed() -> void:
	_controls_overlay.hide()
	_controls_button.grab_focus()
