extends Control

class_name QuestJournal

# Main panels
@onready var main_container: HSplitContainer
@onready var quest_list_panel: Panel
@onready var quest_details_panel: Panel

# Quest list
var quest_list_container: VBoxContainer
var quest_category_tabs: TabContainer
var active_quests_tab: Control
var completed_quests_tab: Control
var failed_quests_tab: Control

# Quest details
var quest_title_label: Label
var quest_description_label: RichTextLabel
var objectives_container: VBoxContainer
var rewards_container: VBoxContainer
var quest_progress_bar: ProgressBar
var quest_timer_label: Label

# Controls
var search_box: LineEdit
var filter_options: OptionButton
var sort_options: OptionButton

# Style
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var dark_bg: Color = Color(0.0, 0.1, 0.05, 0.95)
var darker_bg: Color = Color(0.0, 0.05, 0.025, 0.98)

# Quest status colors
var status_colors: Dictionary = {
	"active": neon_green,
	"completed": Color.GOLD,
	"failed": Color.CRIMSON,
	"available": Color.CYAN
}

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var quest_system: QuestSystem = get_node("/root/QuestSystem")
@onready var ui_manager: UIManager

# Current selection
var selected_quest: Dictionary = {}

func _ready():
	setup_quest_journal()
	setup_connections()
	print("[QuestJournal] Diário de Missões inicializado")

