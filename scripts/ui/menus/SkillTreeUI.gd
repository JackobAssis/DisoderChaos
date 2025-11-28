extends Control

class_name SkillTreeUI

# Main panels
@onready var main_container: VBoxContainer
@onready var header_panel: Panel
@onready var tree_container: HSplitContainer
@onready var tree_tabs: TabContainer
@onready var info_panel: Panel

# Header elements
var skill_points_label: Label
var tree_selector: OptionButton
var reset_button: Button

# Tree display
var current_tree_canvas: Control
var skill_nodes: Dictionary = {} # skill_id -> SkillNode
var connection_lines: Array[Line2D] = []

# Info panel elements
var skill_name_label: Label
var skill_description_label: RichTextLabel
var skill_level_label: Label
var skill_effects_container: VBoxContainer
var upgrade_button: Button
var skill_preview: TextureRect

# Current state
var selected_skill: String = ""
var current_tree: String = "warrior"
var available_skill_points: int = 0
var player_skills: Dictionary = {} # skill_id -> level

# Style
var bg_color: Color = Color(0.1, 0.1, 0.15, 0.9)
var darker_bg: Color = Color(0.05, 0.05, 0.1, 1.0)
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)

# Grid settings
var grid_size: Vector2 = Vector2(100, 100)
var tree_offset: Vector2 = Vector2(50, 50)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var ui_manager: UIManager
var player_progression: PlayerProgression

func _ready():
	setup_skill_tree_ui()
	setup_connections()
	load_skill_data()
	print("[SkillTreeUI] Interface de Ãrvore de Habilidades inicializada")

func setup_skill_tree_ui():
# Setup skill tree UI layout
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()
	
	create_main_layout()
	create_header()
	create_tree_display()
	create_info_panel()

func create_main_layout():
# Create main layout structure
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)

func create_header():
# Create header with skill points and controls
	header_panel = Panel.new()
	header_panel.name = "HeaderPanel"
	header_panel.custom_minimum_size = Vector2(0, 60)
	
	# Apply styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	header_panel.add_theme_stylebox_override("panel", panel_style)
	main_container.add_child(header_panel)
	
	var header_layout = HBoxContainer.new()
	header_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_layout.add_theme_constant_override("separation", 20)
	header_panel.add_child(header_layout)
	
	# Title
	var title = Label.new()
	title.text = "SKILL TREES"
	title.add_theme_color_override("font_color", neon_green)
	title.add_theme_font_size_override("font_size", 24)
	header_layout.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_layout.add_child(spacer)
	
	# Skill points display
	skill_points_label = Label.new()
	skill_points_label.text = "Skill Points: 0"
	skill_points_label.add_theme_color_override("font_color", Color.WHITE)
	skill_points_label.add_theme_font_size_override("font_size", 18)
	header_layout.add_child(skill_points_label)
	
	# Tree selector
	tree_selector = OptionButton.new()
	tree_selector.custom_minimum_size = Vector2(150, 40)
	tree_selector.item_selected.connect(_on_tree_changed)
	apply_option_button_style(tree_selector)
	header_layout.add_child(tree_selector)
	
	# Reset button
	reset_button = Button.new()
	reset_button.text = "RESET TREE"
	reset_button.custom_minimum_size = Vector2(120, 40)
	reset_button.pressed.connect(_on_reset_tree_pressed)
	apply_button_style(reset_button)
	header_layout.add_child(reset_button)

func create_tree_display():
# Create skill tree display area
	tree_container = HSplitContainer.new()
	tree_container.name = "TreeContainer"
	tree_container.split_offset = 800
	tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(tree_container)
	
	# Tree canvas (left side)
	var tree_scroll = ScrollContainer.new()
	tree_scroll.name = "TreeScroll"
	tree_container.add_child(tree_scroll)
	
	current_tree_canvas = Control.new()
	current_tree_canvas.name = "TreeCanvas"
	current_tree_canvas.custom_minimum_size = Vector2(1000, 800)
	current_tree_canvas.gui_input.connect(_on_tree_canvas_input)
	tree_scroll.add_child(current_tree_canvas)
	
	# Apply background
	var canvas_bg = Panel.new()
	canvas_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.border_color = neon_green
	bg_style.border_width_left = 2
	bg_style.border_width_right = 1
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	canvas_bg.add_theme_stylebox_override("panel", bg_style)
	current_tree_canvas.add_child(canvas_bg)
	current_tree_canvas.move_child(canvas_bg, 0)  # Send to back

