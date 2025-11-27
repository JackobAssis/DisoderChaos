class_name AdvancedInventoryUI
extends Control

## Sistema avançado de inventário com grid responsivo e drag & drop

@onready var grid_container: GridContainer = $Background/MainContainer/InventoryGrid
@onready var filter_container: HBoxContainer = $Background/MainContainer/HeaderContainer/FilterContainer
@onready var sort_container: HBoxContainer = $Background/MainContainer/HeaderContainer/SortContainer
@onready var search_input: LineEdit = $Background/MainContainer/HeaderContainer/SearchInput
@onready var item_info_panel: Panel = $Background/ItemInfoPanel

# Filtros
@onready var all_filter: Button = $Background/MainContainer/HeaderContainer/FilterContainer/AllButton
@onready var weapon_filter: Button = $Background/MainContainer/HeaderContainer/FilterContainer/WeaponButton
@onready var armor_filter: Button = $Background/MainContainer/HeaderContainer/FilterContainer/ArmorButton
@onready var consumable_filter: Button = $Background/MainContainer/HeaderContainer/FilterContainer/ConsumableButton
@onready var misc_filter: Button = $Background/MainContainer/HeaderContainer/FilterContainer/MiscButton

# Ordenação
@onready var sort_name_btn: Button = $Background/MainContainer/HeaderContainer/SortContainer/NameButton
@onready var sort_type_btn: Button = $Background/MainContainer/HeaderContainer/SortContainer/TypeButton
@onready var sort_rarity_btn: Button = $Background/MainContainer/HeaderContainer/SortContainer/RarityButton
@onready var sort_value_btn: Button = $Background/MainContainer/HeaderContainer/SortContainer/ValueButton

# Info do item
@onready var item_icon: TextureRect = $Background/ItemInfoPanel/VBox/ItemIcon
@onready var item_name_label: Label = $Background/ItemInfoPanel/VBox/ItemName
@onready var item_type_label: Label = $Background/ItemInfoPanel/VBox/ItemType
@onready var item_rarity_label: Label = $Background/ItemInfoPanel/VBox/ItemRarity
@onready var item_description: RichTextLabel = $Background/ItemInfoPanel/VBox/Description
@onready var item_stats: VBoxContainer = $Background/ItemInfoPanel/VBox/StatsContainer

# Sistema de inventário
var inventory_data: InventorySystem
var slot_size: Vector2 = Vector2(64, 64)
var grid_size: Vector2i = Vector2i(10, 8)  # 10x8 grid
var inventory_slots: Array[InventorySlot] = []

# Drag & Drop
var dragging_item: InventorySlot = null
var drag_preview: Control = null

# Filtros e ordenação
var current_filter: String = "all"
var current_sort: String = "name"
var sort_ascending: bool = true
var search_text: String = ""

signal item_used(item_id: String, slot: InventorySlot)
signal item_dropped(item_id: String, slot: InventorySlot)
signal item_right_clicked(item_id: String, slot: InventorySlot)

func _ready():
	setup_ui_theme()
	setup_connections()
	setup_grid()
	setup_inventory_system()

func setup_ui_theme():
	"""Aplica tema dark fantasy"""
	# Background principal
	var bg = $Background as ColorRect
	if bg:
		bg.color = UIThemeManager.Colors.BG_POPUP
	
	# Panel de informações
	item_info_panel.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	
	# Grid container
	grid_container.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.PRIMARY_DARK))
	
	# Botões de filtro
	var filter_buttons = [all_filter, weapon_filter, armor_filter, consumable_filter, misc_filter]
	for btn in filter_buttons:
		if btn:
			btn.add_theme_stylebox_override("normal", 
				UIThemeManager.create_button_style(
					UIThemeManager.Colors.PRIMARY_DARK,
					UIThemeManager.Colors.PRIMARY_NAVY,
					UIThemeManager.Colors.CYBER_CYAN
				))
			btn.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	
	# Botões de ordenação
	var sort_buttons = [sort_name_btn, sort_type_btn, sort_rarity_btn, sort_value_btn]
	for btn in sort_buttons:
		if btn:
			btn.add_theme_stylebox_override("normal", 
				UIThemeManager.create_button_style(
					UIThemeManager.Colors.PRIMARY_DARK,
					UIThemeManager.Colors.PRIMARY_NAVY,
					UIThemeManager.Colors.TECH_ORANGE
				))
			btn.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	
	# Search input
	search_input.add_theme_stylebox_override("normal", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.PRIMARY_DARK))
	search_input.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	
	# Labels do item info
	item_name_label.add_theme_color_override("font_color", UIThemeManager.Colors.ACCENT_GOLD)
	item_type_label.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
	item_rarity_label.add_theme_color_override("font_color", UIThemeManager.Colors.TECH_ORANGE)

