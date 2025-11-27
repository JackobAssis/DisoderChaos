class_name EquipmentUI
extends Control

## Interface de equipamentos com 10 slots especÃ­ficos e preview 3D

@onready var character_preview: SubViewport = $Background/MainContainer/CharacterPreview
@onready var equipment_panel: Control = $Background/MainContainer/EquipmentPanel

# Equipment slots - 10 slots especÃ­ficos
@onready var weapon_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/WeaponSlot
@onready var helmet_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/HelmetSlot
@onready var chest_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/ChestSlot
@onready var legs_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/LegsSlot
@onready var boots_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/BootsSlot
@onready var cloak_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/CloakSlot
@onready var offhand_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/OffhandSlot
@onready var accessory1_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/Accessory1Slot
@onready var accessory2_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/Accessory2Slot
@onready var special_slot: EquipmentSlot = $Background/MainContainer/EquipmentPanel/SpecialSlot

# Stats panel
@onready var stats_panel: VBoxContainer = $Background/StatsPanel/VBox
@onready var total_stats_label: RichTextLabel = $Background/StatsPanel/VBox/TotalStatsLabel

# Character model (3D)
var character_model: Node3D
var camera: Camera3D

# Equipment system
var equipment_data: EquipmentSystem
var equipped_items: Dictionary = {}

# Equipment types mapping
var slot_types: Dictionary = {
	"weapon": "weapon",
	"helmet": "helmet", 
	"chest": "chest_armor",
	"legs": "leg_armor",
	"boots": "boots",
	"cloak": "cloak",
	"offhand": "shield",
	"accessory1": "accessory",
	"accessory2": "accessory",
	"special": "special"
}

signal item_equipped(slot_type: String, item_data: Dictionary)
signal item_unequipped(slot_type: String, item_data: Dictionary)
signal stats_updated(new_stats: Dictionary)

func _ready():
	setup_ui_theme()
	setup_equipment_slots()
	setup_3d_preview()
	setup_connections()
	update_character_stats()

func setup_ui_theme():
# Aplica tema dark fantasy
	# Background principal
	var bg = $Background as ColorRect
	if bg:
		bg.color = UIThemeManager.Colors.BG_POPUP
	
	# Equipment panel
	equipment_panel.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	
	# Stats panel
	var stats_bg = $Background/StatsPanel as Panel
	if stats_bg:
		stats_bg.add_theme_stylebox_override("panel", 
			UIThemeManager.create_panel_style(UIThemeManager.Colors.PRIMARY_DARK))

func setup_equipment_slots():
# Configura todos os slots de equipamento
	var slots = {
		weapon_slot: "weapon",
		helmet_slot: "helmet",
		chest_slot: "chest",
		legs_slot: "legs", 
		boots_slot: "boots",
		cloak_slot: "cloak",
		offhand_slot: "offhand",
		accessory1_slot: "accessory1",
		accessory2_slot: "accessory2",
		special_slot: "special"
	}
	
	for slot in slots:
		if slot:
			var slot_type = slots[slot]
			slot.setup(slot_type, Vector2(64, 64))
			slot.item_equipped.connect(_on_item_equipped.bind(slot_type))
			slot.item_unequipped.connect(_on_item_unequipped.bind(slot_type))
			slot.item_hovered.connect(_on_equipment_hovered)
			slot.item_unhovered.connect(_on_equipment_unhovered)

func setup_3d_preview():
# Configura preview 3D do personagem
	if not character_preview:
		return
	
	# Camera
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.5, 3)
	camera.look_at(Vector3(0, 1, 0), Vector3.UP)
	character_preview.add_child(camera)
	
	# Luz
	var light = DirectionalLight3D.new()
	light.position = Vector3(2, 2, 2)
	light.look_at(Vector3.ZERO, Vector3.UP)
	character_preview.add_child(light)
	
	# Model do personagem (placeholder)
	create_character_model()
	
	# Permite rotaÃ§Ã£o com mouse
	character_preview.gui_input.connect(_on_preview_input)