func setup_quest_journal():
	"""Setup quest journal layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()
	
	create_main_layout()
	create_quest_list_panel()
	create_quest_details_panel()
	create_header_controls()

func create_main_layout():
	"""Create main layout structure"""
	main_container = HSplitContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.split_offset = 400
	add_child(main_container)

func create_quest_list_panel():
	"""Create quest list panel"""
	quest_list_panel = Panel.new()
	quest_list_panel.name = "QuestListPanel"
	quest_list_panel.custom_minimum_size = Vector2(400, 500)
	main_container.add_child(quest_list_panel)
	
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
	quest_list_panel.add_theme_stylebox_override("panel", panel_style)
	
	create_quest_categories()

func create_quest_categories():
	"""Create quest category tabs"""
	quest_category_tabs = TabContainer.new()
	quest_category_tabs.name = "QuestCategories"
	quest_category_tabs.anchor_top = 0.15  # Below header
	quest_category_tabs.anchor_bottom = 1.0
	quest_category_tabs.anchor_left = 0.0
	quest_category_tabs.anchor_right = 1.0
	quest_category_tabs.offset_left = 10
	quest_category_tabs.offset_right = -10
	quest_category_tabs.offset_bottom = -10
	quest_list_panel.add_child(quest_category_tabs)
	
	style_tab_container(quest_category_tabs)
	
	# Active Quests Tab
	active_quests_tab = create_quest_tab("ACTIVE")
	quest_category_tabs.add_child(active_quests_tab)
	
	# Completed Quests Tab
	completed_quests_tab = create_quest_tab("COMPLETED")
	quest_category_tabs.add_child(completed_quests_tab)
	
	# Failed Quests Tab
	failed_quests_tab = create_quest_tab("FAILED")
	quest_category_tabs.add_child(failed_quests_tab)

func create_quest_tab(tab_name: String) -> Control:
	"""Create a quest category tab"""
	var tab = Control.new()
	tab.name = tab_name
	
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab.add_child(scroll_container)
	
	var quest_container = VBoxContainer.new()
	quest_container.name = "QuestContainer"
	quest_container.add_theme_constant_override("separation", 5)
	scroll_container.add_child(quest_container)
	
	return tab

func style_tab_container(tab_container: TabContainer):
	"""Apply neon green style to tab container"""
	# Tab bar style
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = darker_bg
	tab_style.border_color = neon_green
	tab_style.border_width_bottom = 2
	tab_style.corner_radius_top_left = 6
	tab_style.corner_radius_top_right = 6
	tab_container.add_theme_stylebox_override("tab_selected", tab_style)
	
	var tab_unselected = StyleBoxFlat.new()
	tab_unselected.bg_color = Color(darker_bg.r, darker_bg.g, darker_bg.b, 0.5)
	tab_unselected.border_color = neon_green
	tab_unselected.border_width_bottom = 1
	tab_container.add_theme_stylebox_override("tab_unselected", tab_unselected)
	
	# Tab font colors
	tab_container.add_theme_color_override("font_selected_color", neon_green)
	tab_container.add_theme_color_override("font_unselected_color", Color.GRAY)
	tab_container.add_theme_font_size_override("font_size", 14)

func create_quest_details_panel():
	"""Create quest details panel"""
	quest_details_panel = Panel.new()
	quest_details_panel.name = "QuestDetailsPanel"
	quest_details_panel.custom_minimum_size = Vector2(500, 500)
	main_container.add_child(quest_details_panel)
	
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
	quest_details_panel.add_theme_stylebox_override("panel", panel_style)
	
	create_quest_details_content()

func create_quest_details_content():
	"""Create quest details content"""
	var details_scroll = ScrollContainer.new()
	details_scroll.name = "DetailsScrollContainer"
	details_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_scroll.add_theme_constant_override("margin_left", 15)
	details_scroll.add_theme_constant_override("margin_right", 15)
	details_scroll.add_theme_constant_override("margin_top", 15)
	details_scroll.add_theme_constant_override("margin_bottom", 15)
	quest_details_panel.add_child(details_scroll)
	
	var details_container = VBoxContainer.new()
	details_container.name = "DetailsContainer"
	details_container.add_theme_constant_override("separation", 15)
	details_scroll.add_child(details_container)
	
	# Quest title
	quest_title_label = Label.new()
	quest_title_label.name = "QuestTitle"
	quest_title_label.text = "Select a Quest"
	quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_title_label.add_theme_color_override("font_color", neon_green)
	quest_title_label.add_theme_font_size_override("font_size", 24)
	quest_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_container.add_child(quest_title_label)
	
	# Quest timer (for time-limited quests)
	quest_timer_label = Label.new()
	quest_timer_label.name = "QuestTimer"
	quest_timer_label.text = ""
	quest_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_timer_label.add_theme_color_override("font_color", Color.ORANGE)
	quest_timer_label.add_theme_font_size_override("font_size", 16)
	quest_timer_label.visible = false
	details_container.add_child(quest_timer_label)
	
	# Quest progress bar
	quest_progress_bar = ProgressBar.new()
	quest_progress_bar.name = "QuestProgress"
	quest_progress_bar.custom_minimum_size = Vector2(0, 20)
	quest_progress_bar.visible = false
	style_progress_bar(quest_progress_bar)
	details_container.add_child(quest_progress_bar)
	
	# Quest description
	var desc_label = Label.new()
	desc_label.text = "DESCRIPTION"
	desc_label.add_theme_color_override("font_color", neon_green)
	desc_label.add_theme_font_size_override("font_size", 16)
	details_container.add_child(desc_label)
	
	quest_description_label = RichTextLabel.new()
	quest_description_label.name = "QuestDescription"
	quest_description_label.custom_minimum_size = Vector2(0, 100)
	quest_description_label.bbcode_enabled = true
	quest_description_label.fit_content = true
	quest_description_label.add_theme_color_override("default_color", Color.LIGHT_GRAY)
	quest_description_label.add_theme_font_size_override("normal_font_size", 14)
	details_container.add_child(quest_description_label)
	
	# Objectives section
	var objectives_label = Label.new()
	objectives_label.text = "OBJECTIVES"
	objectives_label.add_theme_color_override("font_color", neon_green)
	objectives_label.add_theme_font_size_override("font_size", 16)
	details_container.add_child(objectives_label)
	
	objectives_container = VBoxContainer.new()
	objectives_container.name = "ObjectivesContainer"
	objectives_container.add_theme_constant_override("separation", 8)
	details_container.add_child(objectives_container)
	
	# Rewards section
	var rewards_label = Label.new()
	rewards_label.text = "REWARDS"
	rewards_label.add_theme_color_override("font_color", neon_green)
	rewards_label.add_theme_font_size_override("font_size", 16)
	details_container.add_child(rewards_label)
	
	rewards_container = VBoxContainer.new()
	rewards_container.name = "RewardsContainer"
	rewards_container.add_theme_constant_override("separation", 5)
	details_container.add_child(rewards_container)

func style_progress_bar(progress_bar: ProgressBar):
	"""Style progress bar with neon green theme"""
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_color = neon_green
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = neon_green
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func create_header_controls():
	"""Create header controls for quest list"""
	var header = VBoxContainer.new()
	header.name = "HeaderControls"
	header.custom_minimum_size = Vector2(0, 60)
	header.add_theme_constant_override("separation", 5)
	
	# Position header at top of quest list panel
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.offset_bottom = 60
	header.offset_left = 10
	header.offset_right = -10
	header.offset_top = 10
	
	quest_list_panel.add_child(header)
	
	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	header.add_child(title_row)
	
	var title_label = Label.new()
	title_label.text = "QUEST JOURNAL"
	title_label.add_theme_color_override("font_color", neon_green)
	title_label.add_theme_font_size_override("font_size", 18)
	title_row.add_child(title_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	
	# Controls row
	var controls_row = HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	header.add_child(controls_row)
	
	# Search box
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search quests..."
	search_box.custom_minimum_size = Vector2(150, 25)
	search_box.text_changed.connect(_on_search_changed)
	style_line_edit(search_box)
	controls_row.add_child(search_box)
	
	# Filter options
	filter_options = OptionButton.new()
	filter_options.custom_minimum_size = Vector2(100, 25)
	filter_options.add_item("All")
	filter_options.add_item("Main")
	filter_options.add_item("Side")
	filter_options.add_item("Daily")
	filter_options.item_selected.connect(_on_filter_changed)
	style_option_button(filter_options)
	controls_row.add_child(filter_options)
	
	# Sort options
	sort_options = OptionButton.new()
	sort_options.custom_minimum_size = Vector2(100, 25)
	sort_options.add_item("Priority")
	sort_options.add_item("Level")
	sort_options.add_item("Progress")
	sort_options.add_item("Name")
	sort_options.item_selected.connect(_on_sort_changed)
	style_option_button(sort_options)
	controls_row.add_child(sort_options)

func style_line_edit(line_edit: LineEdit):
	"""Apply neon green style to line edit"""
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
	"""Apply neon green style to option button"""
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

func setup_connections():
	"""Setup event connections"""
	if event_bus:
		event_bus.connect("quest_started", _on_quest_started)
		event_bus.connect("quest_completed", _on_quest_completed)
		event_bus.connect("quest_failed", _on_quest_failed)
		event_bus.connect("quest_objective_completed", _on_objective_completed)
		event_bus.connect("quest_progress_updated", _on_progress_updated)

func show():
	"""Show quest journal"""
	super.show()
	refresh_quest_lists()

func refresh_quest_lists():
	"""Refresh all quest lists"""
	if not quest_system:
		return
	
	refresh_tab_quests("ACTIVE", quest_system.get_active_quests())
	refresh_tab_quests("COMPLETED", quest_system.get_completed_quests())
	refresh_tab_quests("FAILED", quest_system.get_failed_quests())

func refresh_tab_quests(tab_name: String, quests: Array):
	"""Refresh quests in a specific tab"""
	var tab = quest_category_tabs.get_node(tab_name)
	if not tab:
		return
	
	var quest_container = tab.get_node("ScrollContainer/QuestContainer")
	if not quest_container:
		return
	
	# Clear existing quest entries
	for child in quest_container.get_children():
		child.queue_free()
	
	# Add quest entries
	for quest_data in quests:
		if should_show_quest(quest_data):
			var quest_entry = create_quest_entry(quest_data)
			quest_container.add_child(quest_entry)

func should_show_quest(quest_data: Dictionary) -> bool:
	"""Check if quest should be shown based on filters"""
	# Search filter
	var search_text = search_box.text.to_lower()
	if search_text != "":
		var quest_name = quest_data.get("name", "").to_lower()
		if not quest_name.contains(search_text):
			return false
	
	# Type filter
	var filter_index = filter_options.selected
	if filter_index > 0:
		var filter_text = filter_options.get_item_text(filter_index).to_lower()
		var quest_type = quest_data.get("type", "side").to_lower()
		if quest_type != filter_text:
			return false
	
	return true

func create_quest_entry(quest_data: Dictionary) -> Control:
	"""Create a quest entry widget"""
	var entry = Panel.new()
	entry.custom_minimum_size = Vector2(0, 80)
	
	# Style the entry
	var entry_style = StyleBoxFlat.new()
	entry_style.bg_color = Color(darker_bg.r, darker_bg.g, darker_bg.b, 0.5)
	entry_style.border_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.3)
	entry_style.border_width_left = 1
	entry_style.border_width_right = 1
	entry_style.border_width_top = 1
	entry_style.border_width_bottom = 1
	entry_style.corner_radius_top_left = 6
	entry_style.corner_radius_top_right = 6
	entry_style.corner_radius_bottom_left = 6
	entry_style.corner_radius_bottom_right = 6
	entry.add_theme_stylebox_override("panel", entry_style)
	
	# Entry content
	var content_container = VBoxContainer.new()
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.add_theme_constant_override("margin_left", 10)
	content_container.add_theme_constant_override("margin_right", 10)
	content_container.add_theme_constant_override("margin_top", 8)
	content_container.add_theme_constant_override("margin_bottom", 8)
	content_container.add_theme_constant_override("separation", 5)
	entry.add_child(content_container)
	
	# Top row - Quest name and level
	var top_row = HBoxContainer.new()
	content_container.add_child(top_row)
	
	var quest_name = Label.new()
	quest_name.text = quest_data.get("name", "Unknown Quest")
	quest_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status = quest_data.get("status", "active")
	var name_color = status_colors.get(status, Color.WHITE)
	quest_name.add_theme_color_override("font_color", name_color)
	quest_name.add_theme_font_size_override("font_size", 14)
	top_row.add_child(quest_name)
	
	var quest_level = Label.new()
	var required_level = quest_data.get("required_level", 1)
	quest_level.text = "Lv. " + str(required_level)
	quest_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quest_level.add_theme_color_override("font_color", Color.GRAY)
	quest_level.add_theme_font_size_override("font_size", 12)
	top_row.add_child(quest_level)
	
	# Middle row - Description
	var description = Label.new()
	var desc_text = quest_data.get("description", "")
	if desc_text.length() > 60:
		desc_text = desc_text.substr(0, 57) + "..."
	description.text = desc_text
	description.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	description.add_theme_font_size_override("font_size", 11)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(description)
	
	# Bottom row - Progress and type
	var bottom_row = HBoxContainer.new()
	content_container.add_child(bottom_row)
	
	# Progress indicator
	if status == "active":
		var progress = calculate_quest_progress(quest_data)
		var progress_label = Label.new()
		progress_label.text = "Progress: " + str(int(progress * 100)) + "%"
		progress_label.add_theme_color_override("font_color", neon_green)
		progress_label.add_theme_font_size_override("font_size", 10)
		bottom_row.add_child(progress_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)
	
	# Quest type
	var type_label = Label.new()
	var quest_type = quest_data.get("type", "side").to_upper()
	type_label.text = quest_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_label.add_theme_color_override("font_color", Color.ORANGE)
	type_label.add_theme_font_size_override("font_size", 10)
	bottom_row.add_child(type_label)
	
	# Make entry clickable
	entry.gui_input.connect(_on_quest_entry_clicked.bind(quest_data))
	entry.mouse_entered.connect(_on_quest_entry_hovered.bind(entry, true))
	entry.mouse_exited.connect(_on_quest_entry_hovered.bind(entry, false))
	
	return entry

func calculate_quest_progress(quest_data: Dictionary) -> float:
	"""Calculate quest completion progress"""
	var objectives = quest_data.get("objectives", [])
	if objectives.is_empty():
		return 0.0
	
	var completed_objectives = 0
	for objective in objectives:
		if objective.get("completed", false):
			completed_objectives += 1
	
	return float(completed_objectives) / float(objectives.size())

func _on_quest_entry_clicked(quest_data: Dictionary, event: InputEvent):
	"""Handle quest entry click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_quest(quest_data)

