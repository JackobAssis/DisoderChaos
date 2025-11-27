extends Control
class_name GameHUD
# game_hud.gd - In-game HUD with health, mana, inventory, and combat log

# Health and Mana bars
@onready var health_bar: ProgressBar
@onready var mana_bar: ProgressBar
@onready var health_label: Label
@onready var mana_label: Label

# Player info
@onready var level_label: Label
@onready var exp_bar: ProgressBar

# Quick item slot
@onready var quick_item_button: Button
@onready var quick_item_icon: TextureRect

# Combat log
@onready var combat_log: RichTextLabel
@onready var combat_log_container: ScrollContainer

# Notification system
@onready var notification_label: Label
var notification_timer: Timer

# Minimap placeholder
@onready var minimap: Control

# Pause menu button
@onready var menu_button: Button

func _ready():
	setup_hud()
	connect_signals()
	update_all_displays()

func setup_hud():
# Setup HUD layout and components
	
	# Main HUD container
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Top-left: Player stats
	create_player_stats_panel()
	
	# Bottom-right: Quick item
	create_quick_item_panel()
	
	# Bottom-left: Combat log
	create_combat_log_panel()
	
	# Top-center: Notifications
	create_notification_panel()
	
	# Top-right: Menu button
	create_menu_panel()
	
	# Setup notification timer
	notification_timer = Timer.new()
	notification_timer.timeout.connect(_on_notification_timeout)
	notification_timer.one_shot = true
	add_child(notification_timer)

func create_player_stats_panel():
# Create player health/mana/level display
	var stats_panel = VBoxContainer.new()
	stats_panel.position = Vector2(20, 20)
	stats_panel.custom_minimum_size = Vector2(250, 120)
	add_child(stats_panel)
	
	# Health bar
	var health_container = HBoxContainer.new()
	stats_panel.add_child(health_container)
	
	var health_text = Label.new()
	health_text.text = "HP:"
	health_text.custom_minimum_size.x = 30
	health_container.add_child(health_text)
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(150, 25)
	health_bar.show_percentage = false
	health_container.add_child(health_bar)
	
	health_label = Label.new()
	health_label.text = "100/100"
	health_label.custom_minimum_size.x = 60
	health_container.add_child(health_label)
	
	# Mana bar
	var mana_container = HBoxContainer.new()
	stats_panel.add_child(mana_container)
	
	var mana_text = Label.new()
	mana_text.text = "MP:"
	mana_text.custom_minimum_size.x = 30
	mana_container.add_child(mana_text)
	
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(150, 25)
	mana_bar.show_percentage = false
	mana_container.add_child(mana_bar)
	
	mana_label = Label.new()
	mana_label.text = "50/50"
	mana_label.custom_minimum_size.x = 60
	mana_container.add_child(mana_label)
	
	# Experience bar
	var exp_container = HBoxContainer.new()
	stats_panel.add_child(exp_container)
	
	level_label = Label.new()
	level_label.text = "Lv 1"
	level_label.custom_minimum_size.x = 40
	exp_container.add_child(level_label)
	
	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(150, 20)
	exp_bar.show_percentage = false
	exp_container.add_child(exp_bar)

func create_quick_item_panel():
# Create quick use item slot
	var quick_panel = VBoxContainer.new()
	quick_panel.position = Vector2(1100, 600)
	quick_panel.custom_minimum_size = Vector2(80, 100)
	add_child(quick_panel)
	
	var quick_label = Label.new()
	quick_label.text = "Quick Item"
	quick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_panel.add_child(quick_label)
	
	quick_item_button = Button.new()
	quick_item_button.custom_minimum_size = Vector2(64, 64)
	quick_item_button.flat = true
	quick_panel.add_child(quick_item_button)
	
	# Add icon to button
	quick_item_icon = TextureRect.new()
	quick_item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	quick_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quick_item_button.add_child(quick_item_icon)
	
	var key_hint = Label.new()
	key_hint.text = "[E]"
	key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_panel.add_child(key_hint)