func create_info_panel():
# Create skill information panel
	info_panel = Panel.new()
	info_panel.name = "InfoPanel"
	info_panel.custom_minimum_size = Vector2(300, 0)
	
	# Apply styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 1
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	info_panel.add_theme_stylebox_override("panel", panel_style)
	tree_container.add_child(info_panel)
	
	var info_layout = VBoxContainer.new()
	info_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_layout.add_theme_constant_override("separation", 15)
	info_panel.add_child(info_layout)
	
	# Skill preview
	skill_preview = TextureRect.new()
	skill_preview.custom_minimum_size = Vector2(64, 64)
	skill_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	info_layout.add_child(skill_preview)
	
	# Skill name
	skill_name_label = Label.new()
	skill_name_label.text = "Select a Skill"
	skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_name_label.add_theme_color_override("font_color", Color.WHITE)
	skill_name_label.add_theme_font_size_override("font_size", 18)
	info_layout.add_child(skill_name_label)
	
	# Skill level
	skill_level_label = Label.new()
	skill_level_label.text = ""
	skill_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_level_label.add_theme_color_override("font_color", neon_green)
	skill_level_label.add_theme_font_size_override("font_size", 14)
	info_layout.add_child(skill_level_label)
	
	# Skill description
	var desc_scroll = ScrollContainer.new()
	desc_scroll.custom_minimum_size = Vector2(0, 100)
	desc_scroll.scroll_horizontal_enabled = false
	info_layout.add_child(desc_scroll)
	
	skill_description_label = RichTextLabel.new()
	skill_description_label.bbcode_enabled = true
	skill_description_label.fit_content = true
	skill_description_label.add_theme_color_override("default_color", Color.LIGHT_GRAY)
	desc_scroll.add_child(skill_description_label)
	
	# Skill effects
	var effects_header = Label.new()
	effects_header.text = "Effects:"
	effects_header.add_theme_color_override("font_color", neon_green)
	effects_header.add_theme_font_size_override("font_size", 14)
	info_layout.add_child(effects_header)
	
	var effects_scroll = ScrollContainer.new()
	effects_scroll.custom_minimum_size = Vector2(0, 150)
	effects_scroll.scroll_horizontal_enabled = false
	effects_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_layout.add_child(effects_scroll)
	
	skill_effects_container = VBoxContainer.new()
	skill_effects_container.add_theme_constant_override("separation", 5)
	effects_scroll.add_child(skill_effects_container)
	
	# Upgrade button
	upgrade_button = Button.new()
	upgrade_button.text = "UPGRADE SKILL"
	upgrade_button.custom_minimum_size = Vector2(0, 40)
	upgrade_button.disabled = true
	upgrade_button.pressed.connect(_on_upgrade_skill_pressed)
	apply_button_style(upgrade_button)
	info_layout.add_child(upgrade_button)

func load_skill_data():
# Load skill tree data
	var skill_data = DataLoader.load_json_data("res://data/skills/skill_trees.json")
	if not skill_data:
		print("[SkillTreeUI] Failed to load skill tree data")
		return
	
	# Populate tree selector
	tree_selector.clear()
	for tree_id in skill_data:
		var tree_info = skill_data[tree_id]
		var tree_name = tree_info.get("name", tree_id)
		tree_selector.add_item(tree_name)
		tree_selector.set_item_metadata(tree_selector.get_item_count() - 1, tree_id)
	
	# Load initial tree
	if tree_selector.get_item_count() > 0:
		current_tree = tree_selector.get_item_metadata(0)
		display_skill_tree(current_tree)

func display_skill_tree(tree_id: String):
# Display the specified skill tree
	clear_skill_nodes()
	
	var skill_data = DataLoader.load_json_data("res://data/skills/skill_trees.json")
	if not skill_data or not skill_data.has(tree_id):
		return
	
	var tree_info = skill_data[tree_id]
	var skills = tree_info.get("skills", {})
	var tree_color = Color(tree_info.get("color", "#FFFFFF"))
	
	# Create skill nodes
	for skill_id in skills:
		var skill = skills[skill_id]
		create_skill_node(skill_id, skill, tree_color)
	
	# Create connection lines
	draw_skill_connections(skills)

