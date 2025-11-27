# Disorder Chaos

A modular RPG/Action game built with Godot 4.x, featuring dynamic dungeons, character progression, and an expandable architecture.

## 🎯 Game Overview

Disorder Chaos is a top-down RPG with action elements where players explore interconnected dungeons, fight enemies, collect loot, and progress their character. The game features a modular design that makes it easy to add new content, mechanics, and systems.

### Core Features
- **Character Creation**: Choose from multiple races and classes with unique attributes
- **Dynamic Dungeons**: Interconnected dungeon system with procedural enemy spawning
- **Combat System**: Real-time combat with skills, status effects, and damage types
- **Progression**: Level up system with attribute growth and skill unlocking
- **Inventory System**: Collect items, equipment, and consumables
- **Modular Architecture**: Easy to expand with new content and features

## 🏗️ Project Structure

```
/project
  /scenes
    /player          # Player character scenes
    /enemies         # Enemy and NPC scenes
    /ui              # User interface scenes
    /world           # World and environment scenes
    /dungeons        # Dungeon templates and instances
  /scripts
    /systems         # Core game systems (combat, dungeon management)
    /entities        # Entity controllers (player, enemies)
    /ui              # UI controllers and managers
    /utils           # Utility scripts and helpers
  /data              # JSON data files for game content
    base_attributes.json  # Core attribute definitions
    races.json           # Player race definitions
    classes.json         # Player class definitions  
    spells.json          # Skills and abilities
    dungeons.json        # Dungeon configurations
    items.json           # Items, weapons, armor
  /assets
    /sprites         # 2D graphics and textures
    /sounds          # Audio files and music
    /fx              # Visual effects
  /autoload          # Global singleton scripts
    GameState.gd     # Global game state management
    EventBus.gd      # Event communication system
    DataLoader.gd    # JSON data loading and caching
```

## 🚀 Quick Start

1. **Open in Godot**: Open the project in Godot 4.x
2. **Run the Game**: Press F5 or click the play button
3. **Create Character**: Choose race, class, and name for your character
4. **Start Playing**: Use WASD to move, Space to attack, E to use items

### Controls
- **WASD**: Movement
- **Space**: Basic attack
- **E**: Use quick item
- **F**: Interact with objects
- **Esc**: Pause/Menu

## 🎮 Game Systems

### Character System
- **Races**: Human (balanced), Beastkin (agile), Mystborn (magical)
- **Classes**: Warrior (melee), Rogue (stealth), Mage (magic)
- **Advanced Classes**: Specializations, prestige evolution, dual-class system
- **Attributes**: Strength, Agility, Vitality, Intelligence, Willpower, Luck

### Combat System
- Real-time combat with attack/dodge mechanics
- Physical, magical, and true damage types
- Critical hits and status effects
- Skill cooldowns and mana costs
- **PvP System**: Arena, battlegrounds, ranking, tournaments

### Guild System
- **Guild Creation**: Member management, ranking system
- **Guild Activities**: Raids, wars, expeditions
- **Alliance System**: Multi-guild cooperation
- **Guild Halls**: Upgradeable facilities and defenses

### Raid & Dungeon System
- **Raid Types**: Dungeon crawl, raid instances, epic raids, world bosses
- **Difficulty Scaling**: Normal to Mythic with unique mechanics
- **Group Mechanics**: Role requirements, coordination tools
- **Loot Systems**: Multiple distribution methods, progression rewards

### Pet & Companion System
- **Pet Types**: Attack, support, passive buff, collection pets
- **AI Behavior**: Advanced follow mechanics, combat assistance
- **Progression**: XP system, abilities, stat growth
- **Management**: Single active pet, UI controls, pet storage

### Data-Driven Design
All game content is defined in JSON files, making it easy to:
- Add new races, classes, and skills
- Create new dungeons and enemies
- Define items and equipment
- Configure advanced systems (classes, guilds, PvP, raids)
- Modify game balance without code changes

## 🔧 Development Guide

### Adding New Content

#### New Race
1. Edit `data/races.json`
2. Add race definition with ID, name, description, and attribute bonuses
3. No code changes required

#### New Class
1. Edit `data/classes.json`
2. Define class with base stats and starting skills
3. Add corresponding skills to `data/spells.json`

#### New Dungeon
1. Edit `data/dungeons.json`
2. Define dungeon with spawn points, enemies, and connections
3. Optionally create custom dungeon scene in `/scenes/dungeons/`

#### New Enemy
1. Create new enemy script extending `BasicEnemy`
2. Configure stats and behaviors
3. Add to dungeon enemy pools in `data/dungeons.json`

### Architecture Principles

#### Event-Driven Communication
- Use `EventBus` for decoupled communication between systems
- Emit events for player actions, combat results, UI updates
- Subscribe to events in relevant systems

#### Modular Systems
- Each system is self-contained and loosely coupled
- `GameState` manages global data and persistence
- `DataLoader` provides centralized data access
- `CombatSystem` handles all combat calculations

#### Data-Driven Configuration
- JSON files define game content and balance
- Scripts focus on behavior, not content
- Easy to modify and expand without programming

## 🛠️ Technical Details

### Built With
- **Engine**: Godot 4.x
- **Language**: GDScript
- **Data Format**: JSON
- **Architecture**: Event-driven, modular design

### Performance Considerations
- JSON data is cached on startup for fast access
- Event system minimizes direct dependencies
- Modular loading allows for efficient memory usage

### Extensibility Features
- Plugin-ready architecture for new systems
- Configurable via external JSON files
- Event system supports custom behaviors
- Clear separation of data and logic

## 🎯 Future Development

### Planned Features
- **Multiplayer Support**: Cooperative dungeon exploration
- **Crafting System**: Item creation and enhancement
- **Quest System**: Story-driven content and side quests
- **Guild System**: Player organizations and group activities
- **PvP Zones**: Competitive player vs player areas
- **Weather & Environment**: Dynamic world conditions
- **Advanced AI**: Smarter enemy behaviors and group tactics

### Technical Roadmap
- Save/load system with multiple save slots
- Localization support for multiple languages
- Mod support with external content loading
- Performance optimization for larger worlds
- Visual effects and animation improvements

## 📄 File Documentation

### Key Scripts
- `GameState.gd`: Global game state, player data, save/load
- `EventBus.gd`: Event communication hub
- `DataLoader.gd`: JSON data loading and management
- `CombatSystem.gd`: Combat calculations and damage handling
- `PlayerController.gd`: Player movement, combat, and interaction
- `DungeonController.gd`: Dungeon spawning and progression logic
- `BasicEnemy.gd`: Enemy AI and behavior template

### Data Files
- `base_attributes.json`: Core character attributes
- `races.json`: Player race definitions and bonuses
- `classes.json`: Character classes with skills and stats
- `spells.json`: All skills and abilities in the game
- `dungeons.json`: Dungeon layouts and configurations
- `items.json`: Items, weapons, armor, and consumables

## 🤝 Contributing

This project is designed to be easily extensible. To contribute:

1. Follow the existing code structure and patterns
2. Use the Event Bus for communication between systems
3. Add new content via JSON files when possible
4. Document any new systems or major changes
5. Test thoroughly with different character builds

## 📝 License

This project is created as a learning example and foundation for RPG game development with Godot.

---

**Disorder Chaos** - Where order meets chaos in an ever-changing world of adventure!