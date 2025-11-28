# Sistema de Input para Montarias - Disorder Chaos
extends Node
class_name MountInputSystem

## Sistema ECS responsável por capturar e processar input relacionado a montarias
## Detecta comandos de montar/desmontar, dash e uso de skills

signal mount_input_detected(entity, action: String, data: Dictionary)

var input_entities: Array = []

# Configurações de input
@export var mount_toggle_action: String = "mount_toggle"
@export var mount_dash_action: String = "mount_dash"
@export var mount_skill_1_action: String = "mount_skill_1"
@export var mount_skill_2_action: String = "mount_skill_2"
@export var mount_skill_3_action: String = "mount_skill_3"

# Estado de input
var input_enabled: bool = true
var last_input_time: float = 0.0
var input_cooldown: float = 0.1  # Prevenir spam de input

func _ready():
	super._ready()
	system_name = "MountInputSystem"
	
	# Conectar sinais
	EventBus.input_map_changed.connect(_on_input_map_changed)
	EventBus.system_paused.connect(_on_system_paused)
	EventBus.system_resumed.connect(_on_system_resumed)
	
	print("MountInputSystem initialized")

func _process(delta):
	super._process(delta)
	
	if not input_enabled:
		return
	
	# Verificar cooldown de input
	var current_time = Time.get_time_dict_from_system().get("second", 0)
	if current_time - last_input_time < input_cooldown:
		return
	
	# Processar input para todas as entidades
	for entity in input_entities:
		if is_instance_valid(entity):
			_process_mount_input(entity)

func _input(event):
	if not input_enabled:
		return
	
	# Processar apenas para a entidade do jogador (por enquanto)
	var player_entity = _get_player_entity()
	if player_entity == null:
		return
	
	_process_input_event(player_entity, event)

## Adiciona entidade ao sistema de input
func add_entity(entity: Entity):
	if entity == null:
		return
	
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	if entity not in input_entities:
		input_entities.append(entity)
		print("Entity added to MountInputSystem: ", entity.name)

## Remove entidade do sistema de input
func remove_entity(entity: Entity):
	if entity in input_entities:
		input_entities.erase(entity)
		print("Entity removed from MountInputSystem: ", entity.name)

## Processa input de montaria para uma entidade específica
func _process_mount_input(entity: Entity):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null or not mount_component.is_mount_input_enabled():
		return
	
	# Toggle montaria
	if Input.is_action_just_pressed(mount_toggle_action):
		_handle_mount_toggle(entity)
	
	# Dash (apenas se montado)
	elif Input.is_action_just_pressed(mount_dash_action) and mount_component.is_mounted():
		_handle_mount_dash(entity)
	
	# Skills de montaria (apenas se montado)
	elif mount_component.is_mounted():
		if Input.is_action_just_pressed(mount_skill_1_action):
			_handle_mount_skill(entity, 1)
		elif Input.is_action_just_pressed(mount_skill_2_action):
			_handle_mount_skill(entity, 2)
		elif Input.is_action_just_pressed(mount_skill_3_action):
			_handle_mount_skill(entity, 3)

## Processa eventos de input específicos
func _process_input_event(entity: Entity, event: InputEvent):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null or not mount_component.is_mount_input_enabled():
		return
	
	# Input de teclado
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed:
			_handle_keyboard_input(entity, key_event)
	
	# Input de mouse (para UI de montarias)
	elif event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			_handle_mouse_input(entity, mouse_event)

## Manipula toggle de montaria
func _handle_mount_toggle(entity: Entity):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	last_input_time = Time.get_time_dict_from_system().get("second", 0)
	
	if mount_component.is_mounted():
		# Dispensar montaria atual
		if mount_component.dismiss_current_mount():
			mount_input_detected.emit(entity, "mount_dismissed", {})
			_show_mount_message(entity, "Montaria dispensada")
	else:
		# Invocar montaria favorita ou primeira disponível
		var favorite_mount = _get_favorite_mount(entity)
		if favorite_mount:
			if mount_component.summon_mount_direct(favorite_mount):
				mount_input_detected.emit(entity, "mount_summoned", {"mount_id": favorite_mount.id})
				_show_mount_message(entity, "Montaria invocada: " + favorite_mount.name)
			else:
				_show_mount_message(entity, "Não foi possível invocar a montaria")
		else:
			_show_mount_message(entity, "Nenhuma montaria disponível")

## Manipula dash de montaria
func _handle_mount_dash(entity: Entity):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	last_input_time = Time.get_time_dict_from_system().get("second", 0)
	
	if mount_component.mount_dash():
		mount_input_detected.emit(entity, "mount_dash", {})
		_show_mount_message(entity, "Dash da montaria!")
	else:
		_show_mount_message(entity, "Dash indisponível - sem stamina")

