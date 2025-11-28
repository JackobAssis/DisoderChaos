extends Control

class_name InventoryUI

# Main panels
@onready var main_container: HSplitContainer
@onready var inventory_panel: Panel
@onready var details_panel: Panel

# Inventory grid
var inventory_grid: GridContainer
var inventory_slots: Array[InventorySlot] = []
var grid_size: Vector2i = Vector2i(8, 6)  # 8x6 grid

# Details section
var item_preview: TextureRect
var item_name_label: Label
var item_description_label: RichTextLabel
var item_stats_container: VBoxContainer
var action_buttons_container: HBoxContainer

# Item management
var selected_slot: InventorySlot
var dragging_slot: InventorySlot
var drag_preview: Control

# Categories
var category_tabs: TabContainer
var equipment_tab: Control
var consumables_tab: Control
var materials_tab: Control
var misc_tab: Control

# Filtering and sorting
var search_box: LineEdit
var sort_button: OptionButton
var filter_rarity: OptionButton

# Style
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var dark_bg: Color = Color(0.0, 0.1, 0.05, 0.95)
var darker_bg: Color = Color(0.0, 0.05, 0.025, 0.98)
var slot_normal: Color = Color(0.1, 0.15, 0.1, 0.8)
var slot_hover: Color = Color(0.0, 1.0, 0.549, 0.3)
var slot_selected: Color = Color(0.0, 1.0, 0.549, 0.6)

# Rarity colors
var rarity_colors: Dictionary = {
	"common": Color.WHITE,
	"uncommon": Color.GREEN,
	"rare": Color.BLUE,
	"epic": Color.PURPLE,
	"legendary": Color.ORANGE,
	"mythic": Color.RED
}

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var inventory_system: InventorySystem = get_node("/root/InventorySystem")
@onready var ui_manager: UIManager

func _ready():
	setup_inventory_ui()
	setup_connections()
	print("[InventoryUI] Interface de InventÃ¡rio inicializada")

func setup_inventory_ui():
# Setup inventory UI layout
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()
	
	create_main_layout()
	create_inventory_panel()
	create_details_panel()
	create_header_controls()
	create_inventory_grid()

func create_main_layout():
# Create main layout structure
	main_container = HSplitContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.split_offset = 600
	add_child(main_container)

func create_inventory_panel():
# Create main inventory panel
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.custom_minimum_size = Vector2(600, 400)
	main_container.add_child(inventory_panel)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = dark_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	inventory_panel.add_theme_stylebox_override("panel", panel_style)

func create_details_panel():
# Create item details panel
	details_panel = Panel.new()
	details_panel.name = "DetailsPanel"
	details_panel.custom_minimum_size = Vector2(300, 400)
	main_container.add_child(details_panel)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	details_panel.add_theme_stylebox_override("panel", panel_style)
	
	setup_details_content()

func setup_details_content():
# Setup details panel content
	var details_container = VBoxContainer.new()
	details_container.name = "DetailsContainer"
	details_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_container.add_theme_constant_override("separation", 10)
	details_panel.add_child(details_container)
	
	# Title
	var title_label = Label.new()
	title_label.text = "ITEM DETAILS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", neon_green)
	title_label.add_theme_font_size_override("font_size", 18)
	details_container.add_child(title_label)
	
	# Item preview
	item_preview = TextureRect.new()
	item_preview.custom_minimum_size = Vector2(64, 64)
	item_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	details_container.add_child(item_preview)
	
	# Item name
	item_name_label = Label.new()
	item_name_label.text = ""
	item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_label.add_theme_color_override("font_color", Color.WHITE)
	item_name_label.add_theme_font_size_override("font_size", 16)
	details_container.add_child(item_name_label)
	
	# Item description
	var desc_scroll = ScrollContainer.new()
	desc_scroll.custom_minimum_size = Vector2(0, 150)
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_container.add_child(desc_scroll)
	
	item_description_label = RichTextLabel.new()
	item_description_label.fit_content = true
	item_description_label.bbcode_enabled = true
	item_description_label.add_theme_color_override("default_color", Color.LIGHT_GRAY)
	item_description_label.add_theme_font_size_override("normal_font_size", 12)
	desc_scroll.add_child(item_description_label)
	
	# Item stats
	item_stats_container = VBoxContainer.new()
	item_stats_container.name = "StatsContainer"
	item_stats_container.add_theme_constant_override("separation", 5)
	details_container.add_child(item_stats_container)
	
	# Action buttons
	action_buttons_container = HBoxContainer.new()
	action_buttons_container.name = "ActionButtons"
	action_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	action_buttons_container.add_theme_constant_override("separation", 10)
	details_container.add_child(action_buttons_container)