func create_character_model():
# Cria modelo 3D do personagem
	character_model = Node3D.new()
	character_model.name = "CharacterModel"
	
	# Base do personagem (placeholder com MeshInstance3D)
	var body = MeshInstance3D.new()
	body.mesh = CylinderMesh.new()
	body.mesh.height = 2.0
	body.mesh.top_radius = 0.3
	body.mesh.bottom_radius = 0.3
	character_model.add_child(body)
	
	# Material bÃ¡sico
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.7, 0.6)  # Cor de pele
	body.material_override = material
	
	character_preview.add_child(character_model)

func setup_connections():
# Conecta com sistemas do jogo
	if EventBus:
		EventBus.equipment_changed.connect(_on_equipment_system_changed)
		EventBus.player_stats_changed.connect(_on_player_stats_changed)

func _on_preview_input(event: InputEvent):
# Gerencia rotaÃ§Ã£o da prÃ©via 3D
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if character_model:
			character_model.rotation_degrees.y += event.relative.x * 0.5

# === EQUIPMENT HANDLING ===
func _on_item_equipped(slot_type: String, item_data: Dictionary):
# Item foi equipado em um slot
	equipped_items[slot_type] = item_data
	update_character_model()
	update_character_stats()
	item_equipped.emit(slot_type, item_data)

func _on_item_unequipped(slot_type: String, item_data: Dictionary):
# Item foi desequipado de um slot
	equipped_items.erase(slot_type)
	update_character_model()
	update_character_stats()
	item_unequipped.emit(slot_type, item_data)

func _on_equipment_hovered(slot: EquipmentSlot):
# Mouse over em equipamento
	if slot.has_item():
		show_equipment_tooltip(slot.item_data, slot.global_position)

func _on_equipment_unhovered(slot: EquipmentSlot):
# Mouse saiu do equipamento
	hide_equipment_tooltip()

# === CHARACTER MODEL UPDATES ===
func update_character_model():
# Atualiza modelo 3D com equipamentos
	if not character_model:
		return
	
	# Remove equipamentos visuais antigos
	for child in character_model.get_children():
		if child.name.begins_with("equipment_"):
			child.queue_free()
	
	# Adiciona novos equipamentos visuais
	for slot_type in equipped_items:
		var item_data = equipped_items[slot_type]
		add_equipment_visual(slot_type, item_data)

func add_equipment_visual(slot_type: String, item_data: Dictionary):
# Adiciona visual de equipamento no modelo 3D
	if not item_data.has("model_3d"):
		return
	
	# Carrega modelo 3D do equipamento
	var equipment_model = load(item_data.model_3d)
	if not equipment_model:
		return
	
	var instance = equipment_model.instantiate()
	instance.name = "equipment_" + slot_type
	
	# Posiciona baseado no tipo de slot
	position_equipment(instance, slot_type)
	
	character_model.add_child(instance)

func position_equipment(equipment_node: Node3D, slot_type: String):
# Posiciona equipamento no corpo
	match slot_type:
		"helmet":
			equipment_node.position = Vector3(0, 1.7, 0)
		"chest":
			equipment_node.position = Vector3(0, 0.8, 0)
		"weapon":
			equipment_node.position = Vector3(0.5, 0.5, 0)
			equipment_node.rotation_degrees = Vector3(0, 0, -45)
		"shield", "offhand":
			equipment_node.position = Vector3(-0.5, 0.5, 0)
		"cloak":
			equipment_node.position = Vector3(0, 0.8, -0.1)
		_:
			equipment_node.position = Vector3.ZERO

# === STATS CALCULATION ===
func update_character_stats():
# Atualiza estatÃ­sticas do personagem
	var total_stats = calculate_total_stats()
	display_stats(total_stats)
	stats_updated.emit(total_stats)

