# Disorder Chaos - Project Structure

## 📁 Estrutura de Diretórios Padronizada

```
DisoderChaos/
├── autoload/              # Scripts autoload do Godot
│   ├── DataLoader.gd      # Carregamento robusto de JSONs
│   ├── GameState.gd       # Estado global do jogo
│   ├── EventBus.gd        # Sistema de eventos
│   └── ConfigManager.gd   # Configurações
│
├── data/                  # Dados do jogo
│   ├── json/              # Arquivos JSON organizados
│   │   ├── races.json
│   │   ├── classes.json
│   │   ├── spells.json
│   │   ├── items.json
│   │   ├── enemies.json
│   │   ├── dungeons.json
│   │   ├── npcs.json
│   │   ├── quests.json
│   │   └── dialogues.json
│   │
│   └── lore/              # Dados de worldbuilding
│       ├── world_timeline.json
│       ├── factions.json
│       └── opening_cinematic.json
│
├── scripts/
│   ├── systems/           # Sistemas de jogo modulares
│   │   ├── QuestSystem.gd
│   │   ├── NPCSystem.gd
│   │   ├── DialogueSystem.gd
│   │   ├── DungeonSystem.gd
│   │   └── (outros sistemas...)
│   │
│   └── entities/          # Entidades de jogo
│       ├── PlayerController.gd
│       ├── PlayerStats.gd
│       ├── EquipmentSystem.gd
│       └── NPCController.gd
│
├── scenes/
│   ├── core/              # Scenes principais
│   │   ├── Player.tscn
│   │   ├── GameManager.tscn
│   │   └── MainMenu.tscn
│   │
│   └── dungeons/          # Scenes de dungeons
│       ├── BasicDungeon.tscn
│       └── (dungeons específicas...)
│
└── assets/                # Recursos visuais e audio
    ├── sprites/
    ├── portraits/
    ├── sounds/
    └── music/
```

## 🔧 Sistemas Implementados (PROMPT 1)

### ✅ DataLoader Robusto
- **Localização**: `autoload/DataLoader.gd`
- **Funcionalidades**:
  - Validação completa de campos obrigatórios
  - Sistema de logs detalhados de erro
  - Prevenção de crash por JSON inválido
  - Carregamento dinâmico de todos os tipos de dados
  - Sistema de sinais para monitoramento de carregamento
  - Métodos getter robustos com fallbacks
  - Validação de cross-references
  - Debug e utilitários de desenvolvimento

### ✅ DungeonSystem Básico
- **Localização**: `scripts/systems/DungeonSystem.gd`
- **Funcionalidades**:
  - Carregamento de dungeons a partir de JSON
  - Instanciação procedural de terreno e decorações
  - Sistema de Fragmentos com conexões
  - Sistema de portais de entrada/saída
  - Verificação de requisitos de entrada
  - Spawners de entidades
  - Efeitos ambientais e climáticos
  - Sistema de descoberta de fragmentos
  - Mapeamento visual de conexões
  - Save/Load de progresso

### ✅ PlayerCore Completo
- **Localização**: `scripts/entities/`
- **Componentes**:
  
  **PlayerController.gd**:
  - Movimento suave com aceleração/friction
  - Sistema de stamina integrado
  - Estados (correndo, interagindo, casting)
  - Input handling completo
  - Animações baseadas em direção
  - Sistema de dodge/roll
  - Interação com objetos
  
  **PlayerStats.gd**:
  - Atributos baseados em raça + classe
  - Sistema de experiência e level up
  - Cálculo automático de HP/Stamina/Mana
  - Modificadores de equipamento
  - Sistema de dano com resistências
  - Progressão de atributos
  
  **EquipmentSystem.gd**:
  - 10 slots de equipamento
  - Validação automática de tipos
  - Cálculo de bônus totais
  - Sistema de sets (preparado)
  - Modificadores de atributo
  - Sistema de durabilidade (placeholder)

## 📋 Padrões de Desenvolvimento

### Arquitetura Modular
- Cada sistema é independente e comunicável via EventBus
- JSON como fonte da verdade para todos os dados
- Componentes reutilizáveis e expansíveis
- Save/Load integrado em todos os sistemas

### Estrutura de Código
- Scripts limpos e bem comentados
- Métodos de debug em todos os sistemas
- Validação de dados em tempo real
- Sistema de logs padronizado
- Tratamento de erro robusto

### Nomenclatura
- **Systems**: `NomeSystem.gd` (ex: `QuestSystem.gd`)
- **Entities**: `NomeController.gd` ou `NomeComponent.gd`
- **Data**: `nome_do_tipo.json` (ex: `world_timeline.json`)
- **Scenes**: `Nome.tscn` (PascalCase)

## 🔗 Integração Between Systems

### EventBus Signals
```gdscript
# Player events
"player_location_changed"
"player_level_changed" 
"player_damaged"
"player_died"

# Dungeon events
"dungeon_loaded"
"fragment_discovered"
"player_entered_dungeon"

# Quest events
"quest_started"
"quest_completed"
"objective_completed"
```

### DataLoader Integration
Todos os sistemas usam o DataLoader para:
- Carregar configurações JSON
- Validar dados antes do uso
- Acessar dados com fallbacks seguros
- Monitorar status de carregamento

## 🚀 Preparação para Próximos Prompts

A base está preparada para:
- **PROMPT 2**: Sistemas narrativos (Quest/NPC/Diálogo/Loot)
- **PROMPT 3**: Sistemas avançados (Boss/Buff/Clima/Stamina/Crafting)

Todos os sistemas seguem o padrão modular estabelecido e podem ser expandidos sem quebrar funcionalidades existentes.