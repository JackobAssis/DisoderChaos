# Sistema de Montarias - Disorder Chaos
extends Node
class_name MountSystem

## Sistema ECS responsável por gerenciar a lógica das montarias
## Processa todas as entidades com MountComponent

signal mount_system_ready()

var mount_entities: Array = []
var global_mount_cooldown: float = 0.0

func _ready():
	super._ready()
	system_name = "MountSystem"
	
	# Conectar sinais do EventBus
	EventBus.mount_summoned.connect(_on_mount_summoned)
	EventBus.mount_dismissed.connect(_on_mount_dismissed)
	EventBus.mount_stamina_changed.connect(_on_mount_stamina_changed)
	EventBus.mount_skill_used.connect(_on_mount_skill_used)
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.area_exited.connect(_on_area_exited)
	
	mount_system_ready.emit()
	print("MountSystem initialized")

func _process(delta):
	super._process(delta)
	
	# Atualizar cooldown global
	if global_mount_cooldown > 0:
		global_mount_cooldown -= delta
	
	# Processar todas as entidades com montarias
	for entity in mount_entities:
		if is_instance_valid(entity):
			_process_mount_entity(entity, delta)

## Adiciona entidade ao sistema
func add_entity(entity: Entity):
	if entity == null:
		return
	
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	if entity not in mount_entities:
		mount_entities.append(entity)
		
		# Carregar montarias se necessário
		if mount_component.available_mounts.is_empty():
			mount_component.load_mounts_from_file()
		
		# Conectar sinais do componente
		_connect_mount_component_signals(mount_component)
		
		print("Entity added to MountSystem: ", entity.name)

## Remove entidade do sistema
func remove_entity(entity: Entity):
	if entity in mount_entities:
		var mount_component = entity.get_component("MountComponent")
		if mount_component:
			# Dispensar montaria se estiver montado
			mount_component.dismiss_current_mount()
			_disconnect_mount_component_signals(mount_component)
		
		mount_entities.erase(entity)
		print("Entity removed from MountSystem: ", entity.name)

## Processa uma entidade com montaria
func _process_mount_entity(entity: Entity, delta: float):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return
	
	# Verificar se está em área restrita e forçar dismiss
	if mount_component.is_mounted():
		var current_mount = mount_component.current_mount
		if current_mount and current_mount.pvp_blocked and _is_entity_in_pvp_area(entity):
			mount_component.dismiss_current_mount()
			_show_notification(entity, "Montaria dispensada - Área PVP restrita")
	
	# Verificar condições automáticas de dismiss
	_check_auto_dismiss_conditions(entity, mount_component)
	
	# Processar recuperação de stamina quando parado
	if mount_component.is_mounted():
		var current_mount = mount_component.current_mount
		var movement_component = entity.get_component("MovementComponent")
		
		if movement_component and not movement_component.is_moving():
			current_mount.recover_stamina(current_mount.stamina_recuperacao * delta)

## Invoca montaria para uma entidade
func summon_mount_for_entity(entity: Entity, mount_id: String) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return false
	
	return mount_component.summon_mount(mount_id)

## Dispensa montaria de uma entidade
func dismiss_mount_for_entity(entity: Entity) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return false
	
	return mount_component.dismiss_current_mount()

## Alterna montaria para uma entidade
func toggle_mount_for_entity(entity: Entity, mount_id: String) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return false
	
	return mount_component.toggle_mount(mount_id)

## Executa dash para uma entidade
func dash_for_entity(entity: Entity) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return false
	
	return mount_component.mount_dash()

## Usa skill de montaria para uma entidade
func use_mount_skill_for_entity(entity: Entity, skill_id: String) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return false
	
	return mount_component.use_mount_skill(skill_id)

