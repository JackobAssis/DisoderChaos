# Disorder Chaos - Game Design Document

## 🎮 GAME OVERVIEW

**Disorder Chaos** é um RPG multiplayer online em desenvolvimento, focado em progressão de personagem, combate estratégico e exploração colaborativa. O jogo combina elementos clássicos de RPG com mecânicas modernas de jogos online.

### Pilares do Design
1. **Progressão Significativa** - Cada ação do jogador contribui para o crescimento do personagem
2. **Combate Estratégico** - Sistema de combate que recompensa planejamento e habilidade
3. **Exploração Recompensadora** - Mundo rico em segredos e tesouros
4. **Interação Social** - Sistemas que promovem colaboração entre jogadores

## 🏗️ ARQUITETURA TÉCNICA

### Stack Tecnológico
- **Engine**: Godot 4.x
- **Linguagem**: GDScript
- **Dados**: JSON para configuração de conteúdo
- **Rede**: Godot Multiplayer API
- **Persistência**: SQLite/PostgreSQL

### Arquitetura de Software
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Game Client   │◄──►│   Game Server   │◄──►│   Database      │
│                 │    │                 │    │                 │
│ • UI/UX         │    │ • Game Logic    │    │ • Player Data   │
│ • Input         │    │ • Validation    │    │ • World State   │
│ • Rendering     │    │ • Networking    │    │ • Analytics     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Sistemas Principais

#### 1. Sistema de Eventos (EventBus)
- **Propósito**: Comunicação desacoplada entre sistemas
- **Implementação**: Singleton com sinais Godot
- **Benefícios**: Facilita manutenção e expansão

#### 2. Sistema de Dados (DataLoader)
- **Propósito**: Carregamento e cache de dados JSON
- **Estrutura**: Races, Classes, Spells, Dungeons, Items, Enemies
- **Vantagens**: Fácil balanceamento sem recompilação

#### 3. Sistema de Estados (GameState)
- **Propósito**: Gerenciamento de estado global do jogo
- **Responsabilidades**: Save/Load, Inventário, Progressão
- **Persistência**: Arquivos locais + sincronização em nuvem

## 🎯 MECÂNICAS CENTRAIS

### Sistema de Progressão

#### Experiência e Níveis
```gdscript
# Fórmula de XP por nível
func calculate_xp_required(level: int) -> int:
    return int(100 * pow(level, 1.5) + 50 * level)
```

#### Atributos Base
- **Força (STR)**: Dano físico, capacidade de carga
- **Destreza (DEX)**: Precisão, esquiva, velocidade de ataque
- **Inteligência (INT)**: Dano mágico, MP máximo
- **Constituição (CON)**: HP máximo, resistência
- **Sabedoria (WIS)**: Regeneração de MP, resistência mágica
- **Carisma (CHA)**: Interações sociais, liderança

#### Atributos Derivados
```gdscript
func calculate_derived_attributes():
    max_hp = base_hp + (constitution * 10) + (level * 5)
    max_mp = base_mp + (intelligence * 8) + (level * 3)
    attack_power = base_attack + (strength * 2) + weapon_bonus
    defense = base_defense + (constitution * 1.5) + armor_bonus
```

### Sistema de Combat

#### Tipos de Dano
1. **Físico**: Reduzido por armadura física
2. **Mágico**: Reduzido por resistência mágica
3. **Elemental**: Fogo, Gelo, Raio, Terra
4. **Sagrado/Sombrio**: Dano especial contra certas criaturas

#### Mecânicas de Combate
- **Cooldown Global**: 1 segundo entre ações
- **Cooldowns Específicos**: Por habilidade/item
- **Status Effects**: Buffs/debuffs temporários
- **Critical Hits**: Baseado em DEX e equipamentos

### Sistema de Itens

#### Categorias de Itens
```json
{
  "weapon": {
    "subcategories": ["sword", "bow", "staff", "dagger"],
    "max_stack": 1,
    "can_equip": true
  },
  "consumable": {
    "subcategories": ["potion", "food", "scroll"],
    "max_stack": 99,
    "can_use": true
  },
  "material": {
    "subcategories": ["ore", "herb", "gem", "essence"],
    "max_stack": 999,
    "used_in_crafting": true
  }
}
```

#### Sistema de Raridade
1. **Comum (Common)** - 60% drop chance - Cinza
2. **Incomum (Uncommon)** - 25% drop chance - Verde
3. **Raro (Rare)** - 10% drop chance - Azul
4. **Épico (Epic)** - 4% drop chance - Roxo
5. **Lendário (Legendary)** - 1% drop chance - Laranja
6. **Mítico (Mythic)** - 0.1% drop chance - Dourado

### Sistema de Dungeons

