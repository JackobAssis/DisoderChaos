# Sistema de Pets e Companions - Disorder Chaos
extends Resource
class_name Pet

## Classe base para todos os pets/companions do jogo
## Representa um pet com suas propriedades, habilidades e IA

signal pet_summoned(pet: Pet)
signal pet_dismissed(pet: Pet)
signal pet_level_up(pet: Pet, new_level: int)
signal pet_xp_gained(pet: Pet, xp_amount: int)
signal pet_ability_used(pet: Pet, ability_id: String)
signal pet_died(pet: Pet)

enum PetType {
	ATAQUE_LEVE,
	SUPORTE,
	COLETA_LOOT,
	PASSIVO
}

enum PetRarity {
	COMUM,
	INCOMUM,
	RARO,
	EPICO,
	LENDARIO,
	MITICO
}

@export var id: String = ""
@export var name: String = ""
@export var type: PetType = PetType.ATAQUE_LEVE
@export var rarity: PetRarity = PetRarity.COMUM
@export var description: String = ""

# Propriedades visuais
@export var icon_path: String = ""
@export var model_path: String = ""

# Sistema de nível e XP
@export var level: int = 1
@export var current_xp: int = 0
@export var max_level: int = 20
@export var level_required: int = 1
@export var unlocked: bool = false

# Estatísticas base
var base_stats: Dictionary = {}
var growth_stats: Dictionary = {}
var current_stats: Dictionary = {}

# Habilidades
var abilities: Dictionary = {}
var ability_cooldowns: Dictionary = {}

# Configuração de IA
var follow_distance: Dictionary = {}
var ai_config: Dictionary = {}

# Estado runtime
var is_active: bool = false
var owner_entity: Entity = null
var pet_node: Node = null
var last_ability_use: Dictionary = {}

# IA e comportamento
var target_position: Vector2 = Vector2.ZERO
var current_behavior: String = "follow"
var last_ai_update: float = 0.0
var behavior_timer: float = 0.0

func _init():
	_initialize_default_values()

func _initialize_default_values():
	base_stats = {
		"health": 50,
		"attack": 10,
		"defense": 5,
		"speed": 100
	}
	
	growth_stats = {
		"health": 5,
		"attack": 1,
		"defense": 1,
		"speed": 2
	}
	
	follow_distance = {
		"min": 50,
		"max": 150,
		"preferred": 80
	}
	
	ai_config = {
		"aggression": 0.5,
		"loyalty": 0.8,
		"independence": 0.3
	}
	
	current_stats = base_stats.duplicate()

## Verifica se o pet pode ser invocado
func can_be_summoned(player: Entity) -> bool:
	if not unlocked:
		return false
	
	if player.level < level_required:
		return false
	
	if is_active:
		return false
	
	return true

## Invoca o pet
func summon(player: Entity) -> bool:
	if not can_be_summoned(player):
		return false
	
	owner_entity = player
	is_active = true
	
	# Criar node do pet se necessário
	if model_path != "" and pet_node == null:
		pet_node = load(model_path).instantiate()
		player.get_parent().add_child(pet_node)
		pet_node.global_position = player.global_position + Vector2(50, 0)
	
	# Calcular stats atuais baseado no nível
	_calculate_current_stats()
	
	# Inicializar IA
	_initialize_ai()
	
	pet_summoned.emit(self)
	return true

## Dispensa o pet
func dismiss() -> bool:
	if not is_active:
		return false
	
	is_active = false
	
	# Remover node do pet
	if pet_node:
		pet_node.queue_free()
		pet_node = null
	
	owner_entity = null
	pet_dismissed.emit(self)
	return true

## Atualiza o pet por frame
func update_pet(delta: float):
	if not is_active or not owner_entity:
		return
	
	# Atualizar IA
	_update_ai(delta)
	
	# Atualizar cooldowns de habilidades
	_update_ability_cooldowns(delta)
	
	# Atualizar posição do node
	if pet_node and owner_entity:
		_update_pet_position(delta)
	
	# Processar comportamento baseado no tipo
	_process_pet_behavior(delta)

## Ganha XP
func gain_xp(amount: int):
	if level >= max_level:
		return
	
	current_xp += amount
	pet_xp_gained.emit(self, amount)
	
	# Verificar level up
	_check_level_up()