func create_header_controls():
# Create header controls (search, sort, filter)
	var header = HBoxContainer.new()
	header.name = "HeaderControls"
	header.custom_minimum_size = Vector2(0, 40)
	header.add_theme_constant_override("separation", 10)
	
	# Position header at top of inventory panel
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.offset_bottom = 40
	header.offset_left = 10
	header.offset_right = -10
	header.offset_top = 10
	
	inventory_panel.add_child(header)
	
	# Title
	var title_label = Label.new()
	title_label.text = "INVENTORY"
	title_label.add_theme_color_override("font_color", neon_green)
	title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(title_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Search box
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search items..."
	search_box.custom_minimum_size = Vector2(150, 30)
	search_box.text_changed.connect(_on_search_changed)
	style_line_edit(search_box)
	header.add_child(search_box)
	
	# Sort options
	sort_button = OptionButton.new()
	sort_button.custom_minimum_size = Vector2(120, 30)
	sort_button.add_item("Name A-Z")
	sort_button.add_item("Name Z-A")
	sort_button.add_item("Rarity â†‘")
	sort_button.add_item("Rarity â†“")
	sort_button.add_item("Type")
	sort_button.item_selected.connect(_on_sort_changed)
	style_option_button(sort_button)
	header.add_child(sort_button)
	
	# Rarity filter
	filter_rarity = OptionButton.new()
	filter_rarity.custom_minimum_size = Vector2(100, 30)
	filter_rarity.add_item("All Rarities")
	filter_rarity.add_item("Common")
	filter_rarity.add_item("Uncommon")
	filter_rarity.add_item("Rare")
	filter_rarity.add_item("Epic")
	filter_rarity.add_item("Legendary")
	filter_rarity.add_item("Mythic")
	filter_rarity.item_selected.connect(_on_filter_changed)
	style_option_button(filter_rarity)
	header.add_child(filter_rarity)

func style_line_edit(line_edit: LineEdit):
# Apply neon green style to line edit
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	line_edit.add_theme_stylebox_override("normal", normal_style)
	
	var focus_style = normal_style.duplicate()
	focus_style.border_color = Color.WHITE
	line_edit.add_theme_stylebox_override("focus", focus_style)
	
	line_edit.add_theme_color_override("font_color", Color.WHITE)
	line_edit.add_theme_color_override("font_placeholder_color", Color.GRAY)

func style_option_button(option_button: OptionButton):
# Apply neon green style to option button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	option_button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.border_color = Color.WHITE
	option_button.add_theme_stylebox_override("hover", hover_style)
	
	option_button.add_theme_color_override("font_color", Color.WHITE)

func create_inventory_grid():
# Create inventory grid of slots
	var scroll_container = ScrollContainer.new()
	scroll_container.name = "GridScrollContainer"
	scroll_container.anchor_top = 0.1  # Below header
	scroll_container.anchor_bottom = 1.0
	scroll_container.anchor_left = 0.0
	scroll_container.anchor_right = 1.0
	scroll_container.offset_left = 10
	scroll_container.offset_right = -10
	scroll_container.offset_bottom = -10
	inventory_panel.add_child(scroll_container)
	
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryGrid"
	inventory_grid.columns = grid_size.x
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	scroll_container.add_child(inventory_grid)
	
	create_inventory_slots()

func create_inventory_slots():
# Create individual inventory slots
	inventory_slots.clear()
	
	for i in range(grid_size.x * grid_size.y):
		var slot = InventorySlot.new()
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(64, 64)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot.drag_started.connect(_on_drag_started)
		slot.drag_ended.connect(_on_drag_ended)
		
		inventory_slots.append(slot)
		inventory_grid.add_child(slot)

func setup_connections():
# Setup event connections
	if event_bus:
		event_bus.connect("inventory_item_added", _on_item_added)
		event_bus.connect("inventory_item_removed", _on_item_removed)
		event_bus.connect("inventory_updated", refresh_inventory)

func show():
# Show inventory with animation
	super.show()
	refresh_inventory()

func refresh_inventory():
# Refresh inventory display
	if not inventory_system:
		return
	
	clear_all_slots()
	
	var items = inventory_system.get_all_items()
	for i in range(min(items.size(), inventory_slots.size())):
		var slot = inventory_slots[i]
		var item_data = items[i]
		
		if item_data:
			slot.set_item(item_data)

func clear_all_slots():
# Clear all inventory slots
	for slot in inventory_slots:
		slot.clear_item()

func update_item_details(item_data):
# Update details panel with item information
	if not item_data:
		clear_item_details()
		return
	
	# Update preview
	if item_data.has("icon"):
		item_preview.texture = item_data.icon
	
	# Update name with rarity color
	var rarity = item_data.get("rarity", "common")
	var rarity_color = rarity_colors.get(rarity, Color.WHITE)
	item_name_label.text = item_data.get("name", "Unknown Item")
	item_name_label.add_theme_color_override("font_color", rarity_color)
	
	# Update description
	var description = item_data.get("description", "No description available.")
	item_description_label.text = description
	
	# Update stats
	update_item_stats(item_data)
	
	# Update action buttons
	update_action_buttons(item_data)

func clear_item_details():
# Clear item details panel
	item_preview.texture = null
	item_name_label.text = ""
	item_description_label.text = ""
	
	# Clear stats
	for child in item_stats_container.get_children():
		child.queue_free()
	
	# Clear action buttons
	for child in action_buttons_container.get_children():
		child.queue_free()

func update_item_stats(item_data):
# Update item stats display
	# Clear existing stats
	for child in item_stats_container.get_children():
		child.queue_free()
	
	# Add stats title
	var stats_title = Label.new()
	stats_title.text = "STATS"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_color_override("font_color", neon_green)
	stats_title.add_theme_font_size_override("font_size", 14)
	item_stats_container.add_child(stats_title)
	
	# Add stats
	var stats = item_data.get("stats", {})
	for stat_name in stats:
		var stat_value = stats[stat_name]
		add_stat_line(stat_name, stat_value)
	
	# Add item type and rarity
	add_info_line("Type", item_data.get("type", "Unknown"))
	add_info_line("Rarity", item_data.get("rarity", "common").capitalize())
	add_info_line("Value", str(item_data.get("value", 0)) + "g")

func add_stat_line(stat_name: String, stat_value):
# Add a stat line to stats container
	var stat_container = HBoxContainer.new()
	item_stats_container.add_child(stat_container)
	
	var name_label = Label.new()
	name_label.text = stat_name.capitalize() + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	name_label.add_theme_font_size_override("font_size", 12)
	stat_container.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = str(stat_value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", neon_green)
	value_label.add_theme_font_size_override("font_size", 12)
	stat_container.add_child(value_label)

func add_info_line(label: String, value: String):
# Add an info line to stats container
	var info_container = HBoxContainer.new()
	item_stats_container.add_child(info_container)
	
	var label_node = Label.new()
	label_node.text = label + ":"
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_node.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	label_node.add_theme_font_size_override("font_size", 12)
	info_container.add_child(label_node)
	
	var value_node = Label.new()
	value_node.text = value
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_node.add_theme_color_override("font_color", Color.WHITE)
	value_node.add_theme_font_size_override("font_size", 12)
	info_container.add_child(value_node)

func update_action_buttons(item_data):
# Update action buttons based on item type
	# Clear existing buttons
	for child in action_buttons_container.get_children():
		child.queue_free()
	
	var item_type = item_data.get("type", "misc")
	
	# Equip/Unequip button for equipment
	if item_type in ["weapon", "armor", "accessory"]:
		var equip_btn = create_action_button("EQUIP")
		equip_btn.pressed.connect(_on_equip_item.bind(item_data))
		action_buttons_container.add_child(equip_btn)
	
	# Use button for consumables
	elif item_type == "consumable":
		var use_btn = create_action_button("USE")
		use_btn.pressed.connect(_on_use_item.bind(item_data))
		action_buttons_container.add_child(use_btn)
	
	# Drop button for all items
	var drop_btn = create_action_button("DROP")
	drop_btn.pressed.connect(_on_drop_item.bind(item_data))
	action_buttons_container.add_child(drop_btn)

func create_action_button(text: String) -> Button:
# Create styled action button
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 30)
	
	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover style
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.2)
	hover_style.border_color = Color.WHITE
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = neon_green
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Font colors
	button.add_theme_color_override("font_color", neon_green)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_font_size_override("font_size", 12)
	
	return button