#### Tipos de Dungeon
1. **Solo**: Para um jogador, balanceado para exploração individual
2. **Party**: Para 2-5 jogadores, requer coordenação
3. **Raid**: Para 10-25 jogadores, eventos especiais
4. **PvP**: Zonas de combate entre jogadores

#### Progressão de Dungeons
```
Goblin Cave (Lvl 1-5) → Dark Forest (Lvl 5-10) → 
Skeleton Crypt (Lvl 10-15) → Dragon Lair (Lvl 15+)
```

## 🎨 DESIGN DE INTERFACE

### Princípios de UI/UX
1. **Clareza**: Informação importante sempre visível
2. **Eficiência**: Ações comuns com poucos cliques
3. **Consistência**: Padrões visuais uniformes
4. **Acessibilidade**: Suporte para diferentes necessidades

### Elementos de Interface

#### HUD Principal
- **Barra de Vida**: Canto superior esquerdo
- **Barra de Mana**: Abaixo da vida
- **Barra de XP**: Parte inferior da tela
- **Slots Rápidos**: Itens e habilidades (1-9)
- **Minimapa**: Canto superior direito

#### Janelas de Sistema
- **Inventário**: Grid 10x6 com filtros
- **Equipamentos**: Paper doll + estatísticas
- **Habilidades**: Árvore de talentos
- **Configurações**: Áudio, vídeo, gameplay

### Temas Visuais
```gdscript
# Paleta de cores principal
var color_scheme = {
    "primary": Color(0.2, 0.3, 0.5),      # Azul escuro
    "secondary": Color(0.8, 0.6, 0.2),    # Dourado
    "success": Color(0.2, 0.8, 0.2),      # Verde
    "warning": Color(0.9, 0.7, 0.1),      # Amarelo
    "danger": Color(0.8, 0.2, 0.2),       # Vermelho
    "info": Color(0.3, 0.6, 0.9)          # Azul claro
}
```

## 🌐 SISTEMAS MULTIPLAYER

### Arquitetura de Rede

#### Cliente-Servidor
- **Servidor Autoritativo**: Todas as decisões importantes no servidor
- **Client Prediction**: Responsividade local para ações do jogador
- **Lag Compensation**: Rollback para ações críticas
- **Anti-Cheat**: Validação server-side de todas as ações

#### Sincronização de Estado
```gdscript
# Frequência de updates
const NETWORK_TICK_RATE = 60  # 60 Hz para precisão
const PLAYER_UPDATE_RATE = 20  # 20 Hz para posição de jogadores
const WORLD_UPDATE_RATE = 5   # 5 Hz para objetos do mundo
```

### Zonas PvP

#### Tipos de Zona
1. **Zona Segura**: Sem PvP, regeneração de vida
2. **Zona Neutra**: PvP opcional, penalidades reduzidas
3. **Zona PvP**: PvP sempre ativo, recompensas maiores
4. **Zona de Guerra**: Combate entre guilds

#### Mecânicas PvP
- **Proteção de Novato**: Jogadores <Lvl 10 protegidos
- **Timer de Proteção**: 30s após deixar zona PvP
- **Sistema de Karma**: Penalidades por PK excessivo
- **Drops Limitados**: Apenas uma porcentagem do inventário

### Sistemas Sociais

#### Guilds/Clans
```gdscript
class Guild:
    var name: String
    var leader: String
    var members: Array[String]
    var level: int
    var experience: int
    var perks: Array[String]
    
    func add_member(player_id: String) -> bool
    func remove_member(player_id: String) -> bool
    func promote_member(player_id: String) -> bool
    func gain_experience(amount: int)
```

#### Chat System
- **Canal Global**: Todos os jogadores online
- **Canal Local**: Jogadores próximos
- **Canal de Guild**: Membros da guild
- **Mensagens Privadas**: Entre jogadores específicos

## 📊 ECONOMIA DO JOGO

### Recursos Principais

#### Moeda
1. **Ouro**: Moeda principal, obtida por quests e vendas
2. **Gemas**: Moeda premium, comprada ou obtida por eventos
3. **Tokens de Guild**: Para melhorias de guild
4. **Materiais de Craft**: Para criação de itens

#### Sistema de Preços
```gdscript
# Fórmula base de preços
func calculate_item_price(base_value: int, rarity: String, level: int) -> int:
    var rarity_multiplier = get_rarity_multiplier(rarity)
    var level_bonus = level * 0.1
    return int(base_value * rarity_multiplier * (1.0 + level_bonus))
```

### Sinks e Sources

#### Gold Sources (Entrada de moeda)
- Morte de inimigos
- Conclusão de quests
- Venda de itens para NPCs
- Participação em eventos

