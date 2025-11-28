# Sistema de Pets - Disorder Chaos
extends Node
class_name PetSystem

## Sistema ECS responsável por gerenciar a lógica dos pets
## Processa todas as entidades com PetComponent

signal pet_system_ready()

var pet_entities: Array = []
var global_pet_cooldown: float = 0.0
var ai_update_rate: float = 0.2
var follow_update_rate: float = 0.1

func _ready():
	super._ready()
	system_name = "PetSystem"
	
	# Conectar sinais do EventBus
	EventBus.pet_summoned.connect(_on_pet_summoned)
	EventBus.pet_dismissed.connect(_on_pet_dismissed)
	EventBus.pet_level_up.connect(_on_pet_level_up)
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.area_exited.connect(_on_area_exited)
	
	# Carregar configuraÃ§Ãµes
	_load_global_config()
	
	pet_system_ready.emit()
	print("PetSystem initialized")

func _process(delta):
	super._process(delta)
	
	# Atualizar cooldown global
	if global_pet_cooldown > 0:
		global_pet_cooldown -= delta
	
	# Processar todas as entidades com pets
	for entity in pet_entities:
		if is_instance_valid(entity):
			_process_pet_entity(entity, delta)

## Adiciona entidade ao sistema
func add_entity(entity: Entity):
	if entity == null:
		return
	
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return
	
	if entity not in pet_entities:
		pet_entities.append(entity)
		
		# Carregar pets se necessÃ¡rio
		if pet_component.available_pets.is_empty():
			pet_component.load_pets_from_file()
		
		# Auto-summon se configurado
		pet_component.auto_summon_first_available()
		
		print("Entity added to PetSystem: ", entity.name)

## Remove entidade do sistema
func remove_entity(entity: Entity):
	if entity in pet_entities:
		var pet_component = entity.get_component("PetComponent")
		if pet_component:
			# Dispensar pet ativo
			pet_component.dismiss_active_pet()
		
		pet_entities.erase(entity)
		print("Entity removed from PetSystem: ", entity.name)

## Processa uma entidade com pets
func _process_pet_entity(entity: Entity, delta: float):
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return
	
	# Verificar se pet deve ser auto-dispensado
	_check_auto_dismiss_conditions(entity, pet_component)
	
	# Processar comportamentos especÃ­ficos do pet ativo
	if pet_component.has_active_pet():
		var active_pet = pet_component.active_pet
		_process_pet_behaviors(entity, active_pet, delta)

## Invoca pet para uma entidade
func summon_pet_for_entity(entity: Entity, pet_id: String) -> bool:
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return false
	
	return pet_component.summon_pet(pet_id)

## Dispensa pet de uma entidade
func dismiss_pet_for_entity(entity: Entity) -> bool:
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return false
	
	return pet_component.dismiss_active_pet()

## Alterna pet para uma entidade
func toggle_pet_for_entity(entity: Entity, pet_id: String) -> bool:
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return false
	
	return pet_component.toggle_pet(pet_id)

## Usa habilidade de pet para uma entidade
func use_pet_ability_for_entity(entity: Entity, ability_id: String) -> bool:
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return false
	
	return pet_component.use_pet_ability(ability_id)

## Desbloqueia pet para uma entidade
func unlock_pet_for_entity(entity: Entity, pet_id: String) -> bool:
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		return false
	
	return pet_component.unlock_pet(pet_id)

## Da XP para pet de uma entidade
func give_pet_xp_to_entity(entity: Entity, xp_amount: int):
	var pet_component = entity.get_component("PetComponent")
	if pet_component:
		pet_component.give_pet_xp(xp_amount)

## ObtÃ©m pets de uma entidade
func get_entity_pets(entity: Entity) -> Array[Pet]:
	var pet_component = entity.get_component("PetComponent")
	if pet_component:
		return pet_component.available_pets
	return []

## ObtÃ©m pet ativo de uma entidade
func get_entity_active_pet(entity: Entity) -> Pet:
	var pet_component = entity.get_component("PetComponent")
	if pet_component:
		return pet_component.active_pet
	return null

## Verifica se entidade tem pet ativo
func entity_has_active_pet(entity: Entity) -> bool:
	var pet_component = entity.get_component("PetComponent")
	if pet_component:
		return pet_component.has_active_pet()
	return false

## Carrega configuraÃ§Ãµes globais
func _load_global_config():
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_data and "global_config" in json_data:
			var config = json_data["global_config"]
			ai_update_rate = config.get("ai_update_rate", 0.2)
			follow_update_rate = config.get("follow_update_rate", 0.1)

## Verifica condiÃ§Ãµes automÃ¡ticas de dismiss
func _check_auto_dismiss_conditions(entity: Entity, pet_component: PetComponent):
	if not pet_component.has_active_pet():
		return
	
	var active_pet = pet_component.active_pet
	
	# Verificar se entrou em Ã¡rea PVP (se configurado)
	if _is_entity_in_pvp_area(entity):
		var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
		if file:
			var json_data = JSON.parse_string(file.get_as_text())
			file.close()
			
			if json_data and "global_config" in json_data:
				var auto_dismiss = json_data["global_config"].get("auto_dismiss_in_pvp", true)
				if auto_dismiss:
					pet_component.dismiss_active_pet()
					_show_notification(entity, "Pet dispensado automaticamente - Ãrea PVP")