func setup_connections():
	"""Conecta todos os sinais"""
	# Filtros
	all_filter.pressed.connect(func(): apply_filter("all"))
	weapon_filter.pressed.connect(func(): apply_filter("weapon"))
	armor_filter.pressed.connect(func(): apply_filter("armor"))
	consumable_filter.pressed.connect(func(): apply_filter("consumable"))
	misc_filter.pressed.connect(func(): apply_filter("misc"))
	
	# Ordenação
	sort_name_btn.pressed.connect(func(): apply_sort("name"))
	sort_type_btn.pressed.connect(func(): apply_sort("type"))
	sort_rarity_btn.pressed.connect(func(): apply_sort("rarity"))
	sort_value_btn.pressed.connect(func(): apply_sort("value"))
	
	# Search
	search_input.text_changed.connect(_on_search_changed)
	
	# Sistema de inventário
	if EventBus:
		EventBus.inventory_item_added.connect(_on_inventory_item_added)
		EventBus.inventory_item_removed.connect(_on_inventory_item_removed)
		EventBus.inventory_updated.connect(_on_inventory_updated)

func setup_grid():
	"""Configura grid de slots"""
	grid_container.columns = grid_size.x
	
	# Cria todos os slots
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var slot = create_inventory_slot(Vector2i(x, y))
			inventory_slots.append(slot)
			grid_container.add_child(slot)

func create_inventory_slot(position: Vector2i) -> InventorySlot:
	"""Cria um slot de inventário"""
	var slot = InventorySlot.new()
	slot.setup(position, slot_size)
	slot.custom_minimum_size = slot_size
	
	# Conecta sinais
	slot.item_clicked.connect(_on_slot_clicked)
	slot.item_right_clicked.connect(_on_slot_right_clicked)
	slot.drag_started.connect(_on_drag_started)
	slot.drop_attempted.connect(_on_drop_attempted)
	slot.item_hovered.connect(_on_item_hovered)
	slot.item_unhovered.connect(_on_item_unhovered)
	
	return slot

func setup_inventory_system():
	"""Conecta com o sistema de inventário"""
	inventory_data = InventorySystem.new()
	inventory_data.setup(grid_size.x * grid_size.y)
	refresh_inventory()

# === FILTROS E ORDENAÇÃO ===
func apply_filter(filter_type: String):
	"""Aplica filtro aos itens"""
	current_filter = filter_type
	
	# Atualiza visual dos botões
	var filter_buttons = [all_filter, weapon_filter, armor_filter, consumable_filter, misc_filter]
	for btn in filter_buttons:
		btn.modulate = Color.WHITE
	
	match filter_type:
		"all": all_filter.modulate = UIThemeManager.Colors.CYBER_CYAN
		"weapon": weapon_filter.modulate = UIThemeManager.Colors.CYBER_CYAN
		"armor": armor_filter.modulate = UIThemeManager.Colors.CYBER_CYAN
		"consumable": consumable_filter.modulate = UIThemeManager.Colors.CYBER_CYAN
		"misc": misc_filter.modulate = UIThemeManager.Colors.CYBER_CYAN
	
	refresh_inventory()

func apply_sort(sort_type: String):
	"""Aplica ordenação aos itens"""
	if current_sort == sort_type:
		sort_ascending = !sort_ascending
	else:
		current_sort = sort_type
		sort_ascending = true
	
	# Atualiza visual dos botões
	var sort_buttons = [sort_name_btn, sort_type_btn, sort_rarity_btn, sort_value_btn]
	for btn in sort_buttons:
		btn.text = btn.text.replace(" ↑", "").replace(" ↓", "")
	
	var active_button: Button
	match sort_type:
		"name": active_button = sort_name_btn
		"type": active_button = sort_type_btn
		"rarity": active_button = sort_rarity_btn
		"value": active_button = sort_value_btn
	
	if active_button:
		active_button.text += " ↑" if sort_ascending else " ↓"
	
	refresh_inventory()

func _on_search_changed(new_text: String):
	"""Atualiza filtro de busca"""
	search_text = new_text.to_lower()
	refresh_inventory()

# === DRAG & DROP ===
func _on_drag_started(slot: InventorySlot):
	"""Inicia drag de um item"""
	if not slot.has_item():
		return
	
	dragging_item = slot
	create_drag_preview(slot)
	
	# Destaca slots válidos
	highlight_valid_drop_zones(slot.item_data)

func create_drag_preview(slot: InventorySlot):
	"""Cria preview visual do drag"""
	drag_preview = Control.new()
	drag_preview.z_index = 1000
	
	# Ícone do item
	var icon = TextureRect.new()
	icon.texture = slot.item_icon.texture
	icon.size = slot_size * 0.8  # Ligeiramente menor
	icon.modulate = Color(1, 1, 1, 0.8)  # Translúcido
	drag_preview.add_child(icon)
	
	get_tree().current_scene.add_child(drag_preview)