# Event Handlers
func _on_slot_clicked(slot: InventorySlot):
# Handle slot click
	if selected_slot:
		selected_slot.set_selected(false)
	
	selected_slot = slot
	slot.set_selected(true)
	
	if slot.item_data:
		update_item_details(slot.item_data)
	else:
		clear_item_details()

func _on_slot_hovered(slot: InventorySlot):
# Handle slot hover
	slot.set_hovered(true)
	
	if slot.item_data:
		show_item_tooltip(slot.item_data, slot.global_position)

func _on_slot_unhovered(slot: InventorySlot):
# Handle slot unhover
	slot.set_hovered(false)
	hide_item_tooltip()

func _on_drag_started(slot: InventorySlot):
# Handle drag start
	dragging_slot = slot
	create_drag_preview(slot.item_data)

func _on_drag_ended(slot: InventorySlot, target_slot: InventorySlot):
# Handle drag end
	if dragging_slot and target_slot and dragging_slot != target_slot:
		swap_items(dragging_slot, target_slot)
	
	dragging_slot = null
	destroy_drag_preview()

func swap_items(from_slot: InventorySlot, to_slot: InventorySlot):
# Swap items between slots
	var from_item = from_slot.item_data
	var to_item = to_slot.item_data
	
	from_slot.set_item(to_item)
	to_slot.set_item(from_item)
	
	# Update inventory system
	if inventory_system:
		inventory_system.swap_items(from_slot.slot_index, to_slot.slot_index)

