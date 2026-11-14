# Orbit Breaker — Domain Model (V3, approved by Developer A)

Source: *Orbit Breaker Domain Model V3* (Developer B). This file records what was approved, where each class lives, and what was added on top of V3. The State column says what actually works.

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
| Spaceship | `scripts/player.gd` + `scenes/player.tscn` | Area2D | B | Done (PRs #4, #6): movement, health, boosts, collisions; tests in `tests/` |
| Planet | `scripts/planet.gd` + `scenes/planet.tscn` | Area2D | A | Done (drawn in editor too) |
| Asteroid | `scripts/asteroid.gd` + `scenes/asteroid.tscn` | Area2D | A | Done (random size, spins) |
| PowerUp | `scripts/power_up.gd` | Area2D | **TBD** | Domain rules done |
| HealthBooster | `scripts/health_booster.gd` + `scenes/health_booster.tscn` | PowerUp | B | Done (PR #7) |
| ThrusterBooster | `scripts/thruster_booster.gd` + `scenes/thruster_booster.tscn` | PowerUp | B | Done (PR #7) |
| World | `scripts/world.gd` | Node2D | A | Done: scrolling, cleanup, gravity, spawning of all three types with fair spacing |
| GameController | `scripts/game_controller.gd` | Node2D | A | Done; collisions still to be wired (see Still open) |
| HUD | `scripts/hud.gd` + `scenes/hud.tscn` | CanvasLayer | B | Done (PR #7): score, health bar, game-over panel, Restart (Enter/Space once focused) |

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

- ~~Collision dispatch owner~~ — resolved: Spaceship's `area_entered` handler (Developer B, PR #6).
- **PowerUp base file owner.**
- **Input action names:** `thrust_up` (W/Up) and `thrust_down` (S/Down) are now in `project.godot`; Developer B to confirm.

## Done in `project.godot`

960×540 viewport, `scenes/main.tscn` as the startup scene, dark background colour, and the two input actions.

## Main scene

```
Main (GameController)
├── Background (Starfield)  3-layer parallax stars, visual only
├── World (World)           planet/asteroid/booster scenes assigned here
├── Player                  instance of scenes/player.tscn at (180, 270)
└── HUD                     instance of scenes/hud.tscn
```

The temporary `DebugLabel` has been removed now that the HUD exists.

## Spawning (World)

Planets every 3 s, asteroids every 1.5 s, power-ups every 8 s — all tunable in World's inspector. Every new object keeps at least `min_spawn_gap` (60 px) of free space from every existing one, so there is always room for the ship; if no clear height is found after 8 tries, that spawn is skipped. Asteroids use a taller band (y 20–520) than planets (y 90–450) so hugging an edge isn't safe.

Both booster scenes are assigned on World in `main.tscn`, so power-ups spawn (random 50/50).

## Web build

`export_presets.cfg` has a **Web** preset (single-threaded, so itch.io needs no special headers). Godot 4.7.2 web export templates are required (Editor → Manage Export Templates). Build output goes to `build/` (git-ignored).

## V4 — weapons, thruster fuel, combined score (agreed 2026-11-14)

Team is now three: **Developer C** owns `hud.gd`/`hud.tscn`, menus, VFX, sound and music. Developer B owns the Player, weapon, bullets, ammo and BulletPickup. Developer A owns fuel rules, scoring, World spawning, `main.tscn` and the web export.

| Decision | Outcome |
|---|---|
| Shooting | Hold Space; 15 starting bullets, one per shot, no cap; BulletPickup +15 |
| Bullet hits asteroid | One hit destroys it; +10 score, at most once per asteroid; an asteroid that hit the ship never scores |
| Bullet hits planet | Bullet disappears; no effect on the planet |
| Bullet hits pickup | Ignored |
| Score | One number labelled **Score** = distance points + asteroid bonuses. `distance_score` stays separate because difficulty is based on it |
| Fuel | Starts at 100, drains only while thrusting; W+S together = no thrust, no drain; at 0 no controlled thrust, momentum and gravity continue |
| ThrusterBooster | Refills fuel (replaces the old 1.5× boost) |

**Interfaces**

| Interface | Owner | Shape |
|---|---|---|
| Kill event | B emits, A receives | `Spaceship.asteroid_destroyed(asteroid, score_bonus)` → `GameController.award_asteroid_bonus(asteroid, score_bonus)` (guards: once per asteroid, only while RUNNING) |
| Fuel | A (`scripts/thruster_fuel.gd`) | `ThrusterFuel` node, child of the Player as `fuel`: `fuel`, `max_fuel`, `drain_per_second`, `fuel_changed(current, maximum)`, `is_empty()`, `drain(delta)`, `refill(amount)` |
| Fuel hook | B (`player.gd`) | Thrust term only: if direction ≠ 0 → empty ? direction = 0 : `fuel.drain(delta)` |
| HUD | C | `update_score(int)`, `update_health(int, int)`, `update_ammo(int)`, `update_fuel(float, float)`, `show_game_over(int)`, `restart_requested`. GameController pushes all values; the HUD never reads the Player |
| Pickups | A (World) | `bullet_pickup_scene` slot; pickups every 6 s, equally health / fuel / ammo |

**Tuning (playtest-chosen 2026-11-14, rollback tag `tuning-baseline-2026-11-14`):**
- Feel: planet pull 2 250 000 (×1.5 of the original), ship drag 2.0/s (set in GameController), thrust 750 and top speed 320 (set on the Player instance in `main.tscn`, so `player.gd` is unchanged).
- Density: asteroids every 1.0 s (was 1.5), pickups every 4 s (was 6), equally likely health / fuel / ammo (fuel at 2x felt like it was everywhere).
- Fuel: drain 3/s (was 5), ThrusterBooster +50. Autopilot thrusting ~32% of the time: with equal pickup weights fuel never ran dry in 150 s runs (min 23%); deaths come from hazards, not fuel.
- Debug-only keys 0-6 (`scripts/tuning_presets.gd`) switch between Baseline / Light / Medium / Strong / Heavy / Extreme / Chosen while playtesting; removed in release builds.
- Tests pin `drain_per_second = 5` where they check fuel arithmetic, so retuning doesn't break them.

**Sequencing risks**
- ThrusterBooster's refill change goes in **the same PR as Developer B's fuel hook**, together with updates to B's tests that still expect the 1.5× boost.
- The old boost variables (`thrust_multiplier`, `boost_time_remaining`, `apply_thrust_boost`) are read by the HUD every frame. Developer C removes the boost countdown **before** (or in the same merge as) Developer B removes them.
- Space is both shoot and the focused Restart button: Developer C makes Restart ignore input for ~0.5 s after game over, or uses Enter/R only.
