extends Control

class_name DialogueUI

# Main panels
@onready var dialogue_panel: Panel
@onready var speaker_panel: Panel
@onready var choice_panel: Panel

# Speaker section
var speaker_portrait: TextureRect
var speaker_name_label: Label
var speaker_background: Panel

# Dialogue section
var dialogue_text: RichTextLabel
var dialogue_background: Panel
var continue_indicator: Label

# Choice section
var choice_container: VBoxContainer
var choice_buttons: Array[Button] = []

# Animation and effects
var text_tween: Tween
var choice_tween: Tween
var panel_tween: Tween

# Text animation
var current_text: String = ""
var displayed_text: String = ""
var text_speed: float = 0.03
var is_text_animating: bool = false

# Dialogue history
var dialogue_history: Array[Dictionary] = []
var history_panel: Panel
var history_container: VBoxContainer
var show_history: bool = false

# Style
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var dark_bg: Color = Color(0.0, 0.1, 0.05, 0.95)
var darker_bg: Color = Color(0.0, 0.05, 0.025, 0.98)
var speaker_bg: Color = Color(0.05, 0.15, 0.1, 0.9)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var dialogue_system: DialogueSystem = get_node("/root/DialogueSystem")
@onready var ui_manager: UIManager

# Current dialogue state
var current_dialogue: Dictionary = {}
var current_node: Dictionary = {}

func _ready():
	setup_dialogue_ui()
	setup_connections()
	setup_animations()
	print("[DialogueUI] Interface de DiÃ¡logo inicializada")

func setup_dialogue_ui():
# Setup dialogue UI layout
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find UI manager
	ui_manager = get_parent().get_parent()
	
	create_dialogue_panel()
	create_speaker_section()
	create_dialogue_section()
	create_choice_section()
	create_history_panel()

func create_dialogue_panel():
# Create main dialogue panel
	dialogue_panel = Panel.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.anchor_left = 0.1
	dialogue_panel.anchor_right = 0.9
	dialogue_panel.anchor_top = 0.6
	dialogue_panel.anchor_bottom = 0.95
	add_child(dialogue_panel)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = dark_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.4)
	panel_style.shadow_size = 8
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)

func create_speaker_section():
# Create speaker information section
	speaker_panel = Panel.new()
	speaker_panel.name = "SpeakerPanel"
	speaker_panel.anchor_left = 0.05
	speaker_panel.anchor_right = 0.35
	speaker_panel.anchor_top = 0.4
	speaker_panel.anchor_bottom = 0.65
	add_child(speaker_panel)
	
	# Style speaker panel
	var speaker_style = StyleBoxFlat.new()
	speaker_style.bg_color = speaker_bg
	speaker_style.border_color = neon_green
	speaker_style.border_width_left = 2
	speaker_style.border_width_right = 2
	speaker_style.border_width_top = 2
	speaker_style.border_width_bottom = 2
	speaker_style.corner_radius_top_left = 10
	speaker_style.corner_radius_top_right = 10
	speaker_style.corner_radius_bottom_left = 10
	speaker_style.corner_radius_bottom_right = 10
	speaker_panel.add_theme_stylebox_override("panel", speaker_style)
	
	# Speaker content container
	var speaker_container = VBoxContainer.new()
	speaker_container.name = "SpeakerContainer"
	speaker_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speaker_container.add_theme_constant_override("margin_left", 15)
	speaker_container.add_theme_constant_override("margin_right", 15)
	speaker_container.add_theme_constant_override("margin_top", 15)
	speaker_container.add_theme_constant_override("margin_bottom", 15)
	speaker_container.add_theme_constant_override("separation", 10)
	speaker_container.alignment = BoxContainer.ALIGNMENT_CENTER
	speaker_panel.add_child(speaker_container)
	
	# Speaker portrait
	speaker_portrait = TextureRect.new()
	speaker_portrait.name = "SpeakerPortrait"
	speaker_portrait.custom_minimum_size = Vector2(128, 128)
	speaker_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	speaker_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	speaker_container.add_child(speaker_portrait)
	
	# Speaker name
	speaker_name_label = Label.new()
	speaker_name_label.name = "SpeakerName"
	speaker_name_label.text = ""
	speaker_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_name_label.add_theme_color_override("font_color", neon_green)
	speaker_name_label.add_theme_font_size_override("font_size", 18)
	speaker_container.add_child(speaker_name_label)