func _on_quest_entry_hovered(entry: Panel, is_hovered: bool):
	"""Handle quest entry hover"""
	var style = entry.get_theme_stylebox("panel").duplicate()
	if is_hovered:
		style.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.1)
		style.border_color = neon_green
	else:
		style.bg_color = Color(darker_bg.r, darker_bg.g, darker_bg.b, 0.5)
		style.border_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.3)
	entry.add_theme_stylebox_override("panel", style)

func select_quest(quest_data: Dictionary):
	"""Select and display quest details"""
	selected_quest = quest_data
	update_quest_details(quest_data)

func update_quest_details(quest_data: Dictionary):
	"""Update quest details panel"""
	if quest_data.is_empty():
		quest_title_label.text = "Select a Quest"
		quest_description_label.text = ""
		quest_progress_bar.visible = false
		quest_timer_label.visible = false
		clear_objectives()
		clear_rewards()
		return
	
	# Update title
	quest_title_label.text = quest_data.get("name", "Unknown Quest")
	
	# Update timer for time-limited quests
	var time_limit = quest_data.get("time_limit", 0)
	if time_limit > 0:
		var remaining_time = quest_data.get("remaining_time", time_limit)
		quest_timer_label.text = "Time Remaining: " + format_time(remaining_time)
		quest_timer_label.visible = true
	else:
		quest_timer_label.visible = false
	
	# Update progress bar
	var status = quest_data.get("status", "active")
	if status == "active":
		var progress = calculate_quest_progress(quest_data)
		quest_progress_bar.value = progress * 100
		quest_progress_bar.visible = true
	else:
		quest_progress_bar.visible = false
	
	# Update description
	quest_description_label.text = quest_data.get("description", "No description available.")
	
	# Update objectives
	update_objectives_display(quest_data.get("objectives", []))
	
	# Update rewards
	update_rewards_display(quest_data.get("rewards", {}))

