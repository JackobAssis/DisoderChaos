extends Control

class_name MainHUD

# HUD Components
@onready var health_bar: ProgressBar
@onready var stamina_bar: ProgressBar
@onready var xp_bar: ProgressBar
@onready var mana_bar: ProgressBar  # Placeholder
@onready var buff_container: HBoxContainer
@onready var quickslot_container: HBoxContainer
@onready var dungeon_info: Label
@onready var level_label: Label
@onready var currency_label: Label

# Animation and Effects
var health_tween: Tween
var stamina_tween: Tween
var xp_tween: Tween
var notification_tween: Tween

# Buff system
var active_buffs: Dictionary = {} # buff_id -> BuffIcon
var buff_icons_pool: Array[Control] = []

# Quick slots
var quickslots: Array[QuickSlot] = []
var max_quickslots: int = 6

# Style colors
var health_color: Color = Color.RED
var stamina_color: Color = Color.YELLOW
var mana_color: Color = Color.BLUE
var xp_color: Color = Color(0.0, 1.0, 0.549, 1.0) # Neon green
var low_health_color: Color = Color(1.0, 0.3, 0.3, 1.0)

# References
var player_stats: PlayerStats
var game_state: GameState

func _ready():
	if not player_stats:
		await get_tree().process_frame
		game_state = get_node("/root/GameState")
		player_stats = game_state.player_stats
	
	create_hud_layout()
	setup_animations()
	print("[MainHUD] HUD Principal inicializada")

func initialize(stats: PlayerStats):
# Initialize HUD with player stats
	player_stats = stats
	if player_stats:
		update_all_bars()

func create_hud_layout():
# Create the HUD layout programmatically
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Top-left area for vital bars
	create_vital_bars()
	
	# Top-right area for level and currency
	create_info_panel()
	
	# Bottom area for quickslots and buffs
	create_bottom_panel()
	
	# Center-top for dungeon info
	create_dungeon_info()

func create_vital_bars():
# Create health, stamina, mana, and XP bars
	var vital_container = VBoxContainer.new()
	vital_container.name = "VitalContainer"
	vital_container.position = Vector2(20, 20)
	vital_container.custom_minimum_size = Vector2(300, 120)
	add_child(vital_container)
	
	# Health Bar
	var health_container = create_bar_container("Health")
	health_bar = create_progress_bar(health_color)
	health_container.add_child(health_bar)
	vital_container.add_child(health_container)
	
	# Stamina Bar
	var stamina_container = create_bar_container("Stamina")
	stamina_bar = create_progress_bar(stamina_color)
	stamina_container.add_child(stamina_bar)
	vital_container.add_child(stamina_container)
	
	# Mana Bar (Placeholder)
	var mana_container = create_bar_container("Mana")
	mana_bar = create_progress_bar(mana_color)
	mana_bar.modulate.a = 0.5  # Semi-transparent as placeholder
	mana_container.add_child(mana_bar)
	vital_container.add_child(mana_container)
	
	# XP Bar
	var xp_container = create_bar_container("Experience")
	xp_bar = create_progress_bar(xp_color)
	xp_container.add_child(xp_bar)
	vital_container.add_child(xp_container)

func create_bar_container(label_text: String) -> VBoxContainer:
# Create a container for a progress bar with label
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(300, 25)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(label)
	
	return container

func create_progress_bar(bar_color: Color) -> ProgressBar:
# Create a styled progress bar
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, 20)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	
	# Apply custom style
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color.BLACK
	style_bg.border_color = bar_color
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = bar_color
	style_fill.corner_radius_top_left = 3
	style_fill.corner_radius_top_right = 3
	style_fill.corner_radius_bottom_left = 3
	style_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", style_fill)
	
	return bar

func create_info_panel():
# Create level and currency info panel
	var info_panel = VBoxContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.offset_left = -200
	info_panel.offset_top = 20
	info_panel.offset_right = -20
	info_panel.offset_bottom = 80
	add_child(info_panel)
	
	# Level Label
	level_label = Label.new()
	level_label.text = "Level 1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_color_override("font_color", xp_color)
	level_label.add_theme_font_size_override("font_size", 18)
	info_panel.add_child(level_label)
	
	# Currency Label
	currency_label = Label.new()
	currency_label.text = "Gold: 0"
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currency_label.add_theme_color_override("font_color", Color.YELLOW)
	currency_label.add_theme_font_size_override("font_size", 14)
	info_panel.add_child(currency_label)

