# Sistema de Componente de Montaria - Disorder Chaos
extends Node
class_name MountComponent

## Componente ECS para gerenciar montarias de uma entidade
## Armazena a montaria atual e suas propriedades

signal mount_changed(old_mount: Mount, new_mount: Mount)
signal mount_summoned(mount: Mount)
signal mount_dismissed(mount: Mount)

@export var current_mount: Mount = null
@export var available_mounts: Array[Mount] = []
@export var auto_dismiss_on_damage: bool = true
@export var auto_dismiss_on_combat: bool = false

var mount_cooldown_timer: float = 0.0
var is_mount_input_enabled: bool = true

var entity: Node

func _ready():
	entity = get_parent()

func _process(delta):
	if mount_cooldown_timer > 0:
		mount_cooldown_timer -= delta
	if current_mount and current_mount.is_mounted:
		current_mount.update_mount(delta)

## Adiciona uma montaria à lista de disponíveis
func add_mount(mount: Mount) -> bool:
	if mount == null or mount in available_mounts:
		return false
	
	available_mounts.append(mount)
	mount.unlocked = true
	
	# Conectar sinais da montaria
	_connect_mount_signals(mount)
	
	return true

## Remove uma montaria da lista
func remove_mount(mount: Mount) -> bool:
	if mount == null or mount not in available_mounts:
		return false
	
	# Dispensar se for a montaria atual
	if current_mount == mount:
		dismiss_current_mount()
	
	_disconnect_mount_signals(mount)
	available_mounts.erase(mount)
	return true

## Obtém uma montaria por ID
func get_mount_by_id(mount_id: String) -> Mount:
	for mount in available_mounts:
		if mount.id == mount_id:
			return mount
	return null

## Verifica se tem uma montaria específica
func has_mount(mount_id: String) -> bool:
	return get_mount_by_id(mount_id) != null

## Invoca uma montaria por ID
func summon_mount(mount_id: String) -> bool:
	var mount = get_mount_by_id(mount_id)
	if mount == null:
		print("Mount not found: ", mount_id)
		return false
	
	return summon_mount_direct(mount)

## Invoca uma montaria diretamente
func summon_mount_direct(mount: Mount) -> bool:
	if mount == null:
		return false
	
	if mount_cooldown_timer > 0:
		print("Mount on cooldown: ", mount_cooldown_timer, " seconds remaining")
		return false
	
	if not mount.can_be_summoned(entity):
		print("Cannot summon mount: ", mount.mount_name)
		return false
	
	# Dispensar montaria atual se houver
	if current_mount and current_mount.is_mounted:
		dismiss_current_mount()
	
	# Invocar nova montaria
	if mount.summon(entity):
		var old_mount = current_mount
		current_mount = mount
		mount_cooldown_timer = mount.cooldown_invocacao
		
		mount_changed.emit(old_mount, current_mount)
		mount_summoned.emit(current_mount)
		
		# Conectar eventos da entidade
		_connect_entity_events()
		
		print("Mount summoned: ", mount.mount_name)
		return true
	
	return false

## Dispensa a montaria atual
func dismiss_current_mount() -> bool:
	if current_mount == null or not current_mount.is_mounted:
		return false
	
	var mount = current_mount
	if mount.dismiss():
		current_mount = null
		mount_dismissed.emit(mount)
		
		# Desconectar eventos da entidade
		_disconnect_entity_events()
		
		print("Mount dismissed: ", mount.name)
		return true
	
	return false

## Alterna montaria (invoca se não tem, dispensa se tem)
func toggle_mount(mount_id: String) -> bool:
	if current_mount and current_mount.id == mount_id:
		return dismiss_current_mount()
	else:
		return summon_mount(mount_id)

## Executa dash da montaria atual
func mount_dash() -> bool:
	if current_mount and current_mount.is_mounted:
		return current_mount.dash()
	return false

## Usa skill da montaria atual
func use_mount_skill(skill_id: String) -> bool:
	if current_mount and current_mount.is_mounted:
		return current_mount.use_skill(skill_id)
	return false

## Verifica se está montado
func is_mounted() -> bool:
	return current_mount != null and current_mount.is_mounted

## Obtém velocidade atual da montaria
func get_mount_speed() -> float:
	if current_mount and current_mount.is_mounted:
		return current_mount.velocidade_base
	return 0.0

## Obtém stamina atual da montaria
func get_mount_stamina() -> float:
	if current_mount and current_mount.is_mounted:
		return current_mount.stamina_atual
	return 0.0

## Obtém stamina máxima da montaria
func get_mount_max_stamina() -> float:
	if current_mount and current_mount.is_mounted:
		return current_mount.stamina_maxima
	return 0.0

## Obtém percentual de stamina
func get_mount_stamina_percent() -> float:
	if current_mount and current_mount.is_mounted:
		return (current_mount.stamina_atual / current_mount.stamina_maxima) * 100.0
	return 0.0

## Habilita/desabilita input de montaria
func set_mount_input_enabled(enabled: bool):
	is_mount_input_enabled = enabled

## Verifica se input está habilitado
func get_mount_input_enabled() -> bool:
	return is_mount_input_enabled