func create_dialogue_section():
# Create dialogue text section
	# Dialogue text container
	var dialogue_container = VBoxContainer.new()
	dialogue_container.name = "DialogueContainer"
	dialogue_container.anchor_left = 0.02
	dialogue_container.anchor_right = 0.98
	dialogue_container.anchor_top = 0.1
	dialogue_container.anchor_bottom = 0.7
	dialogue_container.add_theme_constant_override("separation", 10)
	dialogue_panel.add_child(dialogue_container)
	
	# Dialogue text background
	dialogue_background = Panel.new()
	dialogue_background.name = "DialogueBackground"
	dialogue_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_container.add_child(dialogue_background)
	
	var dialogue_bg_style = StyleBoxFlat.new()
	dialogue_bg_style.bg_color = darker_bg
	dialogue_bg_style.border_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.5)
	dialogue_bg_style.border_width_left = 1
	dialogue_bg_style.border_width_right = 1
	dialogue_bg_style.border_width_top = 1
	dialogue_bg_style.border_width_bottom = 1
	dialogue_bg_style.corner_radius_top_left = 8
	dialogue_bg_style.corner_radius_top_right = 8
	dialogue_bg_style.corner_radius_bottom_left = 8
	dialogue_bg_style.corner_radius_bottom_right = 8
	dialogue_background.add_theme_stylebox_override("panel", dialogue_bg_style)
	
	# Dialogue text
	dialogue_text = RichTextLabel.new()
	dialogue_text.name = "DialogueText"
	dialogue_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_text.add_theme_constant_override("margin_left", 20)
	dialogue_text.add_theme_constant_override("margin_right", 20)
	dialogue_text.add_theme_constant_override("margin_top", 15)
	dialogue_text.add_theme_constant_override("margin_bottom", 15)
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = true
	dialogue_text.scroll_active = false
	dialogue_text.add_theme_color_override("default_color", Color.WHITE)
	dialogue_text.add_theme_font_size_override("normal_font_size", 16)
	dialogue_background.add_child(dialogue_text)
	
	# Continue indicator
	continue_indicator = Label.new()
	continue_indicator.name = "ContinueIndicator"
	continue_indicator.text = "Press SPACE to continue..."
	continue_indicator.anchor_left = 1.0
	continue_indicator.anchor_right = 1.0
	continue_indicator.anchor_top = 1.0
	continue_indicator.anchor_bottom = 1.0
	continue_indicator.offset_left = -200
	continue_indicator.offset_top = -30
	continue_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_indicator.add_theme_color_override("font_color", neon_green)
	continue_indicator.add_theme_font_size_override("font_size", 12)
	continue_indicator.modulate.a = 0.7
	dialogue_container.add_child(continue_indicator)
	
	# Animate continue indicator
	animate_continue_indicator()

func create_choice_section():
# Create choice buttons section
	choice_panel = Panel.new()
	choice_panel.name = "ChoicePanel"
	choice_panel.anchor_left = 0.02
	choice_panel.anchor_right = 0.98
	choice_panel.anchor_top = 0.75
	choice_panel.anchor_bottom = 0.95
	choice_panel.visible = false
	dialogue_panel.add_child(choice_panel)
	
	# Style choice panel
	var choice_style = StyleBoxFlat.new()
	choice_style.bg_color = Color(darker_bg.r, darker_bg.g, darker_bg.b, 0.8)
	choice_style.border_color = neon_green
	choice_style.border_width_left = 1
	choice_style.border_width_right = 1
	choice_style.border_width_top = 2
	choice_style.border_width_bottom = 1
	choice_style.corner_radius_top_left = 8
	choice_style.corner_radius_top_right = 8
	choice_style.corner_radius_bottom_left = 8
	choice_style.corner_radius_bottom_right = 8
	choice_panel.add_theme_stylebox_override("panel", choice_style)
	
	# Choice container
	var choice_scroll = ScrollContainer.new()
	choice_scroll.name = "ChoiceScrollContainer"
	choice_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_scroll.add_theme_constant_override("margin_left", 15)
	choice_scroll.add_theme_constant_override("margin_right", 15)
	choice_scroll.add_theme_constant_override("margin_top", 10)
	choice_scroll.add_theme_constant_override("margin_bottom", 10)
	choice_panel.add_child(choice_scroll)
	
	choice_container = VBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.add_theme_constant_override("separation", 8)
	choice_scroll.add_child(choice_container)

