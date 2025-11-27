# UI de Montarias - Disorder Chaos
extends Control
class_name MountUI

## Interface de usuário para o sistema de montarias
## Exibe barra de stamina, ícone da montaria, e controles

signal mount_selected(mount_id: String)
signal mount_skill_activated(skill_id: String)
signal mount_menu_requested()

@onready var stamina_bar: ProgressBar = $VBoxContainer/StaminaBar
@onready var mount_icon: TextureRect = $VBoxContainer/HBoxContainer/MountIcon
@onready var mount_name_label: Label = $VBoxContainer/HBoxContainer/MountName
@onready var skill_buttons_container: HBoxContainer = $VBoxContainer/SkillButtons
@onready var mount_selector: OptionButton = $VBoxContainer/MountSelector
@onready var toggle_button: Button = $VBoxContainer/HBoxContainer/ToggleButton
@onready var dash_button: Button = $VBoxContainer/HBoxContainer/DashButton

var current_entity: Entity = null
var mount_component: MountComponent = null
var skill_buttons: Array[Button] = []

# Estilo visual
var stamina_color_full: Color = Color.GREEN
var stamina_color_medium: Color = Color.YELLOW
var stamina_color_low: Color = Color.RED
var stamina_color_empty: Color = Color.DARK_RED

func _ready():
	# Configurar sinais dos botões
	toggle_button.pressed.connect(_on_toggle_button_pressed)
	dash_button.pressed.connect(_on_dash_button_pressed)
	mount_selector.item_selected.connect(_on_mount_selector_item_selected)
	
	# Configurar tooltips
	toggle_button.tooltip_text = "Invocar/Dispensar Montaria (Ctrl+M)"
	dash_button.tooltip_text = "Dash da Montaria (Shift)"
	
	# Configurar barra de stamina
	stamina_bar.min_value = 0
	stamina_bar.max_value = 100
	stamina_bar.value = 0
	stamina_bar.show_percentage = true
	
	# Inicializar como invisível
	visible = false
	
	# Conectar sinais do EventBus
	EventBus.mount_summoned.connect(_on_mount_summoned)
	EventBus.mount_dismissed.connect(_on_mount_dismissed)
	EventBus.mount_stamina_changed.connect(_on_mount_stamina_changed)
	EventBus.mount_skill_used.connect(_on_mount_skill_used)
	EventBus.mount_unlocked.connect(_on_mount_unlocked)

## Define a entidade que esta UI deve monitorar
func set_entity(entity: Entity):
	if current_entity == entity:
		return
	
	# Desconectar entidade anterior
	if current_entity and mount_component:
		_disconnect_mount_component()
	
	current_entity = entity
	mount_component = null
	
	if current_entity:
		mount_component = current_entity.get_component("MountComponent")
		if mount_component:
			_connect_mount_component()
			_refresh_ui()
		else:
			visible = false

## Atualiza a UI com as informações atuais
func _refresh_ui():
	if not mount_component:
		visible = false
		return
	
	_update_mount_selector()
	_update_current_mount_display()
	_update_skill_buttons()
	
	# Mostrar UI se tiver montarias disponíveis
	visible = not mount_component.available_mounts.is_empty()

## Atualiza o seletor de montarias
func _update_mount_selector():
	if not mount_component:
		return
	
	mount_selector.clear()
	
	for mount in mount_component.available_mounts:
		if mount.unlocked:
			var item_text = mount.name
			if mount.level_required > 1:
				item_text += " (Nv." + str(mount.level_required) + ")"
			
			mount_selector.add_item(item_text)
			mount_selector.set_item_metadata(mount_selector.get_item_count() - 1, mount.id)
			
			# Selecionar montaria atual
			if mount_component.current_mount and mount_component.current_mount.id == mount.id:
				mount_selector.selected = mount_selector.get_item_count() - 1