func create_drag_preview(item_data):
# Create drag preview
	if not item_data:
		return
	
	drag_preview = Control.new()
	drag_preview.name = "DragPreview"
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().add_child(drag_preview)
	
	var preview_texture = TextureRect.new()
	preview_texture.texture = item_data.get("icon")
	preview_texture.custom_minimum_size = Vector2(32, 32)
	preview_texture.modulate.a = 0.7
	drag_preview.add_child(preview_texture)

func destroy_drag_preview():
# Destroy drag preview
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func show_item_tooltip(item_data, position: Vector2):
# Show item tooltip
	# Create tooltip implementation
	pass

func hide_item_tooltip():
# Hide item tooltip
	# Hide tooltip implementation
	pass

# Action Handlers
func _on_equip_item(item_data):
# Equip selected item
	if inventory_system:
		inventory_system.equip_item(item_data.get("id"))

func _on_use_item(item_data):
# Use selected item
	if inventory_system:
		inventory_system.use_item(item_data.get("id"))

func _on_drop_item(item_data):
# Drop selected item
	show_drop_confirmation(item_data)

func show_drop_confirmation(item_data):
# Show drop confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Drop Item"
	dialog.dialog_text = "Drop " + item_data.get("name", "item") + "?"
	dialog.add_cancel_button("Cancel")
	dialog.confirmed.connect(_confirm_drop_item.bind(item_data))
	get_viewport().add_child(dialog)
	dialog.popup_centered()

func _confirm_drop_item(item_data):
# Confirm item drop
	if inventory_system:
		inventory_system.drop_item(item_data.get("id"))

# Filter and Sort Handlers
func _on_search_changed(search_text: String):
# Handle search text change
	filter_inventory_display()

func _on_sort_changed(index: int):
# Handle sort option change
	sort_inventory_display(index)

func _on_filter_changed(index: int):
# Handle filter change
	filter_inventory_display()

func filter_inventory_display():
# Filter inventory display based on search and filters
	var search_text = search_box.text.to_lower()
	var filter_index = filter_rarity.selected
	
	for slot in inventory_slots:
		var item_data = slot.item_data
		if not item_data:
			slot.visible = true
			continue
		
		var show_item = true
		
		# Apply search filter
		if search_text != "":
			var item_name = item_data.get("name", "").to_lower()
			if not item_name.contains(search_text):
				show_item = false
		
		# Apply rarity filter
		if filter_index > 0:
			var filter_rarity_text = filter_rarity.get_item_text(filter_index).to_lower()
			var item_rarity = item_data.get("rarity", "common").to_lower()
			if item_rarity != filter_rarity_text:
				show_item = false
		
		slot.visible = show_item

func sort_inventory_display(sort_index: int):
# Sort inventory display
	if not inventory_system:
		return
	
	var items = inventory_system.get_all_items()
	
	match sort_index:
		0:  # Name A-Z
			items.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))
		1:  # Name Z-A
			items.sort_custom(func(a, b): return a.get("name", "") > b.get("name", ""))
		2:  # Rarity ascending
			items.sort_custom(func(a, b): return get_rarity_value(a) < get_rarity_value(b))
		3:  # Rarity descending
			items.sort_custom(func(a, b): return get_rarity_value(a) > get_rarity_value(b))
		4:  # Type
			items.sort_custom(func(a, b): return a.get("type", "") < b.get("type", ""))
	
	# Update slots with sorted items
	clear_all_slots()
	for i in range(min(items.size(), inventory_slots.size())):
		if items[i]:
			inventory_slots[i].set_item(items[i])

