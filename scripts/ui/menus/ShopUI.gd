extends Control

class_name ShopUI

# Main panels
@onready var main_container: HSplitContainer
@onready var shop_panel: Panel
@onready var player_panel: Panel

# Shop display
var shop_header: VBoxContainer
var shop_name_label: Label
var shop_description_label: Label
var shop_categories: TabContainer
var shop_items_container: VBoxContainer
var shop_services_container: VBoxContainer

# Player display
var player_inventory_panel: Panel
var player_gold_label: Label
var player_items_grid: GridContainer
var player_slots: Array[Control] = []

# Transaction area
var transaction_panel: Panel
var selected_item_info: VBoxContainer
var quantity_selector: SpinBox
var buy_button: Button
var sell_button: Button
var total_price_label: Label

# Buyback system
var buyback_panel: Panel
var buyback_items_container: VBoxContainer

# Current state
var current_shop_data: Dictionary = {}
var current_shop_inventory: Array[Dictionary] = []
var selected_shop_item: Dictionary = {}
var selected_player_item: Dictionary = {}
var current_category: String = ""

# Style
var bg_color: Color = Color(0.1, 0.1, 0.15, 0.9)
var darker_bg: Color = Color(0.05, 0.05, 0.1, 1.0)
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var gold_color: Color = Color(1.0, 0.84, 0.0, 1.0)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var ui_manager: UIManager
var inventory_system: InventorySystem
var economy_system: EconomySystem

func _ready():
	setup_shop_ui()
	setup_connections()
	visible = false
	print("[ShopUI] Interface de Loja inicializada")

func setup_shop_ui():
# Setup shop UI layout
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()
	
	create_main_layout()
	create_shop_panel()
	create_player_panel()
	create_transaction_area()
	create_buyback_panel()

func create_main_layout():
# Create main layout structure
	main_container = HSplitContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.split_offset = 600
	add_child(main_container)

func create_shop_panel():
# Create shop display panel
	shop_panel = Panel.new()
	shop_panel.name = "ShopPanel"
	
	# Apply styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_color = gold_color
	panel_style.border_width_left = 2
	panel_style.border_width_right = 1
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	shop_panel.add_theme_stylebox_override("panel", panel_style)
	main_container.add_child(shop_panel)
	
	var shop_layout = VBoxContainer.new()
	shop_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_layout.add_theme_constant_override("separation", 10)
	shop_panel.add_child(shop_layout)
	
	# Shop header
	create_shop_header(shop_layout)
	
	# Shop categories
	create_shop_categories(shop_layout)

func create_shop_header(parent: Control):
# Create shop header with name and description
	shop_header = VBoxContainer.new()
	shop_header.name = "ShopHeader"
	shop_header.custom_minimum_size = Vector2(0, 80)
	parent.add_child(shop_header)
	
	shop_name_label = Label.new()
	shop_name_label.text = "Shop Name"
	shop_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_name_label.add_theme_color_override("font_color", gold_color)
	shop_name_label.add_theme_font_size_override("font_size", 24)
	shop_header.add_child(shop_name_label)
	
	shop_description_label = Label.new()
	shop_description_label.text = "Shop description"
	shop_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_description_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	shop_description_label.add_theme_font_size_override("font_size", 14)
	shop_header.add_child(shop_description_label)

func create_shop_categories(parent: Control):
# Create shop categories tabs
	shop_categories = TabContainer.new()
	shop_categories.name = "ShopCategories"
	shop_categories.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_categories.tab_changed.connect(_on_category_changed)
	parent.add_child(shop_categories)
	
	# Items tab
	var items_scroll = ScrollContainer.new()
	items_scroll.name = "Items"
	items_scroll.scroll_horizontal_enabled = false
	shop_categories.add_child(items_scroll)
	
	shop_items_container = VBoxContainer.new()
	shop_items_container.add_theme_constant_override("separation", 5)
	items_scroll.add_child(shop_items_container)
	
	# Services tab (for blacksmith, etc.)
	var services_scroll = ScrollContainer.new()
	services_scroll.name = "Services"
	services_scroll.scroll_horizontal_enabled = false
	shop_categories.add_child(services_scroll)
	
	shop_services_container = VBoxContainer.new()
	shop_services_container.add_theme_constant_override("separation", 5)
	services_scroll.add_child(shop_services_container)

