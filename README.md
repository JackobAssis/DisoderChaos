# Disorder Chaos

A modular RPG/Action game built with Godot 4.x, featuring dynamic dungeons, character progression, and an expandable architecture.

## 🚀 Execução Rápida

```powershell
# Abrir no editor Godot
godot4.exe -e -p "d:\Arquivos DEV\DisoderChaos"

# Rodar o jogo diretamente
godot4.exe -p "d:\Arquivos DEV\DisoderChaos"
```

## 🎯 Game Overview

Disorder Chaos is a top-down RPG with action elements where players explore interconnected dungeons, fight enemies, collect loot, and progress their character. The game features a modular design that makes it easy to add new content, mechanics, and systems.

### Core Features
- **Character Creation**: Choose from multiple races and classes with unique attributes
- **Dynamic Dungeons**: Interconnected dungeon system with procedural enemy spawning
- **Combat System**: Real-time combat with skills, status effects, and damage types
- **Progression**: Level up system with attribute growth and skill unlocking
- **Inventory System**: Collect items, equipment, and consumables
- **Advanced Class System**: 6 specializations with prestige evolution and dual-class mechanics
- **Guild System**: Member management, guild halls, alliances, and activities
- **PvP System**: 6 game modes with ranking system and tournaments
- **Raid System**: 5 raid types with difficulty scaling and boss mechanics
- **Pet System**: Tame, evolve and battle with mystical creatures
- **Mount System**: Rideable creatures with unique abilities and skills
- **Crafting System**: Comprehensive crafting with recipes, materials, and progression
- **Skill Trees**: Advanced character development with multiple specialization paths
- **Boss Fights**: Specialized boss encounters with unique mechanics and phases
- **Economy System**: Dynamic NPC shops with market events and reputation
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
      /classes       # Advanced class and specialization systems
      /guilds        # Guild management and alliance systems
      /pvp           # PvP matchmaking and tournament systems
      /raids         # Raid instance and boss encounter systems
    /entities        # Entity controllers (player, enemies)
    /ui              # UI controllers and managers
      /hud           # HUD components (MainHUD, Minimap)
      /menus         # Menu systems (Inventory, Crafting, Skills, Shop, etc.)
    /utils           # Utility scripts and helpers
  /data              # JSON data files for game content
    /classes         # Advanced class system data
    /guilds          # Guild system configuration
    /pvp             # PvP modes and ranking data
    /raids           # Raid encounters and boss data
    /pets            # Pet system configuration
    /mounts          # Mount system data
    /crafting        # Crafting recipes and materials
    /skills          # Skill trees and abilities
    /economy         # Shop and economic system data
    base_attributes.json  # Core attribute definitions
    races.json           # Player race definitions
    classes.json         # Player class definitions  
    spells.json          # Skills and abilities
    dungeons.json        # Dungeon configurations
    items.json           # Items, weapons, armor
  /ui                # UI scenes and components
    /hud             # HUD interface scenes
    /menus           # Menu interface scenes
    /pets            # Pet system UI
    /mounts          # Mount system UI
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

### User Interface Systems
- **HUD Base**: MainHUD with health/mana/XP bars, quickslots, notifications
- **Menus**: Main menu, pause menu, character creation
- **Inventory & Equipment**: Complete inventory management with drag/drop
- **Crafting Interface**: Recipe browser, crafting queue, material tracking
- **Skill Trees**: Visual skill trees with prerequisites and specializations
- **Boss Fight UI**: Specialized interface for boss encounters with mechanics tracking
- **Shop System**: NPC merchants with dynamic pricing and reputation
- **Minimap**: Navigation, markers, fog of war, zoom controls

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

#### New Crafting Recipe
1. Edit `data/crafting/recipes.json`
2. Add recipe with materials, skill requirements, and results
3. Configure crafting stations if needed

#### New Skill Tree
1. Edit `data/skills/skill_trees.json`
2. Define skills with prerequisites, effects, and positioning
3. UI will automatically generate the skill tree

#### New Shop
1. Edit `data/economy/shop_system.json`
2. Configure shop type, inventory, and pricing
3. Add to NPC interaction system

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

### Recently Implemented ✅
- **Advanced UI Systems**: Complete interface overhaul with crafting, skill trees, boss fights, shops
- **Guild System**: Full guild management with alliances and activities
- **PvP System**: Arena modes, ranking, tournaments
- **Raid System**: Instance management with boss mechanics
- **Pet & Mount Systems**: Creature companions with unique abilities
- **Crafting System**: Recipe-based item creation with stations
- **Dynamic Minimap**: Enhanced navigation with markers and fog of war

### Planned Features
- **Multiplayer Support**: Cooperative dungeon exploration
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

## 🧪 Checklist de Validação

### Main Menu
- [ ] Main Menu inicia e mostra opções (Novo Jogo, Carregar, Opções, Créditos, Sair)
- [ ] Botões respondem a hover e click com feedback visual/sonoro
- [ ] Carregar Jogo abre UI de slots de save

### In-Game
- [ ] Novo Jogo entra na cena principal com HUD ativo
- [ ] Movimento WASD funciona
- [ ] ESC abre/fecha Pause Menu
- [ ] HUD mostra HP/MP/XP e informações do personagem

### Pause Menu
- [ ] Pause → Inventário abre e fecha corretamente
- [ ] Pause → Equipamentos abre e fecha corretamente
- [ ] Pause → Crafting abre e fecha corretamente
- [ ] Pause → Opções abre menu de configurações
- [ ] Popup de confirmação ao clicar em "Sair" ou "Menu Principal"

### Sistemas
- [ ] Notificações aparecem na tela (info/success/warning/error)
- [ ] Save/Load funciona via slots
- [ ] Sistema de quests registra progresso
- [ ] Sistema de combate calcula dano e status

## 📐 EventBus API Padronizada

Todas as comunicações UI utilizam a API unificada do EventBus:

### Menus
```gdscript
EventBus.request_menu("inventory")
EventBus.request_menu("equipment")
EventBus.request_menu("crafting")
EventBus.request_menu("options")
```

### Popups
```gdscript
EventBus.request_popup("confirmation", {
    "title": "Confirmar Ação",
    "message": "Tem certeza que deseja sair?",
    "confirm_text": "Sim",
    "cancel_text": "Não"
})
```

### Notificações
```gdscript
EventBus.show_notification("Item adquirido!", "success")
EventBus.show_notification("Atenção: HP baixo", "warning")
EventBus.show_notification("Erro ao salvar", "error")
```

### Sons
```gdscript
EventBus.play_sound("button_click")
EventBus.play_sound("button_hover")
```

## 📄 File Documentation

### Key Scripts
- `GameState.gd`: Global game state, player data, save/load
- `EventBus.gd`: Event communication hub with unified API
- `UIManager.gd`: Orchestrates all UI systems (HUD, menus, popups)
- `PopupManager.gd`: Manages notification and confirmation popups
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