func clear_skill_nodes():
# Clear all skill nodes from display
	for node in skill_nodes.values():
		node.queue_free()
	
	for line in connection_lines:
		line.queue_free()
	
	skill_nodes.clear()
	connection_lines.clear()

func create_skill_node(skill_id: String, skill_data: Dictionary, tree_color: Color):
# Create a skill node display
	var node = SkillNode.new()
	node.initialize(skill_id, skill_data, tree_color)
	node.skill_selected.connect(_on_skill_node_selected)
	
	# Position based on grid
	var pos = skill_data.get("position", {"x": 1, "y": 1})
	var world_pos = Vector2(pos.x * grid_size.x, pos.y * grid_size.y) + tree_offset
	node.position = world_pos
	
	current_tree_canvas.add_child(node)
	skill_nodes[skill_id] = node
	
	# Update node state
	update_skill_node(skill_id)

func draw_skill_connections(skills: Dictionary):
# Draw connections between prerequisite skills
	for skill_id in skills:
		var skill = skills[skill_id]
		var prerequisites = skill.get("prerequisites", [])
		
		for prereq_id in prerequisites:
			if skill_nodes.has(skill_id) and skill_nodes.has(prereq_id):
				create_connection_line(prereq_id, skill_id)

func create_connection_line(from_skill: String, to_skill: String):
# Create connection line between skills
	var line = Line2D.new()
	line.width = 3
	line.default_color = Color.GRAY
	line.z_index = -1
	
	var from_pos = skill_nodes[from_skill].position + Vector2(32, 32)  # Center of node
	var to_pos = skill_nodes[to_skill].position + Vector2(32, 32)
	
	line.add_point(from_pos)
	line.add_point(to_pos)
	
	current_tree_canvas.add_child(line)
	connection_lines.append(line)

func update_skill_node(skill_id: String):
# Update skill node based on current state
	if not skill_nodes.has(skill_id):
		return
	
	var node = skill_nodes[skill_id]
	var current_level = player_skills.get(skill_id, 0)
	var can_upgrade = can_upgrade_skill(skill_id)
	
	node.update_state(current_level, can_upgrade)

func update_all_skill_nodes():
# Update all skill nodes
	for skill_id in skill_nodes.keys():
		update_skill_node(skill_id)

func can_upgrade_skill(skill_id: String) -> bool:
# Check if skill can be upgraded
	var skill_data = get_skill_data(skill_id)
	if not skill_data:
		return false
	
	var current_level = player_skills.get(skill_id, 0)
	var max_level = skill_data.get("max_level", 1)
	
	# Check if already at max level
	if current_level >= max_level:
		return false
	
	# Check skill points
	var cost = skill_data.get("skill_points_cost", 1)
	if available_skill_points < cost:
		return false
	
	# Check prerequisites
	var prerequisites = skill_data.get("prerequisites", [])
	for prereq_id in prerequisites:
		var prereq_level = player_skills.get(prereq_id, 0)
		if prereq_level <= 0:
			return false
	
	return true

func get_skill_data(skill_id: String) -> Dictionary:
# Get skill data for given skill ID
	var skill_data = DataLoader.load_json_data("res://data/skills/skill_trees.json")
	if not skill_data:
		return {}
	
	for tree_id in skill_data:
		var tree_info = skill_data[tree_id]
		var skills = tree_info.get("skills", {})
		if skills.has(skill_id):
			return skills[skill_id]
	
	return {}

# Event handlers
func _on_tree_changed(index: int):
# Handle tree selection change
	if index >= 0 and index < tree_selector.get_item_count():
		current_tree = tree_selector.get_item_metadata(index)
		display_skill_tree(current_tree)

func _on_skill_node_selected(skill_id: String):
# Handle skill node selection
	selected_skill = skill_id
	update_skill_info()

func update_skill_info():
# Update skill information panel
	if selected_skill == "":
		skill_name_label.text = "Select a Skill"
		skill_description_label.text = ""
		skill_level_label.text = ""
		upgrade_button.disabled = true
		clear_skill_effects()
		return
	
	var skill_data = get_skill_data(selected_skill)
	if skill_data.is_empty():
		return
	
	var current_level = player_skills.get(selected_skill, 0)
	var max_level = skill_data.get("max_level", 1)
	
	# Update labels
	skill_name_label.text = skill_data.get("name", selected_skill)
	skill_description_label.text = skill_data.get("description", "No description available")
	skill_level_label.text = "Level: " + str(current_level) + "/" + str(max_level)
	
	# Update upgrade button
	upgrade_button.disabled = not can_upgrade_skill(selected_skill)
	
	# Update effects display
	display_skill_effects(skill_data, current_level)