## Desbloqueia uma montaria para uma entidade
func unlock_mount_for_entity(entity: Entity, mount_id: String) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		return false
	
	var mount = mount_component.get_mount_by_id(mount_id)
	if mount == null:
		# Carregar montaria do JSON se não existir
		mount = _create_mount_from_id(mount_id)
		if mount:
			mount_component.add_mount(mount)
	
	if mount:
		mount.unlocked = true
		_show_notification(entity, "Nova montaria desbloqueada: " + mount.name)
		EventBus.mount_unlocked.emit(entity, mount)
		return true
	
	return false

## Obtém todas as montarias de uma entidade
func get_entity_mounts(entity: Entity) -> Array[Mount]:
	var mount_component = entity.get_component("MountComponent")
	if mount_component:
		return mount_component.available_mounts
	return []

## Obtém montaria atual de uma entidade
func get_entity_current_mount(entity: Entity) -> Mount:
	var mount_component = entity.get_component("MountComponent")
	if mount_component:
		return mount_component.current_mount
	return null

## Verifica se entidade está montada
func is_entity_mounted(entity: Entity) -> bool:
	var mount_component = entity.get_component("MountComponent")
	if mount_component:
		return mount_component.is_mounted()
	return false

## Conecta sinais do componente de montaria
func _connect_mount_component_signals(mount_component: MountComponent):
	if not mount_component.mount_summoned.is_connected(_on_component_mount_summoned):
		mount_component.mount_summoned.connect(_on_component_mount_summoned)
	if not mount_component.mount_dismissed.is_connected(_on_component_mount_dismissed):
		mount_component.mount_dismissed.connect(_on_component_mount_dismissed)

## Desconecta sinais do componente de montaria
func _disconnect_mount_component_signals(mount_component: MountComponent):
	if mount_component.mount_summoned.is_connected(_on_component_mount_summoned):
		mount_component.mount_summoned.disconnect(_on_component_mount_summoned)
	if mount_component.mount_dismissed.is_connected(_on_component_mount_dismissed):
		mount_component.mount_dismissed.disconnect(_on_component_mount_dismissed)

## Verifica se entidade está em área PVP
func _is_entity_in_pvp_area(entity: Entity) -> bool:
	# Esta função precisa ser implementada baseada no sistema de áreas do jogo
	var area_component = entity.get_component("AreaComponent")
	if area_component and area_component.has_method("get_current_area"):
		var area_name = area_component.get_current_area()
		var restricted_areas = [
			"arena_1v1",
			"arena_3v3",
			"battleground_central", 
			"tournament_grounds"
		]
		return area_name in restricted_areas
	
	return false

## Verifica condições automáticas de dismiss
func _check_auto_dismiss_conditions(entity: Entity, mount_component: MountComponent):
	if not mount_component.is_mounted():
		return
	
	var current_mount = mount_component.current_mount
	
	# Verificar se ficou sem stamina
	if current_mount.stamina_atual <= 0:
		mount_component.dismiss_current_mount()
		_show_notification(entity, "Montaria dispensada - Sem stamina")
	
	# Verificar se entrou em combate (se auto dismiss estiver ativo)
	var combat_component = entity.get_component("CombatComponent")
	if combat_component and mount_component.auto_dismiss_on_combat:
		if combat_component.has_method("is_in_combat") and combat_component.is_in_combat():
			mount_component.dismiss_current_mount()
			_show_notification(entity, "Montaria dispensada - Combate iniciado")

## Cria montaria a partir do ID carregando do JSON
func _create_mount_from_id(mount_id: String) -> Mount:
	var file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if file == null:
		return null
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data and "mounts" in json_data:
		for mount_data in json_data["mounts"]:
			if mount_data.get("id", "") == mount_id:
				return Mount.from_json_data(mount_data)
	
	return null

## Mostra notificação para a entidade
func _show_notification(entity: Entity, message: String):
	# Sistema de notificações - placeholder
	print("[Mount Notification] ", entity.name, ": ", message)
	EventBus.notification_triggered.emit(entity, message, "mount")