func create_player_panel():
# Create player inventory and info panel
	player_panel = Panel.new()
	player_panel.name = "PlayerPanel"
	
	# Apply styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 1
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	player_panel.add_theme_stylebox_override("panel", panel_style)
	main_container.add_child(player_panel)
	
	var player_layout = VBoxContainer.new()
	player_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_layout.add_theme_constant_override("separation", 10)
	player_panel.add_child(player_layout)
	
	# Player info header
	create_player_header(player_layout)
	
	# Transaction area
	create_transaction_area_in_player_panel(player_layout)
	
	# Player inventory
	create_player_inventory(player_layout)

func create_player_header(parent: Control):
# Create player header with gold display
	var header_container = HBoxContainer.new()
	header_container.name = "PlayerHeader"
	header_container.custom_minimum_size = Vector2(0, 40)
	header_container.add_theme_constant_override("separation", 10)
	parent.add_child(header_container)
	
	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_color_override("font_color", neon_green)
	title.add_theme_font_size_override("font_size", 16)
	header_container.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(spacer)
	
	player_gold_label = Label.new()
	player_gold_label.text = "Gold: 0"
	player_gold_label.add_theme_color_override("font_color", gold_color)
	player_gold_label.add_theme_font_size_override("font_size", 16)
	header_container.add_child(player_gold_label)

func create_transaction_area_in_player_panel(parent: Control):
# Create transaction area within player panel
	transaction_panel = Panel.new()
	transaction_panel.name = "TransactionPanel"
	transaction_panel.custom_minimum_size = Vector2(0, 150)
	
	var trans_style = StyleBoxFlat.new()
	trans_style.bg_color = bg_color
	trans_style.border_color = gold_color
	trans_style.border_width_left = 2
	trans_style.border_width_right = 2
	trans_style.border_width_top = 2
	trans_style.border_width_bottom = 2
	transaction_panel.add_theme_stylebox_override("panel", trans_style)
	parent.add_child(transaction_panel)
	
	var trans_layout = VBoxContainer.new()
	trans_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trans_layout.add_theme_constant_override("separation", 5)
	transaction_panel.add_child(trans_layout)
	
	# Selected item info
	selected_item_info = VBoxContainer.new()
	selected_item_info.add_theme_constant_override("separation", 3)
	trans_layout.add_child(selected_item_info)
	
	# Quantity and controls
	var controls_container = HBoxContainer.new()
	controls_container.add_theme_constant_override("separation", 10)
	trans_layout.add_child(controls_container)
	
	# Quantity selector
	var qty_label = Label.new()
	qty_label.text = "Qty:"
	qty_label.add_theme_color_override("font_color", Color.WHITE)
	controls_container.add_child(qty_label)
	
	quantity_selector = SpinBox.new()
	quantity_selector.min_value = 1
	quantity_selector.max_value = 99
	quantity_selector.value = 1
	quantity_selector.custom_minimum_size = Vector2(80, 30)
	quantity_selector.value_changed.connect(_on_quantity_changed)
	apply_spinbox_style(quantity_selector)
	controls_container.add_child(quantity_selector)
	
	# Total price
	total_price_label = Label.new()
	total_price_label.text = "Total: 0 gold"
	total_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_price_label.add_theme_color_override("font_color", gold_color)
	controls_container.add_child(total_price_label)
	
	# Transaction buttons
	var buttons_container = HBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 10)
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	trans_layout.add_child(buttons_container)
	
	buy_button = Button.new()
	buy_button.text = "BUY"
	buy_button.custom_minimum_size = Vector2(80, 35)
	buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_button_pressed)
	apply_button_style(buy_button, gold_color)
	buttons_container.add_child(buy_button)
	
	sell_button = Button.new()
	sell_button.text = "SELL"
	sell_button.custom_minimum_size = Vector2(80, 35)
	sell_button.disabled = true
	sell_button.pressed.connect(_on_sell_button_pressed)
	apply_button_style(sell_button, neon_green)
	buttons_container.add_child(sell_button)