#### Gold Sinks (Saída de moeda)
- Compra de itens de NPCs
- Reparos de equipamentos
- Taxas de guild
- Fast travel

## 🔒 SISTEMAS DE SEGURANÇA

### Anti-Cheat

#### Validações Server-Side
```gdscript
func validate_player_action(player_id: String, action: Dictionary) -> bool:
    # Verificar se ação é fisicamente possível
    if not validate_physics(action):
        return false
    
    # Verificar cooldowns
    if not validate_cooldowns(player_id, action):
        return false
    
    # Verificar recursos necessários
    if not validate_resources(player_id, action):
        return false
    
    return true
```

#### Detecção de Anomalias
- **Speed Hacking**: Monitoramento de velocidade de movimento
- **Teleport Hacking**: Validação de posições consecutivas
- **Item Duplication**: Verificação de hash de inventário
- **DPS Impossível**: Análise estatística de dano

### Proteção de Dados

#### Criptografia
- **Comunicação**: TLS 1.3 para todas as conexões
- **Senhas**: bcrypt com salt aleatório
- **Dados Sensíveis**: AES-256 para informações críticas

#### Privacy
- **GDPR Compliance**: Direito ao esquecimento
- **Data Minimization**: Coleta apenas dados necessários
- **Anonymization**: Analytics sem identificação pessoal

## 📈 MÉTRICAS E ANALYTICS

### KPIs Principais

#### Engajamento
- **DAU/MAU**: Usuários ativos diários/mensais
- **Session Length**: Duração média de sessão
- **Retention Rate**: Taxa de retenção (D1, D7, D30)
- **Churn Rate**: Taxa de abandono

#### Progressão
- **Level Distribution**: Distribuição de levels dos jogadores
- **Quest Completion**: Taxa de conclusão de quests
- **Item Usage**: Frequência de uso de itens
- **Death Analysis**: Principais causas de morte

#### Economia
- **Gold Flow**: Entrada vs. saída de moeda
- **Item Popularity**: Itens mais usados/desejados
- **Trade Volume**: Volume de trocas entre jogadores
- **Price Trends**: Tendências de preços no mercado

### Telemetria

#### Eventos Coletados
```gdscript
# Exemplos de eventos de telemetria
EventBus.analytics_event.emit("player_level_up", {
    "player_id": player_id,
    "new_level": level,
    "time_played": session_time,
    "location": current_zone
})

EventBus.analytics_event.emit("item_used", {
    "item_id": item_id,
    "player_level": player_level,
    "context": usage_context
})
```

## 🚀 ROADMAP DE LANÇAMENTO

### Fase Alpha (Desenvolvimento Atual)
**Duração**: 3-4 meses
**Objetivos**:
- Sistemas centrais funcionais
- Gameplay loop básico completo
- Teste interno com equipe

**Features Principais**:
- ✅ Sistema de progressão completo
- ✅ Combat e loot básicos
- ✅ Dungeons solos
- 🚧 Crafting básico
- 🚧 Interface polida

### Fase Beta Fechada
**Duração**: 2-3 meses
**Objetivos**:
- Teste com jogadores limitados
- Balanceamento de gameplay
- Identificação de bugs críticos

**Features Adicionais**:
- Sistema de guilds básico
- PvP em zonas específicas
- Mais dungeons e conteúdo
- Sistema de amigos

### Fase Beta Aberta
**Duração**: 1-2 meses
**Objetivos**:
- Teste de carga do servidor
- Feedback público amplo
- Marketing e divulgação

**Features Finais**:
- Sistema de eventos
- Marketplace entre jogadores
- Rankings e leaderboards
- Tutorial completo

### Lançamento 1.0
**Objetivos**:
- Experiência polida e estável
- Suporte para 1000+ jogadores simultâneos
- Monetização ética implementada

**Conteúdo de Lançamento**:
- 20+ dungeons únicos
- 5+ zonas de mundo abertas
- 200+ itens únicos
- Sistema de temporadas

---

## 📝 CONSIDERAÇÕES FINAIS

Este documento representa a visão atual do projeto **Disorder Chaos**. Como um documento vivo, será atualizado conforme o desenvolvimento progride e feedback é incorporado.

### Próximos Passos Imediatos
1. ✅ Finalizar sistemas centrais de gameplay
2. 🚧 Implementar crafting básico
3. 🚧 Adicionar mais conteúdo (dungeons, itens, inimigos)
4. 📋 Preparar para testes Alpha

### Contato e Contribuições
Para sugestões, bugs ou contribuições, utilize os canais apropriados de desenvolvimento ou abra issues no repositório do projeto.

---

*Documento criado em: Dezembro 2024*  
*Última atualização: Dezembro 2024*  
*Versão: 1.0*