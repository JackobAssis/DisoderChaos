# Gerenciador de Pets - Disorder Chaos
extends Node
class_name PetManager

## Gerenciador global do sistema de pets
## Coordena todas as funcionalidades relacionadas a pets e companions

signal pet_system_ready()
signal global_pet_event(event_type: String, data: Dictionary)

var pet_system: PetSystem = null
var loaded_pet_data: Dictionary = {}
var global_pet_config: Dictionary = {}

# Configurações globais
@export var max_active_pets: int = 1
@export var global_xp_modifier: float = 1.0
@export var pet_revival_enabled: bool = true
@export var auto_dismiss_in_pvp: bool = true

func _ready():
	# Inicializar sistema
	pet_system = PetSystem.new()
	add_child(pet_system)
	
	# Carregar configurações e dados
	_load_pet_configuration()
	_load_global_pet_data()
	
	# Conectar sinais
	_connect_system_signals()
	
	pet_system_ready.emit()
	print("[PetManager] Pet system initialized")

## Carrega configurações do sistema de pets
func _load_pet_configuration():
	var config_file = FileAccess.open("res://data/pets/pet_config.json", FileAccess.READ)
	if config_file:
		var config_data = JSON.parse_string(config_file.get_as_text())
		config_file.close()
		
		if config_data:
			global_pet_config = config_data
			_apply_global_config()
	else:
		# Configuração padrão
		global_pet_config = {
			"max_active_pets": 1,
			"global_xp_modifier": 1.0,
			"pet_revival_enabled": true,
			"auto_dismiss_in_pvp": true,
			"summon_cooldown": 3.0,
			"max_follow_distance": 200.0,
			"ai_update_frequency": 0.2
		}
		_save_pet_configuration()

## Aplica configurações globais
func _apply_global_config():
	max_active_pets = global_pet_config.get("max_active_pets", 1)
	global_xp_modifier = global_pet_config.get("global_xp_modifier", 1.0)
	pet_revival_enabled = global_pet_config.get("pet_revival_enabled", true)
	auto_dismiss_in_pvp = global_pet_config.get("auto_dismiss_in_pvp", true)