func create_transaction_area():
# Create main transaction area - using the one in player panel
	pass

func create_player_inventory(parent: Control):
# Create player inventory display
	player_inventory_panel = Panel.new()
	player_inventory_panel.name = "PlayerInventory"
	player_inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var inv_style = StyleBoxFlat.new()
	inv_style.bg_color = bg_color
	player_inventory_panel.add_theme_stylebox_override("panel", inv_style)
	parent.add_child(player_inventory_panel)
	
	var inv_scroll = ScrollContainer.new()
	inv_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv_scroll.scroll_horizontal_enabled = false
	player_inventory_panel.add_child(inv_scroll)
	
	player_items_grid = GridContainer.new()
	player_items_grid.columns = 6
	player_items_grid.add_theme_constant_override("h_separation", 5)
	player_items_grid.add_theme_constant_override("v_separation", 5)
	inv_scroll.add_child(player_items_grid)

func create_buyback_panel():
# Create buyback panel for recently sold items
	buyback_panel = Panel.new()
	buyback_panel.name = "BuybackPanel"
	buyback_panel.anchor_left = 0.0
	buyback_panel.anchor_right = 1.0
	buyback_panel.anchor_top = 0.85
	buyback_panel.anchor_bottom = 1.0
	buyback_panel.visible = false
	
	var buyback_style = StyleBoxFlat.new()
	buyback_style.bg_color = darker_bg
	buyback_style.border_color = Color.ORANGE
	buyback_style.border_width_left = 2
	buyback_style.border_width_right = 2
	buyback_style.border_width_top = 2
	buyback_style.border_width_bottom = 2
	buyback_panel.add_theme_stylebox_override("panel", buyback_style)
	add_child(buyback_panel)
	
	var buyback_layout = VBoxContainer.new()
	buyback_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buyback_panel.add_child(buyback_layout)
	
	var buyback_header = Label.new()
	buyback_header.text = "BUYBACK"
	buyback_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buyback_header.add_theme_color_override("font_color", Color.ORANGE)
	buyback_layout.add_child(buyback_header)
	
	var buyback_scroll = ScrollContainer.new()
	buyback_scroll.scroll_horizontal_enabled = false
	buyback_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buyback_layout.add_child(buyback_scroll)
	
	buyback_items_container = HBoxContainer.new()
	buyback_items_container.add_theme_constant_override("separation", 5)
	buyback_scroll.add_child(buyback_items_container)

# Shop management functions
func open_shop(shop_id: String, npc_data: Dictionary = {}):
# Open shop with specified ID
	var shop_config = load_shop_config(shop_id)
	if shop_config.is_empty():
		print("[ShopUI] Failed to load shop config: ", shop_id)
		return
	
	current_shop_data = shop_config
	visible = true
	
	setup_shop_display()
	generate_shop_inventory()
	update_player_display()
	
	print("[ShopUI] Opened shop: ", shop_id)

func load_shop_config(shop_id: String) -> Dictionary:
# Load shop configuration
	var shop_data = DataLoader.load_json_data("res://data/economy/shop_system.json")
	if not shop_data or not shop_data.has("shop_types"):
		return {}
	
	var shop_types = shop_data.shop_types
	if shop_types.has(shop_id):
		return shop_types[shop_id]
	
	return {}

func setup_shop_display():
# Setup shop information display
	shop_name_label.text = current_shop_data.get("name", "Unknown Shop")
	shop_description_label.text = current_shop_data.get("description", "No description")
	
	# Setup tabs based on categories
	var categories = current_shop_data.get("categories", ["items"])
	
	# Clear existing tabs except first two (items and services)
	while shop_categories.get_tab_count() > 2:
		shop_categories.remove_child(shop_categories.get_child(2))
	
	# Add category-specific tabs
	for category in categories:
		if category not in ["items", "services"]:
			var tab_scroll = ScrollContainer.new()
			tab_scroll.name = category.capitalize()
			tab_scroll.scroll_horizontal_enabled = false
			shop_categories.add_child(tab_scroll)
			
			var tab_container = VBoxContainer.new()
			tab_container.add_theme_constant_override("separation", 5)
			tab_scroll.add_child(tab_container)

