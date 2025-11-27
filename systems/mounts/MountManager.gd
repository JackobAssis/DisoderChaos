# Sistema de Manager de Montarias - Disorder Chaos
extends Node
class_name MountManager

## Gerenciador global do sistema de montarias
## Coordena todas as funcionalidades relacionadas a montarias

signal mount_system_ready()
signal global_mount_event(event_type: String, data: Dictionary)

var mount_system: MountSystem = null
var mount_input_system: MountInputSystem = null
var loaded_mount_data: Dictionary = {}
var global_mount_config: Dictionary = {}

# Configurações globais
@export var enable_pvp_restrictions: bool = true
@export var global_stamina_modifier: float = 1.0
@export var global_speed_modifier: float = 1.0
@export var enable_mount_combat: bool = false
@export var mount_fall_damage_reduction: float = 0.5

func _ready():
	# Inicializar sistemas
	mount_system = MountSystem.new()
	mount_input_system = MountInputSystem.new()
	
	add_child(mount_system)
	add_child(mount_input_system)
	
	# Carregar configurações e dados
	_load_mount_configuration()
	_load_global_mount_data()
	
	# Conectar sinais
	_connect_system_signals()
	
	mount_system_ready.emit()
	print("[MountManager] Mount system initialized")

## Carrega configurações do sistema de montarias
func _load_mount_configuration():
	var config_file = FileAccess.open("res://data/mounts/mount_config.json", FileAccess.READ)
	if config_file:
		var config_data = JSON.parse_string(config_file.get_as_text())
		config_file.close()
		
		if config_data:
			global_mount_config = config_data
			_apply_global_config()
	else:
		# Configuração padrão
		global_mount_config = {
			"enable_pvp_restrictions": true,
			"global_stamina_modifier": 1.0,
			"global_speed_modifier": 1.0,
			"enable_mount_combat": false,
			"mount_fall_damage_reduction": 0.5,
			"default_dash_cooldown": 3.0,
			"stamina_recovery_rate": 1.0
		}
		_save_mount_configuration()

## Aplica configurações globais
func _apply_global_config():
	enable_pvp_restrictions = global_mount_config.get("enable_pvp_restrictions", true)
	global_stamina_modifier = global_mount_config.get("global_stamina_modifier", 1.0)
	global_speed_modifier = global_mount_config.get("global_speed_modifier", 1.0)
	enable_mount_combat = global_mount_config.get("enable_mount_combat", false)
	mount_fall_damage_reduction = global_mount_config.get("mount_fall_damage_reduction", 0.5)