func calculate_total_stats() -> Dictionary:
# Calcula stats totais com equipamentos
	var base_stats = {
		"attack": 10,
		"defense": 5,
		"health": 100,
		"mana": 50,
		"stamina": 100,
		"critical_chance": 5,
		"critical_damage": 150,
		"attack_speed": 1.0,
		"movement_speed": 100,
		"magic_resistance": 0,
		"fire_resistance": 0,
		"ice_resistance": 0,
		"lightning_resistance": 0
	}
	
	# Adiciona bÃ´nus dos equipamentos
	var total_stats = base_stats.duplicate()
	
	for slot_type in equipped_items:
		var item_data = equipped_items[slot_type]
		var item_stats = item_data.get("stats", {})
		
		for stat in item_stats:
			if total_stats.has(stat):
				total_stats[stat] += item_stats[stat]
			else:
				total_stats[stat] = item_stats[stat]
	
	return total_stats

func display_stats(stats: Dictionary):
# Exibe estatÃ­sticas na UI
	# Limpa stats antigas
	for child in stats_panel.get_children():
		if child != total_stats_label:
			child.queue_free()
	
	# Stats principais (combate)
	add_stat_category("Combate")
	add_stat_row("Ataque", stats.get("attack", 0), UIThemeManager.Colors.ERROR_RED)
	add_stat_row("Defesa", stats.get("defense", 0), UIThemeManager.Colors.CYBER_CYAN)
	add_stat_row("Chance CrÃ­tica", str(stats.get("critical_chance", 0)) + "%", UIThemeManager.Colors.ACCENT_GOLD)
	add_stat_row("Dano CrÃ­tico", str(stats.get("critical_damage", 0)) + "%", UIThemeManager.Colors.ACCENT_GOLD)
	
	# Stats de recursos
	add_stat_category("Recursos")
	add_stat_row("Vida", stats.get("health", 0), UIThemeManager.Colors.HP_RED)
	add_stat_row("Mana", stats.get("mana", 0), UIThemeManager.Colors.MANA_BLUE)
	add_stat_row("Stamina", stats.get("stamina", 0), UIThemeManager.Colors.STAMINA_GREEN)
	
	# Stats de velocidade
	add_stat_category("Velocidade")
	add_stat_row("Atk Speed", str(stats.get("attack_speed", 1.0)), UIThemeManager.Colors.TECH_ORANGE)
	add_stat_row("Movimento", stats.get("movement_speed", 100), UIThemeManager.Colors.SUCCESS_GREEN)
	
	# ResistÃªncias
	var has_resistances = false
	for stat in stats:
		if stat.ends_with("_resistance") and stats[stat] > 0:
			if not has_resistances:
				add_stat_category("ResistÃªncias")
				has_resistances = true
			var resistance_name = stat.replace("_resistance", "").capitalize()
			add_stat_row(resistance_name, str(stats[stat]) + "%", UIThemeManager.Colors.MANA_BLUE)

func add_stat_category(name: String):
# Adiciona categoria de stats
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	stats_panel.add_child(spacer)
	
	var label = Label.new()
	label.text = "=== " + name + " ==="
	label.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(label)