func display_skill_effects(skill_data: Dictionary, current_level: int):
# Display skill effects
	clear_skill_effects()
	
	var effects = skill_data.get("effects", {})
	for effect_name in effects:
		var effect_values = effects[effect_name]
		if typeof(effect_values) == TYPE_ARRAY and effect_values.size() > 0:
			var effect_item = create_effect_item(effect_name, effect_values, current_level)
			skill_effects_container.add_child(effect_item)
	
	# Show cooldown if applicable
	if skill_data.has("cooldown"):
		var cooldown_item = create_effect_item("cooldown", [skill_data.cooldown], 0)
		skill_effects_container.add_child(cooldown_item)

func create_effect_item(effect_name: String, values: Array, current_level: int) -> Control:
# Create effect display item
	var item_container = HBoxContainer.new()
	item_container.add_theme_constant_override("separation", 10)
	
	# Effect name
	var name_label = Label.new()
	name_label.text = effect_name.replace("_", " ").capitalize() + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 12)
	item_container.add_child(name_label)
	
	# Effect value
	var value_label = Label.new()
	if current_level > 0 and current_level <= values.size():
		var current_value = values[current_level - 1]
		var next_value = ""
		if current_level < values.size():
			next_value = " â†’ " + str(values[current_level])
		value_label.text = str(current_value) + next_value
		value_label.add_theme_color_override("font_color", neon_green)
	else:
		if values.size() > 0:
			value_label.text = str(values[0])
			value_label.add_theme_color_override("font_color", Color.GRAY)
	
	value_label.add_theme_font_size_override("font_size", 12)
	item_container.add_child(value_label)
	
	return item_container

func clear_skill_effects():
# Clear skill effects display
	for child in skill_effects_container.get_children():
		child.queue_free()

func _on_upgrade_skill_pressed():
# Handle upgrade skill button press
	if selected_skill != "" and can_upgrade_skill(selected_skill):
		upgrade_skill(selected_skill)

func upgrade_skill(skill_id: String):
# Upgrade the specified skill
	var skill_data = get_skill_data(skill_id)
	if not skill_data:
		return
	
	var cost = skill_data.get("skill_points_cost", 1)
	if available_skill_points < cost:
		return
	
	# Spend skill points
	available_skill_points -= cost
	
	# Increase skill level
	var current_level = player_skills.get(skill_id, 0)
	player_skills[skill_id] = current_level + 1
	
	# Update displays
	update_skill_points_display()
	update_skill_info()
	update_skill_node(skill_id)
	update_all_skill_nodes()  # Update all nodes in case prerequisites changed
	
	# Notify systems
	event_bus.emit_signal("skill_upgraded", skill_id, player_skills[skill_id])
	
	print("[SkillTreeUI] Skill upgraded: ", skill_id, " to level ", player_skills[skill_id])

func _on_reset_tree_pressed():
# Handle reset tree button press
	show_reset_confirmation()

func show_reset_confirmation():
# Show skill tree reset confirmation
	var dialog = AcceptDialog.new()
	dialog.title = "Reset Skill Tree"
	dialog.dialog_text = "Are you sure you want to reset this skill tree? This will refund all skill points but remove all skill levels."
	
	var confirm_button = dialog.add_button("Reset", true, "reset")
	dialog.custom_action.connect(_on_reset_confirmed)
	
	add_child(dialog)
	dialog.popup_centered()

func _on_reset_confirmed(action: String):
# Handle reset confirmation
	if action == "reset":
		reset_skill_tree()

func reset_skill_tree():
# Reset current skill tree
	var refunded_points = 0
	
	# Calculate refunded points and reset skills
	for skill_id in player_skills.keys():
		if is_skill_in_current_tree(skill_id):
			var skill_data = get_skill_data(skill_id)
			var level = player_skills[skill_id]
			var cost = skill_data.get("skill_points_cost", 1)
			refunded_points += level * cost
			player_skills[skill_id] = 0
	
	# Refund points
	available_skill_points += refunded_points
	
	# Update displays
	update_skill_points_display()
	update_all_skill_nodes()
	clear_skill_info()
	
	event_bus.emit_signal("skill_tree_reset", current_tree)