func clear_objectives():
	"""Clear objectives display"""
	for child in objectives_container.get_children():
		child.queue_free()

func update_objectives_display(objectives: Array):
	"""Update objectives display"""
	clear_objectives()
	
	for i in range(objectives.size()):
		var objective = objectives[i]
		var objective_entry = create_objective_entry(objective, i + 1)
		objectives_container.add_child(objective_entry)

func create_objective_entry(objective: Dictionary, index: int) -> Control:
	"""Create objective entry widget"""
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 10)
	
	# Objective index/checkbox
	var checkbox = CheckBox.new()
	checkbox.text = str(index)
	checkbox.button_pressed = objective.get("completed", false)
	checkbox.disabled = true
	style_checkbox(checkbox)
	entry.add_child(checkbox)
	
	# Objective description and progress
	var desc_container = VBoxContainer.new()
	desc_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(desc_container)
	
	# Description
	var description = Label.new()
	description.text = objective.get("description", "Unknown objective")
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if objective.get("completed", false):
		description.add_theme_color_override("font_color", Color.GRAY)
	else:
		description.add_theme_color_override("font_color", Color.WHITE)
	description.add_theme_font_size_override("font_size", 13)
	desc_container.add_child(description)
	
	# Progress (if applicable)
	var current = objective.get("current", 0)
	var target = objective.get("target", 1)
	if target > 1:
		var progress_label = Label.new()
		progress_label.text = "Progress: " + str(current) + " / " + str(target)
		progress_label.add_theme_color_override("font_color", neon_green)
		progress_label.add_theme_font_size_override("font_size", 11)
		desc_container.add_child(progress_label)
	
	return entry