func generate_shop_inventory():
# Generate shop inventory based on configuration
	current_shop_inventory.clear()
	
	var shop_data = DataLoader.load_json_data("res://data/economy/shop_system.json")
	if not shop_data:
		return
	
	var items_for_sale = shop_data.get("items_for_sale", {})
	var categories = current_shop_data.get("categories", [])
	
	for category in categories:
		if items_for_sale.has(category):
			var category_items = items_for_sale[category]
			for item_info in category_items:
				if should_stock_item(item_info):
					var stock_item = generate_stock_item(item_info)
					current_shop_inventory.append(stock_item)
	
	populate_shop_items()

func should_stock_item(item_info: Dictionary) -> bool:
# Check if item should be in stock
	var availability = item_info.get("availability", 1.0)
	return randf() < availability

func generate_stock_item(item_info: Dictionary) -> Dictionary:
# Generate stock item with quantity and price
	var stock_range = item_info.get("stock", {"min": 1, "max": 1})
	var quantity = randi_range(stock_range.min, stock_range.max)
	
	var base_price = item_info.get("base_price", 10)
	var markup = current_shop_data.get("markup", 1.0)
	var final_price = int(base_price * markup)
	
	return {
		"item_id": item_info.get("item_id", ""),
		"quantity": quantity,
		"price": final_price,
		"base_price": base_price
	}

func populate_shop_items():
# Populate shop items in UI
	clear_shop_items()
	
	for stock_item in current_shop_inventory:
		var item_display = create_shop_item_display(stock_item)
		shop_items_container.add_child(item_display)

func clear_shop_items():
# Clear shop items display
	for child in shop_items_container.get_children():
		child.queue_free()

func create_shop_item_display(stock_item: Dictionary) -> Control:
# Create shop item display
	var item_container = HBoxContainer.new()
	item_container.custom_minimum_size = Vector2(0, 50)
	item_container.add_theme_constant_override("separation", 10)
	
	# Item icon (placeholder)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_container.add_child(icon)
	
	# Item info
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_child(info_container)
	
	var name_label = Label.new()
	var item_id = stock_item.get("item_id", "")
	name_label.text = item_id.replace("_", " ").capitalize()
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_container.add_child(name_label)
	
	var stock_label = Label.new()
	stock_label.text = "Stock: " + str(stock_item.get("quantity", 0))
	stock_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	stock_label.add_theme_font_size_override("font_size", 12)
	info_container.add_child(stock_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = str(stock_item.get("price", 0)) + "g"
	price_label.add_theme_color_override("font_color", gold_color)
	price_label.add_theme_font_size_override("font_size", 14)
	item_container.add_child(price_label)
	
	# Make clickable
	var button = Button.new()
	button.text = ""
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_shop_item_selected.bind(stock_item))
	item_container.add_child(button)
	
	return item_container

func update_player_display():
# Update player inventory and gold display
	update_player_gold()
	populate_player_inventory()

func update_player_gold():
# Update player gold display
	var gold = get_player_gold()
	player_gold_label.text = "Gold: " + str(gold)

func get_player_gold() -> int:
# Get player's current gold
	# TODO: Integrate with player data system
	return 1000  # Placeholder

func populate_player_inventory():
# Populate player inventory display
	clear_player_inventory()
	
	# Get player items
	var player_items = get_player_items()
	for item_data in player_items:
		var item_slot = create_player_item_slot(item_data)
		player_items_grid.add_child(item_slot)
		player_slots.append(item_slot)

func clear_player_inventory():
# Clear player inventory display
	for slot in player_slots:
		slot.queue_free()
	player_slots.clear()

func get_player_items() -> Array:
# Get player's inventory items
	# TODO: Integrate with inventory system
	return []  # Placeholder

func create_player_item_slot(item_data: Dictionary) -> Control:
# Create player item slot
	var slot = Button.new()
	slot.custom_minimum_size = Vector2(50, 50)
	slot.text = ""
	slot.pressed.connect(_on_player_item_selected.bind(item_data))
	
	# Apply slot styling
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = bg_color
	slot_style.border_color = neon_green
	slot_style.border_width_left = 1
	slot_style.border_width_right = 1
	slot_style.border_width_top = 1
	slot_style.border_width_bottom = 1
	slot.add_theme_stylebox_override("normal", slot_style)
	
	return slot