func create_combat_log_panel():
# Create combat log display
	combat_log_container = ScrollContainer.new()
	combat_log_container.position = Vector2(20, 500)
	combat_log_container.custom_minimum_size = Vector2(400, 180)
	combat_log_container.scroll_horizontal_enabled = false
	add_child(combat_log_container)
	
	combat_log = RichTextLabel.new()
	combat_log.bbcode_enabled = true
	combat_log.scroll_following = true
	combat_log.fit_content = true
	combat_log_container.add_child(combat_log)
	
	# Add background panel
	var log_bg = Panel.new()
	log_bg.position = combat_log_container.position - Vector2(5, 5)
	log_bg.size = combat_log_container.size + Vector2(10, 10)
	log_bg.modulate = Color(0, 0, 0, 0.7)
	add_child(log_bg)
	# Move background behind log
	move_child(log_bg, get_child_count() - 2)

func create_notification_panel():
# Create notification display
	notification_label = Label.new()
	notification_label.position = Vector2(640, 50)
	notification_label.custom_minimum_size = Vector2(400, 50)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 18)
	notification_label.visible = false
	add_child(notification_label)

func create_menu_panel():
# Create menu access button
	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.position = Vector2(1180, 20)
	menu_button.custom_minimum_size = Vector2(80, 30)
	add_child(menu_button)