## Salva configurações do sistema
func _save_mount_configuration():
	var config_file = FileAccess.open("res://data/mounts/mount_config.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(global_mount_config, "\t"))
		config_file.close()

## Carrega dados globais de montarias
func _load_global_mount_data():
	var data_file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if data_file:
		loaded_mount_data = JSON.parse_string(data_file.get_as_text())
		data_file.close()

## Conecta sinais dos sistemas
func _connect_system_signals():
	# Sinais do EventBus
	EventBus.mount_summoned.connect(_on_mount_summoned)
	EventBus.mount_dismissed.connect(_on_mount_dismissed)
	EventBus.mount_stamina_changed.connect(_on_mount_stamina_changed)
	EventBus.mount_skill_used.connect(_on_mount_skill_used)
	
	# Sinais dos sistemas
	if mount_system:
		mount_system.mount_system_ready.connect(_on_mount_system_ready)
	
	if mount_input_system:
		mount_input_system.mount_input_detected.connect(_on_mount_input_detected)

## Registra uma entidade no sistema de montarias
func register_entity(entity: Entity) -> bool:
	if entity == null:
		return false
	
	# Verificar se a entidade tem componente de montaria
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		print("Entity doesn't have MountComponent: ", entity.name)
		return false
	
	# Registrar nos sistemas
	if mount_system:
		mount_system.add_entity(entity)
	
	if mount_input_system:
		mount_input_system.add_entity(entity)
	
	print("Entity registered in mount system: ", entity.name)
	return true

## Remove uma entidade do sistema de montarias
func unregister_entity(entity: Entity) -> bool:
	if entity == null:
		return false
	
	# Remover dos sistemas
	if mount_system:
		mount_system.remove_entity(entity)
	
	if mount_input_system:
		mount_input_system.remove_entity(entity)
	
	print("Entity unregistered from mount system: ", entity.name)
	return true

## Invoca uma montaria para uma entidade específica
func summon_mount(entity: Entity, mount_id: String) -> bool:
	if mount_system:
		return mount_system.summon_mount_for_entity(entity, mount_id)
	return false

## Dispensa montaria de uma entidade
func dismiss_mount(entity: Entity) -> bool:
	if mount_system:
		return mount_system.dismiss_mount_for_entity(entity)
	return false

## Alterna montaria de uma entidade
func toggle_mount(entity: Entity, mount_id: String) -> bool:
	if mount_system:
		return mount_system.toggle_mount_for_entity(entity, mount_id)
	return false

## Executa dash de montaria
func mount_dash(entity: Entity) -> bool:
	if mount_system:
		return mount_system.dash_for_entity(entity)
	return false

## Usa skill de montaria
func use_mount_skill(entity: Entity, skill_id: String) -> bool:
	if mount_system:
		return mount_system.use_mount_skill_for_entity(entity, skill_id)
	return false

## Desbloqueia uma montaria para uma entidade
func unlock_mount(entity: Entity, mount_id: String) -> bool:
	if mount_system:
		return mount_system.unlock_mount_for_entity(entity, mount_id)
	return false

## Obtém todas as montarias de uma entidade
func get_entity_mounts(entity: Entity) -> Array[Mount]:
	if mount_system:
		return mount_system.get_entity_mounts(entity)
	return []

## Obtém montaria atual de uma entidade
func get_current_mount(entity: Entity) -> Mount:
	if mount_system:
		return mount_system.get_entity_current_mount(entity)
	return null

## Verifica se entidade está montada
func is_entity_mounted(entity: Entity) -> bool:
	if mount_system:
		return mount_system.is_entity_mounted(entity)
	return false

## Cria uma nova montaria a partir de dados
func create_mount_from_data(mount_data: Dictionary) -> Mount:
	return Mount.from_json_data(mount_data)

## Obtém dados de uma montaria por ID
func get_mount_data(mount_id: String) -> Dictionary:
	if loaded_mount_data.has("mounts"):
		for mount_data in loaded_mount_data["mounts"]:
			if mount_data.get("id", "") == mount_id:
				return mount_data
	return {}

## Obtém dados de uma skill por ID
func get_skill_data(skill_id: String) -> Dictionary:
	if loaded_mount_data.has("mount_skills"):
		return loaded_mount_data["mount_skills"].get(skill_id, {})
	return {}

## Aplica modificadores globais a uma montaria
func apply_global_modifiers(mount: Mount):
	if mount == null:
		return
	
	# Modificar stamina
	mount.stamina_maxima *= global_stamina_modifier
	mount.stamina_atual = min(mount.stamina_atual, mount.stamina_maxima)
	
	# Modificar velocidade
	mount.velocidade_base *= global_speed_modifier
	
	# Modificar recuperação de stamina
	var stamina_recovery_rate = global_mount_config.get("stamina_recovery_rate", 1.0)
	mount.stamina_recuperacao *= stamina_recovery_rate

## Verifica se área permite montarias
func is_area_mount_allowed(area_name: String) -> bool:
	if not enable_pvp_restrictions:
		return true
	
	var restricted_areas = loaded_mount_data.get("pvp_restricted_areas", [])
	return area_name not in restricted_areas

## Obtém estatísticas globais do sistema
func get_system_statistics() -> Dictionary:
	var stats = {
		"total_entities": 0,
		"mounted_entities": 0,
		"total_mounts": 0,
		"unlocked_mounts": 0,
		"active_skills": 0
	}
	
	if mount_system:
		var system_stats = mount_system.get_system_stats()
		stats["total_entities"] = system_stats.get("entities_with_mounts", 0)
		stats["mounted_entities"] = system_stats.get("currently_mounted", 0)
		stats["total_mounts"] = system_stats.get("total_available_mounts", 0)
	
	return stats

## Configurações do sistema
func set_global_stamina_modifier(modifier: float):
	global_stamina_modifier = modifier
	global_mount_config["global_stamina_modifier"] = modifier
	_save_mount_configuration()

func set_global_speed_modifier(modifier: float):
	global_speed_modifier = modifier
	global_mount_config["global_speed_modifier"] = modifier
	_save_mount_configuration()

func set_pvp_restrictions_enabled(enabled: bool):
	enable_pvp_restrictions = enabled
	global_mount_config["enable_pvp_restrictions"] = enabled
	_save_mount_configuration()

func set_mount_combat_enabled(enabled: bool):
	enable_mount_combat = enabled
	global_mount_config["enable_mount_combat"] = enabled
	_save_mount_configuration()

## Callbacks de sinais
func _on_mount_summoned(entity: Entity, mount: Mount):
	# Aplicar modificadores globais
	apply_global_modifiers(mount)
	
	# Emitir evento global
	global_mount_event.emit("mount_summoned", {
		"entity": entity,
		"mount": mount,
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_mount_dismissed(entity: Entity, mount: Mount):
	global_mount_event.emit("mount_dismissed", {
		"entity": entity,
		"mount": mount,
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_mount_stamina_changed(entity: Entity, current: float, maximum: float):
	# Verificar se stamina está criticamente baixa
	var stamina_percent = (current / maximum) * 100
	if stamina_percent < 10:
		EventBus.ui_notification_shown.emit("Stamina da montaria baixa!", "warning")

func _on_mount_skill_used(entity: Entity, skill_id: String):
	global_mount_event.emit("mount_skill_used", {
		"entity": entity,
		"skill_id": skill_id,
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_mount_system_ready():
	print("[MountManager] Mount system is ready")

func _on_mount_input_detected(entity: Entity, action: String, data: Dictionary):
	# Log de input para debug
	print("[MountManager] Input detected: ", action, " from ", entity.name)

## Métodos de debug
func debug_list_all_entities():
	print("=== Mount System Entities ===")
	if mount_system:
		for entity in mount_system.mount_entities:
			var mount_component = entity.get_component("MountComponent")
			if mount_component:
				print("Entity: ", entity.name)
				print("  Mounts: ", mount_component.available_mounts.size())
				print("  Current: ", mount_component.current_mount.name if mount_component.current_mount else "None")
				print("  Mounted: ", mount_component.is_mounted())
	print("============================")

func debug_mount_statistics():
	var stats = get_system_statistics()
	print("=== Mount System Statistics ===")
	for key in stats:
		print("  ", key, ": ", stats[key])
	print("==============================")

## Cleanup
func _exit_tree():
	if mount_system:
		mount_system.queue_free()
	
	if mount_input_system:
		mount_input_system.queue_free()