func _on_drop_attempted(from_slot: InventorySlot, to_slot: InventorySlot):
	"""Tenta fazer drop de um item"""
	if not dragging_item or not to_slot:
		return
	
	var success = inventory_data.move_item(from_slot.position, to_slot.position)
	
	if success:
		# Move item visualmente
		to_slot.set_item(from_slot.item_data, from_slot.item_icon.texture)
		from_slot.clear_item()
		
		# Atualiza UI
		refresh_inventory()
	
	cleanup_drag()

func cleanup_drag():
	"""Limpa estado de drag"""
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_item = null
	clear_drop_zone_highlights()

func highlight_valid_drop_zones(item_data: Dictionary):
	"""Destaca zonas válidas para drop"""
	for slot in inventory_slots:
		if can_drop_item_in_slot(item_data, slot):
			slot.modulate = UIThemeManager.Colors.SUCCESS_GREEN * 1.2
		else:
			slot.modulate = Color(0.5, 0.5, 0.5, 0.5)

func clear_drop_zone_highlights():
	"""Remove destaque das zonas de drop"""
	for slot in inventory_slots:
		slot.modulate = Color.WHITE

func can_drop_item_in_slot(item_data: Dictionary, slot: InventorySlot) -> bool:
	"""Verifica se item pode ser dropado no slot"""
	return not slot.has_item() or slot.can_stack_with(item_data)

# === MOUSE TRACKING ===
func _input(event):
	"""Gerencia drag preview seguindo mouse"""
	if drag_preview and event is InputEventMouseMotion:
		drag_preview.global_position = event.global_position - slot_size * 0.4

# === SLOT EVENTS ===
func _on_slot_clicked(slot: InventorySlot):
	"""Click normal em slot"""
	if slot.has_item():
		show_item_info(slot.item_data)

func _on_slot_right_clicked(slot: InventorySlot):
	"""Right click em slot"""
	if slot.has_item():
		item_right_clicked.emit(slot.item_data.id, slot)
		show_context_menu(slot)

func _on_item_hovered(slot: InventorySlot):
	"""Mouse over item"""
	if slot.has_item():
		show_item_tooltip(slot.item_data, slot.global_position)

func _on_item_unhovered(slot: InventorySlot):
	"""Mouse deixa item"""
	hide_item_tooltip()

# === ITEM INFO ===
func show_item_info(item_data: Dictionary):
	"""Mostra informações detalhadas do item"""
	if not item_data:
		return
	
	# Ícone
	if item_data.has("icon"):
		item_icon.texture = load(item_data.icon) if item_data.icon is String else item_data.icon
	
	# Nome com cor baseada na raridade
	item_name_label.text = item_data.get("name", "Item Desconhecido")
	var rarity_color = get_rarity_color(item_data.get("rarity", "common"))
	item_name_label.add_theme_color_override("font_color", rarity_color)
	
	# Tipo
	item_type_label.text = item_data.get("type", "Diversos")
	
	# Raridade
	var rarity = item_data.get("rarity", "common")
	item_rarity_label.text = rarity.capitalize()
	item_rarity_label.add_theme_color_override("font_color", rarity_color)
	
	# Descrição
	item_description.text = item_data.get("description", "Nenhuma descrição disponível.")
	
	# Stats
	update_item_stats(item_data)
	
	# Mostra panel
	item_info_panel.visible = true

func update_item_stats(item_data: Dictionary):
	"""Atualiza stats do item"""
	# Limpa stats antigas
	for child in item_stats.get_children():
		child.queue_free()
	
	var stats = item_data.get("stats", {})
	for stat_name in stats:
		var stat_value = stats[stat_name]
		
		var stat_container = HBoxContainer.new()
		
		var stat_label = Label.new()
		stat_label.text = stat_name.capitalize() + ":"
		stat_label.custom_minimum_size.x = 100
		stat_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
		stat_container.add_child(stat_label)
		
		var value_label = Label.new()
		value_label.text = str(stat_value)
		var color = UIThemeManager.Colors.SUCCESS_GREEN if stat_value > 0 else UIThemeManager.Colors.TEXT_PRIMARY
		value_label.add_theme_color_override("font_color", color)
		stat_container.add_child(value_label)
		
		item_stats.add_child(stat_container)

func get_rarity_color(rarity: String) -> Color:
	"""Retorna cor baseada na raridade"""
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)  # Dourado
		"epic": return Color(0.6, 0.3, 0.9)       # Roxo
		"rare": return Color(0.0, 0.5, 1.0)       # Azul
		"uncommon": return Color(0.0, 1.0, 0.0)   # Verde
		_: return UIThemeManager.Colors.TEXT_PRIMARY  # Comum = branco

