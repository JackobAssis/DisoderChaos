# Sistema de Componente de Pets - Disorder Chaos
extends Component
class_name PetComponent

## Componente ECS para gerenciar pets de uma entidade
## Permite apenas 1 pet ativo por vez, controla XP e habilidades

signal pet_summoned(pet: Pet)
signal pet_dismissed(pet: Pet)
signal pet_level_up(pet: Pet, new_level: int)
signal pet_xp_gained(pet: Pet, amount: int)
signal active_pet_changed(old_pet: Pet, new_pet: Pet)

@export var available_pets: Array[Pet] = []
@export var active_pet: Pet = null
@export var auto_summon_on_start: bool = false
@export var share_xp_with_pet: bool = true
@export var pet_xp_share_rate: float = 0.3

var summon_cooldown_timer: float = 0.0
var last_xp_share_time: float = 0.0

func _ready():
	super._ready()
	component_name = "PetComponent"
	
	# Conectar sinais do jogador para compartilhamento de XP
	if entity.has_signal("xp_gained"):
		entity.xp_gained.connect(_on_owner_xp_gained)

func _process(delta):
	super._process(delta)
	
	# Atualizar cooldown
	if summon_cooldown_timer > 0:
		summon_cooldown_timer -= delta
	
	# Atualizar pet ativo
	if active_pet and active_pet.is_active:
		active_pet.update_pet(delta)

## Adiciona um pet à coleção
func add_pet(pet: Pet) -> bool:
	if pet == null or pet in available_pets:
		return false
	
	available_pets.append(pet)
	pet.unlocked = true
	
	# Conectar sinais do pet
	_connect_pet_signals(pet)
	
	print("Pet adicionado: ", pet.name)
	return true

## Remove um pet da coleção
func remove_pet(pet: Pet) -> bool:
	if pet == null or pet not in available_pets:
		return false
	
	# Dispensar se for o pet ativo
	if active_pet == pet:
		dismiss_active_pet()
	
	_disconnect_pet_signals(pet)
	available_pets.erase(pet)
	return true

## Obtém pet por ID
func get_pet_by_id(pet_id: String) -> Pet:
	for pet in available_pets:
		if pet.id == pet_id:
			return pet
	return null

## Verifica se tem um pet específico
func has_pet(pet_id: String) -> bool:
	return get_pet_by_id(pet_id) != null

## Invoca um pet por ID
func summon_pet(pet_id: String) -> bool:
	var pet = get_pet_by_id(pet_id)
	if pet == null:
		print("Pet não encontrado: ", pet_id)
		return false
	
	return summon_pet_direct(pet)

## Invoca um pet diretamente
func summon_pet_direct(pet: Pet) -> bool:
	if pet == null:
		return false
	
	if summon_cooldown_timer > 0:
		print("Pet em cooldown: ", summon_cooldown_timer, " segundos restantes")
		return false
	
	if not pet.can_be_summoned(entity):
		print("Não é possível invocar o pet: ", pet.name)
		return false
	
	# Dispensar pet ativo se houver
	if active_pet and active_pet.is_active:
		dismiss_active_pet()
	
	# Invocar novo pet
	if pet.summon(entity):
		var old_pet = active_pet
		active_pet = pet
		summon_cooldown_timer = _get_summon_cooldown()
		
		active_pet_changed.emit(old_pet, active_pet)
		pet_summoned.emit(active_pet)
		
		print("Pet invocado: ", pet.name)
		return true
	
	return false

## Dispensa o pet ativo
func dismiss_active_pet() -> bool:
	if active_pet == null or not active_pet.is_active:
		return false
	
	var pet = active_pet
	if pet.dismiss():
		active_pet = null
		pet_dismissed.emit(pet)
		print("Pet dispensado: ", pet.name)
		return true
	
	return false

## Alterna pet (invoca se não tem, dispensa se tem, ou troca)
func toggle_pet(pet_id: String) -> bool:
	var pet = get_pet_by_id(pet_id)
	if pet == null:
		return false
	
	if active_pet == pet:
		return dismiss_active_pet()
	else:
		return summon_pet_direct(pet)

## Usa habilidade do pet ativo
func use_pet_ability(ability_id: String) -> bool:
	if active_pet and active_pet.is_active:
		return active_pet.use_ability(ability_id)
	return false