## Usa uma habilidade
func use_ability(ability_id: String) -> bool:
	if not is_active or ability_id not in abilities:
		return false
	
	# Verificar cooldown
	var current_time = Time.get_time_dict_from_system().get("second", 0)
	if ability_id in last_ability_use:
		var ability_data = _get_ability_data(ability_id)
		if ability_data:
			var cooldown = ability_data.get("cooldown", 0)
			var time_since_use = current_time - last_ability_use[ability_id]
			if time_since_use < cooldown:
				return false
	
	# Executar habilidade
	_execute_ability(ability_id)
	last_ability_use[ability_id] = current_time
	pet_ability_used.emit(self, ability_id)
	return true

## Calcula stats atuais baseado no nível
func _calculate_current_stats():
	current_stats.clear()
	
	for stat_name in base_stats:
		var base_value = base_stats.get(stat_name, 0)
		var growth_value = growth_stats.get(stat_name, 0)
		current_stats[stat_name] = base_value + (growth_value * (level - 1))

## Verifica se deve subir de nível
func _check_level_up():
	var xp_needed = _get_xp_for_level(level + 1)
	
	while current_xp >= xp_needed and level < max_level:
		level += 1
		current_xp -= xp_needed
		_calculate_current_stats()
		pet_level_up.emit(self, level)
		
		if level < max_level:
			xp_needed = _get_xp_for_level(level + 1)
		else:
			break

## Obtém XP necessário para um nível
func _get_xp_for_level(target_level: int) -> int:
	# XP progressivo: nível * 100 + nível²  * 50
	return target_level * 100 + target_level * target_level * 50

## Inicializa IA do pet
func _initialize_ai():
	target_position = owner_entity.global_position
	current_behavior = "follow"
	behavior_timer = 0.0

## Atualiza IA do pet
func _update_ai(delta: float):
	if not owner_entity:
		return
	
	last_ai_update += delta
	behavior_timer += delta
	
	# Atualizar IA a cada 0.2 segundos para performance
	if last_ai_update < 0.2:
		return
	
	last_ai_update = 0.0
	
	# Determinar comportamento baseado no tipo e situação
	_determine_behavior()
	
	# Executar comportamento
	_execute_behavior()

## Determina comportamento do pet
func _determine_behavior():
	if not owner_entity:
		return
	
	var distance_to_owner = pet_node.global_position.distance_to(owner_entity.global_position)
	var max_distance = follow_distance.get("max", 150)
	var min_distance = follow_distance.get("min", 50)
	
	# Se muito longe, sempre seguir
	if distance_to_owner > max_distance:
		current_behavior = "follow"
		return
	
	# Se muito perto, manter distância
	if distance_to_owner < min_distance and current_behavior == "follow":
		current_behavior = "maintain_distance"
		return
	
	# Comportamento específico por tipo
	match type:
		PetType.ATAQUE_LEVE:
			_determine_attack_behavior()
		PetType.SUPORTE:
			_determine_support_behavior()
		PetType.COLETA_LOOT:
			_determine_collect_behavior()
		PetType.PASSIVO:
			_determine_passive_behavior()

## Determina comportamento de ataque
func _determine_attack_behavior():
	# Procurar inimigos próximos
	var enemies = _find_nearby_enemies()
	
	if enemies.size() > 0 and ai_config.get("aggression", 0.5) > 0.5:
		current_behavior = "attack"
	else:
		current_behavior = "follow"

## Determina comportamento de suporte
func _determine_support_behavior():
	# Verificar se owner precisa de cura
	var owner_health_component = owner_entity.get_component("HealthComponent")
	if owner_health_component:
		var health_percent = owner_health_component.current_health / owner_health_component.max_health
		if health_percent < 0.5:
			current_behavior = "heal"
			return
	
	current_behavior = "follow"

## Determina comportamento de coleta
func _determine_collect_behavior():
	# Procurar itens próximos
	var items = _find_nearby_items()
	
	if items.size() > 0:
		current_behavior = "collect"
	else:
		current_behavior = "follow"

## Determina comportamento passivo
func _determine_passive_behavior():
	# Pets passivos sempre seguem
	current_behavior = "follow"

## Executa comportamento atual
func _execute_behavior():
	match current_behavior:
		"follow":
			_execute_follow_behavior()
		"attack":
			_execute_attack_behavior()
		"heal":
			_execute_heal_behavior()
		"collect":
			_execute_collect_behavior()
		"maintain_distance":
			_execute_maintain_distance_behavior()

## Executa comportamento de seguir
func _execute_follow_behavior():
	if not owner_entity:
		return
	
	var preferred_distance = follow_distance.get("preferred", 80)
	var direction = owner_entity.global_position.direction_to(pet_node.global_position)
	target_position = owner_entity.global_position + direction * preferred_distance