## Conecta sinais da montaria
func _connect_mount_signals(mount: Mount):
	if not mount.mount_summoned.is_connected(_on_mount_summoned):
		mount.mount_summoned.connect(_on_mount_summoned)
	if not mount.mount_dismissed.is_connected(_on_mount_dismissed):
		mount.mount_dismissed.connect(_on_mount_dismissed)
	if not mount.stamina_changed.is_connected(_on_stamina_changed):
		mount.stamina_changed.connect(_on_stamina_changed)
	if not mount.skill_used.is_connected(_on_skill_used):
		mount.skill_used.connect(_on_skill_used)

## Desconecta sinais da montaria
func _disconnect_mount_signals(mount: Mount):
	if mount.mount_summoned.is_connected(_on_mount_summoned):
		mount.mount_summoned.disconnect(_on_mount_summoned)
	if mount.mount_dismissed.is_connected(_on_mount_dismissed):
		mount.mount_dismissed.disconnect(_on_mount_dismissed)
	if mount.stamina_changed.is_connected(_on_stamina_changed):
		mount.stamina_changed.disconnect(_on_stamina_changed)
	if mount.skill_used.is_connected(_on_skill_used):
		mount.skill_used.disconnect(_on_skill_used)

## Conecta eventos da entidade
func _connect_entity_events():
	# Conectar ao sistema de combate se disponível
	var combat_component = entity.get_component("CombatComponent")
	if combat_component and auto_dismiss_on_damage:
		if combat_component.has_signal("damage_taken") and not combat_component.damage_taken.is_connected(_on_damage_taken):
			combat_component.damage_taken.connect(_on_damage_taken)
	
	# Conectar ao sistema de combat se disponível
	if entity.has_signal("combat_started") and auto_dismiss_on_combat:
		if not entity.combat_started.is_connected(_on_combat_started):
			entity.combat_started.connect(_on_combat_started)

## Desconecta eventos da entidade
func _disconnect_entity_events():
	var combat_component = entity.get_component("CombatComponent")
	if combat_component:
		if combat_component.has_signal("damage_taken") and combat_component.damage_taken.is_connected(_on_damage_taken):
			combat_component.damage_taken.disconnect(_on_damage_taken)
	
	if entity.has_signal("combat_started") and entity.combat_started.is_connected(_on_combat_started):
		entity.combat_started.disconnect(_on_combat_started)

## Callbacks de sinais
func _on_mount_summoned(mount: Mount):
	EventBus.mount_summoned.emit(entity, mount)

func _on_mount_dismissed(mount: Mount):
	EventBus.mount_dismissed.emit(entity, mount)

func _on_stamina_changed(current: float, maximum: float):
	EventBus.mount_stamina_changed.emit(entity, current, maximum)

func _on_skill_used(skill_id: String):
	EventBus.mount_skill_used.emit(entity, skill_id)

func _on_damage_taken(damage: float, attacker: Node):
	if auto_dismiss_on_damage:
		dismiss_current_mount()

func _on_combat_started():
	if auto_dismiss_on_combat:
		dismiss_current_mount()

## Carregar montarias do arquivo JSON
func load_mounts_from_file():
	var file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if file == null:
		print("Failed to open mount list file")
		return
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data == null or not "mounts" in json_data:
		print("Invalid mount data in file")
		return
	
	available_mounts.clear()
	
	for mount_data in json_data["mounts"]:
		var mount = Mount.from_json_data(mount_data)
		available_mounts.append(mount)
		_connect_mount_signals(mount)
	
	print("Loaded ", available_mounts.size(), " mounts")

## Salva dados para save system
func get_save_data() -> Dictionary:
	var save_data = {
		"available_mounts": [],
		"current_mount_id": "",
		"mount_cooldown": mount_cooldown_timer,
		"auto_dismiss_on_damage": auto_dismiss_on_damage,
		"auto_dismiss_on_combat": auto_dismiss_on_combat
	}
	
	# Salvar dados das montarias
	for mount in available_mounts:
		save_data["available_mounts"].append(mount.get_save_data())
	
	# Salvar ID da montaria atual
	if current_mount:
		save_data["current_mount_id"] = current_mount.id
	
	return save_data

## Carrega dados do save system
func load_save_data(data: Dictionary):
	mount_cooldown_timer = data.get("mount_cooldown", 0.0)
	auto_dismiss_on_damage = data.get("auto_dismiss_on_damage", true)
	auto_dismiss_on_combat = data.get("auto_dismiss_on_combat", false)
	
	# Recriar montarias
	available_mounts.clear()
	current_mount = null
	
	var mount_data_list = data.get("available_mounts", [])
	for mount_data in mount_data_list:
		var mount = Mount.new()
		mount.id = mount_data.get("id", "")
		
		# Carregar dados base do JSON
		var json_mount = _load_mount_json_data(mount.id)
		if json_mount:
			mount = Mount.from_json_data(json_mount)
		
		# Aplicar dados do save
		mount.load_save_data(mount_data)
		available_mounts.append(mount)
		_connect_mount_signals(mount)
	
	# Restaurar montaria atual se estava montado
	var current_mount_id = data.get("current_mount_id", "")
	if current_mount_id != "":
		var mount = get_mount_by_id(current_mount_id)
		if mount and mount.is_mounted:
			current_mount = mount
			_connect_entity_events()

func _load_mount_json_data(mount_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if file == null:
		return {}
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data and "mounts" in json_data:
		for mount_data in json_data["mounts"]:
			if mount_data.get("id", "") == mount_id:
				return mount_data
	
	return {}