## Verifica se há pet ativo
func has_active_pet() -> bool:
	return active_pet != null and active_pet.is_active

## Obtém informações do pet ativo
func get_active_pet_info() -> Dictionary:
	if not has_active_pet():
		return {}
	
	return {
		"name": active_pet.name,
		"level": active_pet.level,
		"xp": active_pet.current_xp,
		"xp_to_next": active_pet._get_xp_for_level(active_pet.level + 1),
		"type": active_pet.type,
		"stats": active_pet.current_stats,
		"abilities": active_pet.abilities
	}

## Obtém lista de pets desbloqueados
func get_unlocked_pets() -> Array[Pet]:
	var unlocked = []
	for pet in available_pets:
		if pet.unlocked:
			unlocked.append(pet)
	return unlocked

## Obtém pets por tipo
func get_pets_by_type(pet_type: Pet.PetType) -> Array[Pet]:
	var filtered_pets = []
	for pet in available_pets:
		if pet.type == pet_type and pet.unlocked:
			filtered_pets.append(pet)
	return filtered_pets

## Desbloqueia um pet
func unlock_pet(pet_id: String) -> bool:
	var pet = get_pet_by_id(pet_id)
	if pet == null:
		# Tentar carregar do JSON
		pet = _create_pet_from_id(pet_id)
		if pet:
			add_pet(pet)
	
	if pet:
		pet.unlocked = true
		print("Pet desbloqueado: ", pet.name)
		EventBus.pet_unlocked.emit(entity, pet)
		return true
	
	return false

## Da XP para o pet ativo
func give_pet_xp(amount: int):
	if active_pet and active_pet.is_active:
		active_pet.gain_xp(amount)

## Conecta sinais do pet
func _connect_pet_signals(pet: Pet):
	if not pet.pet_summoned.is_connected(_on_pet_summoned):
		pet.pet_summoned.connect(_on_pet_summoned)
	if not pet.pet_dismissed.is_connected(_on_pet_dismissed):
		pet.pet_dismissed.connect(_on_pet_dismissed)
	if not pet.pet_level_up.is_connected(_on_pet_level_up):
		pet.pet_level_up.connect(_on_pet_level_up)
	if not pet.pet_xp_gained.is_connected(_on_pet_xp_gained):
		pet.pet_xp_gained.connect(_on_pet_xp_gained)

## Desconecta sinais do pet
func _disconnect_pet_signals(pet: Pet):
	if pet.pet_summoned.is_connected(_on_pet_summoned):
		pet.pet_summoned.disconnect(_on_pet_summoned)
	if pet.pet_dismissed.is_connected(_on_pet_dismissed):
		pet.pet_dismissed.disconnect(_on_pet_dismissed)
	if pet.pet_level_up.is_connected(_on_pet_level_up):
		pet.pet_level_up.disconnect(_on_pet_level_up)
	if pet.pet_xp_gained.is_connected(_on_pet_xp_gained):
		pet.pet_xp_gained.disconnect(_on_pet_xp_gained)

## Obtém cooldown de invocação
func _get_summon_cooldown() -> float:
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_data and "global_config" in json_data:
			return json_data["global_config"].get("summon_cooldown", 3.0)
	
	return 3.0

## Cria pet a partir do ID carregando do JSON
func _create_pet_from_id(pet_id: String) -> Pet:
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file == null:
		return null
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data and "pets" in json_data:
		for pet_data in json_data["pets"]:
			if pet_data.get("id", "") == pet_id:
				return Pet.from_json_data(pet_data)
	
	return null

## Carrega pets do arquivo JSON
func load_pets_from_file():
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file == null:
		print("Falha ao abrir arquivo de pets")
		return
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data == null or not "pets" in json_data:
		print("Dados de pets inválidos no arquivo")
		return
	
	available_pets.clear()
	
	for pet_data in json_data["pets"]:
		var pet = Pet.from_json_data(pet_data)
		available_pets.append(pet)
		_connect_pet_signals(pet)
	
	print("Carregados ", available_pets.size(), " pets")

## Callbacks de sinais do pet
func _on_pet_summoned(pet: Pet):
	EventBus.pet_summoned.emit(entity, pet)

func _on_pet_dismissed(pet: Pet):
	EventBus.pet_dismissed.emit(entity, pet)