func create_history_panel():
# Create dialogue history panel
	history_panel = Panel.new()
	history_panel.name = "HistoryPanel"
	history_panel.anchor_left = 0.05
	history_panel.anchor_right = 0.95
	history_panel.anchor_top = 0.1
	history_panel.anchor_bottom = 0.55
	history_panel.visible = false
	add_child(history_panel)
	
	# Style history panel
	var history_style = StyleBoxFlat.new()
	history_style.bg_color = Color(dark_bg.r, dark_bg.g, dark_bg.b, 0.95)
	history_style.border_color = neon_green
	history_style.border_width_left = 2
	history_style.border_width_right = 2
	history_style.border_width_top = 2
	history_style.border_width_bottom = 2
	history_style.corner_radius_top_left = 10
	history_style.corner_radius_top_right = 10
	history_style.corner_radius_bottom_left = 10
	history_style.corner_radius_bottom_right = 10
	history_panel.add_theme_stylebox_override("panel", history_style)
	
	# History title
	var history_title = Label.new()
	history_title.text = "DIALOGUE HISTORY"
	history_title.anchor_left = 0.5
	history_title.anchor_right = 0.5
	history_title.offset_left = -100
	history_title.offset_right = 100
	history_title.offset_top = 10
	history_title.offset_bottom = 30
	history_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_title.add_theme_color_override("font_color", neon_green)
	history_title.add_theme_font_size_override("font_size", 16)
	history_panel.add_child(history_title)
	
	# History scroll
	var history_scroll = ScrollContainer.new()
	history_scroll.anchor_top = 0.1
	history_scroll.anchor_bottom = 1.0
	history_scroll.anchor_left = 0.0
	history_scroll.anchor_right = 1.0
	history_scroll.offset_left = 15
	history_scroll.offset_right = -15
	history_scroll.offset_bottom = -15
	history_panel.add_child(history_scroll)
	
	history_container = VBoxContainer.new()
	history_container.name = "HistoryContainer"
	history_container.add_theme_constant_override("separation", 10)
	history_scroll.add_child(history_container)

func setup_connections():
# Setup event connections
	if event_bus:
		event_bus.connect("dialogue_started", _on_dialogue_started)
		event_bus.connect("dialogue_ended", _on_dialogue_ended)
		event_bus.connect("dialogue_choice_made", _on_choice_made)

func setup_animations():
# Setup animation systems
	text_tween = create_tween()
	choice_tween = create_tween()
	panel_tween = create_tween()

func open():
# Show dialogue UI with animation (renomeado de show)
	super.show()
	animate_show()

func close():
# Hide dialogue UI with animation (renomeado de hide)
	animate_hide()

func animate_show():
# Animate dialogue UI appearance
	if not panel_tween:
		return
	
	# Start with panels off-screen
	dialogue_panel.position.y = get_viewport().size.y
	speaker_panel.position.x = -speaker_panel.size.x
	
	# Animate panels into position
	panel_tween.parallel().tween_property(dialogue_panel, "position:y", 0, 0.4)
	panel_tween.parallel().tween_property(speaker_panel, "position:x", 0, 0.3)

func animate_hide():
# Animate dialogue UI disappearance
	if not panel_tween:
		super.hide()
		return
	
	# Animate panels out
	panel_tween.tween_property(dialogue_panel, "position:y", get_viewport().size.y, 0.3)
	panel_tween.tween_callback(func(): super.hide())

func animate_continue_indicator():
# Animate continue indicator blinking
	if not continue_indicator:
		return
	
	var indicator_tween = create_tween()
	indicator_tween.set_loops()
	indicator_tween.tween_property(continue_indicator, "modulate:a", 0.3, 1.0)
	indicator_tween.tween_property(continue_indicator, "modulate:a", 0.9, 1.0)

func start_dialogue(dialogue_data: Dictionary):
# Start a new dialogue
	current_dialogue = dialogue_data
	
	# Reset state
	dialogue_history.clear()
	clear_choices()
	
	# Show UI
	show()
	
	# Start with first node
	var start_node = dialogue_data.get("start_node", "")
	if start_node != "":
		display_dialogue_node(start_node)

