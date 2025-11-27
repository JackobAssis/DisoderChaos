# Interface de Usuário para Pets - Disorder Chaos
extends Control
class_name PetUI

## Interface completa para gerenciar pets e companions
## Exibe pet ativo, lista de pets, botões de controle e informações

signal pet_selected(pet_id: String)
signal pet_ability_activated(ability_id: String)
signal pet_menu_requested()

@onready var active_pet_container: VBoxContainer = $VBoxContainer/ActivePetContainer
@onready var pet_icon: TextureRect = $VBoxContainer/ActivePetContainer/HBoxContainer/PetIcon
@onready var pet_name_label: Label = $VBoxContainer/ActivePetContainer/HBoxContainer/PetInfo/PetName
@onready var pet_level_label: Label = $VBoxContainer/ActivePetContainer/HBoxContainer/PetInfo/PetLevel
@onready var pet_xp_bar: ProgressBar = $VBoxContainer/ActivePetContainer/XPBar
@onready var summon_dismiss_button: Button = $VBoxContainer/ActivePetContainer/HBoxContainer/SummonDismissButton

@onready var pet_list_container: VBoxContainer = $VBoxContainer/PetListContainer
@onready var pet_selector: OptionButton = $VBoxContainer/PetListContainer/PetSelector
@onready var pet_abilities_container: HBoxContainer = $VBoxContainer/AbilitiesContainer

@onready var pet_stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var health_label: Label = $VBoxContainer/StatsContainer/HealthLabel
@onready var attack_label: Label = $VBoxContainer/StatsContainer/AttackLabel
@onready var defense_label: Label = $VBoxContainer/StatsContainer/DefenseLabel
@onready var speed_label: Label = $VBoxContainer/StatsContainer/SpeedLabel

var current_entity: Entity = null
var pet_component: PetComponent = null
var ability_buttons: Array[Button] = []

# Estilo visual
var xp_color_full: Color = Color.CYAN
var xp_color_medium: Color = Color.BLUE
var xp_color_low: Color = Color.PURPLE

func _ready():
	# Configurar sinais dos botões
	summon_dismiss_button.pressed.connect(_on_summon_dismiss_button_pressed)
	pet_selector.item_selected.connect(_on_pet_selector_item_selected)
	
	# Configurar tooltips
	summon_dismiss_button.tooltip_text = "Invocar/Dispensar Pet (Ctrl+P)"
	pet_selector.tooltip_text = "Selecionar Pet Disponível"
	
	# Configurar barra de XP
	pet_xp_bar.min_value = 0
	pet_xp_bar.max_value = 100
	pet_xp_bar.value = 0
	pet_xp_bar.show_percentage = true
	
	# Inicializar como invisível
	visible = false
	
	# Conectar sinais do EventBus
	EventBus.pet_summoned.connect(_on_pet_summoned)
	EventBus.pet_dismissed.connect(_on_pet_dismissed)
	EventBus.pet_level_up.connect(_on_pet_level_up)
	EventBus.pet_unlocked.connect(_on_pet_unlocked)

## Define a entidade que esta UI deve monitorar
func set_entity(entity: Entity):
	if current_entity == entity:
		return
	
	# Desconectar entidade anterior
	if current_entity and pet_component:
		_disconnect_pet_component()
	
	current_entity = entity
	pet_component = null
	
	if current_entity:
		pet_component = current_entity.get_component("PetComponent")
		if pet_component:
			_connect_pet_component()
			_refresh_ui()
		else:
			visible = false

## Atualiza toda a UI com as informações atuais
func _refresh_ui():
	if not pet_component:
		visible = false
		return
	
	_update_pet_selector()
	_update_active_pet_display()
	_update_ability_buttons()
	_update_pet_stats()
	
	# Mostrar UI se tiver pets disponíveis
	visible = not pet_component.available_pets.is_empty()

## Atualiza o seletor de pets
func _update_pet_selector():
	if not pet_component:
		return
	
	pet_selector.clear()
	
	var unlocked_pets = pet_component.get_unlocked_pets()
	for pet in unlocked_pets:
		var item_text = pet.name + " (Nv." + str(pet.level) + ")"
		
		# Adicionar indicador de raridade
		match pet.rarity:
			Pet.PetRarity.INCOMUM:
				item_text += " ✦"
			Pet.PetRarity.RARO:
				item_text += " ✦✦"
			Pet.PetRarity.EPICO:
				item_text += " ✦✦✦"
			Pet.PetRarity.LENDARIO:
				item_text += " ✦✦✦✦"
			Pet.PetRarity.MITICO:
				item_text += " ✦✦✦✦✦"
		
		pet_selector.add_item(item_text)
		pet_selector.set_item_metadata(pet_selector.get_item_count() - 1, pet.id)
		
		# Selecionar pet ativo
		if pet_component.active_pet and pet_component.active_pet.id == pet.id:
			pet_selector.selected = pet_selector.get_item_count() - 1