## Atualiza exibição da montaria atual
func _update_current_mount_display():
	if not mount_component or not mount_component.current_mount:
		mount_icon.texture = null
		mount_name_label.text = ""
		stamina_bar.value = 0
		toggle_button.text = "Invocar"
		dash_button.disabled = true
		return
	
	var current_mount = mount_component.current_mount
	
	# Ícone da montaria
	if current_mount.icon_path != "":
		mount_icon.texture = load(current_mount.icon_path)
	else:
		mount_icon.texture = null
	
	# Nome da montaria
	mount_name_label.text = current_mount.name
	
	# Barra de stamina
	var stamina_percent = (current_mount.stamina_atual / current_mount.stamina_maxima) * 100
	stamina_bar.value = stamina_percent
	
	# Cor da barra baseada na stamina
	if stamina_percent > 75:
		stamina_bar.modulate = stamina_color_full
	elif stamina_percent > 50:
		stamina_bar.modulate = stamina_color_medium
	elif stamina_percent > 25:
		stamina_bar.modulate = stamina_color_low
	else:
		stamina_bar.modulate = stamina_color_empty
	
	# Estado dos botões
	if current_mount.is_mounted:
		toggle_button.text = "Dispensar"
		dash_button.disabled = current_mount.stamina_atual < 30
	else:
		toggle_button.text = "Invocar"
		dash_button.disabled = true

## Atualiza botões de skills
func _update_skill_buttons():
	# Limpar botões existentes
	for button in skill_buttons:
		button.queue_free()
	skill_buttons.clear()
	
	if not mount_component or not mount_component.current_mount:
		return
	
	var current_mount = mount_component.current_mount
	
	# Criar botões para cada skill
	for i in range(current_mount.skills.size()):
		var skill_id = current_mount.skills[i]
		var skill_button = Button.new()
		
		# Configurar botão
		skill_button.text = str(i + 1)
		skill_button.tooltip_text = _get_skill_tooltip(skill_id)
		skill_button.custom_minimum_size = Vector2(40, 40)
		
		# Conectar sinal
		skill_button.pressed.connect(_on_skill_button_pressed.bind(skill_id))
		
		# Adicionar à UI
		skill_buttons_container.add_child(skill_button)
		skill_buttons.append(skill_button)
	
	# Adicionar teclas de atalho na tooltip
	for i in range(min(skill_buttons.size(), 3)):
		skill_buttons[i].tooltip_text += "\nTecla: " + str(i + 1)

## Conecta sinais do componente de montaria
func _connect_mount_component():
	if not mount_component:
		return
	
	if not mount_component.mount_summoned.is_connected(_on_component_mount_summoned):
		mount_component.mount_summoned.connect(_on_component_mount_summoned)
	if not mount_component.mount_dismissed.is_connected(_on_component_mount_dismissed):
		mount_component.mount_dismissed.connect(_on_component_mount_dismissed)
	if not mount_component.mount_changed.is_connected(_on_component_mount_changed):
		mount_component.mount_changed.connect(_on_component_mount_changed)

## Desconecta sinais do componente de montaria
func _disconnect_mount_component():
	if not mount_component:
		return
	
	if mount_component.mount_summoned.is_connected(_on_component_mount_summoned):
		mount_component.mount_summoned.disconnect(_on_component_mount_summoned)
	if mount_component.mount_dismissed.is_connected(_on_component_mount_dismissed):
		mount_component.mount_dismissed.disconnect(_on_component_mount_dismissed)
	if mount_component.mount_changed.is_connected(_on_component_mount_changed):
		mount_component.mount_changed.disconnect(_on_component_mount_changed)

## Obtém tooltip de uma skill
func _get_skill_tooltip(skill_id: String) -> String:
	var file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if file == null:
		return skill_id
	
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json_data and "mount_skills" in json_data:
		var skill_data = json_data["mount_skills"].get(skill_id, {})
		var name = skill_data.get("name", skill_id)
		var description = skill_data.get("description", "")
		var cooldown = skill_data.get("cooldown", 0)
		var stamina_cost = skill_data.get("stamina_cost", 0)
		
		var tooltip = name
		if description != "":
			tooltip += "\n" + description
		if cooldown > 0:
			tooltip += "\nCooldown: " + str(cooldown) + "s"
		if stamina_cost > 0:
			tooltip += "\nCusto: " + str(stamina_cost) + " stamina"
		
		return tooltip
	
	return skill_id