func display_dialogue_node(node_id: String):
# Display a specific dialogue node
	if not current_dialogue.has("nodes"):
		end_dialogue()
		return
	
	var nodes = current_dialogue.nodes
	if not nodes.has(node_id):
		end_dialogue()
		return
	
	current_node = nodes[node_id]
	
	# Update speaker info
	update_speaker_display()
	
	# Display dialogue text with animation
	var text = current_node.get("text", "")
	display_text_animated(text)
	
	# Add to history
	add_to_history(current_node.get("speaker", ""), text)
	
	# Handle choices or continue options
	handle_node_options()

func update_speaker_display():
# Update speaker portrait and name
	var speaker_name = current_node.get("speaker", "Unknown")
	speaker_name_label.text = speaker_name
	
	# Load speaker portrait if available
	var portrait_path = current_node.get("portrait", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		speaker_portrait.texture = load(portrait_path)
	else:
		speaker_portrait.texture = null

func display_text_animated(text: String):
# Display text with typewriter animation
	current_text = text
	displayed_text = ""
	is_text_animating = true
	
	# Clear existing text
	dialogue_text.text = ""
	
	# Hide continue indicator during animation
	continue_indicator.visible = false
	
	# Start text animation
	animate_text()

func animate_text():
# Animate text appearance character by character
	if not text_tween:
		dialogue_text.text = current_text
		is_text_animating = false
		continue_indicator.visible = true
		return
	
	# Calculate animation duration based on text length
	var duration = current_text.length() * text_speed
	
	# Animate text reveal
	text_tween.tween_method(update_text_display, 0, current_text.length(), duration)
	text_tween.tween_callback(finish_text_animation)

func update_text_display(char_count: int):
# Update displayed text during animation
	displayed_text = current_text.substr(0, char_count)
	dialogue_text.text = displayed_text
	
	# Play typing sound effect
	if event_bus and char_count % 3 == 0:  # Play sound every few characters
		EventBus.play_sound("dialogue_type")

func finish_text_animation():
# Finish text animation
	dialogue_text.text = current_text
	is_text_animating = false
	continue_indicator.visible = true

func skip_text_animation():
# Skip text animation and show full text
	if is_text_animating:
		if text_tween:
			text_tween.kill()
		dialogue_text.text = current_text
		is_text_animating = false
		continue_indicator.visible = true

func handle_node_options():
# Handle node choices or continuation
	var choices = current_node.get("choices", [])
	
	if choices.is_empty():
		# No choices - show continue indicator
		show_continue_option()
	else:
		# Show choice buttons
		show_choices(choices)

func show_continue_option():
# Show continue option for single-path dialogue
	choice_panel.visible = false
	continue_indicator.visible = true

func show_choices(choices: Array):
# Show choice buttons
	clear_choices()
	choice_panel.visible = true
	continue_indicator.visible = false
	
	for i in range(choices.size()):
		var choice = choices[i]
		var choice_button = create_choice_button(choice, i)
		choice_container.add_child(choice_button)
		choice_buttons.append(choice_button)
	
	# Animate choices appearing
	animate_choices_in()

func create_choice_button(choice: Dictionary, index: int) -> Button:
# Create a choice button
	var button = Button.new()
	button.text = str(index + 1) + ". " + choice.get("text", "...")
	button.custom_minimum_size = Vector2(0, 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Check if choice is available
	var available = is_choice_available(choice)
	button.disabled = not available
	
	# Style the button
	style_choice_button(button, available)
	
	# Connect signal
	button.pressed.connect(_on_choice_selected.bind(index))
	button.mouse_entered.connect(_on_choice_hovered.bind(button))
	
	return button

func style_choice_button(button: Button, available: bool):
# Style choice button
	var normal_style = StyleBoxFlat.new()
	var hover_style = StyleBoxFlat.new()
	var pressed_style = StyleBoxFlat.new()
	
	if available:
		# Available choice styling
		normal_style.bg_color = darker_bg
		normal_style.border_color = neon_green
		hover_style.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.2)
		hover_style.border_color = Color.WHITE
		pressed_style.bg_color = neon_green
		
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.BLACK)
	else:
		# Unavailable choice styling
		normal_style.bg_color = Color(darker_bg.r, darker_bg.g, darker_bg.b, 0.5)
		normal_style.border_color = Color.GRAY
		hover_style = normal_style.duplicate()
		pressed_style = normal_style.duplicate()
		
		button.add_theme_color_override("font_color", Color.GRAY)
		button.add_theme_color_override("font_disabled_color", Color.GRAY)
	
	# Apply border and corner styling
	for style in [normal_style, hover_style, pressed_style]:
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", normal_style)
	
	button.add_theme_font_size_override("font_size", 14)