func add_stat_row(stat_name: String, value, color: Color = UIThemeManager.Colors.TEXT_PRIMARY):
# Adiciona linha de stat
	var container = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = stat_name + ":"
	name_label.custom_minimum_size.x = 120
	name_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
	container.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = str(value)
	value_label.add_theme_color_override("font_color", color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(value_label)
	
	stats_panel.add_child(container)

# === TOOLTIP SYSTEM ===
var tooltip_popup: Control

func show_equipment_tooltip(item_data: Dictionary, position: Vector2):
# Mostra tooltip detalhado do equipamento
	hide_equipment_tooltip()
	
	tooltip_popup = create_detailed_tooltip(item_data)
	tooltip_popup.global_position = position + Vector2(70, 0)
	get_tree().current_scene.add_child(tooltip_popup)

func create_detailed_tooltip(item_data: Dictionary) -> Control:
# Cria tooltip detalhado
	var tooltip = Control.new()
	tooltip.z_index = 1000
	
	# Background
	var bg = ColorRect.new()
	bg.color = UIThemeManager.Colors.BG_POPUP
	tooltip.add_child(bg)
	
	var container = VBoxContainer.new()
	container.position = Vector2(8, 8)
	tooltip.add_child(container)
	
	# Nome do item
	var name_label = Label.new()
	name_label.text = item_data.get("name", "Item Desconhecido")
	var rarity_color = get_rarity_color(item_data.get("rarity", "common"))
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.add_theme_font_size_override("font_size", 16)
	container.add_child(name_label)
	
	# Tipo
	var type_label = Label.new()
	type_label.text = item_data.get("type", "").capitalize()
	type_label.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
	container.add_child(type_label)
	
	# Separador
	var separator = HSeparator.new()
	container.add_child(separator)
	
	# Stats
	var stats = item_data.get("stats", {})
	if not stats.is_empty():
		for stat in stats:
			var stat_container = HBoxContainer.new()
			
			var stat_label = Label.new()
			stat_label.text = stat.capitalize() + ":"
			stat_label.custom_minimum_size.x = 100
			stat_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
			stat_container.add_child(stat_label)
			
			var value_label = Label.new()
			value_label.text = "+" + str(stats[stat])
			value_label.add_theme_color_override("font_color", UIThemeManager.Colors.SUCCESS_GREEN)
			stat_container.add_child(value_label)
			
			container.add_child(stat_container)
		
		# Outro separador
		var separator2 = HSeparator.new()
		container.add_child(separator2)
	
	# DescriÃ§Ã£o
	if item_data.has("description"):
		var desc_label = Label.new()
		desc_label.text = item_data.description
		desc_label.custom_minimum_size.x = 200
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
		container.add_child(desc_label)
	
	# Ajusta tamanho do background
	bg.size = container.get_rect().size + Vector2(16, 16)
	tooltip.size = bg.size
	
	return tooltip

func hide_equipment_tooltip():
# Esconde tooltip
	if tooltip_popup:
		tooltip_popup.queue_free()
		tooltip_popup = null

func get_rarity_color(rarity: String) -> Color:
# Retorna cor da raridade
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)
		"epic": return Color(0.6, 0.3, 0.9)
		"rare": return Color(0.0, 0.5, 1.0)
		"uncommon": return Color(0.0, 1.0, 0.0)
		_: return UIThemeManager.Colors.TEXT_PRIMARY

# === EXTERNAL INTERFACE ===
func equip_item(item_data: Dictionary, slot_type: String) -> bool:
# Equipa item em slot especÃ­fico
	var slot = get_slot_by_type(slot_type)
	if slot and can_equip_item(item_data, slot_type):
		slot.set_item(item_data)
		return true
	return false

func unequip_item(slot_type: String) -> Dictionary:
# Desequipa item de um slot
	var slot = get_slot_by_type(slot_type)
	if slot and slot.has_item():
		var item_data = slot.item_data.duplicate()
		slot.clear_item()
		return item_data
	return {}

func can_equip_item(item_data: Dictionary, slot_type: String) -> bool:
# Verifica se item pode ser equipado no slot
	var required_type = slot_types.get(slot_type, "")
	var item_type = item_data.get("type", "")
	
	# Accessory slots podem aceitar qualquer accessory
	if slot_type in ["accessory1", "accessory2"]:
		return item_type == "accessory"
	
	return item_type == required_type

func get_slot_by_type(slot_type: String) -> EquipmentSlot:
# Retorna slot por tipo
	match slot_type:
		"weapon": return weapon_slot
		"helmet": return helmet_slot
		"chest": return chest_slot
		"legs": return legs_slot
		"boots": return boots_slot
		"cloak": return cloak_slot
		"offhand": return offhand_slot
		"accessory1": return accessory1_slot
		"accessory2": return accessory2_slot
		"special": return special_slot
		_: return null

func get_equipped_items() -> Dictionary:
# Retorna todos os itens equipados
	return equipped_items.duplicate()

func get_total_stats() -> Dictionary:
# Retorna stats totais calculados
	return calculate_total_stats()

# === EVENT HANDLERS ===
func _on_equipment_system_changed():
# Sistema de equipamento foi atualizado
	# Recarrega equipamentos do sistema
	pass

func _on_player_stats_changed(stats: PlayerStats):
# Stats base do player mudaram
	update_character_stats()