## Salva configurações do sistema
func _save_pet_configuration():
	var config_file = FileAccess.open("res://data/pets/pet_config.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(global_pet_config, "\t"))
		config_file.close()

## Carrega dados globais de pets
func _load_global_pet_data():
	var data_file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if data_file:
		loaded_pet_data = JSON.parse_string(data_file.get_as_text())
		data_file.close()

## Conecta sinais dos sistemas
func _connect_system_signals():
	# Sinais do EventBus
	EventBus.pet_summoned.connect(_on_pet_summoned)
	EventBus.pet_dismissed.connect(_on_pet_dismissed)
	EventBus.pet_level_up.connect(_on_pet_level_up)
	EventBus.pet_xp_gained.connect(_on_pet_xp_gained)
	
	# Sinais do sistema
	if pet_system:
		pet_system.pet_system_ready.connect(_on_pet_system_ready)

## Registra uma entidade no sistema de pets
func register_entity(entity: Entity) -> bool:
	if entity == null:
		return false
	
	# Verificar se a entidade tem componente de pet
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		print("Entity doesn't have PetComponent: ", entity.name)
		return false
	
	# Registrar no sistema
	if pet_system:
		pet_system.add_entity(entity)
	
	print("Entity registered in pet system: ", entity.name)
	return true

## Remove uma entidade do sistema de pets
func unregister_entity(entity: Entity) -> bool:
	if entity == null:
		return false
	
	# Remover do sistema
	if pet_system:
		pet_system.remove_entity(entity)
	
	print("Entity unregistered from pet system: ", entity.name)
	return true

## Invoca um pet para uma entidade específica
func summon_pet(entity: Entity, pet_id: String) -> bool:
	if pet_system:
		return pet_system.summon_pet_for_entity(entity, pet_id)
	return false

## Dispensa pet de uma entidade
func dismiss_pet(entity: Entity) -> bool:
	if pet_system:
		return pet_system.dismiss_pet_for_entity(entity)
	return false

## Alterna pet de uma entidade
func toggle_pet(entity: Entity, pet_id: String) -> bool:
	if pet_system:
		return pet_system.toggle_pet_for_entity(entity, pet_id)
	return false

## Usa habilidade de pet
func use_pet_ability(entity: Entity, ability_id: String) -> bool:
	if pet_system:
		return pet_system.use_pet_ability_for_entity(entity, ability_id)
	return false

## Desbloqueia um pet para uma entidade
func unlock_pet(entity: Entity, pet_id: String) -> bool:
	if pet_system:
		return pet_system.unlock_pet_for_entity(entity, pet_id)
	return false

## Da XP para pet de uma entidade
func give_pet_xp(entity: Entity, xp_amount: int):
	if pet_system:
		var modified_xp = int(xp_amount * global_xp_modifier)
		pet_system.give_pet_xp_to_entity(entity, modified_xp)

## Obtém todos os pets de uma entidade
func get_entity_pets(entity: Entity) -> Array[Pet]:
	if pet_system:
		return pet_system.get_entity_pets(entity)
	return []

## Obtém pet ativo de uma entidade
func get_active_pet(entity: Entity) -> Pet:
	if pet_system:
		return pet_system.get_entity_active_pet(entity)
	return null

## Verifica se entidade tem pet ativo
func entity_has_active_pet(entity: Entity) -> bool:
	if pet_system:
		return pet_system.entity_has_active_pet(entity)
	return false

## Cria um novo pet a partir de dados
func create_pet_from_data(pet_data: Dictionary) -> Pet:
	return Pet.from_json_data(pet_data)

## Obtém dados de um pet por ID
func get_pet_data(pet_id: String) -> Dictionary:
	if loaded_pet_data.has("pets"):
		for pet_data in loaded_pet_data["pets"]:
			if pet_data.get("id", "") == pet_id:
				return pet_data
	return {}

## Obtém dados de uma habilidade por ID
func get_ability_data(ability_id: String) -> Dictionary:
	if loaded_pet_data.has("pet_abilities"):
		return loaded_pet_data["pet_abilities"].get(ability_id, {})
	return {}

## Aplica modificadores globais a um pet
func apply_global_modifiers(pet: Pet):
	if pet == null:
		return
	
	# Modificar XP baseado no modificador global
	if global_xp_modifier != 1.0:
		# XP modificado já é aplicado em give_pet_xp
		pass

## Obtém pets disponíveis por tipo
func get_pets_by_type(pet_type: Pet.PetType) -> Array[Dictionary]:
	var filtered_pets = []
	
	if loaded_pet_data.has("pets"):
		for pet_data in loaded_pet_data["pets"]:
			var type_str = pet_data.get("type", "")
			var matches_type = false
			
			match pet_type:
				Pet.PetType.ATAQUE_LEVE:
					matches_type = type_str == "ataque_leve"
				Pet.PetType.SUPORTE:
					matches_type = type_str == "suporte"
				Pet.PetType.COLETA_LOOT:
					matches_type = type_str == "coleta_loot"
				Pet.PetType.PASSIVO:
					matches_type = type_str == "passivo"
			
			if matches_type:
				filtered_pets.append(pet_data)
	
	return filtered_pets

## Obtém estatísticas globais do sistema
func get_system_statistics() -> Dictionary:
	var stats = {
		"total_entities": 0,
		"entities_with_active_pets": 0,
		"total_pets_unlocked": 0,
		"average_pet_level": 0.0,
		"pets_by_type": {}
	}
	
	if pet_system:
		var system_stats = pet_system.get_system_stats()
		stats["total_entities"] = system_stats.get("entities_with_pets", 0)
		stats["entities_with_active_pets"] = system_stats.get("active_pets", 0)
		stats["average_pet_level"] = system_stats.get("average_pet_level", 0.0)
		stats["pets_by_type"] = system_stats.get("pets_by_type", {})
	
	return stats

## Efeitos globais para pets
func apply_global_pet_effect(effect_name: String, data: Dictionary):
	"""Aplica efeito global a todos os pets ativos"""
	if pet_system:
		pet_system.apply_global_pet_effect(effect_name, data)

func dismiss_all_pets_in_area(area_name: String):
	"""Dispensa todos os pets em uma área específica"""
	if pet_system:
		pet_system.dismiss_all_pets_in_area(area_name)

## Configurações do sistema
func set_global_xp_modifier(modifier: float):
	global_xp_modifier = modifier
	global_pet_config["global_xp_modifier"] = modifier
	_save_pet_configuration()

func set_max_active_pets(count: int):
	max_active_pets = count
	global_pet_config["max_active_pets"] = count
	_save_pet_configuration()

func set_pet_revival_enabled(enabled: bool):
	pet_revival_enabled = enabled
	global_pet_config["pet_revival_enabled"] = enabled
	_save_pet_configuration()

func set_auto_dismiss_in_pvp(enabled: bool):
	auto_dismiss_in_pvp = enabled
	global_pet_config["auto_dismiss_in_pvp"] = enabled
	_save_pet_configuration()

## Sistema de recompensas para pets
func reward_all_active_pets(reward_type: String, amount: int):
	"""Recompensa todos os pets ativos"""
	if not pet_system:
		return
	
	for entity in pet_system.pet_entities:
		var pet_component = entity.get_component("PetComponent")
		if pet_component and pet_component.has_active_pet():
			match reward_type:
				"xp":
					give_pet_xp(entity, amount)
				"level":
					var active_pet = pet_component.active_pet
					for i in amount:
						active_pet.gain_xp(active_pet._get_xp_for_level(active_pet.level + 1))

## Sistema de eventos para pets
func trigger_pet_event(event_name: String, event_data: Dictionary = {}):
	"""Dispara evento específico para pets"""
	match event_name:
		"xp_boost_hour":
			var boost_amount = event_data.get("boost", 100)
			reward_all_active_pets("xp", boost_amount)
			EventBus.ui_notification_shown.emit("Evento: Hora do XP de Pets! +" + str(boost_amount) + " XP", "event")
		
		"pet_ability_reset":
			apply_global_pet_effect("ability_reset", {})
			EventBus.ui_notification_shown.emit("Evento: Cooldowns de pets resetados!", "event")
		
		"pet_stat_boost":
			var boost_duration = event_data.get("duration", 300) # 5 minutos
			apply_global_pet_effect("stat_boost", {"duration": boost_duration})
			EventBus.ui_notification_shown.emit("Evento: Pets receberam boost de stats temporário!", "event")

## Callbacks de sinais
func _on_pet_summoned(entity: Entity, pet: Pet):
	# Aplicar modificadores globais
	apply_global_modifiers(pet)
	
	# Emitir evento global
	global_pet_event.emit("pet_summoned", {
		"entity": entity,
		"pet": pet,
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_pet_dismissed(entity: Entity, pet: Pet):
	global_pet_event.emit("pet_dismissed", {
		"entity": entity,
		"pet": pet,
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_pet_level_up(entity: Entity, pet: Pet, new_level: int):
	global_pet_event.emit("pet_level_up", {
		"entity": entity,
		"pet": pet,
		"new_level": new_level,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	# Efeito especial a cada 5 níveis
	if new_level % 5 == 0:
		EventBus.ui_notification_shown.emit(pet.name + " atingiu nível " + str(new_level) + "! Pets crescem mais fortes!", "achievement")

func _on_pet_xp_gained(entity: Entity, pet: Pet, xp_amount: int):
	# Log de XP para estatísticas
	pass

func _on_pet_system_ready():
	print("[PetManager] Pet system is ready")

## Métodos de debug
func debug_list_all_entities():
	print("=== Pet System Entities ===")
	if pet_system:
		for entity in pet_system.pet_entities:
			var pet_component = entity.get_component("PetComponent")
			if pet_component:
				print("Entity: ", entity.name)
				print("  Pets: ", pet_component.available_pets.size())
				print("  Active: ", pet_component.active_pet.name if pet_component.active_pet else "None")
				print("  Has Active: ", pet_component.has_active_pet())
	print("==========================")

func debug_pet_statistics():
	var stats = get_system_statistics()
	print("=== Pet System Statistics ===")
	for key in stats:
		print("  ", key, ": ", stats[key])
	print("============================")

## Cleanup
func _exit_tree():
	if pet_system:
		pet_system.queue_free()

## Sistema de migração de dados
func migrate_pet_data_if_needed():
	"""Migra dados de pets para versões mais novas se necessário"""
	# Placeholder para futuras migrações de dados
	pass