# Orbit Breaker — Domain Model (V3, approved by Developer A)

Source: *Orbit Breaker Domain Model V3* (Developer B). This file records what was approved, where each class lives, and what was added on top of V3. Developer B's scripts are still contracts; the State column says what actually works.

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

**Health scale (decided by Developer A after reviewing `feature/player-controls`):** `max_health = 100` (Developer B's value), asteroid `collision_damage = 25` (four hits to die), HealthBooster `healing_amount = 25` (undoes one hit).

Still tunable: boost duration, scroll-speed curve, spawn probabilities, gravity/thrust values (Developer B's player uses thrust 600, max speed 300).

## Files

| Class | File | Extends | Owner | State |
|---|---|---|---|---|
| Spaceship | `scripts/player.gd` | Area2D | B | Contract; bodies TODO |
| Planet | `scripts/planet.gd` + `scenes/planet.tscn` | Area2D | A | Done (drawn in editor too) |
| Asteroid | `scripts/asteroid.gd` + `scenes/asteroid.tscn` | Area2D | A | Done (random size, spins) |
| PowerUp | `scripts/power_up.gd` | Area2D | **TBD** | Domain rules done |
| HealthBooster | `scripts/health_booster.gd` | PowerUp | B | Done (one-liner from V3) |
| ThrusterBooster | `scripts/thruster_booster.gd` | PowerUp | B | Done (one-liner from V3) |
| World | `scripts/world.gd` | Node2D | A | Done: scrolling, cleanup, gravity, spawning of all three types with fair spacing |
| GameController | `scripts/game_controller.gd` | Node2D | A | Done; collisions still to be wired (see Still open) |
| HUD | `scripts/hud.gd` | CanvasLayer | B | Contract; bodies TODO |

GameController is the root of `main.tscn` and World is its child, as V3 allows. The earlier `main.gd` name is replaced by `game_controller.gd`.

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
8. `World.update_spawning(delta)` — World owns the planet/asteroid/power-up spawn timers (GameController just calls it).

## Still open

- **Collision dispatch owner.** Who detects overlaps and calls `die()` / `take_damage()` + `deactivate()` / `collect()`? Proposal: Spaceship's `area_entered` handler (Developer B), checking the type of the area it touched.
- **PowerUp base file owner.**
- **Input action names:** `thrust_up` (W/Up) and `thrust_down` (S/Down) are now in `project.godot`; Developer B to confirm.

## Done in `project.godot`

960×540 viewport, `scenes/main.tscn` as the startup scene, dark background colour, and the two input actions.

## Main scene (temporary parts)

`main.tscn` has a **placeholder `Player` node** (Spaceship script, radius-12 circle, cyan triangle) and a **`DebugLabel`** showing score, speed, planet count and gravity on the ship. When Developer B's `player.tscn` is merged, replace the placeholder with an instance of it and re-assign GameController's `player` export. Delete `DebugLabel` once the HUD exists.

## Spawning (World)

Planets every 3 s, asteroids every 1.5 s, power-ups every 8 s — all tunable in World's inspector. Every new object keeps at least `min_spawn_gap` (60 px) of free space from every existing one, so there is always room for the ship; if no clear height is found after 8 tries, that spawn is skipped. Asteroids use a taller band (y 20–520) than planets (y 90–450) so hugging an edge isn't safe.

**Power-ups don't spawn yet** because `health_booster_scene` and `thruster_booster_scene` on World are empty. When Developer B's booster scenes exist, assign them on the World node in `main.tscn` (Developer A).

## Web build

`export_presets.cfg` has a **Web** preset (single-threaded, so itch.io needs no special headers). Godot 4.7.2 web export templates are required (Editor → Manage Export Templates). Build output goes to `build/` (git-ignored).
