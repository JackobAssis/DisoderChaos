class_name EquipmentSlot
extends Control

## Slot específico para equipamentos

@onready var background: ColorRect
@onready var slot_icon: TextureRect  # Ícone do tipo de slot
@onready var item_icon: TextureRect  # Ícone do item equipado
@onready var enchant_indicator: ColorRect  # Indicador de encantamento

var slot_type: String
var item_data: Dictionary = {}
var slot_size: Vector2

signal item_equipped(item_data: Dictionary)
signal item_unequipped(item_data: Dictionary)
signal item_hovered(slot: EquipmentSlot)
signal item_unhovered(slot: EquipmentSlot)
signal slot_clicked(slot: EquipmentSlot)

# Ícones dos tipos de slot
var slot_icons: Dictionary = {
	"weapon": "res://assets/icons/slots/weapon_slot.png",
	"helmet": "res://assets/icons/slots/helmet_slot.png",
	"chest": "res://assets/icons/slots/chest_slot.png",
	"legs": "res://assets/icons/slots/legs_slot.png",
	"boots": "res://assets/icons/slots/boots_slot.png",
	"cloak": "res://assets/icons/slots/cloak_slot.png",
	"offhand": "res://assets/icons/slots/shield_slot.png",
	"accessory1": "res://assets/icons/slots/accessory_slot.png",
	"accessory2": "res://assets/icons/slots/accessory_slot.png",
	"special": "res://assets/icons/slots/special_slot.png"
}

func _ready():
	setup_slot_ui()
	setup_connections()

func setup(type: String, size: Vector2):
	"""Configura slot com tipo e tamanho"""
	slot_type = type
	slot_size = size
	custom_minimum_size = size
	
	# Carrega ícone do slot
	if slot_icons.has(slot_type):
		var icon_path = slot_icons[slot_type]
		if ResourceLoader.exists(icon_path):
			slot_icon.texture = load(icon_path)

func setup_slot_ui():
	"""Cria interface do slot"""
	# Background principal
	background = ColorRect.new()
	background.color = UIThemeManager.Colors.PRIMARY_DARK
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	# Adiciona borda
	var border = ReferenceRect.new()
	border.border_color = UIThemeManager.Colors.CYBER_CYAN
	border.border_width = 2
	border.anchors_preset = Control.PRESET_FULL_RECT
	add_child(border)
	
	# Ícone do tipo de slot (placeholder quando vazio)
	slot_icon = TextureRect.new()
	slot_icon.anchors_preset = Control.PRESET_CENTER
	slot_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	slot_icon.modulate = Color(1, 1, 1, 0.3)  # Translúcido quando vazio
	slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot_icon)
	
	# Ícone do item equipado
	item_icon = TextureRect.new()
	item_icon.anchors_preset = Control.PRESET_CENTER
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.visible = false
	add_child(item_icon)
	
	# Indicador de encantamento
	enchant_indicator = ColorRect.new()
	enchant_indicator.color = UIThemeManager.Colors.ACCENT_GOLD
	enchant_indicator.size = Vector2(8, 8)
	enchant_indicator.position = Vector2(2, 2)
	enchant_indicator.visible = false
	add_child(enchant_indicator)

