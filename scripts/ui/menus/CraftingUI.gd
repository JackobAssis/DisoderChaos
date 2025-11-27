extends Control

class_name CraftingUI

# Main panels
@onready var main_container: HSplitContainer
@onready var recipe_panel: Panel
@onready var crafting_panel: Panel

# Recipe browser
var recipe_categories: TabContainer
var recipe_list: ItemList
var recipe_search: LineEdit
var recipe_filter: OptionButton

# Recipe details
var recipe_preview: TextureRect
var recipe_name_label: Label
var recipe_description_label: RichTextLabel
var materials_container: VBoxContainer
var result_preview: Control

# Crafting interface
var crafting_queue: VBoxContainer
var craft_button: Button
var craft_all_button: Button
var progress_bar: ProgressBar
var queue_container: VBoxContainer

# Player inventory display
var player_materials: GridContainer
var material_slots: Array[Control] = []

# Crafting station info
var station_label: Label
var station_bonus_label: Label

# Current state
var selected_recipe: Dictionary = {}
var current_station: String = ""
var crafting_queue_data: Array[Dictionary] = []
var is_crafting: bool = false
var craft_progress: float = 0.0
var current_craft_time: float = 0.0

# Style colors
var bg_color: Color = Color(0.1, 0.1, 0.15, 0.9)
var darker_bg: Color = Color(0.05, 0.05, 0.1, 1.0)
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var ui_manager: UIManager
var crafting_system: CraftingSystem

func _ready():
	setup_crafting_ui()
	setup_connections()
	print("[CraftingUI] Interface de Crafting inicializada")