func is_skill_in_current_tree(skill_id: String) -> bool:
# Check if skill belongs to current tree
	var skill_data = DataLoader.load_json_data("res://data/skills/skill_trees.json")
	if not skill_data or not skill_data.has(current_tree):
		return false
	
	var skills = skill_data[current_tree].get("skills", {})
	return skills.has(skill_id)

func clear_skill_info():
# Clear skill information display
	selected_skill = ""
	skill_name_label.text = "Select a Skill"
	skill_description_label.text = ""
	skill_level_label.text = ""
	upgrade_button.disabled = true
	clear_skill_effects()

func update_skill_points_display():
# Update skill points display
	skill_points_label.text = "Skill Points: " + str(available_skill_points)

# Setup and connections
func setup_connections():
# Setup signal connections
	if event_bus:
		event_bus.connect("player_leveled_up", _on_player_level_up)
		event_bus.connect("skill_points_awarded", _on_skill_points_awarded)

func _on_player_level_up(new_level: int):
# Handle player level up
	# Award skill points on level up
	var points_per_level = 2
	available_skill_points += points_per_level
	update_skill_points_display()

func _on_skill_points_awarded(points: int):
# Handle skill points awarded
	available_skill_points += points
	update_skill_points_display()

func _on_tree_canvas_input(event: InputEvent):
# Handle tree canvas input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Deselect if clicking empty area
			var clicked_on_node = false
			for node in skill_nodes.values():
				if node.get_global_rect().has_point(event.global_position):
					clicked_on_node = true
					break
			
			if not clicked_on_node:
				selected_skill = ""
				update_skill_info()

# Styling functions
func apply_button_style(button: Button):
# Apply dark theme style to button
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

func apply_option_button_style(option_button: OptionButton):
# Apply dark theme style to option button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = darker_bg
	normal_style.border_color = neon_green
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	option_button.add_theme_stylebox_override("normal", normal_style)
	option_button.add_theme_color_override("font_color", Color.WHITE)

# Input handling
func _input(event):
# Handle input events
	if visible and event.is_action_pressed("ui_cancel"):
		if ui_manager:
			ui_manager.close_skill_tree()

func open():
# Show skill tree UI (renomeado de show)
	super.show()
	load_skill_data()
	update_skill_points_display()

# Skill Node Class
class SkillNode extends Control:
	signal skill_selected(skill_id: String)
	
	var skill_id: String = ""
	var skill_data: Dictionary = {}
	var tree_color: Color = Color.WHITE
	var current_level: int = 0
	var can_upgrade: bool = false
	var max_level: int = 1
	
	var icon: TextureRect
	var level_label: Label
	var background_panel: Panel
	
	func initialize(id: String, data: Dictionary, color: Color):
		skill_id = id
		skill_data = data
		tree_color = color
		max_level = data.get("max_level", 1)
		
		setup_node()
	
	func setup_node():
		custom_minimum_size = Vector2(64, 64)
		
		# Background panel
		background_panel = Panel.new()
		background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(background_panel)
		
		# Icon (placeholder)
		icon = TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		add_child(icon)
		
		# Level indicator
		level_label = Label.new()
		level_label.anchor_left = 0.8
		level_label.anchor_right = 1.0
		level_label.anchor_top = 0.8
		level_label.anchor_bottom = 1.0
		level_label.text = "0"
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_color_override("font_color", Color.WHITE)
		level_label.add_theme_font_size_override("font_size", 12)
		add_child(level_label)
		
		# Connect input
		gui_input.connect(_on_node_input)
		
		update_style()
	
	func update_state(level: int, upgradeable: bool):
		current_level = level
		can_upgrade = upgradeable
		level_label.text = str(current_level)
		update_style()
	
	func update_style():
		var style = StyleBoxFlat.new()
		
		if current_level > 0:
			# Learned skill
			style.bg_color = tree_color
			style.border_color = Color.WHITE
		elif can_upgrade:
			# Can learn
			style.bg_color = Color(tree_color.r, tree_color.g, tree_color.b, 0.3)
			style.border_color = tree_color
		else:
			# Locked
			style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			style.border_color = Color.GRAY
		
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		
		background_panel.add_theme_stylebox_override("panel", style)
	
	func _on_node_input(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				skill_selected.emit(skill_id)