## Executa comportamento de ataque
func _execute_attack_behavior():
	var enemies = _find_nearby_enemies()
	if enemies.size() > 0:
		var closest_enemy = enemies[0]
		# Usar habilidade de ataque se disponível
		for ability_id in abilities.values():
			var ability_data = _get_ability_data(ability_id)
			if ability_data and ability_data.get("type", "") == "active_attack":
				use_ability(ability_id)
				break
	else:
		current_behavior = "follow"

## Executa comportamento de cura
func _execute_heal_behavior():
	# Usar habilidade de cura
	for ability_id in abilities.values():
		var ability_data = _get_ability_data(ability_id)
		if ability_data and ability_data.get("type", "") in ["conditional_heal", "instant_heal"]:
			if use_ability(ability_id):
				break

## Executa comportamento de coleta
func _execute_collect_behavior():
	var items = _find_nearby_items()
	if items.size() > 0:
		# Mover para o item mais próximo
		var closest_item = items[0]
		target_position = closest_item.global_position
		
		# Usar habilidade de coleta se próximo o suficiente
		if pet_node.global_position.distance_to(closest_item.global_position) < 30:
			for ability_id in abilities.values():
				var ability_data = _get_ability_data(ability_id)
				if ability_data and ability_data.get("type", "") == "auto_collect":
					use_ability(ability_id)
					break

## Executa comportamento de manter distância
func _execute_maintain_distance_behavior():
	if not owner_entity:
		return
	
	var preferred_distance = follow_distance.get("preferred", 80)
	var direction = pet_node.global_position.direction_to(owner_entity.global_position)
	target_position = owner_entity.global_position + direction * preferred_distance

## Atualiza posição do pet
func _update_pet_position(delta: float):
	if not pet_node:
		return
	
	var speed = current_stats.get("speed", 100)
	var direction = pet_node.global_position.direction_to(target_position)
	var distance = pet_node.global_position.distance_to(target_position)
	
	if distance > 10:  # Margem para evitar oscilação
		pet_node.global_position += direction * speed * delta

## Processa comportamento específico do tipo
func _process_pet_behavior(delta: float):
	match type:
		PetType.PASSIVO:
			_process_passive_buffs()
		PetType.SUPORTE:
			_process_auto_heal(delta)
		PetType.COLETA_LOOT:
			_process_auto_collect(delta)
		PetType.ATAQUE_LEVE:
			_process_auto_attack(delta)

## Processa buffs passivos
func _process_passive_buffs():
	if not owner_entity:
		return
	
	# Aplicar buffs baseados nas habilidades passivas
	for ability_id in abilities.values():
		var ability_data = _get_ability_data(ability_id)
		if ability_data and ability_data.get("type", "") in ["passive_buff", "aura_buff"]:
			_apply_passive_effect(ability_id, ability_data)

## Processa cura automática
func _process_auto_heal(delta: float):
	# Lógica de cura automática já está em _determine_support_behavior
	pass

## Processa coleta automática
func _process_auto_collect(delta: float):
	# Usar habilidade de auto coleta periodicamente
	for ability_id in abilities.values():
		var ability_data = _get_ability_data(ability_id)
		if ability_data and ability_data.get("type", "") == "auto_collect":
			if behavior_timer > ability_data.get("interval", 2.0):
				use_ability(ability_id)
				behavior_timer = 0.0
				break

## Processa ataque automático
func _process_auto_attack(delta: float):
	# Lógica de ataque automático já está em _determine_attack_behavior
	pass

## Atualiza cooldowns de habilidades
func _update_ability_cooldowns(delta: float):
	# Cooldowns são gerenciados em use_ability()
	pass

## Encontra inimigos próximos
func _find_nearby_enemies() -> Array:
	var enemies = []
	
	if not pet_node:
		return enemies
	
	# Placeholder - implementar busca real de inimigos
	# var bodies = pet_node.get_overlapping_bodies()
	# for body in bodies:
	#     if body.has_method("is_enemy") and body.is_enemy():
	#         enemies.append(body)
	
	return enemies

## Encontra itens próximos
func _find_nearby_items() -> Array:
	var items = []
	
	if not pet_node:
		return items
	
	# Placeholder - implementar busca real de itens
	# var bodies = pet_node.get_overlapping_areas()
	# for body in bodies:
	#     if body.has_method("is_item") and body.is_item():
	#         items.append(body)
	
	return items