func is_choice_available(choice: Dictionary) -> bool:
# Check if a choice is available based on conditions
	var conditions = choice.get("conditions", [])
	
	for condition in conditions:
		if not evaluate_condition(condition):
			return false
	
	return true

func evaluate_condition(condition: Dictionary) -> bool:
# Evaluate a dialogue condition
	var type = condition.get("type", "")
	
	match type:
		"variable":
			var var_name = condition.get("variable", "")
			var operator = condition.get("operator", "==")
			var value = condition.get("value")
			var current_value = dialogue_system.get_variable(var_name)
			return compare_values(current_value, operator, value)
		
		"quest":
			var quest_id = condition.get("quest_id", "")
			var status = condition.get("status", "completed")
			return game_state.is_quest_status(quest_id, status)
		
		"item":
			var item_id = condition.get("item_id", "")
			var count = condition.get("count", 1)
			return game_state.has_item(item_id, count)
		
		"level":
			var required_level = condition.get("level", 1)
			return game_state.player_stats.current_level >= required_level
		
		_:
			return true

func compare_values(value1, operator: String, value2) -> bool:
# Compare two values based on operator
	match operator:
		"==": return value1 == value2
		"!=": return value1 != value2
		">": return value1 > value2
		"<": return value1 < value2
		">=": return value1 >= value2
		"<=": return value1 <= value2
		_: return false

func animate_choices_in():
# Animate choice buttons appearing
	if not choice_tween:
		return
	
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		button.modulate.a = 0.0
		button.scale = Vector2(0.8, 0.8)
		
		var delay = i * 0.1
		choice_tween.parallel().tween_delay(delay)
		choice_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.3)
		choice_tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.3)

func clear_choices():
# Clear all choice buttons
	for button in choice_buttons:
		if button:
			button.queue_free()
	choice_buttons.clear()