func setup_connections():
	"""Conecta eventos"""
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent):
	"""Gerencia input no slot"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click()

func _on_left_click():
	"""Click esquerdo no slot"""
	slot_clicked.emit(self)
	
	# Se tiver item, desequipa
	if has_item():
		unequip_current_item()

func _on_right_click():
	"""Click direito no slot"""
	if has_item():
		show_item_context_menu()

func _on_mouse_entered():
	"""Mouse entra no slot"""
	# Efeito hover
	var tween = create_tween()
	tween.tween_property(background, "color", UIThemeManager.Colors.PRIMARY_NAVY, 0.1)
	
	if has_item():
		item_hovered.emit(self)

func _on_mouse_exited():
	"""Mouse sai do slot"""
	# Remove efeito hover
	var tween = create_tween()
	tween.tween_property(background, "color", UIThemeManager.Colors.PRIMARY_DARK, 0.1)
	
	if has_item():
		item_unhovered.emit(self)

func set_item(data: Dictionary):
	"""Equipa item no slot"""
	item_data = data
	
	# Mostra ícone do item
	if data.has("icon"):
		var texture = load(data.icon) if data.icon is String else data.icon
		item_icon.texture = texture
		item_icon.visible = true
		
		# Esconde ícone do slot vazio
		slot_icon.modulate = Color.TRANSPARENT
	
	# Efeito de raridade
	apply_rarity_effects(data.get("rarity", "common"))
	
	# Indicador de encantamento
	if data.get("enchanted", false) or data.get("enchantments", []).size() > 0:
		enchant_indicator.visible = true
		UIThemeManager.apply_glow_effect(enchant_indicator, UIThemeManager.Colors.ACCENT_GOLD)
	
	# Animação de equipar
	play_equip_animation()
	
	# Emite sinal
	item_equipped.emit(data)

func clear_item():
	"""Remove item do slot"""
	if has_item():
		var old_data = item_data.duplicate()
		item_data = {}
		
		# Esconde ícone do item
		item_icon.visible = false
		item_icon.texture = null
		
		# Mostra ícone do slot vazio
		slot_icon.modulate = Color(1, 1, 1, 0.3)
		
		# Remove indicador de encantamento
		enchant_indicator.visible = false
		
		# Remove efeitos de raridade
		clear_rarity_effects()
		
		# Animação de desequipar
		play_unequip_animation()
		
		# Emite sinal
		item_unequipped.emit(old_data)

func has_item() -> bool:
	"""Verifica se slot tem item"""
	return not item_data.is_empty()

func can_equip_item(data: Dictionary) -> bool:
	"""Verifica se item pode ser equipado neste slot"""
	var item_type = data.get("type", "")
	var level_req = data.get("level_requirement", 1)
	
	# Verifica tipo compatível
	if not is_type_compatible(item_type):
		return false
	
	# Verifica nível (assumindo que player stats estão disponíveis)
	var player_level = 1  # TODO: Pegar do sistema de player
	if level_req > player_level:
		return false
	
	return true

func is_type_compatible(item_type: String) -> bool:
	"""Verifica se tipo de item é compatível com o slot"""
	match slot_type:
		"weapon":
			return item_type in ["sword", "axe", "mace", "dagger", "staff", "bow"]
		"helmet":
			return item_type == "helmet"
		"chest":
			return item_type in ["chest_armor", "robe"]
		"legs":
			return item_type in ["leg_armor", "pants"]
		"boots":
			return item_type == "boots"
		"cloak":
			return item_type == "cloak"
		"offhand":
			return item_type in ["shield", "tome", "quiver"]
		"accessory1", "accessory2":
			return item_type in ["ring", "amulet", "trinket"]
		"special":
			return item_type == "special"
		_:
			return false

func apply_rarity_effects(rarity: String):
	"""Aplica efeitos visuais da raridade"""
	var rarity_color = get_rarity_color(rarity)
	
	# Borda colorida
	var border = get_child(1) as ReferenceRect  # Border é o segundo filho
	if border:
		border.border_color = rarity_color
		
		# Glow para itens épicos e lendários
		if rarity in ["epic", "legendary"]:
			UIThemeManager.apply_glow_effect(border, rarity_color)
	
	# Background com cor sutil
	if rarity != "common":
		background.color = rarity_color * Color(0.2, 0.2, 0.2, 1.0)

func clear_rarity_effects():
	"""Remove efeitos de raridade"""
	background.color = UIThemeManager.Colors.PRIMARY_DARK
	
	var border = get_child(1) as ReferenceRect
	if border:
		border.border_color = UIThemeManager.Colors.CYBER_CYAN

func get_rarity_color(rarity: String) -> Color:
	"""Retorna cor da raridade"""
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)  # Dourado
		"epic": return Color(0.6, 0.3, 0.9)       # Roxo
		"rare": return Color(0.0, 0.5, 1.0)       # Azul
		"uncommon": return Color(0.0, 1.0, 0.0)   # Verde
		_: return UIThemeManager.Colors.CYBER_CYAN  # Comum

func play_equip_animation():
	"""Animação ao equipar item"""
	var tween = create_tween()
	
	# Scale up
	scale = Vector2(0.8, 0.8)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	
	# Flash
	tween.parallel().tween_property(item_icon, "modulate", Color.WHITE * 1.5, 0.1)
	tween.tween_property(item_icon, "modulate", Color.WHITE, 0.1)

func play_unequip_animation():
	"""Animação ao desequipar item"""
	var tween = create_tween()
	
	# Fade out
	tween.tween_property(item_icon, "modulate", Color.TRANSPARENT, 0.2)
	tween.tween_callback(func(): item_icon.modulate = Color.WHITE)

func unequip_current_item():
	"""Desequipa item atual"""
	if has_item():
		# TODO: Adicionar item de volta ao inventário
		clear_item()

func show_item_context_menu():
	"""Mostra menu de contexto do item"""
	# TODO: Implementar menu com opções como:
	# - Desequipar
	# - Inspecionar
	# - Encantar
	# - Reparar
	pass

func get_tooltip_text() -> String:
	"""Retorna texto para tooltip"""
	if not has_item():
		return get_slot_description()
	
	var tooltip = item_data.get("name", "Item Desconhecido")
	tooltip += "\n[" + item_data.get("rarity", "common").capitalize() + "]"
	
	if item_data.has("stats"):
		tooltip += "\n"
		var stats = item_data.stats
		for stat in stats:
			tooltip += "\n+" + str(stats[stat]) + " " + stat.capitalize()
	
	if item_data.has("description"):
		tooltip += "\n\n" + item_data.description
	
	return tooltip

func get_slot_description() -> String:
	"""Retorna descrição do slot vazio"""
	match slot_type:
		"weapon": return "Slot de Arma\nEquipe espadas, machados, cajados..."
		"helmet": return "Slot de Capacete\nEquipe proteção para cabeça"
		"chest": return "Slot de Peitoral\nEquipe armaduras de torso"
		"legs": return "Slot de Pernas\nEquipe proteção para pernas"
		"boots": return "Slot de Botas\nEquipe calçados"
		"cloak": return "Slot de Capa\nEquipe capas e mantos"
		"offhand": return "Slot Auxiliar\nEquipe escudos, tomos, aljavas"
		"accessory1", "accessory2": return "Slot de Acessório\nEquipe anéis, amuletos, adornos"
		"special": return "Slot Especial\nEquipe itens únicos"
		_: return "Slot de Equipamento"

func highlight_as_compatible():
	"""Destaca slot como compatível para drag"""
	background.color = UIThemeManager.Colors.SUCCESS_GREEN * 0.3

func highlight_as_incompatible():
	"""Destaca slot como incompatível para drag"""
	background.color = UIThemeManager.Colors.ERROR_RED * 0.3

func clear_highlight():
	"""Remove destaque"""
	background.color = UIThemeManager.Colors.PRIMARY_DARK

func get_item_level_requirement() -> int:
	"""Retorna nível necessário do item equipado"""
	return item_data.get("level_requirement", 1)

func get_item_stats() -> Dictionary:
	"""Retorna stats do item equipado"""
	return item_data.get("stats", {})

func is_enchanted() -> bool:
	"""Verifica se item está encantado"""
	return item_data.get("enchanted", false) or item_data.get("enchantments", []).size() > 0