## Atualiza exibição do pet ativo
func _update_active_pet_display():
	if not pet_component or not pet_component.active_pet:
		pet_icon.texture = null
		pet_name_label.text = "Nenhum Pet Ativo"
		pet_level_label.text = ""
		pet_xp_bar.value = 0
		summon_dismiss_button.text = "Invocar"
		active_pet_container.visible = false
		return
	
	var active_pet = pet_component.active_pet
	active_pet_container.visible = true
	
	# Ícone do pet
	if active_pet.icon_path != "":
		pet_icon.texture = load(active_pet.icon_path)
	else:
		pet_icon.texture = null
	
	# Nome e nível do pet
	pet_name_label.text = active_pet.name
	pet_level_label.text = "Nível " + str(active_pet.level)
	
	# Barra de XP
	var xp_to_next = active_pet._get_xp_for_level(active_pet.level + 1) if active_pet.level < active_pet.max_level else 1
	var xp_percent = (float(active_pet.current_xp) / float(xp_to_next)) * 100
	pet_xp_bar.value = xp_percent
	
	# Tooltip da barra de XP
	if active_pet.level >= active_pet.max_level:
		pet_xp_bar.tooltip_text = "Nível Máximo Atingido"
	else:
		pet_xp_bar.tooltip_text = str(active_pet.current_xp) + "/" + str(xp_to_next) + " XP"
	
	# Cor da barra baseada no nível
	if xp_percent > 75:
		pet_xp_bar.modulate = xp_color_full
	elif xp_percent > 25:
		pet_xp_bar.modulate = xp_color_medium
	else:
		pet_xp_bar.modulate = xp_color_low
	
	# Estado do botão
	if active_pet.is_active:
		summon_dismiss_button.text = "Dispensar"
	else:
		summon_dismiss_button.text = "Invocar"

## Atualiza botões de habilidades
func _update_ability_buttons():
	# Limpar botões existentes
	for button in ability_buttons:
		button.queue_free()
	ability_buttons.clear()
	
	if not pet_component or not pet_component.active_pet:
		return
	
	var active_pet = pet_component.active_pet
	
	# Criar botões para cada habilidade
	var ability_index = 0
	for ability_id in active_pet.abilities.values():
		var ability_button = Button.new()
		
		# Configurar botão
		ability_button.text = str(ability_index + 1)
		ability_button.tooltip_text = _get_ability_tooltip(ability_id)
		ability_button.custom_minimum_size = Vector2(40, 40)
		
		# Conectar sinal
		ability_button.pressed.connect(_on_ability_button_pressed.bind(ability_id))
		
		# Verificar se está em cooldown
		_update_ability_button_state(ability_button, ability_id, active_pet)
		
		# Adicionar à UI
		pet_abilities_container.add_child(ability_button)
		ability_buttons.append(ability_button)
		
		ability_index += 1
	
	# Adicionar teclas de atalho na tooltip
	for i in range(min(ability_buttons.size(), 5)):
		ability_buttons[i].tooltip_text += "\nTecla: " + str(i + 1)

## Atualiza estatísticas do pet
func _update_pet_stats():
	if not pet_component or not pet_component.active_pet:
		health_label.text = "Vida: --"
		attack_label.text = "Ataque: --"
		defense_label.text = "Defesa: --"
		speed_label.text = "Velocidade: --"
		pet_stats_container.visible = false
		return
	
	var active_pet = pet_component.active_pet
	var stats = active_pet.current_stats
	
	health_label.text = "Vida: " + str(stats.get("health", 0))
	attack_label.text = "Ataque: " + str(stats.get("attack", 0))
	defense_label.text = "Defesa: " + str(stats.get("defense", 0))
	speed_label.text = "Velocidade: " + str(stats.get("speed", 0))
	
	pet_stats_container.visible = true

## Atualiza estado do botão de habilidade
func _update_ability_button_state(button: Button, ability_id: String, pet: Pet):
	var current_time = Time.get_time_dict_from_system().get("second", 0)
	
	if ability_id in pet.last_ability_use:
		var ability_data = _get_ability_data(ability_id)
		if ability_data:
			var cooldown = ability_data.get("cooldown", 0)
			var time_since_use = current_time - pet.last_ability_use[ability_id]
			
			if time_since_use < cooldown:
				button.disabled = true
				button.text = str(int(cooldown - time_since_use))
			else:
				button.disabled = false

## Conecta sinais do componente de pets
func _connect_pet_component():
	if not pet_component:
		return
	
	if not pet_component.pet_summoned.is_connected(_on_component_pet_summoned):
		pet_component.pet_summoned.connect(_on_component_pet_summoned)
	if not pet_component.pet_dismissed.is_connected(_on_component_pet_dismissed):
		pet_component.pet_dismissed.connect(_on_component_pet_dismissed)
	if not pet_component.pet_level_up.is_connected(_on_component_pet_level_up):
		pet_component.pet_level_up.connect(_on_component_pet_level_up)