## Processa comportamentos especÃ­ficos do pet
func _process_pet_behaviors(entity: Entity, pet: Pet, delta: float):
	if not pet or not pet.is_active:
		return
	
	# Processar baseado no tipo do pet
	match pet.type:
		Pet.PetType.ATAQUE_LEVE:
			_process_attack_pet(entity, pet, delta)
		Pet.PetType.SUPORTE:
			_process_support_pet(entity, pet, delta)
		Pet.PetType.COLETA_LOOT:
			_process_collector_pet(entity, pet, delta)
		Pet.PetType.PASSIVO:
			_process_passive_pet(entity, pet, delta)

## Processa pet de ataque
func _process_attack_pet(entity: Entity, pet: Pet, delta: float):
	# Verificar se hÃ¡ inimigos prÃ³ximos
	var enemies = _find_enemies_near_entity(entity, 200.0)
	
	if enemies.size() > 0:
		var closest_enemy = _get_closest_enemy(pet.pet_node, enemies)
		if closest_enemy:
			_attack_enemy_with_pet(pet, closest_enemy)

## Processa pet de suporte
func _process_support_pet(entity: Entity, pet: Pet, delta: float):
	# Verificar se owner precisa de cura
	var health_component = entity.get_component("HealthComponent")
	if health_component:
		var health_percent = health_component.current_health / health_component.max_health
		
		# Usar cura automÃ¡tica se vida estiver baixa
		if health_percent < 0.5:
			_use_pet_heal_ability(pet)

## Processa pet coletor
func _process_collector_pet(entity: Entity, pet: Pet, delta: float):
	# Procurar itens prÃ³ximos
	var items = _find_items_near_entity(entity, 150.0)
	
	if items.size() > 0:
		_collect_items_with_pet(pet, items)

## Processa pet passivo
func _process_passive_pet(entity: Entity, pet: Pet, delta: float):
	# Aplicar buffs passivos continuamente
	_apply_passive_buffs(entity, pet)

## Verifica se entidade estÃ¡ em Ã¡rea PVP
func _is_entity_in_pvp_area(entity: Entity) -> bool:
	var area_component = entity.get_component("AreaComponent")
	if area_component and area_component.has_method("get_current_area"):
		var area_name = area_component.get_current_area()
		var pvp_areas = [
			"arena_1v1",
			"arena_3v3",
			"battleground_central",
			"tournament_grounds"
		]
		return area_name in pvp_areas
	
	return false

## Encontra inimigos prÃ³ximos a uma entidade
func _find_enemies_near_entity(entity: Entity, radius: float) -> Array:
	var enemies = []
	
	# Placeholder - implementar busca real de inimigos
	# var space_state = entity.get_world_2d().direct_space_state
	# var query = PhysicsPointQueryParameters2D.new()
	# query.position = entity.global_position
	# query.collision_mask = enemy_layer_mask
	# var results = space_state.intersect_point(query)
	
	return enemies

## Encontra itens prÃ³ximos a uma entidade
func _find_items_near_entity(entity: Entity, radius: float) -> Array:
	var items = []
	
	# Placeholder - implementar busca real de itens
	# Similar ao _find_enemies_near_entity mas para itens
	
	return items

## ObtÃ©m inimigo mais prÃ³ximo
func _get_closest_enemy(pet_node: Node, enemies: Array) -> Node:
	if enemies.is_empty() or not pet_node:
		return null
	
	var closest = enemies[0]
	var closest_distance = pet_node.global_position.distance_to(closest.global_position)
	
	for enemy in enemies:
		var distance = pet_node.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	
	return closest

## Pet ataca inimigo
func _attack_enemy_with_pet(pet: Pet, enemy: Node):
	# Usar habilidade de ataque do pet
	for ability_id in pet.abilities.values():
		var ability_data = _get_ability_data(ability_id)
		if ability_data and ability_data.get("type", "") == "active_attack":
			if pet.use_ability(ability_id):
				print("Pet ", pet.name, " atacou inimigo")
				break

## Pet usa habilidade de cura
func _use_pet_heal_ability(pet: Pet):
	for ability_id in pet.abilities.values():
		var ability_data = _get_ability_data(ability_id)
		if ability_data and ability_data.get("type", "") in ["conditional_heal", "instant_heal"]:
			if pet.use_ability(ability_id):
				break

## Pet coleta itens
func _collect_items_with_pet(pet: Pet, items: Array):
	for ability_id in pet.abilities.values():
		var ability_data = _get_ability_data(ability_id)
		if ability_data and ability_data.get("type", "") == "auto_collect":
			if pet.use_ability(ability_id):
				break