## Obtém dados de uma habilidade
func _get_ability_data(ability_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_data and "pet_abilities" in json_data:
			return json_data["pet_abilities"].get(ability_id, {})
	
	return {}

## Executa uma habilidade
func _execute_ability(ability_id: String):
	var ability_data = _get_ability_data(ability_id)
	if not ability_data:
		return
	
	var ability_type = ability_data.get("type", "")
	
	match ability_type:
		"active_attack":
			_execute_attack_ability(ability_data)
		"instant_heal":
			_execute_heal_ability(ability_data)
		"temporary_buff":
			_execute_buff_ability(ability_data)
		"auto_collect":
			_execute_collect_ability(ability_data)
		"area_attack":
			_execute_area_attack_ability(ability_data)

## Executa habilidade de ataque
func _execute_attack_ability(ability_data: Dictionary):
	print("Pet ", name, " usou ataque: ", ability_data.get("name", ""))
	# Implementar dano real aqui

## Executa habilidade de cura
func _execute_heal_ability(ability_data: Dictionary):
	if owner_entity:
		var health_component = owner_entity.get_component("HealthComponent")
		if health_component and health_component.has_method("heal"):
			var heal_amount = ability_data.get("healAmount", 10)
			health_component.heal(heal_amount)
			print("Pet ", name, " curou ", heal_amount, " de vida")

## Executa habilidade de buff
func _execute_buff_ability(ability_data: Dictionary):
	print("Pet ", name, " aplicou buff: ", ability_data.get("name", ""))
	# Implementar buff real aqui

## Executa habilidade de coleta
func _execute_collect_ability(ability_data: Dictionary):
	print("Pet ", name, " coletou itens próximos")
	# Implementar coleta real aqui

## Executa habilidade de ataque em área
func _execute_area_attack_ability(ability_data: Dictionary):
	print("Pet ", name, " usou ataque em área: ", ability_data.get("name", ""))
	# Implementar ataque em área real aqui

## Aplica efeito passivo
func _apply_passive_effect(ability_id: String, ability_data: Dictionary):
	if not owner_entity:
		return
	
	var effect_type = ability_data.get("effect", "")
	
	# Placeholder - implementar efeitos passivos reais
	match effect_type:
		"player_attack_boost":
			# Aumentar ataque do jogador
			pass
		"player_speed_boost":
			# Aumentar velocidade do jogador
			pass
		"stealth":
			# Aplicar stealth
			pass

## Serialização para save/load
func get_save_data() -> Dictionary:
	return {
		"id": id,
		"level": level,
		"current_xp": current_xp,
		"unlocked": unlocked,
		"is_active": is_active,
		"current_stats": current_stats,
		"last_ability_use": last_ability_use
	}

func load_save_data(data: Dictionary):
	level = data.get("level", 1)
	current_xp = data.get("current_xp", 0)
	unlocked = data.get("unlocked", false)
	is_active = data.get("is_active", false)
	current_stats = data.get("current_stats", base_stats.duplicate())
	last_ability_use = data.get("last_ability_use", {})

## Cria pet a partir de dados JSON
static func from_json_data(data: Dictionary) -> Pet:
	var pet = Pet.new()
	
	pet.id = data.get("id", "")
	pet.name = data.get("name", "")
	pet.description = data.get("description", "")
	pet.icon_path = data.get("iconPath", "")
	pet.model_path = data.get("modelPath", "")
	pet.level_required = data.get("levelRequired", 1)
	pet.max_level = data.get("maxLevel", 20)
	pet.unlocked = data.get("unlocked", false)
	
	# Converter tipo
	var type_str = data.get("type", "ataque_leve")
	match type_str:
		"ataque_leve":
			pet.type = PetType.ATAQUE_LEVE
		"suporte":
			pet.type = PetType.SUPORTE
		"coleta_loot":
			pet.type = PetType.COLETA_LOOT
		"passivo":
			pet.type = PetType.PASSIVO
	
	# Converter raridade
	var rarity_str = data.get("rarity", "comum")
	match rarity_str:
		"comum":
			pet.rarity = PetRarity.COMUM
		"incomum":
			pet.rarity = PetRarity.INCOMUM
		"raro":
			pet.rarity = PetRarity.RARO
		"épico":
			pet.rarity = PetRarity.EPICO
		"lendário":
			pet.rarity = PetRarity.LENDARIO
		"mítico":
			pet.rarity = PetRarity.MITICO
	
	# Carregar stats
	pet.base_stats = data.get("baseStats", {})
	pet.growth_stats = data.get("growthStats", {})
	pet.abilities = data.get("abilities", {})
	pet.follow_distance = data.get("followDistance", {})
	pet.ai_config = data.get("aiConfig", {})
	
	pet._calculate_current_stats()
	return pet