func style_checkbox(checkbox: CheckBox):
	"""Style checkbox with neon theme"""
	# Checkbox icon styles would need custom textures
	checkbox.add_theme_color_override("font_color", Color.WHITE)
	checkbox.add_theme_font_size_override("font_size", 12)

func clear_rewards():
	"""Clear rewards display"""
	for child in rewards_container.get_children():
		child.queue_free()

func update_rewards_display(rewards: Dictionary):
	"""Update rewards display"""
	clear_rewards()
	
	# Experience reward
	if rewards.has("experience"):
		var exp_reward = create_reward_entry("Experience", str(rewards.experience) + " XP")
		rewards_container.add_child(exp_reward)
	
	# Gold reward
	if rewards.has("gold"):
		var gold_reward = create_reward_entry("Gold", str(rewards.gold) + "g")
		rewards_container.add_child(gold_reward)
	
	# Item rewards
	if rewards.has("items"):
		var items = rewards.items
		for item in items:
			var item_name = item.get("name", "Unknown Item")
			var item_count = item.get("count", 1)
			var item_text = item_name
			if item_count > 1:
				item_text += " x" + str(item_count)
			var item_reward = create_reward_entry("Item", item_text)
			rewards_container.add_child(item_reward)

func create_reward_entry(reward_type: String, reward_text: String) -> Control:
	"""Create reward entry widget"""
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 10)
	
	# Reward icon placeholder
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.color = neon_green
	entry.add_child(icon)
	
	# Reward type
	var type_label = Label.new()
	type_label.text = reward_type + ":"
	type_label.custom_minimum_size = Vector2(80, 0)
	type_label.add_theme_color_override("font_color", Color.GRAY)
	type_label.add_theme_font_size_override("font_size", 12)
	entry.add_child(type_label)
	
	# Reward value
	var value_label = Label.new()
	value_label.text = reward_text
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_color_override("font_color", neon_green)
	value_label.add_theme_font_size_override("font_size", 12)
	entry.add_child(value_label)
	
	return entry

