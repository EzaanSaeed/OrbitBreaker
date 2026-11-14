class_name HUD
extends CanvasLayer
## Presentation only: health, score, ammo, fuel, game-over panel, restart.
## Owner: Developer C. Source: HUD Contracts (Developer A, 2026-11-14).
##
## GameController pushes all values by calling the methods below, once at the
## start of every run and then whenever something changes.
##
## The HUD never reads the Player directly and never calculates any resource
## value (no score, ammo, fuel or health maths live here).

signal restart_requested
signal main_menu_requested

# ── Top-bar references ───────────────────────────────────────────────────────
@onready var _health_bar: ProgressBar  = $Layout/TopMargin/TopRows/Row1/Health/HealthBar
@onready var _health_value: Label      = $Layout/TopMargin/TopRows/Row1/Health/HealthValue
@onready var _score_value: Label       = $Layout/TopMargin/TopRows/Row1/Score/ScoreValue
@onready var _ammo_value: Label        = $Layout/TopMargin/TopRows/Row2/Ammo/AmmoValue
@onready var _fuel_bar: ProgressBar    = $Layout/TopMargin/TopRows/Row2/Fuel/FuelBar
@onready var _fuel_value: Label        = $Layout/TopMargin/TopRows/Row2/Fuel/FuelRow/FuelValue

# ── Game-over references ─────────────────────────────────────────────────────
@onready var _game_over: Control         = $Layout/GameOverPanel
@onready var _final_score: Label         = $Layout/GameOverPanel/Center/Card/Padding/Content/FinalScore
@onready var _restart: Button            = $Layout/GameOverPanel/Center/Card/Padding/Content/RestartButton
@onready var _main_menu_button: Button   = $Layout/GameOverPanel/Center/Card/Padding/Content/MainMenuButton

# ── Internal state ────────────────────────────────────────────────────────────
var _health_tween: Tween
var _health_initialized: bool = false
var _restart_lockout: float   = 0.0

## Seconds after show_game_over() during which the Restart button is disabled.
## Prevents Space (the shoot key) held at the moment of death from instantly
## dismissing the game-over screen.
const RESTART_LOCKOUT_DURATION: float = 0.5

# Runtime StyleBox overrides — created in _build_dynamic_styles().
var _health_fill_normal: StyleBoxFlat
var _health_fill_crit: StyleBoxFlat
var _fuel_fill_normal: StyleBoxFlat
var _fuel_fill_low: StyleBoxFlat


func _ready() -> void:
	_restart.pressed.connect(func(): restart_requested.emit())
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_game_over.hide()
	set_process(false)
	_build_dynamic_styles()
	# Sensible defaults; GameController overwrites these on its first push.
	update_score(0)
	update_ammo(15)
	update_fuel(100.0, 100.0)
	update_health(100, 100)


# ── Style construction ────────────────────────────────────────────────────────

func _build_dynamic_styles() -> void:
	# Health bar — cyan (normal) / red (critical: ≤ 25 % of max)
	_health_fill_normal = StyleBoxFlat.new()
	_health_fill_normal.bg_color = Color(0.15, 0.87, 0.95, 1.0)
	_health_fill_normal.corner_radius_top_left    = 3
	_health_fill_normal.corner_radius_top_right   = 3
	_health_fill_normal.corner_radius_bottom_right = 3
	_health_fill_normal.corner_radius_bottom_left  = 3

	_health_fill_crit = StyleBoxFlat.new()
	_health_fill_crit.bg_color = Color(0.90, 0.15, 0.10, 1.0)
	_health_fill_crit.corner_radius_top_left    = 3
	_health_fill_crit.corner_radius_top_right   = 3
	_health_fill_crit.corner_radius_bottom_right = 3
	_health_fill_crit.corner_radius_bottom_left  = 3

	_health_bar.add_theme_stylebox_override("fill", _health_fill_normal)

	# Fuel bar — amber (normal) / red (low: ≤ 25 % of max)
	_fuel_fill_normal = StyleBoxFlat.new()
	_fuel_fill_normal.bg_color = Color(0.95, 0.60, 0.05, 1.0)
	_fuel_fill_normal.corner_radius_top_left    = 3
	_fuel_fill_normal.corner_radius_top_right   = 3
	_fuel_fill_normal.corner_radius_bottom_right = 3
	_fuel_fill_normal.corner_radius_bottom_left  = 3

	_fuel_fill_low = StyleBoxFlat.new()
	_fuel_fill_low.bg_color = Color(0.95, 0.20, 0.10, 1.0)
	_fuel_fill_low.corner_radius_top_left    = 3
	_fuel_fill_low.corner_radius_top_right   = 3
	_fuel_fill_low.corner_radius_bottom_right = 3
	_fuel_fill_low.corner_radius_bottom_left  = 3

	_fuel_bar.add_theme_stylebox_override("fill", _fuel_fill_normal)