func create_bottom_panel():
# Create bottom panel for quickslots and buffs
	var bottom_container = HBoxContainer.new()
	bottom_container.name = "BottomPanel"
	bottom_container.anchor_left = 0.5
	bottom_container.anchor_right = 0.5
	bottom_container.anchor_top = 1.0
	bottom_container.anchor_bottom = 1.0
	bottom_container.offset_left = -250
	bottom_container.offset_right = 250
	bottom_container.offset_top = -100
	bottom_container.offset_bottom = -20
	add_child(bottom_container)
	
	# Quickslot Container
	quickslot_container = HBoxContainer.new()
	quickslot_container.name = "QuickSlots"
	quickslot_container.custom_minimum_size = Vector2(300, 60)
	bottom_container.add_child(quickslot_container)
	
	# Create quickslots
	for i in range(max_quickslots):
		var quickslot = create_quickslot(i)
		quickslots.append(quickslot)
		quickslot_container.add_child(quickslot)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(50, 10)
	bottom_container.add_child(spacer)
	
	# Buff Container
	buff_container = HBoxContainer.new()
	buff_container.name = "BuffContainer"
	buff_container.custom_minimum_size = Vector2(150, 60)
	bottom_container.add_child(buff_container)

func create_quickslot(index: int) -> Control:
# Create a quickslot
	var quickslot = Control.new()
	quickslot.name = "QuickSlot_" + str(index)
	quickslot.custom_minimum_size = Vector2(48, 48)
	
	# Background panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quickslot.add_child(panel)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_color = xp_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	
	# Keybind label
	var keybind_label = Label.new()
	keybind_label.text = str(index + 1)
	keybind_label.anchor_left = 0.0
	keybind_label.anchor_right = 0.0
	keybind_label.anchor_top = 0.0
	keybind_label.anchor_bottom = 0.0
	keybind_label.offset_left = 2
	keybind_label.offset_top = 2
	keybind_label.offset_right = 15
	keybind_label.offset_bottom = 15
	keybind_label.add_theme_color_override("font_color", Color.WHITE)
	keybind_label.add_theme_font_size_override("font_size", 10)
	quickslot.add_child(keybind_label)
	
	return quickslot

func create_dungeon_info():
# Create dungeon information display
	dungeon_info = Label.new()
	dungeon_info.name = "DungeonInfo"
	dungeon_info.anchor_left = 0.5
	dungeon_info.anchor_right = 0.5
	dungeon_info.offset_left = -150
	dungeon_info.offset_right = 150
	dungeon_info.offset_top = 20
	dungeon_info.offset_bottom = 40
	dungeon_info.text = "Tutorial Dungeon"
	dungeon_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dungeon_info.add_theme_color_override("font_color", xp_color)
	dungeon_info.add_theme_font_size_override("font_size", 16)
	add_child(dungeon_info)

func setup_animations():
# Setup animation tweens (Godot 4 create_tween pattern)
	health_tween = create_tween()
	stamina_tween = create_tween()
	xp_tween = create_tween()
	notification_tween = create_tween()

# Update Functions
func update_health(current: int, maximum: int):
# Update health bar
	if not health_bar:
		return
	
	var percentage = (float(current) / float(maximum)) * 100.0
	var target_value = clampf(percentage, 0.0, 100.0)
	
	# Animate health change
	if health_tween:
		health_tween.tween_property(health_bar, "value", target_value, 0.3)
	else:
		health_bar.value = target_value
	
	# Change color based on health level
	var bar_color = health_color
	if percentage < 25:
		bar_color = low_health_color
	elif percentage < 50:
		bar_color = Color.ORANGE
	
	update_bar_color(health_bar, bar_color)

func update_stamina(current: float, maximum: float):
# Update stamina bar
	if not stamina_bar:
		return
	
	var percentage = (current / maximum) * 100.0
	var target_value = clampf(percentage, 0.0, 100.0)
	
	# Animate stamina change
	if stamina_tween:
		stamina_tween.tween_property(stamina_bar, "value", target_value, 0.2)
	else:
		stamina_bar.value = target_value

func update_xp(current: int, required: int, level: int):
# Update XP bar and level
	if not xp_bar:
		return
	
	var percentage = (float(current) / float(required)) * 100.0 if required > 0 else 0.0
	var target_value = clampf(percentage, 0.0, 100.0)
	
	# Animate XP change
	if xp_tween:
		xp_tween.tween_property(xp_bar, "value", target_value, 0.5)
	else:
		xp_bar.value = target_value
	
	# Update level label
	if level_label:
		level_label.text = "Level " + str(level)

func update_currency(amount: int):
# Update currency display
	if currency_label:
		currency_label.text = "Gold: " + str(amount)

func update_dungeon_name(dungeon_name: String):
# Update dungeon name display
	if dungeon_info:
		dungeon_info.text = dungeon_name

