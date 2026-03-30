# CLAUDE.md

## Project Overview

Euphoric is an Ultima IV-inspired 2D RPG built in **Godot 4.5** using **GDScript**. It features tile-based movement, turn-based combat, NPC dialog, fog of war, procedural island map generation, and a virtue-based character creation system.

## Tech Stack

- Engine: Godot 4.5 (Mobile renderer)
- Language: GDScript
- Art: 32x32 pixel sprites (Ultima IV-style tileset in `res/u4graphics-master/`)
- Data: JSON files in `data/` for zones, dialogs, shop items; `res/npcs.json` for NPC definitions
- CI: GitHub Actions (`barichello/godot-ci:4.3` container) builds for Windows, Linux, macOS, Android on release

## Project Structure

```
scripts/          # Core game systems (singletons, combat, dialog, inventory, etc.)
scenes/           # Scene files (.tscn) and scene-specific scripts (.gd)
  overworld/      # Overworld map and fog manager
  settlement/     # Village scenes (valewind, eldoria, hut_alvo, gemini)
  dungeon/        # Dungeon scenes (despair, unjust, avarice)
  char_gen/       # Character creation quiz
  menu/           # Main menu
data/             # JSON game data (zones.json, dialogs.json, shop_items.json)
res/              # Assets: sprites, music, sound effects, tilesets, fonts, NPC data
test/             # Test scenes
```

## Key Architecture

### Autoloads (Singletons)
- `Global` (`scripts/global.gd`) — holds `player_inventory` instance, `player_in_scene` flag
- `DialogManager` (`scripts/dialog_manager.gd`) — loads `res/npcs.json`, spawns NPCs in village scenes

### Core Classes
- `CharacterEntity` (`scenes/hero.gd`) — player character; tile-based grid movement, raycast collision, combat trigger, dialog system integration
- `CombatSystem` (`scripts/combat_system.gd`) — self-contained turn-based combat with initiative queue, grid movement, attack targeting, loot drops. Inner classes: `CombatUnit`, `LootChest`
- `dialog_system` (`scripts/dialog_system.gd`) — state machine (READY → DIRECTION → DIALOG) for Ultima-style "press T then direction" NPC conversations
- `npc_node` (`scripts/npc.gd`) — NPC scene node with sprite selection based on NPC data
- `player_inventory` (`scripts/Inventory.gd`) — item dictionary + gold, with signals
- `FollowingCamera2D` (`scenes/FollowingCamera2D.gd`) — camera clamped to tilemap bounds
- `FogOfWar` (`scenes/fog_of_war.gd`) — raycasting fog with persistent revealed tiles
- `Teleporter` (`scripts/Teleporter.gd`) — scene transitions with destination node targeting
- `EncounterManager` (`scripts/EncounterManager.gd`) — zone-based random encounters from JSON

### Map Generator
- `scripts/map_generator.gd` — `@tool` EditorScript that procedurally generates a 256×256 island overworld using centroid-based height maps, saves to `res://map.tscn`

## Conventions

- GDScript style: `snake_case` for variables/functions, `PascalCase` for class names and exported node types
- Tile IDs map to terrain types: 0=Ocean, 1=Water, 2=Shallow, 3=Swamp, 4=Grass, 5=Shrub, 6=Forest, 7=Hill, 8=Mountain
- Blocked movement tiles: 0, 1, 2, 8, 18-20, 25, 27-60
- NPC data keys are UPPERCASE (NAME, JOB, HEALTH, GOLD, DESCRIPTION, HOOK, SPRITE, CLEAN_NAME, LOCATION)
- Dialog input: player types keywords; system matches against NPC data keys and synonym maps
- Grid size is 32px throughout

## Build & Run

- Open in Godot 4.5 editor, run main scene (menu → char gen → overworld)
- CI builds trigger on GitHub release creation
- Export presets configured for Windows, Linux, macOS, Android

## Important Notes

- Combat is triggered by pressing 'A' key in overworld; loads `scenes/combat.tscn` as overlay
- Scene transitions via `Teleporter` reparent the hero and camera to the new scene
- Fog of war uses a static singleton pattern for persistence across scene changes
- The `dialog_system` consumes all input when in DIRECTION or DIALOG state
- NPC sprites are selected by substring matching on the SPRITE field in NPC JSON data