# ── Per-frame update (only active during restart lockout) ─────────────────────

func _process(delta: float) -> void:
	_restart_lockout = maxf(0.0, _restart_lockout - delta)
	if _restart_lockout == 0.0:
		_restart.disabled = false
		_main_menu_button.disabled = false
		set_process(false)


# ── Public API — called exclusively by GameController ────────────────────────

## Rename: was "DISTANCE … m". Now plain integer score (distance + kills).
func update_score(score: int) -> void:
	assert(score >= 0)
	_score_value.text = "%d" % score


## Unchanged contract from V3.
func update_health(current: int, maximum: int) -> void:
	assert(maximum > 0 and current >= 0 and current <= maximum)
	if _health_tween != null:
		_health_tween.kill()
	_health_bar.max_value = maximum
	_health_value.text = "%d / %d" % [current, maximum]
	# Instant on first call; animated on subsequent calls.
	if not _health_initialized:
		_health_bar.value = current
		_health_initialized = true
	else:
		_health_tween = create_tween()
		_health_tween.tween_property(_health_bar, "value", float(current), 0.2) \
			.set_trans(Tween.TRANS_QUAD as Tween.TransitionType).set_ease(Tween.EASE_OUT as Tween.EaseType)
	# Switch bar colour at <= 25 % health.
	var is_crit: bool = float(current) <= float(maximum) * 0.25
	_health_bar.add_theme_stylebox_override(
		"fill", _health_fill_crit if is_crit else _health_fill_normal)


## New. Ammo has no maximum; show 0 clearly in red.
func update_ammo(current: int) -> void:
	assert(current >= 0)
	_ammo_value.text = "%d" % current
	_ammo_value.add_theme_color_override(
		"font_color",
		Color(1.0, 0.25, 0.25, 1.0) if current == 0 else Color(0.85, 0.96, 1.0, 1.0))


## New. Fuel range 0–maximum (typically 0–100). Called frequently while
## W/S is held, so keep this path allocation-free.
func update_fuel(current: float, maximum: float) -> void:
	assert(maximum > 0.0 and current >= 0.0 and current <= maximum + 0.001)
	var clamped: float = clampf(current, 0.0, maximum)
	_fuel_bar.max_value = maximum
	_fuel_bar.value = clamped
	var pct: int = int(round(clamped / maximum * 100.0))
	_fuel_value.text = "%d%%" % pct
	var is_low: bool = clamped / maximum <= 0.25
	_fuel_bar.add_theme_stylebox_override(
		"fill", _fuel_fill_low if is_low else _fuel_fill_normal)
	_fuel_value.add_theme_color_override(
		"font_color",
		Color(1.0, 0.25, 0.25, 1.0) if is_low else Color(0.85, 0.96, 1.0, 1.0))


## Unchanged contract from V3, except score is now the combined total.
func show_game_over(score: int) -> void:
	assert(score >= 0)
	_final_score.text = "%d" % score
	_game_over.show()
	# Lock out the buttons briefly so a Space press held at the moment
	# of death (Space is now the shoot key) cannot instantly skip the screen.
	_restart.disabled = true
	_main_menu_button.disabled = true
	_restart_lockout = RESTART_LOCKOUT_DURATION
	set_process(true)
	_restart.grab_focus()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