func update_bar_color(bar: ProgressBar, color: Color):
# Update progress bar color
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = color
	style_fill.corner_radius_top_left = 3
	style_fill.corner_radius_top_right = 3
	style_fill.corner_radius_bottom_left = 3
	style_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", style_fill)

func update_all_bars():
# Update all bars with current player stats
	if not player_stats:
		return
	
	update_health(player_stats.current_health, player_stats.max_health)
	update_stamina(player_stats.current_stamina, player_stats.max_stamina)
	update_xp(player_stats.experience, player_stats.get_xp_for_next_level(), player_stats.current_level)
	
	if game_state:
		update_currency(game_state.currency)

# Notification System
func show_xp_gain(amount: int):
# Show XP gain notification
	var notification = create_floating_text("+" + str(amount) + " XP", xp_color)
	show_floating_notification(notification, Vector2(0, -30))

func show_damage_taken(amount: int):
# Show damage taken notification
	var notification = create_floating_text("-" + str(amount), Color.RED)
	show_floating_notification(notification, Vector2(-50, -20))

func show_healing(amount: int):
# Show healing notification
	var notification = create_floating_text("+" + str(amount), Color.GREEN)
	show_floating_notification(notification, Vector2(-50, -20))

func create_floating_text(text: String, color: Color) -> Label:
# Create floating text notification
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.z_index = 100
	return label

func show_floating_notification(notification: Label, offset: Vector2):
# Show floating notification with animation
	var start_pos = Vector2(size.x * 0.5, size.y * 0.4) + offset
	notification.position = start_pos
	add_child(notification)
	
	# Animate the notification
	if notification_tween:
		var end_pos = start_pos + Vector2(0, -60)
		notification_tween.parallel().tween_property(notification, "position", end_pos, 2.0)
		notification_tween.parallel().tween_property(notification, "modulate:a", 0.0, 2.0)
		notification_tween.tween_callback(notification.queue_free)

# Buff System
func add_buff_icon(buff_id: String, duration: float):
# Add buff icon to display
	if active_buffs.has(buff_id):
		# Update existing buff duration
		active_buffs[buff_id].update_duration(duration)
		return
	
	var buff_icon = create_buff_icon(buff_id, duration)
	if buff_icon:
		active_buffs[buff_id] = buff_icon
		buff_container.add_child(buff_icon)

func remove_buff_icon(buff_id: String):
# Remove buff icon
	if active_buffs.has(buff_id):
		var buff_icon = active_buffs[buff_id]
		buff_icon.queue_free()
		active_buffs.erase(buff_id)

func create_buff_icon(buff_id: String, duration: float) -> Control:
# Create buff icon control
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(40, 40)
	
	# Background
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_container.add_child(panel)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.2, 0.8)  # Green tint for buff
	style.border_color = xp_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	
	# Duration label
	var duration_label = Label.new()
	duration_label.text = str(int(duration))
	duration_label.anchor_left = 0.5
	duration_label.anchor_right = 0.5
	duration_label.anchor_top = 0.5
	duration_label.anchor_bottom = 0.5
	duration_label.offset_left = -10
	duration_label.offset_right = 10
	duration_label.offset_top = -8
	duration_label.offset_bottom = 8
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	duration_label.add_theme_color_override("font_color", Color.WHITE)
	duration_label.add_theme_font_size_override("font_size", 12)
	icon_container.add_child(duration_label)
	
	# Add update method to buff icon
	icon_container.set_script(preload("res://scripts/ui/hud/BuffIcon.gd") if ResourceLoader.exists("res://scripts/ui/hud/BuffIcon.gd") else null)
	
	return icon_container

# Quick Slot System
func set_quickslot_item(slot_index: int, item_id: String, quantity: int = 1):
# Set item in quickslot
	if slot_index < 0 or slot_index >= quickslots.size():
		return
	
	var quickslot = quickslots[slot_index]
	# Add item display logic here
	print("[MainHUD] Item %s equipped to slot %d" % [item_id, slot_index])

func clear_quickslot(slot_index: int):
# Clear quickslot
	if slot_index < 0 or slot_index >= quickslots.size():
		return
	
	var quickslot = quickslots[slot_index]
	# Clear item display logic here
	print("[MainHUD] Slot %d cleared" % slot_index)

# Utility Functions
func fade_in():
# Fade in the HUD
	modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.5)

func fade_out():
# Fade out the HUD
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)

# Debug Functions
func debug_test_notifications():
# Debug: Test notification system
	show_xp_gain(50)
	await get_tree().create_timer(0.5).timeout
	show_damage_taken(25)
	await get_tree().create_timer(0.5).timeout
	show_healing(15)

func debug_test_buffs():
# Debug: Test buff system
	add_buff_icon("strength", 30.0)
	add_buff_icon("speed", 15.0)
	add_buff_icon("protection", 60.0)