func show_context_menu(slot: InventorySlot):
	"""Mostra menu de contexto do item"""
	# Implementar menu de contexto (usar, dropar, etc.)
	pass

# === TOOLTIP ===
var tooltip_popup: Control

func show_item_tooltip(item_data: Dictionary, position: Vector2):
	"""Mostra tooltip rápido do item"""
	hide_item_tooltip()
	
	tooltip_popup = Control.new()
	tooltip_popup.z_index = 999
	
	var bg = ColorRect.new()
	bg.color = UIThemeManager.Colors.BG_POPUP
	tooltip_popup.add_child(bg)
	
	var label = Label.new()
	label.text = item_data.get("name", "Item")
	label.add_theme_color_override("font_color", get_rarity_color(item_data.get("rarity", "common")))
	label.position = Vector2(8, 8)
	tooltip_popup.add_child(label)
	
	tooltip_popup.size = label.size + Vector2(16, 16)
	tooltip_popup.global_position = position + Vector2(slot_size.x + 10, 0)
	
	get_tree().current_scene.add_child(tooltip_popup)

func hide_item_tooltip():
	"""Esconde tooltip"""
	if tooltip_popup:
		tooltip_popup.queue_free()
		tooltip_popup = null

# === INVENTORY UPDATES ===
func _on_inventory_item_added(item_data: Dictionary, position: Vector2i):
	"""Item adicionado ao inventário"""
	refresh_slot(position)

func _on_inventory_item_removed(position: Vector2i):
	"""Item removido do inventário"""
	refresh_slot(position)

func _on_inventory_updated():
	"""Inventário foi atualizado"""
	refresh_inventory()

func refresh_inventory():
	"""Atualiza toda a visualização do inventário"""
	var filtered_items = get_filtered_items()
	var sorted_items = sort_items(filtered_items)
	
	# Limpa todos os slots
	for slot in inventory_slots:
		slot.clear_item()
	
	# Reposiciona itens filtrados e ordenados
	for i in range(min(sorted_items.size(), inventory_slots.size())):
		var item = sorted_items[i]
		var slot = inventory_slots[i]
		
		if item.has("icon"):
			var texture = load(item.icon) if item.icon is String else item.icon
			slot.set_item(item, texture)

func refresh_slot(position: Vector2i):
	"""Atualiza um slot específico"""
	var slot_index = position.y * grid_size.x + position.x
	if slot_index >= 0 and slot_index < inventory_slots.size():
		var slot = inventory_slots[slot_index]
		var item_data = inventory_data.get_item_at(position)
		
		if item_data:
			var texture = load(item_data.icon) if item_data.has("icon") and item_data.icon is String else null
			slot.set_item(item_data, texture)
		else:
			slot.clear_item()

func get_filtered_items() -> Array[Dictionary]:
	"""Retorna itens filtrados"""
	var items = inventory_data.get_all_items()
	var filtered: Array[Dictionary] = []
	
	for item in items:
		# Filtro por tipo
		if current_filter != "all" and item.get("type", "") != current_filter:
			continue
		
		# Filtro por busca
		if search_text != "" and not item.get("name", "").to_lower().contains(search_text):
			continue
		
		filtered.append(item)
	
	return filtered

func sort_items(items: Array[Dictionary]) -> Array[Dictionary]:
	"""Ordena itens conforme critério atual"""
	var sorted = items.duplicate()
	
	sorted.sort_custom(func(a, b):
		var value_a = get_sort_value(a)
		var value_b = get_sort_value(b)
		
		if sort_ascending:
			return value_a < value_b
		else:
			return value_a > value_b
	)
	
	return sorted

func get_sort_value(item: Dictionary):
	"""Retorna valor para ordenação"""
	match current_sort:
		"name": return item.get("name", "")
		"type": return item.get("type", "")
		"rarity": return get_rarity_order(item.get("rarity", "common"))
		"value": return item.get("value", 0)
		_: return item.get("name", "")

func get_rarity_order(rarity: String) -> int:
	"""Retorna ordem numérica da raridade"""
	match rarity:
		"legendary": return 5
		"epic": return 4
		"rare": return 3
		"uncommon": return 2
		"common": return 1
		_: return 0

# === PUBLIC METHODS ===
func add_item(item_data: Dictionary) -> bool:
	"""Adiciona item ao inventário"""
	return inventory_data.add_item(item_data)

func remove_item(item_id: String, quantity: int = 1) -> bool:
	"""Remove item do inventário"""
	return inventory_data.remove_item(item_id, quantity)

func has_item(item_id: String) -> bool:
	"""Verifica se tem item"""
	return inventory_data.has_item(item_id)

func get_item_count(item_id: String) -> int:
	"""Retorna quantidade de um item"""
	return inventory_data.get_item_count(item_id)