# Event handlers
func _on_category_changed(tab: int):
# Handle category tab change
	if tab >= 0 and tab < shop_categories.get_tab_count():
		var tab_name = shop_categories.get_tab_title(tab)
		current_category = tab_name.to_lower()
		
		if current_category == "services":
			populate_shop_services()

func populate_shop_services():
# Populate shop services
	clear_shop_services()
	
	var services = current_shop_data.get("services", [])
	for service_id in services:
		var service_display = create_service_display(service_id)
		shop_services_container.add_child(service_display)

func clear_shop_services():
# Clear shop services display
	for child in shop_services_container.get_children():
		child.queue_free()

func create_service_display(service_id: String) -> Control:
# Create service display
	var service_container = VBoxContainer.new()
	service_container.add_theme_constant_override("separation", 5)
	
	var name_label = Label.new()
	name_label.text = service_id.replace("_", " ").capitalize()
	name_label.add_theme_color_override("font_color", Color.WHITE)
	service_container.add_child(name_label)
	
	var service_button = Button.new()
	service_button.text = "Use Service"
	service_button.pressed.connect(_on_service_selected.bind(service_id))
	apply_button_style(service_button, gold_color)
	service_container.add_child(service_button)
	
	return service_container

func _on_shop_item_selected(stock_item: Dictionary):
# Handle shop item selection
	selected_shop_item = stock_item
	selected_player_item.clear()
	update_transaction_display()

func _on_player_item_selected(item_data: Dictionary):
# Handle player item selection
	selected_player_item = item_data
	selected_shop_item.clear()
	update_transaction_display()

func _on_service_selected(service_id: String):
# Handle service selection
	# TODO: Implement service functionality
	print("[ShopUI] Service selected: ", service_id)

func update_transaction_display():
# Update transaction area display
	clear_transaction_info()
	
	if not selected_shop_item.is_empty():
		display_buy_transaction()
	elif not selected_player_item.is_empty():
		display_sell_transaction()

func clear_transaction_info():
# Clear transaction info display
	for child in selected_item_info.get_children():
		child.queue_free()
	
	buy_button.disabled = true
	sell_button.disabled = true
	total_price_label.text = "Total: 0 gold"

func display_buy_transaction():
# Display buy transaction info
	var item_id = selected_shop_item.get("item_id", "")
	var price = selected_shop_item.get("price", 0)
	var stock = selected_shop_item.get("quantity", 0)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item_id.replace("_", " ").capitalize()
	name_label.add_theme_color_override("font_color", Color.WHITE)
	selected_item_info.add_child(name_label)
	
	# Price per unit
	var price_label = Label.new()
	price_label.text = "Price: " + str(price) + "g each"
	price_label.add_theme_color_override("font_color", gold_color)
	selected_item_info.add_child(price_label)
	
	# Set quantity limits
	quantity_selector.max_value = min(stock, 99)
	quantity_selector.value = 1
	
	# Enable buy button if player has enough gold
	var total_cost = price * int(quantity_selector.value)
	buy_button.disabled = get_player_gold() < total_cost
	
	update_total_price()

func display_sell_transaction():
# Display sell transaction info
	var item_id = selected_player_item.get("id", "")
	var sell_price = calculate_sell_price(selected_player_item)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item_id.replace("_", " ").capitalize()
	name_label.add_theme_color_override("font_color", Color.WHITE)
	selected_item_info.add_child(name_label)
	
	# Sell price
	var price_label = Label.new()
	price_label.text = "Sell price: " + str(sell_price) + "g each"
	price_label.add_theme_color_override("font_color", neon_green)
	selected_item_info.add_child(price_label)
	
	# Set quantity limits
	var item_quantity = selected_player_item.get("quantity", 1)
	quantity_selector.max_value = item_quantity
	quantity_selector.value = 1
	
	sell_button.disabled = false
	
	update_total_price()