## Callbacks de botões
func _on_toggle_button_pressed():
	if not mount_component:
		return
	
	if mount_component.is_mounted():
		mount_component.dismiss_current_mount()
	else:
		# Invocar montaria selecionada
		var selected_index = mount_selector.selected
		if selected_index >= 0:
			var mount_id = mount_selector.get_item_metadata(selected_index)
			mount_component.summon_mount(mount_id)

func _on_dash_button_pressed():
	if mount_component and mount_component.is_mounted():
		mount_component.mount_dash()

func _on_mount_selector_item_selected(index: int):
	if index >= 0:
		var mount_id = mount_selector.get_item_metadata(index)
		mount_selected.emit(mount_id)

func _on_skill_button_pressed(skill_id: String):
	if mount_component and mount_component.is_mounted():
		mount_component.use_mount_skill(skill_id)
		mount_skill_activated.emit(skill_id)

## Callbacks do EventBus
func _on_mount_summoned(entity: Entity, mount: Mount):
	if entity == current_entity:
		_update_current_mount_display()
		_update_skill_buttons()

func _on_mount_dismissed(entity: Entity, mount: Mount):
	if entity == current_entity:
		_update_current_mount_display()
		_update_skill_buttons()

func _on_mount_stamina_changed(entity: Entity, current: float, maximum: float):
	if entity == current_entity:
		var stamina_percent = (current / maximum) * 100
		stamina_bar.value = stamina_percent
		
		# Atualizar cor da barra
		if stamina_percent > 75:
			stamina_bar.modulate = stamina_color_full
		elif stamina_percent > 50:
			stamina_bar.modulate = stamina_color_medium
		elif stamina_percent > 25:
			stamina_bar.modulate = stamina_color_low
		else:
			stamina_bar.modulate = stamina_color_empty
		
		# Atualizar estado do botão dash
		dash_button.disabled = not mount_component.is_mounted() or current < 30

func _on_mount_skill_used(entity: Entity, skill_id: String):
	if entity == current_entity:
		# Efeito visual de skill usada (placeholder)
		_flash_skill_button(skill_id)

func _on_mount_unlocked(entity: Entity, mount: Mount):
	if entity == current_entity:
		_update_mount_selector()
		
		# Notificação visual de nova montaria
		_show_mount_unlock_notification(mount)

## Callbacks do componente
func _on_component_mount_summoned(mount: Mount):
	_update_current_mount_display()
	_update_skill_buttons()

func _on_component_mount_dismissed(mount: Mount):
	_update_current_mount_display()
	_update_skill_buttons()

func _on_component_mount_changed(old_mount: Mount, new_mount: Mount):
	_update_current_mount_display()
	_update_skill_buttons()

## Efeitos visuais
func _flash_skill_button(skill_id: String):
	# Encontrar botão da skill e fazer efeito de flash
	for i in range(skill_buttons.size()):
		if mount_component.current_mount.skills[i] == skill_id:
			var button = skill_buttons[i]
			var tween = create_tween()
			tween.tween_property(button, "modulate", Color.YELLOW, 0.1)
			tween.tween_property(button, "modulate", Color.WHITE, 0.1)
			break

func _show_mount_unlock_notification(mount: Mount):
	# Placeholder para notificação de desbloqueio
	print("Nova montaria desbloqueada: ", mount.name)

## Métodos públicos para controle da UI
func show_mount_ui():
	visible = true

func hide_mount_ui():
	visible = false

func toggle_mount_ui():
	visible = not visible

## Métodos de configuração
func set_stamina_colors(full: Color, medium: Color, low: Color, empty: Color):
	stamina_color_full = full
	stamina_color_medium = medium
	stamina_color_low = low
	stamina_color_empty = empty

func set_ui_position(pos: Vector2):
	position = pos

func set_ui_scale(scale_factor: float):
	scale = Vector2(scale_factor, scale_factor)

## Cleanup
func _exit_tree():
	if mount_component:
		_disconnect_mount_component()
	
	for button in skill_buttons:
		if is_instance_valid(button):
			button.queue_free()
	skill_buttons.clear()