## Desconecta sinais do componente de pets
func _disconnect_pet_component():
	if not pet_component:
		return
	
	if pet_component.pet_summoned.is_connected(_on_component_pet_summoned):
		pet_component.pet_summoned.disconnect(_on_component_pet_summoned)
	if pet_component.pet_dismissed.is_connected(_on_component_pet_dismissed):
		pet_component.pet_dismissed.disconnect(_on_component_pet_dismissed)
	if pet_component.pet_level_up.is_connected(_on_component_pet_level_up):
		pet_component.pet_level_up.disconnect(_on_component_pet_level_up)

## Obtém tooltip de uma habilidade
func _get_ability_tooltip(ability_id: String) -> String:
	var ability_data = _get_ability_data(ability_id)
	if not ability_data:
		return ability_id
	
	var name = ability_data.get("name", ability_id)
	var description = ability_data.get("description", "")
	var cooldown = ability_data.get("cooldown", 0)
	var ability_type = ability_data.get("type", "")
	
	var tooltip = name
	if description != "":
		tooltip += "\n" + description
	if cooldown > 0:
		tooltip += "\nCooldown: " + str(cooldown) + "s"
	tooltip += "\nTipo: " + ability_type
	
	return tooltip

## Obtém dados de uma habilidade
func _get_ability_data(ability_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/pets/pets.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_data and "pet_abilities" in json_data:
			return json_data["pet_abilities"].get(ability_id, {})
	
	return {}

## Callbacks de botões
func _on_summon_dismiss_button_pressed():
	if not pet_component:
		return
	
	if pet_component.has_active_pet():
		pet_component.dismiss_active_pet()
	else:
		# Invocar pet selecionado
		var selected_index = pet_selector.selected
		if selected_index >= 0:
			var pet_id = pet_selector.get_item_metadata(selected_index)
			pet_component.summon_pet(pet_id)

func _on_pet_selector_item_selected(index: int):
	if index >= 0:
		var pet_id = pet_selector.get_item_metadata(index)
		pet_selected.emit(pet_id)

func _on_ability_button_pressed(ability_id: String):
	if pet_component and pet_component.has_active_pet():
		pet_component.use_pet_ability(ability_id)
		pet_ability_activated.emit(ability_id)

## Callbacks do EventBus
func _on_pet_summoned(entity: Entity, pet: Pet):
	if entity == current_entity:
		_update_active_pet_display()
		_update_ability_buttons()
		_update_pet_stats()

func _on_pet_dismissed(entity: Entity, pet: Pet):
	if entity == current_entity:
		_update_active_pet_display()
		_update_ability_buttons()
		_update_pet_stats()

func _on_pet_level_up(entity: Entity, pet: Pet, new_level: int):
	if entity == current_entity:
		_update_active_pet_display()
		_update_pet_stats()
		_flash_level_up_effect()

func _on_pet_unlocked(entity: Entity, pet: Pet):
	if entity == current_entity:
		_update_pet_selector()
		_show_pet_unlock_notification(pet)

## Callbacks do componente
func _on_component_pet_summoned(pet: Pet):
	_update_active_pet_display()
	_update_ability_buttons()

func _on_component_pet_dismissed(pet: Pet):
	_update_active_pet_display()
	_update_ability_buttons()

func _on_component_pet_level_up(pet: Pet, new_level: int):
	_update_active_pet_display()
	_update_pet_stats()

## Efeitos visuais
func _flash_level_up_effect():
	# Efeito de flash para level up
	var tween = create_tween()
	tween.tween_property(pet_name_label, "modulate", Color.GOLD, 0.2)
	tween.tween_property(pet_name_label, "modulate", Color.WHITE, 0.2)
	tween.tween_property(pet_name_label, "modulate", Color.GOLD, 0.2)
	tween.tween_property(pet_name_label, "modulate", Color.WHITE, 0.2)

func _show_pet_unlock_notification(pet: Pet):
	# Placeholder para notificação de desbloqueio
	print("Novo pet desbloqueado: ", pet.name)

## Atualização contínua de cooldowns
func _process(delta):
	if not visible or not pet_component or not pet_component.has_active_pet():
		return
	
	# Atualizar estado dos botões de habilidade
	var active_pet = pet_component.active_pet
	for i in range(ability_buttons.size()):
		if i < active_pet.abilities.values().size():
			var ability_id = active_pet.abilities.values()[i]
			_update_ability_button_state(ability_buttons[i], ability_id, active_pet)

## Métodos públicos para controle da UI
func show_pet_ui():
	visible = true

func hide_pet_ui():
	visible = false

func toggle_pet_ui():
	visible = not visible

## Configurações da UI
func set_ui_position(pos: Vector2):
	position = pos

func set_ui_scale(scale_factor: float):
	scale = Vector2(scale_factor, scale_factor)

func set_xp_colors(full: Color, medium: Color, low: Color):
	xp_color_full = full
	xp_color_medium = medium
	xp_color_low = low

## Cleanup
func _exit_tree():
	if pet_component:
		_disconnect_pet_component()
	
	for button in ability_buttons:
		if is_instance_valid(button):
			button.queue_free()
	ability_buttons.clear()