func get_rarity_value(item_data) -> int:
# Get numeric value for rarity sorting
	var rarity = item_data.get("rarity", "common").to_lower()
	match rarity:
		"common": return 0
		"uncommon": return 1
		"rare": return 2
		"epic": return 3
		"legendary": return 4
		"mythic": return 5
		_: return 0

# System Event Handlers
func _on_item_added(item_data):
# Handle item added to inventory
	refresh_inventory()

func _on_item_removed(item_id):
# Handle item removed from inventory
	refresh_inventory()

# Input Handling
func _input(event):
# Handle input events
	if visible and event.is_action_pressed("ui_cancel"):
		if ui_manager:
			ui_manager.close_inventory()
	
	# Update drag preview position
	if drag_preview and event is InputEventMouseMotion:
		drag_preview.global_position = event.global_position

# Debug Functions
func debug_populate_test_items():
# Debug: Populate with test items
	var test_items = [
		{"name": "Iron Sword", "type": "weapon", "rarity": "common", "value": 50},
		{"name": "Health Potion", "type": "consumable", "rarity": "common", "value": 25},
		{"name": "Mystic Orb", "type": "accessory", "rarity": "legendary", "value": 1000},
	]
	
	for i in range(min(test_items.size(), inventory_slots.size())):
		inventory_slots[i].set_item(test_items[i])

# InventorySlot Class Definition (removido class_name para evitar erro)
# Use a classe separada em res://scripts/ui/inventory/InventorySlot.gd
class InnerInventorySlot:
extends Control

signal slot_clicked(slot: InventorySlot)
signal slot_hovered(slot: InventorySlot)
signal slot_unhovered(slot: InventorySlot)
signal drag_started(slot: InventorySlot)
signal drag_ended(slot: InventorySlot, target: InventorySlot)

var slot_index: int = 0
var item_data: Dictionary = {}
var is_selected: bool = false
var is_hovered: bool = false

var background_panel: Panel
var item_icon: TextureRect
var stack_label: Label

var slot_normal: Color = Color(0.1, 0.15, 0.1, 0.8)
var slot_hover: Color = Color(0.0, 1.0, 0.549, 0.3)
var slot_selected: Color = Color(0.0, 1.0, 0.549, 0.6)
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)

func _init():
	setup_slot()

func setup_slot():
# Setup slot appearance
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Background panel
	background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_panel)
	
	update_slot_style()
	
	# Item icon
	item_icon = TextureRect.new()
	item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item_icon)
	
	# Stack count label
	stack_label = Label.new()
	stack_label.anchor_left = 1.0
	stack_label.anchor_right = 1.0
	stack_label.anchor_top = 1.0
	stack_label.anchor_bottom = 1.0
	stack_label.offset_left = -20
	stack_label.offset_top = -20
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.add_theme_font_size_override("font_size", 10)
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack_label)

func set_item(new_item_data: Dictionary):
# Set item data for this slot
	item_data = new_item_data
	
	if item_data.is_empty():
		clear_item()
		return
	
	# Set icon
	if item_data.has("icon"):
		item_icon.texture = item_data.icon
	
	# Set stack count
	var stack_count = item_data.get("stack_count", 1)
	if stack_count > 1:
		stack_label.text = str(stack_count)
		stack_label.visible = true
	else:
		stack_label.visible = false

func clear_item():
# Clear item from slot
	item_data.clear()
	item_icon.texture = null
	stack_label.visible = false

func set_selected(selected: bool):
# Set slot selection state
	is_selected = selected
	update_slot_style()

func set_hovered(hovered: bool):
# Set slot hover state
	is_hovered = hovered
	update_slot_style()

func update_slot_style():
# Update slot visual style
	var style = StyleBoxFlat.new()
	
	if is_selected:
		style.bg_color = slot_selected
	elif is_hovered:
		style.bg_color = slot_hover
	else:
		style.bg_color = slot_normal
	
	style.border_color = neon_green
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	background_panel.add_theme_stylebox_override("panel", style)

# Input handling
func _gui_input(event):
# Handle GUI input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(self)
	
	elif event is InputEventMouseMotion:
		if not is_hovered:
			slot_hovered.emit(self)
	
	else:
		# Handle mouse exit
		if is_hovered:
			slot_unhovered.emit(self)

func _can_drop_data(position, data):
# Check if data can be dropped on this slot
	return data is InventorySlot

func _drop_data(position, data):
# Handle data drop
	if data is InventorySlot:
		drag_ended.emit(data, self)