func add_to_history(speaker: String, text: String):
# Add dialogue to history
	dialogue_history.append({
		"speaker": speaker,
		"text": text,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	# Keep history limited
	if dialogue_history.size() > 50:
		dialogue_history.pop_front()

func show_dialogue_history():
# Show dialogue history panel
	if show_history:
		return
	
	show_history = true
	refresh_history_display()
	history_panel.visible = true

func hide_dialogue_history():
# Hide dialogue history panel
	show_history = false
	history_panel.visible = false

func refresh_history_display():
# Refresh history panel content
	# Clear existing history
	for child in history_container.get_children():
		child.queue_free()
	
	# Add history entries
	for entry in dialogue_history:
		var history_entry = create_history_entry(entry)
		history_container.add_child(history_entry)

func create_history_entry(entry: Dictionary) -> Control:
# Create history entry widget
	var entry_container = VBoxContainer.new()
	entry_container.add_theme_constant_override("separation", 5)
	
	# Speaker name
	var speaker_label = Label.new()
	speaker_label.text = entry.get("speaker", "Unknown")
	speaker_label.add_theme_color_override("font_color", neon_green)
	speaker_label.add_theme_font_size_override("font_size", 14)
	entry_container.add_child(speaker_label)
	
	# Dialogue text
	var text_label = RichTextLabel.new()
	text_label.text = entry.get("text", "")
	text_label.custom_minimum_size = Vector2(0, 60)
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.add_theme_color_override("default_color", Color.LIGHT_GRAY)
	text_label.add_theme_font_size_override("normal_font_size", 12)
	entry_container.add_child(text_label)
	
	# Separator
	var separator = HSeparator.new()
	separator.add_theme_color_override("separator", Color(neon_green.r, neon_green.g, neon_green.b, 0.3))
	entry_container.add_child(separator)
	
	return entry_container

func end_dialogue():
# End current dialogue
	current_dialogue.clear()
	current_node.clear()
	
	# Hide UI
	hide()
	
	# Emit dialogue ended event
	if event_bus:
		event_bus.emit_signal("dialogue_ended")

# Event Handlers
func _on_dialogue_started(dialogue_id: String):
# Handle dialogue started event
	if dialogue_system:
		var dialogue_data = dialogue_system.get_dialogue(dialogue_id)
		if dialogue_data:
			start_dialogue(dialogue_data)

func _on_dialogue_ended():
# Handle dialogue ended event
	hide()

func _on_choice_selected(choice_index: int):
# Handle choice selection
	if choice_index >= current_node.get("choices", []).size():
		return
	
	var choice = current_node.choices[choice_index]
	
	# Execute choice actions
	execute_choice_actions(choice.get("actions", []))
	
	# Move to next node
	var next_node = choice.get("next_node", "")
	if next_node == "END":
		end_dialogue()
	elif next_node != "":
		display_dialogue_node(next_node)
	else:
		end_dialogue()
	
	# Emit choice event
	if event_bus:
		event_bus.emit_signal("dialogue_choice_made", choice_index, choice)

func _on_choice_made(choice_index: int, choice: Dictionary):
# Handle choice made event
	pass  # Already handled in _on_choice_selected

func _on_choice_hovered(button: Button):
# Handle choice hover
	if event_bus:
		EventBus.play_sound("button_hover")

func execute_choice_actions(actions: Array):
# Execute actions from dialogue choice
	for action in actions:
		execute_dialogue_action(action)

func execute_dialogue_action(action: Dictionary):
# Execute a dialogue action
	var type = action.get("type", "")
	
	match type:
		"set_variable":
			var var_name = action.get("variable", "")
			var value = action.get("value")
			dialogue_system.set_variable(var_name, value)
		
		"give_item":
			var item_id = action.get("item_id", "")
			var count = action.get("count", 1)
			game_state.add_item(item_id, count)
		
		"give_experience":
			var exp = action.get("amount", 0)
			game_state.player_stats.add_experience(exp)
		
		"start_quest":
			var quest_id = action.get("quest_id", "")
			game_state.start_quest(quest_id)
		
		"complete_quest":
			var quest_id = action.get("quest_id", "")
			game_state.complete_quest(quest_id)

# Input Handling
func _input(event):
# Handle input events
	if not visible:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if is_text_animating:
			skip_text_animation()
		elif choice_panel.visible:
			# Do nothing - player should click choice buttons
			pass
		else:
			# Continue to next node or end dialogue
			continue_dialogue()
	
	elif event.is_action_pressed("ui_cancel"):
		if show_history:
			hide_dialogue_history()
		else:
			end_dialogue()
	
	elif event.is_action_pressed("dialogue_history"):  # Custom action for history
		if show_history:
			hide_dialogue_history()
		else:
			show_dialogue_history()

func continue_dialogue():
# Continue dialogue to next node
	var next_node = current_node.get("next_node", "")
	if next_node == "END" or next_node == "":
		end_dialogue()
	else:
		display_dialogue_node(next_node)

# Debug Functions
func debug_start_test_dialogue():
# Debug: Start test dialogue
	var test_dialogue = {
		"id": "test_dialogue",
		"title": "Test Dialogue",
		"start_node": "greeting",
		"nodes": {
			"greeting": {
				"speaker": "Mysterious Stranger",
				"text": "Greetings, traveler. What brings you to these dark lands?",
				"portrait": "",
				"choices": [
					{
						"text": "I'm searching for ancient artifacts.",
						"next_node": "artifacts",
						"conditions": [],
						"actions": [{"type": "set_variable", "variable": "met_stranger", "value": true}]
					},
					{
						"text": "Just passing through.",
						"next_node": "passing",
						"conditions": [],
						"actions": []
					},
					{
						"text": "That's none of your business.",
						"next_node": "rude",
						"conditions": [],
						"actions": [{"type": "set_variable", "variable": "stranger_angry", "value": true}]
					}
				]
			},
			"artifacts": {
				"speaker": "Mysterious Stranger",
				"text": "Ah, a scholar! I may have information that could help you... for a price.",
				"next_node": "END"
			},
			"passing": {
				"speaker": "Mysterious Stranger", 
				"text": "Safe travels, stranger. These roads are dangerous at night.",
				"next_node": "END"
			},
			"rude": {
				"speaker": "Mysterious Stranger",
				"text": "Such hostility... Very well, keep your secrets.",
				"next_node": "END"
			}
		}
	}
	
	start_dialogue(test_dialogue)