func connect_signals():
# Connect to EventBus signals
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.player_mp_changed.connect(_on_player_mp_changed)
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.combat_log_updated.connect(_on_combat_log_updated)
	EventBus.ui_notification_shown.connect(_on_notification_shown)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.heal_applied.connect(_on_heal_applied)
	
	# Button connections
	quick_item_button.pressed.connect(_on_quick_item_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func update_all_displays():
# Update all HUD elements with current game state
	var player_data = GameState.get_player_data()
	
	# Update health/mana
	_on_player_hp_changed(player_data.current_hp, player_data.max_hp)
	_on_player_mp_changed(player_data.current_mp, player_data.max_mp)
	
	# Update level
	level_label.text = "Lv " + str(player_data.level)
	
	# Update experience bar
	var current_exp = player_data.experience
	var required_exp = GameState.get_required_experience_for_level(player_data.level + 1)
	var level_start_exp = GameState.get_required_experience_for_level(player_data.level)
	
	exp_bar.max_value = required_exp - level_start_exp
	exp_bar.value = current_exp - level_start_exp
	
	# Update quick item (if any)
	update_quick_item_display()

func update_quick_item_display():
# Update quick item slot display
	# TODO: Implement when inventory system is complete
	quick_item_icon.texture = null
	quick_item_button.text = "Empty"

# Signal handlers
func _on_player_hp_changed(current_hp: int, max_hp: int):
# Update health bar
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_label.text = str(current_hp) + "/" + str(max_hp)
	
	# Change color based on health percentage
	var health_percent = float(current_hp) / float(max_hp)
	if health_percent > 0.6:
		health_bar.modulate = Color.GREEN
	elif health_percent > 0.3:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func _on_player_mp_changed(current_mp: int, max_mp: int):
# Update mana bar
	mana_bar.max_value = max_mp
	mana_bar.value = current_mp
	mana_label.text = str(current_mp) + "/" + str(max_mp)

func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
# Handle level up display
	level_label.text = "Lv " + str(level)
	
	# Show level up notification
	show_notification("LEVEL UP! +" + str(hp_gain) + " HP, +" + str(mp_gain) + " MP", "success")
	
	# Update experience bar
	var player_data = GameState.get_player_data()
	var required_exp = GameState.get_required_experience_for_level(level + 1)
	var level_start_exp = GameState.get_required_experience_for_level(level)
	
	exp_bar.max_value = required_exp - level_start_exp
	exp_bar.value = player_data.experience - level_start_exp

func _on_combat_log_updated(message: String):
# Add message to combat log
	var timestamp = "[color=gray]" + Time.get_time_string_from_system() + "[/color] "
	combat_log.append_text(timestamp + message + "\n")
	
	# Limit log size (keep last 50 lines)
	var text_lines = combat_log.get_parsed_text().split("\n")
	if text_lines.size() > 50:
		var new_text = ""
		for i in range(text_lines.size() - 50, text_lines.size()):
			new_text += text_lines[i] + "\n"
		combat_log.clear()
		combat_log.append_text(new_text)

func _on_damage_dealt(attacker: String, target: String, amount: int, damage_type):
# Handle damage dealt event
	var color = "white"
	var type_text = ""
	
	match damage_type:
		0:  # Physical
			color = "orange"
			type_text = ""
		1:  # Magical
			color = "lightblue"
			type_text = " (magical)"
		2:  # True
			color = "red"
			type_text = " (true)"
	
	var message = "[color=" + color + "]" + attacker + " deals " + str(amount) + " damage" + type_text + " to " + target + "[/color]"
	_on_combat_log_updated(message)

func _on_heal_applied(target: Node, amount: int):
# Handle heal applied event
	var target_name = "Unknown"
	if target.has_method("get_display_name"):
		target_name = target.get_display_name()
	elif "name" in target:
		target_name = target.name
	
	var message = "[color=green]" + target_name + " healed for " + str(amount) + " HP[/color]"
	_on_combat_log_updated(message)

func _on_notification_shown(message: String, type: String):
# Show notification message
	show_notification(message, type)

func show_notification(message: String, type: String = "info"):
# Display a temporary notification
	var color = Color.WHITE
	
	match type:
		"success":
			color = Color.GREEN
		"warning":
			color = Color.YELLOW
		"error":
			color = Color.RED
		_:
			color = Color.WHITE
	
	notification_label.text = message
	notification_label.modulate = color
	notification_label.visible = true
	
	# Auto-hide after 3 seconds
	notification_timer.wait_time = 3.0
	notification_timer.start()

func _on_notification_timeout():
# Hide notification after timeout
	notification_label.visible = false

func _on_quick_item_pressed():
# Handle quick item button press
	# Simulate using quick item
	EventBus.show_notification("Quick item used!", "info")

func _on_menu_button_pressed():
# Handle menu button press
	# TODO: Open pause/settings menu
	EventBus.show_notification("Menu not yet implemented!", "warning")

# Input handling
func _input(event):
# Handle HUD-specific input
	if event.is_action_pressed("use_item"):
		_on_quick_item_pressed()

# Utility functions
func set_quick_item(item_id: String):
# Set the quick use item
	var item_data = DataLoader.get_item(item_id)
	if item_data:
		# TODO: Set item icon and update display
		quick_item_button.text = item_data.name
		show_notification("Quick item set to: " + item_data.name, "info")

func flash_health_bar():
# Flash health bar when taking damage
	var tween = create_tween()
	tween.tween_property(health_bar, "modulate", Color.RED, 0.1)
	tween.tween_property(health_bar, "modulate", Color.WHITE, 0.1)

func flash_mana_bar():
# Flash mana bar when using skills
	var tween = create_tween()
	tween.tween_property(mana_bar, "modulate", Color.BLUE, 0.1)
	tween.tween_property(mana_bar, "modulate", Color.WHITE, 0.1)

# Debug functions (only in debug builds)
func add_debug_panel():
# Add debug information panel
	if not OS.is_debug_build():
		return
	
	var debug_panel = VBoxContainer.new()
	debug_panel.position = Vector2(20, 200)
	add_child(debug_panel)
	
	var debug_label = Label.new()
	debug_label.text = "DEBUG INFO"
	debug_panel.add_child(debug_label)
	
	# Add debug info updates in _process if needed

# TODO: Future enhancements
# - Inventory panel integration
# - Skill hotbar with cooldown displays
# - Minimap with dungeon layout
# - Quest tracker integration
# - Status effect display
# - Damage number animations
# - Equipment durability indicators
# - Group/party member health bars