## Manipula uso de skill de montaria
func _handle_mount_skill(entity: Entity, skill_slot: int):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null or not mount_component.is_mounted():
		return
	
	var current_mount = mount_component.current_mount
	if current_mount == null:
		return
	
	last_input_time = Time.get_time_dict_from_system().get("second", 0)
	
	# Verificar se a skill existe no slot
	if skill_slot <= current_mount.skills.size():
		var skill_id = current_mount.skills[skill_slot - 1]
		
		if mount_component.use_mount_skill(skill_id):
			mount_input_detected.emit(entity, "mount_skill_used", {"skill_id": skill_id, "slot": skill_slot})
			_show_mount_message(entity, "Skill usada: " + _get_skill_name(skill_id))
		else:
			_show_mount_message(entity, "Skill em cooldown ou sem stamina")
	else:
		_show_mount_message(entity, "Slot de skill vazio")

## Manipula input de teclado específico
func _handle_keyboard_input(entity: Entity, key_event: InputEventKey):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	match key_event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			# Teclas numéricas para invocar montaria específica
			var mount_index = key_event.keycode - KEY_1
			_summon_mount_by_index(entity, mount_index)
		
		KEY_H:
			# Tecla H para abrir menu de montarias (placeholder)
			mount_input_detected.emit(entity, "mount_menu_toggle", {})

## Manipula input de mouse para UI
func _handle_mouse_input(entity: Entity, mouse_event: InputEventMouseButton):
	# Placeholder para interações de UI com montarias
	pass

## Invoca montaria por índice
func _summon_mount_by_index(entity: Entity, index: int):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	var available_mounts = mount_component.available_mounts
	var unlocked_mounts = []
	
	# Filtrar montarias desbloqueadas
	for mount in available_mounts:
		if mount.unlocked:
			unlocked_mounts.append(mount)
	
	if index < unlocked_mounts.size():
		var mount = unlocked_mounts[index]
		if mount_component.toggle_mount(mount.id):
			_show_mount_message(entity, "Montaria: " + mount.name)
	else:
		_show_mount_message(entity, "Slot de montaria vazio")

## Obtém montaria favorita da entidade
func _get_favorite_mount(entity: Entity) -> Mount:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return null
	
	# Por enquanto, retorna a primeira montaria desbloqueada
	for mount in mount_component.available_mounts:
		if mount.unlocked:
			return mount
	
	return null

## Obtém entidade do jogador
func _get_player_entity() -> Entity:
	# Esta função precisa ser implementada baseada no sistema de entidades
	# Por enquanto, retorna a primeira entidade da lista
	if not input_entities.is_empty():
		for entity in input_entities:
			# Verificar se é o jogador (placeholder)
			if entity.name == "Player" or entity.has_method("is_player"):
				return entity
	
	return null

## Obtém nome de uma skill
func _get_skill_name(skill_id: String) -> String:
	var file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if file == null:
		return skill_id
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data and "mount_skills" in json_data:
		var skill_data = json_data["mount_skills"].get(skill_id, {})
		return skill_data.get("name", skill_id)
	
	return skill_id

## Mostra mensagem de montaria
func _show_mount_message(entity: Entity, message: String):
	print("[Mount Input] ", entity.name, ": ", message)
	EventBus.notification_triggered.emit(entity, message, "mount_input")

## Habilita/desabilita sistema de input
func set_input_enabled(enabled: bool):
	input_enabled = enabled

## Verifica se input está habilitado
func is_input_enabled() -> bool:
	return input_enabled

## Configura ações de input personalizadas
func set_mount_actions(toggle: String, dash: String, skill1: String, skill2: String, skill3: String):
	mount_toggle_action = toggle
	mount_dash_action = dash
	mount_skill_1_action = skill1
	mount_skill_2_action = skill2
	mount_skill_3_action = skill3

## Callbacks de sinais
func _on_input_map_changed():
	# Recarregar configurações de input se necessário
	print("Input map changed - updating mount actions")

func _on_system_paused():
	input_enabled = false

func _on_system_resumed():
	input_enabled = true

## Obtém estatísticas do sistema de input
func get_input_stats() -> Dictionary:
	var entities_with_input = input_entities.size()
	var player_entity = _get_player_entity()
	var has_player_input = player_entity != null
	
	return {
		"entities_with_input": entities_with_input,
		"has_player_input": has_player_input,
		"input_enabled": input_enabled,
		"last_input_time": last_input_time,
		"mount_toggle_action": mount_toggle_action,
		"mount_dash_action": mount_dash_action
	}

## Debug - listar todas as ações de input de montaria
func debug_list_mount_actions():
	print("=== Mount Input Actions ===")
	print("Toggle Mount: ", mount_toggle_action)
	print("Mount Dash: ", mount_dash_action)
	print("Mount Skill 1: ", mount_skill_1_action)
	print("Mount Skill 2: ", mount_skill_2_action)
	print("Mount Skill 3: ", mount_skill_3_action)
	print("Input Enabled: ", input_enabled)
	print("Entities with input: ", input_entities.size())
	print("===========================")

## Cleanup
func _exit_tree():
	input_entities.clear()
	super._exit_tree()