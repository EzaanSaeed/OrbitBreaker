# itch.io page — Orbit Breaker

Everything needed to publish the web build. Upload steps first, then copy to paste.

## Build to upload

1. Export: **Project → Export… → Web → Export Project**, or
   `godot --headless --path . --export-release "Web" build/web/index.html`
2. Zip the **contents** of `build/web/` so `index.html` is at the top level of the zip:
   `cd build/web && zip -r ../orbit-breaker-web.zip . -x '*.import' -x '.*'`
3. Screenshots for the page: `build/itch/screenshot-gameplay.png`, `build/itch/screenshot-gameover.png` (regenerate if the look changes).

## Settings on "Create new project"

| Field | Value |
|---|---|
| Kind of project | **HTML** |
| Upload | `build/orbit-breaker-web.zip`, tick **This file will be played in the browser** |
| Viewport dimensions | **960 × 540** |
| Fullscreen button | On |
| Mobile friendly | Off (keyboard only) |
| SharedArrayBuffer support | **Off** (our build is single-threaded; turning it on is unnecessary) |
| Automatically start on page load | Off ("Click to launch" also gives the game keyboard focus) |
| Genre | Action |
| Tags | `space`, `endless-runner`, `gravity`, `arcade`, `godot`, `2d` |
| Release status | Released (or Prototype) |
| Jam submission | Submit the page to the jam from the jam's page once it's public |

## Short description (tagline)

> Fight planetary gravity with nothing but two thrusters. How far can you get?

## Page description

> **Orbit Breaker** is a 2D endless space runner made in 24 hours for a game jam with the theme **COSMOS**.
>
> Your ship flies forward on its own. All you control is up and down thrust. Every planet you pass pulls you toward it, and the closer you get, the harder it pulls. Use your thrusters to fight the pull, dodge the asteroid field and travel as far as you can.
>
> **Controls**
> - **W / ↑**: thrust up
> - **S / ↓**: thrust down
> - **Enter / Space** on the game-over screen: restart
>
> **Rules**
> - Touch a planet: instant death.
> - Hit an asteroid: lose 25 hull. Four hits and you're done.
> - Leave the top or bottom of the screen: lost in space.
> - Green **+** pickups repair 25 hull. Orange **⚡** pickups give 1.5× thrust for 5 seconds.
> - It keeps getting faster, then hazards keep getting denser.
>
> **Credits**
> Made by a team of two with Godot 4 (GDScript).
> - Developer A: world, planets, asteroids, spawning, difficulty, integration, web build
> - Developer B: ship, physics, health, collisions, boosters, HUD
>
> Art: meteors and effects from [Space Shooter Remastered](https://kenney.nl/assets/space-shooter-remastered) by Kenney (CC0).
> Font: [Orbitron](https://github.com/theleagueof/orbitron) by The Orbitron Project Authors (SIL Open Font License 1.1).
>
> Source: https://github.com/EzaanSaeed/OrbitBreaker

Replace "Developer A / Developer B" with your names before publishing.