func format_time(seconds: float) -> String:
	"""Format time for display"""
	var hours = int(seconds) / 3600
	var minutes = (int(seconds) % 3600) / 60
	var secs = int(seconds) % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%02d:%02d" % [minutes, secs]

# Filter and Sort Handlers
func _on_search_changed(search_text: String):
	"""Handle search text change"""
	refresh_quest_lists()

func _on_filter_changed(index: int):
	"""Handle filter change"""
	refresh_quest_lists()

func _on_sort_changed(index: int):
	"""Handle sort change"""
	refresh_quest_lists()

# Quest System Event Handlers
func _on_quest_started(quest_id: String):
	"""Handle quest started event"""
	refresh_quest_lists()

func _on_quest_completed(quest_id: String):
	"""Handle quest completed event"""
	refresh_quest_lists()

func _on_quest_failed(quest_id: String):
	"""Handle quest failed event"""
	refresh_quest_lists()

func _on_objective_completed(quest_id: String, objective_index: int):
	"""Handle objective completed event"""
	if selected_quest.get("id") == quest_id:
		# Refresh details if currently viewing this quest
		if quest_system:
			var updated_quest = quest_system.get_quest(quest_id)
			if updated_quest:
				update_quest_details(updated_quest)
	refresh_quest_lists()

func _on_progress_updated(quest_id: String):
	"""Handle quest progress update"""
	if selected_quest.get("id") == quest_id:
		# Refresh details if currently viewing this quest
		if quest_system:
			var updated_quest = quest_system.get_quest(quest_id)
			if updated_quest:
				update_quest_details(updated_quest)

# Input Handling
func _input(event):
	"""Handle input events"""
	if visible and event.is_action_pressed("ui_cancel"):
		if ui_manager:
			ui_manager.close_quest_journal()

# Debug Functions
func debug_populate_test_quests():
	"""Debug: Populate with test quests"""
	if not quest_system:
		return
	
	var test_quests = [
		{
			"id": "main_001",
			"name": "The Ancient Artifact",
			"type": "main",
			"description": "Seek the legendary artifact hidden deep within the Shadowmere Caverns. Ancient texts speak of its power to restore balance to the realm.",
			"required_level": 5,
			"status": "active",
			"objectives": [
				{"description": "Enter Shadowmere Caverns", "completed": true, "current": 1, "target": 1},
				{"description": "Defeat the Guardian", "completed": false, "current": 0, "target": 1},
				{"description": "Retrieve the artifact", "completed": false, "current": 0, "target": 1}
			],
			"rewards": {
				"experience": 1500,
				"gold": 250,
				"items": [{"name": "Mystic Blade", "count": 1}]
			}
		},
		{
			"id": "side_001",
			"name": "Lost Merchant's Goods",
			"type": "side",
			"description": "Help recover stolen goods for the merchant Aldric.",
			"required_level": 3,
			"status": "active",
			"objectives": [
				{"description": "Find the bandits' hideout", "completed": true, "current": 1, "target": 1},
				{"description": "Recover stolen items", "completed": false, "current": 2, "target": 5}
			],
			"rewards": {
				"experience": 500,
				"gold": 100
			}
		}
	]
	
	# Add test quests to system and refresh display
	for quest in test_quests:
		if quest_system:
			quest_system.start_quest(quest.id)
	
	refresh_quest_lists()