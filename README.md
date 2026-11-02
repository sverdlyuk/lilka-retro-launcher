# Retro Launcher

Меню для запуску ретро-ігор на Лілці через ядра retro-go.

## Платформи
- NES, PC Engine, Game Boy / Color, Master System, Game Gear, ColecoVision, Atari Lynx (ядро `retro-core`)
- Mega Drive / Genesis (`gwenesis`)
- SNES (`snes9x`)
- PICO-8 (`pico8`)
- Commodore 64 (`frodo`)
- Duke Nukem 3D (`duke3d-go`)

## Як користуватися
1. Покладіть ROM-и у відповідні теки `/sd/roms/<платформа>` (напр. `/sd/roms/nes`).
2. Оберіть платформу та гру в меню.
3. Потрібне ядро завантажиться автоматично (потрібен Wi-Fi) і гра запуститься.

Лаунчер пише `/sd/retro-go/config/boot.json` і стартує ядро через `util.multiboot`.

## Керування
- **↑ / ↓** — вибір
- **A** — запустити
- **B** — назад / вихід

- # Retro Launcher

A menu to launch retro games on Lilka using retro-go cores.

## Platforms
- NES, PC Engine, Game Boy / Color, Master System, Game Gear, ColecoVision, Atari Lynx (`retro-core`)
- Mega Drive / Genesis (`gwenesis`)
- SNES (`snes9x`)
- PICO-8 (`pico8`)
- Commodore 64 (`frodo`)
- Duke Nukem 3D (`duke3d-go`)

## Usage
1. Put ROMs into `/sd/roms/<platform>` (e.g. `/sd/roms/nes`).
2. Pick a platform and a game in the menu.
3. The required core is downloaded automatically (Wi-Fi needed) and the game starts.

The launcher writes `/sd/retro-go/config/boot.json` and boots the core via `util.multiboot`.

## Controls
- **↑ / ↓** — navigate
- **A** — launch
- **B** — back / exit
