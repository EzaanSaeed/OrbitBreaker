# 🚀 Orbit Breaker

**Orbit Breaker** is a 2D space-themed endless runner developed for a 24-hour game jam under the theme **COSMOS**.

Navigate through space, fight the gravitational pull of planets, dodge obstacles, and survive as long as possible!

## 🎮 Gameplay

Control a spaceship traveling through an endless universe. Nearby planets exert gravitational forces that affect your movement. Use your thrusters to avoid collisions and travel as far as possible.

As you progress, the game becomes increasingly challenging.

## 🕹️ Controls

| Key | Action |
|---|---|
| W / ↑ | Thrust upward |
| S / ↓ | Thrust downward |

## 🛠️ Tech Stack

- **Engine:** Godot 4
- **Language:** GDScript
- **Platform:** Web (HTML5)
- **Architecture:** Scene-based, component-oriented

## 📁 Project Structure

```text
OrbitBreaker/
├── scenes/       # main.tscn (startup), planet.tscn
├── scripts/      # one script per game object (player, planet, world, HUD, ...)
├── assets/       # fonts, Kenney art, audio
└── project.godot
```

## 🌐 Web build

1. In Godot: **Editor → Manage Export Templates** → install templates for your Godot version (4.7.2).
2. **Project → Export… → Web → Export Project** (writes `build/web/index.html`), or from a terminal:
   `godot --headless --path . --export-release "Web" build/web/index.html`
3. Test locally: `cd build/web && python3 -m http.server 8000`, then open http://localhost:8000.
4. For itch.io, zip the *contents* of `build/web/` (so `index.html` is at the top of the zip) and upload it as an HTML game.

## 🚧 Development Status

Currently in development for a 24-hour game jam.

## 👥 Team

Developed by a team of three programmers. Ezaan, Fawaz and Danish.
