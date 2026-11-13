# Orbit Breaker — Domain Model (V3, approved by Developer A)

Source: *Orbit Breaker Domain Model V3* (Developer B). This file records what was approved, where each class lives, and what was added on top of V3. Nothing here means a feature works yet — the scripts are contracts.

## Approved by Developer A (V3 §9)

| Decision | Outcome |
|---|---|
| Expanded MVP | Health, asteroids, HealthBooster, ThrusterBooster are in scope |
| Planet collision | Instant death regardless of health |
| Asteroid collision | Damage once, then the asteroid is deactivated and removed |
| Screen boundaries | Instant death |
| HealthBooster | Instant heal, capped at max health |
| ThrusterBooster | 1.5× thrust, refresh instead of stack, reset on restart |
| Spawn ownership | World / Developer A |
| Effect ownership | Spaceship / Developer B |

Still tunable: initial health, asteroid damage, healing amount, boost duration, scroll-speed curve, spawn probabilities, gravity/thrust values.

## Files

| Class | File | Extends | Owner | State |
|---|---|---|---|---|
| Spaceship | `scripts/player.gd` | Area2D | B | Contract; bodies TODO |
| Planet | `scripts/planet.gd` | Area2D | A | Domain rules done |
| Asteroid | `scripts/asteroid.gd` | Area2D | A | Domain rules done |
| PowerUp | `scripts/power_up.gd` | Area2D | **TBD** | Domain rules done |
| HealthBooster | `scripts/health_booster.gd` | PowerUp | B | Done (one-liner from V3) |
| ThrusterBooster | `scripts/thruster_booster.gd` | PowerUp | B | Done (one-liner from V3) |
| World | `scripts/world.gd` | Node2D | A | Scroll/cleanup/gravity done; spawning TODO |
| GameController | `scripts/game_controller.gd` | Node2D | A | State/score/difficulty done; physics loop TODO |
| HUD | `scripts/hud.gd` | CanvasLayer | B | Contract; bodies TODO |

GameController is the root of `main.tscn` and World is its child, as V3 allows. The earlier `main.gd` name is replaced by `game_controller.gd`. No scenes exist yet.

**Sign convention:** screen space throughout — negative is up, positive is down (thrust direction, gravity, velocity).

## Additions to V3 — Developer B to confirm

These were needed to make V3 implementable. None changes gameplay.

1. `Spaceship.boost_time_remaining: float` — lets the boost expire.
2. `Asteroid.is_active` + `Asteroid.deactivate()` — enforces "damage once per impact".
3. `World.update_world(delta, scroll_speed)` — takes speed from GameController instead of keeping a second copy.
4. `World.get_total_gravity_at(ship_position) -> float` — the "Main sums contributions" step.
5. `GameController.check_boundaries()` — gives the boundary-death rule an owner.
6. `GameController.get_display_score() -> int` — converts float pixels to the int the HUD takes.
7. `apply_thrust(direction)`: -1 = full up, +1 = full down (matches `Input.get_axis("thrust_up", "thrust_down")`).

## Still open

- **Collision dispatch owner.** Who detects overlaps and calls `die()` / `take_damage()` + `deactivate()` / `collect()`? Proposal: Spaceship's `area_entered` handler (Developer B), checking the type of the area it touched.
- **PowerUp base file owner.**
- **Input action names** (`thrust_up` / `thrust_down` proposed, mapped to W/Up and S/Down).
- **Viewport** 960×540 still has to be set in `project.godot`.