func setup_crafting_ui():
	"""Setup crafting UI layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()
	
	create_main_layout()
	create_recipe_browser()
	create_crafting_interface()
	create_material_display()
	
	load_recipes()

func create_main_layout():
	"""Create main layout structure"""
	main_container = HSplitContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.split_offset = 600
	add_child(main_container)

func create_recipe_browser():
	"""Create recipe browser panel"""
	recipe_panel = Panel.new()
	recipe_panel.name = "RecipePanel"
	
	# Apply dark theme
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 2
	panel_style.border_width_right = 1
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	recipe_panel.add_theme_stylebox_override("panel", panel_style)
	main_container.add_child(recipe_panel)
	
	var recipe_layout = VBoxContainer.new()
	recipe_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recipe_layout.add_theme_constant_override("separation", 10)
	recipe_panel.add_child(recipe_layout)
	
	# Header
	create_recipe_header(recipe_layout)
	
	# Categories and recipes
	create_recipe_categories(recipe_layout)

func create_recipe_header(parent: Control):
	"""Create recipe browser header"""
	var header = VBoxContainer.new()
	header.name = "RecipeHeader"
	header.custom_minimum_size = Vector2(0, 80)
	parent.add_child(header)
	
	var title = Label.new()
	title.text = "RECIPES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", neon_green)
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	
	# Search and filter
	var filter_container = HBoxContainer.new()
	filter_container.add_theme_constant_override("separation", 10)
	header.add_child(filter_container)
	
	# Search box
	recipe_search = LineEdit.new()
	recipe_search.placeholder_text = "Search recipes..."
	recipe_search.custom_minimum_size = Vector2(200, 30)
	apply_line_edit_style(recipe_search)
	recipe_search.text_changed.connect(_on_recipe_search_changed)
	filter_container.add_child(recipe_search)
	
	# Filter dropdown
	recipe_filter = OptionButton.new()
	recipe_filter.custom_minimum_size = Vector2(120, 30)
	recipe_filter.add_item("All")
	recipe_filter.add_item("Weapons")
	recipe_filter.add_item("Armor")
	recipe_filter.add_item("Consumables")
	recipe_filter.add_item("Materials")
	apply_option_button_style(recipe_filter)
	recipe_filter.item_selected.connect(_on_recipe_filter_changed)
	filter_container.add_child(recipe_filter)

func create_recipe_categories(parent: Control):
	"""Create recipe categories and list"""
	recipe_categories = TabContainer.new()
	recipe_categories.name = "RecipeCategories"
	recipe_categories.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(recipe_categories)
	
	# Recipe list
	var scroll = ScrollContainer.new()
	scroll.name = "RecipeScroll"
	scroll.scroll_horizontal_enabled = false
	recipe_categories.add_child(scroll)
	
	recipe_list = ItemList.new()
	recipe_list.name = "RecipeList"
	recipe_list.item_selected.connect(_on_recipe_selected)
	apply_item_list_style(recipe_list)
	scroll.add_child(recipe_list)

func create_crafting_interface():
	"""Create crafting interface panel"""
	crafting_panel = Panel.new()
	crafting_panel.name = "CraftingPanel"
	
	# Apply theme
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_color = neon_green
	panel_style.border_width_left = 1
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	crafting_panel.add_theme_stylebox_override("panel", panel_style)
	main_container.add_child(crafting_panel)
	
	var crafting_layout = VBoxContainer.new()
	crafting_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crafting_layout.add_theme_constant_override("separation", 15)
	crafting_panel.add_child(crafting_layout)
	
	# Station info
	create_station_info(crafting_layout)
	
	# Recipe details
	create_recipe_details(crafting_layout)
	
	# Crafting controls
	create_crafting_controls(crafting_layout)
	
	# Queue display
	create_queue_display(crafting_layout)

func create_station_info(parent: Control):
	"""Create crafting station info"""
	var station_container = VBoxContainer.new()
	station_container.name = "StationInfo"
	station_container.custom_minimum_size = Vector2(0, 60)
	parent.add_child(station_container)
	
	station_label = Label.new()
	station_label.text = "No Station Selected"
	station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	station_label.add_theme_color_override("font_color", Color.WHITE)
	station_label.add_theme_font_size_override("font_size", 16)
	station_container.add_child(station_label)
	
	station_bonus_label = Label.new()
	station_bonus_label.text = ""
	station_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	station_bonus_label.add_theme_color_override("font_color", neon_green)
	station_bonus_label.add_theme_font_size_override("font_size", 12)
	station_container.add_child(station_bonus_label)

func create_recipe_details(parent: Control):
	"""Create recipe details display"""
	var details_scroll = ScrollContainer.new()
	details_scroll.name = "RecipeDetails"
	details_scroll.custom_minimum_size = Vector2(0, 250)
	details_scroll.scroll_horizontal_enabled = false
	parent.add_child(details_scroll)
	
	var details_container = VBoxContainer.new()
	details_container.add_theme_constant_override("separation", 10)
	details_scroll.add_child(details_container)
	
	# Recipe preview and name
	var header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 15)
	details_container.add_child(header_container)
	
	recipe_preview = TextureRect.new()
	recipe_preview.custom_minimum_size = Vector2(64, 64)
	recipe_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	recipe_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	header_container.add_child(recipe_preview)
	
	var name_container = VBoxContainer.new()
	name_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(name_container)
	
	recipe_name_label = Label.new()
	recipe_name_label.text = "Select a Recipe"
	recipe_name_label.add_theme_color_override("font_color", Color.WHITE)
	recipe_name_label.add_theme_font_size_override("font_size", 18)
	name_container.add_child(recipe_name_label)
	
	recipe_description_label = RichTextLabel.new()
	recipe_description_label.bbcode_enabled = true
	recipe_description_label.fit_content = true
	recipe_description_label.custom_minimum_size = Vector2(0, 60)
	recipe_description_label.add_theme_color_override("default_color", Color.LIGHT_GRAY)
	name_container.add_child(recipe_description_label)
	
	# Materials required
	var materials_header = Label.new()
	materials_header.text = "Materials Required:"
	materials_header.add_theme_color_override("font_color", neon_green)
	materials_header.add_theme_font_size_override("font_size", 14)
	details_container.add_child(materials_header)
	
	materials_container = VBoxContainer.new()
	materials_container.add_theme_constant_override("separation", 5)
	details_container.add_child(materials_container)

func create_crafting_controls(parent: Control):
	"""Create crafting control buttons"""
	var controls_container = HBoxContainer.new()
	controls_container.name = "CraftingControls"
	controls_container.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_container.add_theme_constant_override("separation", 15)
	controls_container.custom_minimum_size = Vector2(0, 50)
	parent.add_child(controls_container)
	
	craft_button = Button.new()
	craft_button.text = "CRAFT"
	craft_button.custom_minimum_size = Vector2(100, 40)
	craft_button.disabled = true
	craft_button.pressed.connect(_on_craft_button_pressed)
	apply_button_style(craft_button)
	controls_container.add_child(craft_button)
	
	craft_all_button = Button.new()
	craft_all_button.text = "CRAFT ALL"
	craft_all_button.custom_minimum_size = Vector2(120, 40)
	craft_all_button.disabled = true
	craft_all_button.pressed.connect(_on_craft_all_button_pressed)
	apply_button_style(craft_all_button)
	controls_container.add_child(craft_all_button)

func create_queue_display(parent: Control):
	"""Create crafting queue display"""
	var queue_header = Label.new()
	queue_header.text = "Crafting Queue:"
	queue_header.add_theme_color_override("font_color", neon_green)
	queue_header.add_theme_font_size_override("font_size", 14)
	parent.add_child(queue_header)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 25)
	progress_bar.show_percentage = true
	progress_bar.modulate.a = 0.0  # Hidden initially
	apply_progress_bar_style(progress_bar)
	parent.add_child(progress_bar)
	
	# Queue scroll
	var queue_scroll = ScrollContainer.new()
	queue_scroll.name = "QueueScroll"
	queue_scroll.custom_minimum_size = Vector2(0, 120)
	queue_scroll.scroll_horizontal_enabled = false
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(queue_scroll)
	
	queue_container = VBoxContainer.new()
	queue_container.add_theme_constant_override("separation", 5)
	queue_scroll.add_child(queue_container)

func create_material_display():
	"""Create player materials display"""
	# This will be integrated into the main layout later
	pass

# Data loading and management
func load_recipes():
	"""Load crafting recipes from JSON"""
	var recipe_data = DataLoader.load_json_data("res://data/crafting/recipes.json")
	if not recipe_data:
		print("[CraftingUI] Failed to load recipes")
		return
	
	populate_recipe_list(recipe_data)

func populate_recipe_list(recipe_data: Dictionary):
	"""Populate recipe list with loaded data"""
	recipe_list.clear()
	
	for category in recipe_data:
		var recipes = recipe_data[category]
		if typeof(recipes) == TYPE_DICTIONARY:
			for recipe_id in recipes:
				var recipe = recipes[recipe_id]
				var display_name = recipe.get("name", recipe_id)
				var rarity = recipe.get("rarity", "common")
				
				# Color code by rarity
				var color_code = get_rarity_color_code(rarity)
				recipe_list.add_item(color_code + display_name)
				recipe_list.set_item_metadata(recipe_list.get_item_count() - 1, {
					"recipe_id": recipe_id,
					"category": category,
					"data": recipe
				})

func get_rarity_color_code(rarity: String) -> String:
	"""Get color code for rarity"""
	match rarity:
		"common": return "[color=white]"
		"uncommon": return "[color=lime]"
		"rare": return "[color=blue]"
		"epic": return "[color=purple]"
		"legendary": return "[color=orange]"
		"mythic": return "[color=red]"
		_: return "[color=white]"

# Event handlers
func _on_recipe_selected(index: int):
	"""Handle recipe selection"""
	if index < 0:
		return
	
	var metadata = recipe_list.get_item_metadata(index)
	if metadata:
		selected_recipe = metadata.data
		update_recipe_details(selected_recipe)
		update_craft_buttons()

func update_recipe_details(recipe: Dictionary):
	"""Update recipe details display"""
	recipe_name_label.text = recipe.get("name", "Unknown Recipe")
	recipe_description_label.text = recipe.get("description", "No description available")
	
	# Clear previous materials
	for child in materials_container.get_children():
		child.queue_free()
	
	# Add materials
	var materials = recipe.get("materials", {})
	for material_id in materials:
		var required_amount = materials[material_id]
		var player_amount = get_player_material_count(material_id)
		
		var material_item = create_material_item(material_id, required_amount, player_amount)
		materials_container.add_child(material_item)

func create_material_item(material_id: String, required: int, available: int) -> Control:
	"""Create material requirement item"""
	var item_container = HBoxContainer.new()
	item_container.add_theme_constant_override("separation", 10)
	
	# Material icon (placeholder)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	item_container.add_child(icon)
	
	# Material name
	var name_label = Label.new()
	name_label.text = material_id.replace("_", " ").capitalize()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.WHITE)
	item_container.add_child(name_label)
	
	# Amount display
	var amount_label = Label.new()
	var color = Color.WHITE if available >= required else Color.RED
	amount_label.text = str(available) + "/" + str(required)
	amount_label.add_theme_color_override("font_color", color)
	item_container.add_child(amount_label)
	
	return item_container

func get_player_material_count(material_id: String) -> int:
	"""Get amount of material player has"""
	# TODO: Integrate with inventory system
	return 0

func update_craft_buttons():
	"""Update craft button states"""
	var can_craft = can_craft_recipe(selected_recipe)
	craft_button.disabled = not can_craft
	craft_all_button.disabled = not can_craft

func can_craft_recipe(recipe: Dictionary) -> bool:
	"""Check if recipe can be crafted"""
	if recipe.is_empty():
		return false
	
	# Check materials
	var materials = recipe.get("materials", {})
	for material_id in materials:
		var required = materials[material_id]
		var available = get_player_material_count(material_id)
		if available < required:
			return false
	
	# Check skill requirements
	var skill_required = recipe.get("skill_required", "")
	var skill_level = recipe.get("skill_level", 0)
	
	if skill_required != "":
		var player_skill_level = get_player_skill_level(skill_required)
		if player_skill_level < skill_level:
			return false
	
	return true

func get_player_skill_level(skill_name: String) -> int:
	"""Get player skill level"""
	# TODO: Integrate with player progression system
	return 1

func _on_craft_button_pressed():
	"""Handle craft button press"""
	if can_craft_recipe(selected_recipe):
		add_to_craft_queue(selected_recipe, 1)

func _on_craft_all_button_pressed():
	"""Handle craft all button press"""
	if can_craft_recipe(selected_recipe):
		var max_possible = calculate_max_craftable(selected_recipe)
		add_to_craft_queue(selected_recipe, max_possible)

func calculate_max_craftable(recipe: Dictionary) -> int:
	"""Calculate maximum number of items that can be crafted"""
	var materials = recipe.get("materials", {})
	var max_craft = 999999
	
	for material_id in materials:
		var required = materials[material_id]
		var available = get_player_material_count(material_id)
		max_craft = min(max_craft, available / required)
	
	return max_craft

func add_to_craft_queue(recipe: Dictionary, quantity: int):
	"""Add recipe to crafting queue"""
	var queue_item = {
		"recipe": recipe,
		"quantity": quantity,
		"progress": 0.0
	}
	
	crafting_queue_data.append(queue_item)
	update_queue_display()
	
	if not is_crafting:
		start_next_craft()

func update_queue_display():
	"""Update crafting queue display"""
	# Clear existing queue items
	for child in queue_container.get_children():
		child.queue_free()
	
	for i in range(crafting_queue_data.size()):
		var queue_item = crafting_queue_data[i]
		var item_display = create_queue_item_display(queue_item, i)
		queue_container.add_child(item_display)

func create_queue_item_display(queue_item: Dictionary, index: int) -> Control:
	"""Create queue item display"""
	var item_container = HBoxContainer.new()
	item_container.add_theme_constant_override("separation", 10)
	
	var name_label = Label.new()
	name_label.text = queue_item.recipe.get("name", "Unknown") + " x" + str(queue_item.quantity)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.WHITE)
	item_container.add_child(name_label)
	
	var remove_button = Button.new()
	remove_button.text = "X"
	remove_button.custom_minimum_size = Vector2(25, 25)
	remove_button.pressed.connect(_on_remove_queue_item.bind(index))
	item_container.add_child(remove_button)
	
	return item_container

func start_next_craft():
	"""Start crafting next item in queue"""
	if crafting_queue_data.is_empty() or is_crafting:
		return
	
	is_crafting = true
	var next_item = crafting_queue_data[0]
	current_craft_time = next_item.recipe.get("crafting_time", 30.0)
	craft_progress = 0.0
	
	progress_bar.modulate.a = 1.0
	progress_bar.value = 0
	progress_bar.max_value = 100

func _process(delta):
	"""Update crafting progress"""
	if is_crafting and not crafting_queue_data.is_empty():
		craft_progress += delta
		var current_item = crafting_queue_data[0]
		var total_time = current_item.recipe.get("crafting_time", 30.0)
		
		var progress_percent = (craft_progress / total_time) * 100.0
		progress_bar.value = progress_percent
		
		if craft_progress >= total_time:
			complete_current_craft()

func complete_current_craft():
	"""Complete current crafting operation"""
	if crafting_queue_data.is_empty():
		return
	
	var completed_item = crafting_queue_data.pop_front()
	var recipe = completed_item.recipe
	
	# Create result item
	create_crafted_item(recipe)
	
	# Remove materials
	consume_materials(recipe.get("materials", {}))
	
	# Award experience
	var exp_reward = recipe.get("experience_reward", 0)
	if exp_reward > 0:
		award_crafting_experience(recipe.get("skill_required", ""), exp_reward)
	
	# Reduce quantity or remove from queue
	completed_item.quantity -= 1
	if completed_item.quantity > 0:
		crafting_queue_data.push_front(completed_item)
	
	update_queue_display()
	
	# Continue with next item or finish
	if not crafting_queue_data.is_empty():
		craft_progress = 0.0
		start_next_craft()
	else:
		is_crafting = false
		progress_bar.modulate.a = 0.0
		craft_progress = 0.0

func create_crafted_item(recipe: Dictionary):
	"""Create the crafted item and add to inventory"""
	var result = recipe.get("result", {})
	var item_id = result.get("item_id", "")
	var quantity = result.get("quantity", 1)
	
	if item_id != "":
		# TODO: Add to player inventory
		event_bus.emit_signal("ui_notification_shown", "Crafted: " + recipe.get("name", item_id), "success")

func consume_materials(materials: Dictionary):
	"""Remove materials from player inventory"""
	for material_id in materials:
		var amount = materials[material_id]
		# TODO: Remove from inventory system
		print("[CraftingUI] Consumed ", amount, " x ", material_id)

func award_crafting_experience(skill: String, amount: int):
	"""Award crafting experience to player"""
	if skill != "":
		# TODO: Integrate with progression system
		event_bus.emit_signal("ui_notification_shown", "+" + str(amount) + " " + skill + " XP", "xp")

# Filter and search functions
func _on_recipe_search_changed(text: String):
	"""Handle recipe search"""
	filter_recipes()

func _on_recipe_filter_changed(index: int):
	"""Handle recipe filter change"""
	filter_recipes()

func filter_recipes():
	"""Filter recipes based on search and category"""
	# TODO: Implement filtering logic
	pass

func _on_remove_queue_item(index: int):
	"""Remove item from crafting queue"""
	if index >= 0 and index < crafting_queue_data.size():
		crafting_queue_data.remove_at(index)
		update_queue_display()

# Setup and connections
func setup_connections():
	"""Setup signal connections"""
	if event_bus:
		event_bus.connect("crafting_station_changed", _on_station_changed)

func _on_station_changed(station_id: String):
	"""Handle crafting station change"""
	current_station = station_id
	update_station_display()

func update_station_display():
	"""Update station display"""
	if current_station == "":
		station_label.text = "No Station Selected"
		station_bonus_label.text = ""
	else:
		station_label.text = current_station.replace("_", " ").capitalize()
		station_bonus_label.text = "Quality +10%, Speed +20%"  # Example bonuses

# Style functions
func apply_line_edit_style(line_edit: LineEdit):
	"""Apply dark theme style to line edit"""
	var style = StyleBoxFlat.new()
	style.bg_color = darker_bg
	style.border_color = neon_green
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_color_override("font_color", Color.WHITE)

func apply_option_button_style(option_button: OptionButton):
	"""Apply dark theme style to option button"""
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	option_button.add_theme_stylebox_override("normal", normal_style)
	option_button.add_theme_color_override("font_color", Color.WHITE)

func apply_button_style(button: Button):
	"""Apply dark theme style to button"""
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.2)
	button.add_theme_stylebox_override("hover", hover_style)
	
	button.add_theme_color_override("font_color", Color.WHITE)

func apply_item_list_style(item_list: ItemList):
	"""Apply dark theme style to item list"""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	item_list.add_theme_stylebox_override("bg", style)
	item_list.add_theme_color_override("font_color", Color.WHITE)

func apply_progress_bar_style(progress_bar: ProgressBar):
	"""Apply style to progress bar"""
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = darker_bg
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = neon_green
	progress_bar.add_theme_stylebox_override("fill", fill_style)

# Input handling
func _input(event):
	"""Handle input events"""
	if visible and event.is_action_pressed("ui_cancel"):
		if ui_manager:
			ui_manager.close_crafting()

func show():
	"""Show crafting UI"""
	super.show()
	load_recipes()

func hide():
	"""Hide crafting UI"""
	super.hide()