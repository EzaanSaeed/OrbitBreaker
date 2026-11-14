# Weapon phases 2 and 3 — Developer B handoff

Implemented in the weapon feature worktree; no Developer A/C production files changed.

## Existing interfaces reused

- Asteroid: `is_active`, `is_offscreen()`, `deactivate()` are sufficient. No Asteroid API change is required.
- Bullet is an Area2D on layer 0, mask 1, monitoring enabled and monitorable disabled. Its enabled rectangle detects the existing layer-1 asteroid areas without making Player detect bullets.
- On an active, onscreen asteroid hit, Bullet synchronously marks itself spent and calls `asteroid.deactivate()` before emitting a destruction event. It then disappears/is queued for deletion. The existing World cleanup frees inactive asteroids.
- Player contact and offscreen cleanup never emit the projectile destruction event.
- A Planet hit consumes the bullet immediately without changing the planet or emitting a reward. All PowerUps (HealthBooster, ThrusterBooster and BulletPickup) are ignored and remain collectible.
- BulletPickup extends PowerUp. Player's existing area_entered dispatch calls collect(), which gates its effect once. It calls `player.restore_ammo(15)` and inherits World movement/offscreen cleanup support.
- No ammo cap. Every run starts with 15; each shot consumes 1; every pickup adds 15.

## Scoring integration needed from Developer A

Player now exposes:

```gdscript
signal asteroid_destroyed(asteroid: Asteroid, score_bonus: int)
```

Each valid projectile kill emits exactly one event with `score_bonus == 10`.

On the current `origin/main` base, GameController has no bonus-score API. Connect Player's event to a GameController-owned handler, and add 10 unscaled score points while RUNNING. Keep distance_score and its difficulty calculation unchanged. A suggested implementation is a separate GameController-owned bonus accumulator reset on reload, with `get_display_score()` returning the existing distance-based result plus that accumulator. Adding 10 directly to distance_score would only display 1 extra point at the existing score_scale of 0.1 and would alter difficulty; do not do that.

No production score is awarded by Developer B's code yet. The physics integration test explicitly checks this gap rather than claiming full scoring success. GameController should decide whether projectile events after GAME_OVER are ignored.

Developer A's current `feature/fuel-and-score` implementation provides `award_asteroid_bonus(asteroid: Node, score_bonus: int)` and connects `player.asteroid_destroyed` in `_connect_weapon_and_fuel()`. It keeps `bonus_score` separate from distance and deduplicates by asteroid instance ID. This matches the weapon event contract; no Player-side score accumulator or A-owned file change is needed in the weapon PR.

## Spawn/Main integration needed from Developer A

Add an agreed BulletPickup PackedScene slot/choice to World's pickup spawning, then assign `res://scenes/bullet_pickup.tscn` in Main. Keep existing World active_powerups registration and cleanup. Agree spawn frequency/weights before adding the third type; changing random choices alters the per-type probabilities of existing boosters.

Do not overload a HealthBooster or ThrusterBooster slot as a production workaround.

Developer A's current branch already provides `World.bullet_pickup_scene`. Assign the new pickup scene there during A's Main integration. A owns the provisional spawn timing/weights and fuel mechanics; the weapon PR does not change them or implement the separate future Player/fuel contract.

## HUD handoff to Developer C

Use Player's `ammo` and `ammo_changed(current)` signal for ammunition. Read `ammo` when wiring after Player._ready(), because its initial 15 event is emitted during _ready(). Existing health/boost signals and polish remain intact. The score caption currently says DISTANCE and uses metres; Developer C should decide how to present combined distance and kill points after Developer A's scoring integration.

## Input and projectile ownership

- Exact ammo signal: `signal ammo_changed(current: int)` (one integer argument).
- `project.godot` currently has no `shoot` action. Player `_ensure_input_actions()` registers `shoot` with physical Spacebar at runtime if it is missing, preserving any existing mapping. No project settings edit is included.
- In normal Main gameplay a fired bullet is a direct child of Main (`get_tree().current_scene`), not Player or World. In standalone Player F6 it is a sibling under Player's parent. Its horizontal movement is independent of Player motion and World scrolling. Scene reload clears projectiles.

## Validation

- `tests/weapon_collision_test.gd`: actual Main, World-spawned asteroids, real physics hits and duplicate suppression; pickup collection/scroll/cleanup with explicit test-only World registration; distance scoring, death and restart.
- `tests/weapon_test.gd`: Phase 1 ammo/autofire/cooldown and actual Main reload.
- Existing Player polish, collision, contract and boost suites remain applicable.
- Both automated weapon tests build fixtures from production scenes and require no temporary playtest scenes.
- Compatibility was also tested in a temporary snapshot combining Developer A's current `feature/fuel-and-score` branch with these weapon files: both weapon suites and A's fuel/score suite passed. Three projectile kills awarded exactly 30 bonus points through A's existing handler, separately from distance. This snapshot does not merge or include A's files in the weapon PR, nor does it claim Main's natural BulletPickup assignment is complete.

Run from the project root after importing the project with Godot 4.7.2:

```sh
Godot --headless --path . --fixed-fps 60 --script res://tests/weapon_test.gd
Godot --headless --path . --fixed-fps 60 --script res://tests/weapon_collision_test.gd
```

Tests do not claim natural Main BulletPickup spawning or the +10 total-score integration is complete.
