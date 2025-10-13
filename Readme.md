![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/EuphoricRPG/euphoric?utm_source=oss&utm_medium=github&utm_campaign=EuphoricRPG%2Feuphoric&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

# 🎮 Project Design Document: *Euphoric* (Ultima IV-Style Game in Godot)

---

## 🎯 Project Goals

* Faithful to **Ultima IV** style
* Modular map system: **Overworld**, **Village**, **Dungeon**, **Combat**
* Tile-based movement and maps
* Turn-based combat system
* Dialogue trees from NPCs
* Menu screen with options and save/load
* Data-driven design (JSON or CSV for items, maps, NPCs)

---

## 🧱 Architecture Overview

### 1. Godot Scene Structure (High-Level)

```
Main (root)
├── MenuScreen (Scene)
├── GameManager (Singleton)
├── World (Node)
│   ├── Overworld (TileMap)
│   ├── Village (TileMap)
│   ├── Dungeon (TileMap)
│   └── Combat (Turn-based scene)
├── Player (KinematicBody2D)
├── UI (CanvasLayer)
│   ├── DialogBox
│   ├── Inventory
│   └── StatusBar
```

### 2. Modes

| Mode               | Scene/State          | Notes                      |
| ------------------ | -------------------- | -------------------------- |
| **Menu**           | MenuScreen           | Title, start/load game     |
| **Overworld**      | TileMapScene         | Shows large world          |
| **Village**        | TileMapScene         | Houses NPCs, shops         |
| **Dungeon**        | TileMapScene         | Combat encounters, puzzles |
| **Combat**         | TurnBasedCombatScene | Party vs enemies           |
| **Menu/Inventory** | UI Popup             | See items, stats, virtues  |

---

## 🔄 State Management

* Controlled via a **GameManager singleton**.
* States: `"MENU"`, `"OVERWORLD"`, `"VILLAGE"`, `"DUNGEON"`, `"COMBAT"`, `"DIALOG"`.
* Switching scenes does not delete player/inventory data; it's preserved in the GameManager.

---

## 🎨 Visual Style

* Pixel art, 16x16 or 32x32 tiles.
* Retro CRT-style optional shader.
* Tilemaps for world/dungeon/village.

---

## 🎮 Controls

| Key           | Action           |
| ------------- | ---------------- |
| Arrows / WASD | Move             |
| Enter / Space | Interact         |
| I             | Open Inventory   |
| Esc           | Pause/Menu       |
| Typing        | Dialog responses |

---

## 🧩 Modular Content

### 🔸 Maps

* TileMaps loaded via `.tscn` or `.json`.
* Easy to add new maps by dropping them into a folder and registering in a config file:

```json
{
  "maps": [
	{ "id": "overworld", "scene": "res://maps/overworld.tscn" },
	{ "id": "village_1", "scene": "res://maps/village_1.tscn" }
  ]
}
```

### 🔸 Items

Stored in a JSON file (`items.json`):

```json
{
  "healing_potion": {
	"name": "Healing Potion",
	"effect": "heal",
	"value": 20,
	"icon": "res://icons/potion.png"
  }
}
```

### 🔸 NPC Dialogs

Stored in an NPC file (`npc.json`):

```json
  "valewind": [
	{
	  "NAME": "I am a guard.",
	  "JOB": "I am a guard.",
	  "HEALTH": "Strong.",
	  "GOLD": "Bribery is illegal.",
	  "DESCRIPTION": "You see a strong guard.",
	  "GENDER": "Male",
	  "AGE": 33,
	  "location": {
		"x": 17,
		"y": 16
	  },
	  "CLEAN_NAME": "Guard",
	  "SPRITE": "guard"
	},...
```

---

## ⚔️ Combat Design

* **Turn-based**, player party vs enemy group.
* Initiative queue (AGI or random roll).
* Tactical, movement on a tile map as well as selection of combat action
* Implement as a self-contained scene to load when combat is triggered.
* Data for enemies loaded from `enemies.json`.

---

## 🧠 Virtue System (Optional, Ultima-Style)

* Player earns virtue points based on actions (e.g., Honesty, Compassion).
* Quests and endings influenced by virtues.

---

## 📁 Folder Structure

```
res://
├── scenes/
│   ├── overworld/
│   ├── settlement/
│   ├── dungeon/
│   └── combat/
├── data/
│   ├── items.json
│   ├── dialogs/
│   └── maps.json
├── res /
│   ├── sprites/
│   ├── u4graphics-master/ <-- Tiles for the world
│   └── sounds (other name)/
├── scripts/
│   ├── game_manager.gd
│   ├── ...
│   └── combat.gd
```

---

## ✅ Milestone Plan

### ✅ Phase 1: Core Framework

* [X] Basic TileMap + Player movement
* [ ] GameManager singleton
* [ ] Menu screen
* [ ] Map loading system

### ✅ Phase 2: NPC & Dialog

* [x] Dialog system from JSON
* [x] NPC interaction
* [x] Dialog triggers external events
* [ ] Persist NPCs from every scene change

### ✅ Phase 3: Inventory & Items

* [ ] Item system with JSON
* [ ] Simple inventory UI
* [ ] Basic item effects (e.g., healing)
* [ ] Set up Party system

### ✅ Phase 4: Combat

* [ ] Turn-based combat framework
* [ ] Basic AI
* [ ] Load enemies from JSON

### ✅ Phase 5: Expansion

* [ ] Add new maps (village, dungeon)
* [ ] Add quests and virtue system
* [ ] Polish with sound, UI and effects
* [ ] IP Cleanup

### ✅ Phase 6: Extension (in parallel)

* [ ] Add a unique storyline
* [ ] Add unique artwork
* [ ] Make a plot spanning multiple area
* [ ] End the game