func _on_pet_level_up(pet: Pet, new_level: int):
	pet_level_up.emit(pet, new_level)
	EventBus.pet_level_up.emit(entity, pet, new_level)
	print("Pet ", pet.name, " subiu para nível ", new_level, "!")

func _on_pet_xp_gained(pet: Pet, amount: int):
	pet_xp_gained.emit(pet, amount)

## Callback de XP do owner para compartilhamento
func _on_owner_xp_gained(amount: int):
	if share_xp_with_pet and has_active_pet():
		var pet_xp = int(amount * pet_xp_share_rate)
		if pet_xp > 0:
			give_pet_xp(pet_xp)
			print("Pet ganhou ", pet_xp, " XP (compartilhamento)")

## Auto-summon no início
func auto_summon_first_available():
	if auto_summon_on_start:
		var unlocked_pets = get_unlocked_pets()
		if unlocked_pets.size() > 0:
			summon_pet_direct(unlocked_pets[0])

## Obter estatísticas do componente
func get_component_stats() -> Dictionary:
	return {
		"total_pets": available_pets.size(),
		"unlocked_pets": get_unlocked_pets().size(),
		"has_active_pet": has_active_pet(),
		"active_pet_name": active_pet.name if active_pet else "",
		"active_pet_level": active_pet.level if active_pet else 0,
		"summon_cooldown": summon_cooldown_timer
	}

## Salva dados para save system
func get_save_data() -> Dictionary:
	var save_data = {
		"available_pets": [],
		"active_pet_id": "",
		"summon_cooldown": summon_cooldown_timer,
		"auto_summon_on_start": auto_summon_on_start,
		"share_xp_with_pet": share_xp_with_pet,
		"pet_xp_share_rate": pet_xp_share_rate
	}
	
	# Salvar dados dos pets
	for pet in available_pets:
		save_data["available_pets"].append(pet.get_save_data())
	
	# Salvar ID do pet ativo
	if active_pet:
		save_data["active_pet_id"] = active_pet.id
	
	return save_data

## Carrega dados do save system
func load_save_data(data: Dictionary):
	summon_cooldown_timer = data.get("summon_cooldown", 0.0)
	auto_summon_on_start = data.get("auto_summon_on_start", false)
	share_xp_with_pet = data.get("share_xp_with_pet", true)
	pet_xp_share_rate = data.get("pet_xp_share_rate", 0.3)
	
	# Recriar pets
	available_pets.clear()
	active_pet = null
	
	var pet_data_list = data.get("available_pets", [])
	for pet_data in pet_data_list:
		var pet = Pet.new()
		pet.id = pet_data.get("id", "")
		
		# Carregar dados base do JSON
		var json_pet = _load_pet_json_data(pet.id)
		if json_pet:
			pet = Pet.from_json_data(json_pet)
		
		# Aplicar dados do save
		pet.load_save_data(pet_data)
		available_pets.append(pet)
		_connect_pet_signals(pet)
	
	# Restaurar pet ativo se estava ativo
	var active_pet_id = data.get("active_pet_id", "")
	if active_pet_id != "":
		var pet = get_pet_by_id(active_pet_id)
		if pet and pet.is_active:
			active_pet = pet

func _load_pet_json_data(pet_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file == null:
		return {}
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data and "pets" in json_data:
		for pet_data in json_data["pets"]:
			if pet_data.get("id", "") == pet_id:
				return pet_data
	
	return {}

## Métodos de debug
func debug_print_pet_info():
	print("=== Pet Component Info ===")
	print("Total pets: ", available_pets.size())
	print("Unlocked pets: ", get_unlocked_pets().size())
	print("Has active pet: ", has_active_pet())
	
	if active_pet:
		print("Active pet: ", active_pet.name, " (Lv.", active_pet.level, ")")
		print("Pet XP: ", active_pet.current_xp, "/", active_pet._get_xp_for_level(active_pet.level + 1))
	
	print("Available pets:")
	for pet in available_pets:
		print("  - ", pet.name, " (Lv.", pet.level, ") - Unlocked: ", pet.unlocked)
	
	print("========================")

## Cleanup
func _exit_tree():
	if active_pet:
		active_pet.dismiss()
	
	for pet in available_pets:
		_disconnect_pet_signals(pet)
	
	available_pets.clear()
	super._exit_tree()