## Aplica buffs passivos
func _apply_passive_buffs(entity: Entity, pet: Pet):
	# Buffs passivos sÃ£o aplicados pela prÃ³pria classe Pet
	# Este mÃ©todo pode ser expandido para coordenar buffs mÃºltiplos
	pass

## ObtÃ©m dados de habilidade
func _get_ability_data(ability_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_data and "pet_abilities" in json_data:
			return json_data["pet_abilities"].get(ability_id, {})
	
	return {}

## Mostra notificaÃ§Ã£o para a entidade
func _show_notification(entity: Entity, message: String):
	print("[Pet Notification] ", entity.name, ": ", message)
	EventBus.notification_triggered.emit(entity, message, "pet")

## Callbacks de sinais globais
func _on_pet_summoned(entity: Entity, pet: Pet):
	print("Pet summoned: ", pet.name, " by ", entity.name)
	
	# Efeitos especiais de invocaÃ§Ã£o
	EventBus.effect_triggered.emit(entity, "pet_summon_" + pet.type)

func _on_pet_dismissed(entity: Entity, pet: Pet):
	print("Pet dismissed: ", pet.name, " by ", entity.name)

func _on_pet_level_up(entity: Entity, pet: Pet, new_level: int):
	print("Pet level up: ", pet.name, " reached level ", new_level)
	
	# Efeito visual de level up
	EventBus.effect_triggered.emit(entity, "pet_levelup")
	
	# NotificaÃ§Ã£o para o jogador
	_show_notification(entity, pet.name + " subiu para nÃ­vel " + str(new_level) + "!")

func _on_area_entered(entity: Entity, area_name: String):
	if not entity_has_active_pet(entity):
		return
	
	# Verificar se Ã© Ã¡rea restrita para pets
	if area_name in ["dungeon_boss_room", "safe_zone"]:
		var pet_component = entity.get_component("PetComponent")
		if pet_component and pet_component.active_pet:
			pet_component.dismiss_active_pet()
			_show_notification(entity, "Pet dispensado automaticamente - Ãrea restrita")

func _on_area_exited(entity: Entity, area_name: String):
	# Placeholder para lÃ³gica de saÃ­da de Ã¡rea
	pass

## MÃ©todos de gerenciamento global
func dismiss_all_pets_in_area(area_name: String):
# Dispensa todos os pets em uma Ã¡rea especÃ­fica
	for entity in pet_entities:
		var area_component = entity.get_component("AreaComponent")
		if area_component and area_component.has_method("get_current_area"):
			if area_component.get_current_area() == area_name:
				dismiss_pet_for_entity(entity)

func apply_global_pet_effect(effect_name: String, data: Dictionary):
# Aplica efeito global a todos os pets ativos
	for entity in pet_entities:
		var pet_component = entity.get_component("PetComponent")
		if pet_component and pet_component.has_active_pet():
			# Aplicar efeito baseado no nome
			_apply_global_effect_to_pet(pet_component.active_pet, effect_name, data)

func _apply_global_effect_to_pet(pet: Pet, effect_name: String, data: Dictionary):
	match effect_name:
		"xp_boost":
			var xp_bonus = data.get("amount", 0)
			pet.gain_xp(xp_bonus)
		"stat_boost":
			# Implementar boost temporÃ¡rio de stats
			pass
		"ability_reset":
			# Resetar cooldowns de habilidades
			pet.last_ability_use.clear()

## Obter estatÃ­sticas do sistema
func get_system_stats() -> Dictionary:
	var active_pets = 0
	var total_pet_level = 0
	var pets_by_type = {}
	
	for entity in pet_entities:
		var pet_component = entity.get_component("PetComponent")
		if pet_component and pet_component.has_active_pet():
			active_pets += 1
			var active_pet = pet_component.active_pet
			total_pet_level += active_pet.level
			
			var type_name = str(active_pet.type)
			pets_by_type[type_name] = pets_by_type.get(type_name, 0) + 1
	
	return {
		"entities_with_pets": pet_entities.size(),
		"active_pets": active_pets,
		"average_pet_level": total_pet_level / max(1, active_pets),
		"pets_by_type": pets_by_type,
		"global_cooldown": global_pet_cooldown
	}

## MÃ©todos de debug
func debug_print_pet_info(entity: Entity):
	var pet_component = entity.get_component("PetComponent")
	if pet_component == null:
		print("Entity has no PetComponent: ", entity.name)
		return
	
	pet_component.debug_print_pet_info()

func debug_print_system_stats():
	var stats = get_system_stats()
	print("=== Pet System Statistics ===")
	for key in stats:
		print("  ", key, ": ", stats[key])
	print("============================")

## Cleanup quando o sistema Ã© removido
func _exit_tree():
	# Dispensar todos os pets
	for entity in pet_entities:
		var pet_component = entity.get_component("PetComponent")
		if pet_component:
			pet_component.dismiss_active_pet()
	
	pet_entities.clear()
	super._exit_tree()