## Callbacks de sinais globais
func _on_mount_summoned(entity: Entity, mount: Mount):
	print("Mount summoned: ", mount.name, " by ", entity.name)
	
	# Aplicar modificadores de movimento
	var movement_component = entity.get_component("MovementComponent")
	if movement_component and movement_component.has_method("set_movement_speed"):
		movement_component.set_movement_speed(mount.velocidade_base)

func _on_mount_dismissed(entity: Entity, mount: Mount):
	print("Mount dismissed: ", mount.name, " by ", entity.name)
	
	# Restaurar velocidade normal
	var movement_component = entity.get_component("MovementComponent")
	if movement_component and movement_component.has_method("reset_movement_speed"):
		movement_component.reset_movement_speed()

func _on_mount_stamina_changed(entity: Entity, current: float, maximum: float):
	# Atualizar UI se necessário
	var ui_component = entity.get_component("UIComponent")
	if ui_component and ui_component.has_method("update_mount_stamina"):
		ui_component.update_mount_stamina(current, maximum)

func _on_mount_skill_used(entity: Entity, skill_id: String):
	print("Mount skill used: ", skill_id, " by ", entity.name)
	
	# Efeitos visuais ou sonoros podem ser adicionados aqui
	EventBus.effect_triggered.emit(entity, "mount_skill_" + skill_id)

func _on_area_entered(entity: Entity, area_name: String):
	if not is_entity_mounted(entity):
		return
	
	var mount_component = entity.get_component("MountComponent")
	if mount_component and mount_component.current_mount:
		var current_mount = mount_component.current_mount
		
		# Verificar se é área restrita para a montaria
		if current_mount.pvp_blocked and area_name in ["arena_1v1", "arena_3v3", "battleground_central", "tournament_grounds"]:
			mount_component.dismiss_current_mount()
			_show_notification(entity, "Montaria automaticamente dispensada - Área PVP")

func _on_area_exited(entity: Entity, area_name: String):
	# Placeholder para lógica de saída de área
	pass

## Callbacks do componente
func _on_component_mount_summoned(mount: Mount):
	# Log adicional ou efeitos especiais
	pass

func _on_component_mount_dismissed(mount: Mount):
	# Log adicional ou efeitos especiais
	pass

## Obter estatísticas do sistema
func get_system_stats() -> Dictionary:
	var mounted_count = 0
	var total_mounts = 0
	
	for entity in mount_entities:
		var mount_component = entity.get_component("MountComponent")
		if mount_component:
			total_mounts += mount_component.available_mounts.size()
			if mount_component.is_mounted():
				mounted_count += 1
	
	return {
		"entities_with_mounts": mount_entities.size(),
		"currently_mounted": mounted_count,
		"total_available_mounts": total_mounts,
		"global_cooldown": global_mount_cooldown
	}

## Métodos de debug
func debug_print_mount_info(entity: Entity):
	var mount_component = entity.get_component("MountComponent")
	if mount_component == null:
		print("Entity has no MountComponent: ", entity.name)
		return
	
	print("=== Mount Info for ", entity.name, " ===")
	print("Available mounts: ", mount_component.available_mounts.size())
	
	for mount in mount_component.available_mounts:
		print("  - ", mount.name, " (", mount.id, ") - Unlocked: ", mount.unlocked)
	
	if mount_component.current_mount:
		var current = mount_component.current_mount
		print("Current mount: ", current.name)
		print("  Stamina: ", current.stamina_atual, "/", current.stamina_maxima)
		print("  Is mounted: ", current.is_mounted)
	else:
		print("No current mount")
	
	print("=============================")

## Cleanup quando o sistema é removido
func _exit_tree():
	# Dispensar todas as montarias
	for entity in mount_entities:
		var mount_component = entity.get_component("MountComponent")
		if mount_component:
			mount_component.dismiss_current_mount()
	
	mount_entities.clear()
	super._exit_tree()