func calculate_sell_price(item_data: Dictionary) -> int:
# Calculate sell price for item
	var base_value = item_data.get("value", 10)
	var buyback_percentage = 0.6  # 60% of base value
	
	return max(1, int(base_value * buyback_percentage))

func _on_quantity_changed(value: float):
# Handle quantity change
	update_total_price()

func update_total_price():
# Update total price display
	var quantity = int(quantity_selector.value)
	
	if not selected_shop_item.is_empty():
		var price = selected_shop_item.get("price", 0)
		var total = price * quantity
		total_price_label.text = "Total: " + str(total) + " gold"
		buy_button.disabled = get_player_gold() < total
	elif not selected_player_item.is_empty():
		var sell_price = calculate_sell_price(selected_player_item)
		var total = sell_price * quantity
		total_price_label.text = "Total: " + str(total) + " gold"

func _on_buy_button_pressed():
# Handle buy button press
	if selected_shop_item.is_empty():
		return
	
	var item_id = selected_shop_item.get("item_id", "")
	var price = selected_shop_item.get("price", 0)
	var quantity = int(quantity_selector.value)
	var total_cost = price * quantity
	
	if get_player_gold() >= total_cost:
		execute_purchase(item_id, quantity, total_cost)

func execute_purchase(item_id: String, quantity: int, total_cost: int):
# Execute item purchase
	# TODO: Integrate with inventory and currency systems
	print("[ShopUI] Purchased: ", quantity, "x ", item_id, " for ", total_cost, " gold")
	
	# Update shop inventory
	update_shop_stock(item_id, -quantity)
	
	# Update displays
	populate_shop_items()
	update_player_display()
	clear_transaction_info()
	
	event_bus.emit_signal("item_purchased", item_id, quantity, total_cost)

func _on_sell_button_pressed():
# Handle sell button press
	if selected_player_item.is_empty():
		return
	
	var item_id = selected_player_item.get("id", "")
	var quantity = int(quantity_selector.value)
	var sell_price = calculate_sell_price(selected_player_item)
	var total_value = sell_price * quantity
	
	execute_sale(item_id, quantity, total_value)

func execute_sale(item_id: String, quantity: int, total_value: int):
# Execute item sale
	# TODO: Integrate with inventory and currency systems
	print("[ShopUI] Sold: ", quantity, "x ", item_id, " for ", total_value, " gold")
	
	# Add to buyback
	add_to_buyback(item_id, quantity, total_value)
	
	# Update displays
	update_player_display()
	clear_transaction_info()
	
	event_bus.emit_signal("item_sold", item_id, quantity, total_value)

func update_shop_stock(item_id: String, quantity_change: int):
# Update shop stock for item
	for i in range(current_shop_inventory.size()):
		var stock_item = current_shop_inventory[i]
		if stock_item.get("item_id", "") == item_id:
			stock_item.quantity += quantity_change
			if stock_item.quantity <= 0:
				current_shop_inventory.remove_at(i)
			break

func add_to_buyback(item_id: String, quantity: int, sell_value: int):
# Add item to buyback system
	# TODO: Implement buyback system
	print("[ShopUI] Added to buyback: ", item_id)

func close_shop():
# Close shop interface
	visible = false
	current_shop_data.clear()
	current_shop_inventory.clear()
	selected_shop_item.clear()
	selected_player_item.clear()
	
	clear_shop_items()
	clear_transaction_info()

# Styling functions
func apply_button_style(button: Button, color: Color = neon_green):
# Apply styled button theme
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = color
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(color.r, color.g, color.b, 0.2)
	button.add_theme_stylebox_override("hover", hover_style)
	
	button.add_theme_color_override("font_color", Color.WHITE)

func apply_spinbox_style(spinbox: SpinBox):
# Apply spinbox styling
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = neon_green
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	spinbox.add_theme_stylebox_override("normal", style)

# Setup and connections
func setup_connections():
# Setup signal connections
	if event_bus:
		event_bus.connect("shop_opened", open_shop)
		event_bus.connect("shop_closed", close_shop)

# Input handling
func _input(event):
# Handle input events
	if visible and event.is_action_pressed("ui_cancel"):
		close_shop()
