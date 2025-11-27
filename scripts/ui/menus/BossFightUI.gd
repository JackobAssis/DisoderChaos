extends Control

class_name BossFightUI

# Main components
@onready var boss_info_panel: Panel
@onready var mechanics_panel: Panel
@onready var party_status_panel: Panel
@onready var timer_panel: Panel

# Boss info elements
var boss_name_label: Label
var boss_level_label: Label
var boss_health_bar: ProgressBar
var boss_shield_bar: ProgressBar
var boss_portrait: TextureRect
var boss_threat_indicator: Control

# Mechanics tracking
var mechanics_container: VBoxContainer
var active_mechanics: Dictionary = {} # mechanic_id -> MechanicTracker
var phase_indicator: Label
var enrage_timer: Label

# Party status (if in group)
var party_members_container: VBoxContainer
var party_health_bars: Dictionary = {} # player_id -> ProgressBar

# Timers and alerts
var encounter_timer: Label
var dps_meter: Label
var warning_overlay: Control
var mechanic_alerts: VBoxContainer

# Boss phases and mechanics
var current_boss_data: Dictionary = {}
var encounter_start_time: float = 0.0
var current_phase: int = 1
var active_warnings: Array[Control] = []

# Style
var bg_color: Color = Color(0.1, 0.1, 0.15, 0.9)
var darker_bg: Color = Color(0.05, 0.05, 0.1, 1.0)
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0)
var danger_color: Color = Color(1.0, 0.2, 0.2, 1.0)
var warning_color: Color = Color(1.0, 0.8, 0.0, 1.0)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
var combat_system: CombatSystem
var raid_system: RaidSystem

func _ready():
	setup_boss_fight_ui()
	setup_connections()
	visible = false
	print("[BossFightUI] Interface de Boss Fight inicializada")

func setup_boss_fight_ui():
	"""Setup boss fight UI layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	create_boss_info_panel()
	create_mechanics_panel()
	create_party_status_panel()
	create_timer_panel()
	create_warning_overlay()

func create_boss_info_panel():
	"""Create boss information panel"""
	boss_info_panel = Panel.new()
	boss_info_panel.name = "BossInfoPanel"
	boss_info_panel.anchor_left = 0.25
	boss_info_panel.anchor_right = 0.75
	boss_info_panel.anchor_top = 0.02
	boss_info_panel.anchor_bottom = 0.15
	boss_info_panel.offset_left = 0
	boss_info_panel.offset_right = 0
	boss_info_panel.offset_top = 0
	boss_info_panel.offset_bottom = 0
	
	# Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = danger_color
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	boss_info_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(boss_info_panel)
	
	var info_layout = HBoxContainer.new()
	info_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_layout.add_theme_constant_override("separation", 15)
	boss_info_panel.add_child(info_layout)
	
	# Boss portrait
	boss_portrait = TextureRect.new()
	boss_portrait.custom_minimum_size = Vector2(80, 80)
	boss_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	info_layout.add_child(boss_portrait)
	
	# Boss info
	var boss_info_container = VBoxContainer.new()
	boss_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_info_container.add_theme_constant_override("separation", 5)
	info_layout.add_child(boss_info_container)
	
	# Name and level
	var name_container = HBoxContainer.new()
	name_container.add_theme_constant_override("separation", 10)
	boss_info_container.add_child(name_container)
	
	boss_name_label = Label.new()
	boss_name_label.text = "Boss Name"
	boss_name_label.add_theme_color_override("font_color", danger_color)
	boss_name_label.add_theme_font_size_override("font_size", 24)
	name_container.add_child(boss_name_label)
	
	boss_level_label = Label.new()
	boss_level_label.text = "Lv. ??"
	boss_level_label.add_theme_color_override("font_color", Color.WHITE)
	boss_level_label.add_theme_font_size_override("font_size", 16)
	name_container.add_child(boss_level_label)
	
	# Phase indicator
	phase_indicator = Label.new()
	phase_indicator.text = "Phase 1"
	phase_indicator.add_theme_color_override("font_color", warning_color)
	phase_indicator.add_theme_font_size_override("font_size", 14)
	boss_info_container.add_child(phase_indicator)
	
	# Health bar
	boss_health_bar = create_boss_health_bar()
	boss_info_container.add_child(boss_health_bar)
	
	# Shield bar (optional)
	boss_shield_bar = create_boss_shield_bar()
	boss_shield_bar.visible = false
	boss_info_container.add_child(boss_shield_bar)
	
	# Threat indicator
	create_threat_indicator(info_layout)

func create_boss_health_bar() -> ProgressBar:
	"""Create boss health bar"""
	var health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 25)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	
	# Health bar styling
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color.BLACK
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = danger_color
	health_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Health text overlay
	var health_label = Label.new()
	health_label.text = "100%"
	health_label.anchor_left = 0.5
	health_label.anchor_right = 0.5
	health_label.anchor_top = 0.5
	health_label.anchor_bottom = 0.5
	health_label.offset_left = -30
	health_label.offset_right = 30
	health_label.offset_top = -10
	health_label.offset_bottom = 10
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.add_theme_font_size_override("font_size", 14)
	health_bar.add_child(health_label)
	
	return health_bar

func create_boss_shield_bar() -> ProgressBar:
	"""Create boss shield bar"""
	var shield_bar = ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(0, 15)
	shield_bar.max_value = 100
	shield_bar.value = 0
	shield_bar.show_percentage = false
	
	# Shield bar styling
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color.TRANSPARENT
	shield_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color.CYAN
	shield_bar.add_theme_stylebox_override("fill", fill_style)
	
	return shield_bar

func create_threat_indicator(parent: Control):
	"""Create threat level indicator"""
	boss_threat_indicator = Control.new()
	boss_threat_indicator.name = "ThreatIndicator"
	boss_threat_indicator.custom_minimum_size = Vector2(60, 80)
	parent.add_child(boss_threat_indicator)
	
	var threat_bg = Panel.new()
	threat_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_threat_indicator.add_child(threat_bg)
	
	var threat_style = StyleBoxFlat.new()
	threat_style.bg_color = bg_color
	threat_style.border_color = neon_green
	threat_style.border_width_left = 2
	threat_style.border_width_right = 2
	threat_style.border_width_top = 2
	threat_style.border_width_bottom = 2
	threat_bg.add_theme_stylebox_override("panel", threat_style)
	
	var threat_label = Label.new()
	threat_label.text = "THREAT\nLOW"
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	threat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	threat_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	threat_label.add_theme_color_override("font_color", neon_green)
	threat_label.add_theme_font_size_override("font_size", 12)
	boss_threat_indicator.add_child(threat_label)

func create_mechanics_panel():
	"""Create mechanics tracking panel"""
	mechanics_panel = Panel.new()
	mechanics_panel.name = "MechanicsPanel"
	mechanics_panel.anchor_left = 0.02
	mechanics_panel.anchor_right = 0.25
	mechanics_panel.anchor_top = 0.2
	mechanics_panel.anchor_bottom = 0.7
	
	# Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_color = warning_color
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	mechanics_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(mechanics_panel)
	
	var mechanics_layout = VBoxContainer.new()
	mechanics_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mechanics_layout.add_theme_constant_override("separation", 5)
	mechanics_panel.add_child(mechanics_layout)
	
	var mechanics_header = Label.new()
	mechanics_header.text = "BOSS MECHANICS"
	mechanics_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mechanics_header.add_theme_color_override("font_color", warning_color)
	mechanics_header.add_theme_font_size_override("font_size", 14)
	mechanics_layout.add_child(mechanics_header)
	
	var scroll_container = ScrollContainer.new()
	scroll_container.scroll_horizontal_enabled = false
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mechanics_layout.add_child(scroll_container)
	
	mechanics_container = VBoxContainer.new()
	mechanics_container.add_theme_constant_override("separation", 5)
	scroll_container.add_child(mechanics_container)

func create_party_status_panel():
	"""Create party status panel"""
	party_status_panel = Panel.new()
	party_status_panel.name = "PartyStatusPanel"
	party_status_panel.anchor_left = 0.75
	party_status_panel.anchor_right = 0.98
	party_status_panel.anchor_top = 0.2
	party_status_panel.anchor_bottom = 0.7
	
	# Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_color = neon_green
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	party_status_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(party_status_panel)
	
	var party_layout = VBoxContainer.new()
	party_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_layout.add_theme_constant_override("separation", 5)
	party_status_panel.add_child(party_layout)
	
	var party_header = Label.new()
	party_header.text = "PARTY STATUS"
	party_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_header.add_theme_color_override("font_color", neon_green)
	party_header.add_theme_font_size_override("font_size", 14)
	party_layout.add_child(party_header)
	
	var party_scroll = ScrollContainer.new()
	party_scroll.scroll_horizontal_enabled = false
	party_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_layout.add_child(party_scroll)
	
	party_members_container = VBoxContainer.new()
	party_members_container.add_theme_constant_override("separation", 5)
	party_scroll.add_child(party_members_container)

func create_timer_panel():
	"""Create timer and information panel"""
	timer_panel = Panel.new()
	timer_panel.name = "TimerPanel"
	timer_panel.anchor_left = 0.3
	timer_panel.anchor_right = 0.7
	timer_panel.anchor_top = 0.85
	timer_panel.anchor_bottom = 0.98
	
	# Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = darker_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	timer_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(timer_panel)
	
	var timer_layout = HBoxContainer.new()
	timer_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer_layout.add_theme_constant_override("separation", 20)
	timer_panel.add_child(timer_layout)
	
	# Encounter timer
	var timer_container = VBoxContainer.new()
	timer_container.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_layout.add_child(timer_container)
	
	var timer_header = Label.new()
	timer_header.text = "TIME"
	timer_header.add_theme_color_override("font_color", Color.WHITE)
	timer_header.add_theme_font_size_override("font_size", 12)
	timer_container.add_child(timer_header)
	
	encounter_timer = Label.new()
	encounter_timer.text = "00:00"
	encounter_timer.add_theme_color_override("font_color", neon_green)
	encounter_timer.add_theme_font_size_override("font_size", 18)
	timer_container.add_child(encounter_timer)
	
	# DPS meter
	var dps_container = VBoxContainer.new()
	dps_container.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_layout.add_child(dps_container)
	
	var dps_header = Label.new()
	dps_header.text = "DPS"
	dps_header.add_theme_color_override("font_color", Color.WHITE)
	dps_header.add_theme_font_size_override("font_size", 12)
	dps_container.add_child(dps_header)
	
	dps_meter = Label.new()
	dps_meter.text = "0"
	dps_meter.add_theme_color_override("font_color", warning_color)
	dps_meter.add_theme_font_size_override("font_size", 18)
	dps_container.add_child(dps_meter)
	
	# Enrage timer
	var enrage_container = VBoxContainer.new()
	enrage_container.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_layout.add_child(enrage_container)
	
	var enrage_header = Label.new()
	enrage_header.text = "ENRAGE"
	enrage_header.add_theme_color_override("font_color", Color.WHITE)
	enrage_header.add_theme_font_size_override("font_size", 12)
	enrage_container.add_child(enrage_header)
	
	enrage_timer = Label.new()
	enrage_timer.text = "10:00"
	enrage_timer.add_theme_color_override("font_color", danger_color)
	enrage_timer.add_theme_font_size_override("font_size", 18)
	enrage_container.add_child(enrage_timer)

func create_warning_overlay():
	"""Create warning overlay for mechanics"""
	warning_overlay = Control.new()
	warning_overlay.name = "WarningOverlay"
	warning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(warning_overlay)
	
	# Mechanic alerts container
	mechanic_alerts = VBoxContainer.new()
	mechanic_alerts.name = "MechanicAlerts"
	mechanic_alerts.anchor_left = 0.3
	mechanic_alerts.anchor_right = 0.7
	mechanic_alerts.anchor_top = 0.3
	mechanic_alerts.anchor_bottom = 0.5
	mechanic_alerts.add_theme_constant_override("separation", 10)
	warning_overlay.add_child(mechanic_alerts)

# Boss encounter management
func start_boss_encounter(boss_id: String):
	"""Start boss encounter"""
	current_boss_data = load_boss_data(boss_id)
	if current_boss_data.is_empty():
		print("[BossFightUI] Failed to load boss data: ", boss_id)
		return
	
	visible = true
	encounter_start_time = Time.get_ticks_msec() / 1000.0
	current_phase = 1
	
	setup_boss_display()
	setup_boss_mechanics()
	setup_party_display()
	
	print("[BossFightUI] Boss encounter started: ", boss_id)

func load_boss_data(boss_id: String) -> Dictionary:
	"""Load boss data from JSON"""
	var boss_data = DataLoader.load_json_data("res://data/raids/raid_system.json")
	if not boss_data:
		return {}
	
	# Search for boss in raid data
	for raid_type in boss_data.get("raid_types", {}):
		var raid_info = boss_data.raid_types[raid_type]
		for encounter in raid_info.get("encounters", []):
			if encounter.get("boss_id", "") == boss_id:
				return encounter
	
	return {}

func setup_boss_display():
	"""Setup boss information display"""
	boss_name_label.text = current_boss_data.get("name", "Unknown Boss")
	boss_level_label.text = "Lv. " + str(current_boss_data.get("level", 1))
	phase_indicator.text = "Phase " + str(current_phase)
	
	# Set health bar
	boss_health_bar.value = 100
	update_boss_health_display(100, 100)

func setup_boss_mechanics():
	"""Setup boss mechanics tracking"""
	clear_mechanics_display()
	
	var mechanics = current_boss_data.get("mechanics", [])
	for mechanic in mechanics:
		add_mechanic_tracker(mechanic)

func setup_party_display():
	"""Setup party member displays"""
	clear_party_display()
	
	# Get party members
	var party_members = get_party_members()
	for member in party_members:
		add_party_member_display(member)

func end_boss_encounter(victory: bool):
	"""End boss encounter"""
	visible = false
	clear_all_displays()
	
	var encounter_time = (Time.get_ticks_msec() / 1000.0) - encounter_start_time
	
	if victory:
		event_bus.emit_signal("boss_defeated", current_boss_data.get("boss_id", ""), encounter_time)
	else:
		event_bus.emit_signal("boss_encounter_failed", current_boss_data.get("boss_id", ""))
	
	current_boss_data.clear()

# Display update functions
func update_boss_health(current_hp: float, max_hp: float):
	"""Update boss health display"""
	var percentage = (current_hp / max_hp) * 100.0
	boss_health_bar.value = percentage
	update_boss_health_display(current_hp, max_hp)
	
	# Check for phase transitions
	check_phase_transition(percentage)

func update_boss_health_display(current_hp: float, max_hp: float):
	"""Update health bar text"""
	var health_label = boss_health_bar.get_child(0) as Label
	if health_label:
		var percentage = (current_hp / max_hp) * 100.0
		health_label.text = str(int(percentage)) + "%"

func update_boss_shield(current_shield: float, max_shield: float):
	"""Update boss shield display"""
	if max_shield > 0:
		boss_shield_bar.visible = true
		var percentage = (current_shield / max_shield) * 100.0
		boss_shield_bar.value = percentage
	else:
		boss_shield_bar.visible = false

func check_phase_transition(health_percentage: float):
	"""Check for boss phase transitions"""
	var phase_thresholds = current_boss_data.get("phase_thresholds", [75.0, 50.0, 25.0])
	var new_phase = 1
	
	for i in range(phase_thresholds.size()):
		if health_percentage <= phase_thresholds[i]:
			new_phase = i + 2
	
	if new_phase != current_phase:
		transition_to_phase(new_phase)

func transition_to_phase(new_phase: int):
	"""Transition to new boss phase"""
	current_phase = new_phase
	phase_indicator.text = "Phase " + str(current_phase)
	
	# Show phase transition warning
	show_mechanic_warning("PHASE " + str(current_phase), 3.0, danger_color)
	
	# Update mechanics for new phase
	setup_boss_mechanics()
	
	event_bus.emit_signal("boss_phase_changed", current_phase)

func add_mechanic_tracker(mechanic_data: Dictionary):
	"""Add mechanic tracker to display"""
	var mechanic_id = mechanic_data.get("id", "unknown")
	
	if active_mechanics.has(mechanic_id):
		return
	
	var tracker = create_mechanic_tracker(mechanic_data)
	active_mechanics[mechanic_id] = tracker
	mechanics_container.add_child(tracker)

func create_mechanic_tracker(mechanic_data: Dictionary) -> Control:
	"""Create mechanic tracker control"""
	var tracker_container = VBoxContainer.new()
	tracker_container.add_theme_constant_override("separation", 2)
	
	# Mechanic name
	var name_label = Label.new()
	name_label.text = mechanic_data.get("name", "Unknown Mechanic")
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 12)
	tracker_container.add_child(name_label)
	
	# Cooldown bar
	var cooldown_bar = ProgressBar.new()
	cooldown_bar.custom_minimum_size = Vector2(0, 15)
	cooldown_bar.max_value = mechanic_data.get("cooldown", 30.0)
	cooldown_bar.value = 0
	cooldown_bar.show_percentage = false
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color.BLACK
	cooldown_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = warning_color
	cooldown_bar.add_theme_stylebox_override("fill", fill_style)
	
	tracker_container.add_child(cooldown_bar)
	
	return tracker_container

func update_mechanic_cooldown(mechanic_id: String, time_remaining: float):
	"""Update mechanic cooldown"""
	if not active_mechanics.has(mechanic_id):
		return
	
	var tracker = active_mechanics[mechanic_id]
	var cooldown_bar = tracker.get_child(1) as ProgressBar
	if cooldown_bar:
		cooldown_bar.value = cooldown_bar.max_value - time_remaining
		
		if time_remaining <= 5.0:
			# Warning - mechanic incoming
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = danger_color
			cooldown_bar.add_theme_stylebox_override("fill", fill_style)

func trigger_boss_mechanic(mechanic_id: String, mechanic_data: Dictionary):
	"""Trigger boss mechanic"""
	var mechanic_name = mechanic_data.get("name", mechanic_id)
	var warning_duration = mechanic_data.get("warning_duration", 5.0)
	
	show_mechanic_warning(mechanic_name.to_upper(), warning_duration, danger_color)
	
	# Reset cooldown
	if active_mechanics.has(mechanic_id):
		var tracker = active_mechanics[mechanic_id]
		var cooldown_bar = tracker.get_child(1) as ProgressBar
		if cooldown_bar:
			cooldown_bar.value = 0
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = warning_color
			cooldown_bar.add_theme_stylebox_override("fill", fill_style)

func show_mechanic_warning(text: String, duration: float, color: Color):
	"""Show mechanic warning"""
	var warning = create_warning_display(text, color)
	active_warnings.append(warning)
	mechanic_alerts.add_child(warning)
	
	# Auto-remove after duration
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): remove_warning(warning))
	add_child(timer)
	timer.start()

func create_warning_display(text: String, color: Color) -> Control:
	"""Create warning display control"""
	var warning_panel = Panel.new()
	warning_panel.custom_minimum_size = Vector2(0, 50)
	
	var warning_style = StyleBoxFlat.new()
	warning_style.bg_color = Color(color.r, color.g, color.b, 0.8)
	warning_style.border_color = color
	warning_style.border_width_left = 3
	warning_style.border_width_right = 3
	warning_style.border_width_top = 3
	warning_style.border_width_bottom = 3
	warning_panel.add_theme_stylebox_override("panel", warning_style)
	
	var warning_label = Label.new()
	warning_label.text = text
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning_label.add_theme_color_override("font_color", Color.WHITE)
	warning_label.add_theme_font_size_override("font_size", 20)
	warning_panel.add_child(warning_label)
	
	return warning_panel

func remove_warning(warning: Control):
	"""Remove warning from display"""
	if warning in active_warnings:
		active_warnings.erase(warning)
	warning.queue_free()

func add_party_member_display(member_data: Dictionary):
	"""Add party member health display"""
	var member_id = member_data.get("id", "")
	if member_id == "":
		return
	
	var member_container = VBoxContainer.new()
	member_container.add_theme_constant_override("separation", 2)
	
	# Member name and role
	var name_label = Label.new()
	var member_name = member_data.get("name", "Player")
	var member_role = member_data.get("role", "DPS")
	name_label.text = member_name + " (" + member_role + ")"
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 12)
	member_container.add_child(name_label)
	
	# Health bar
	var health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 20)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color.BLACK
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color.GREEN
	health_bar.add_theme_stylebox_override("fill", fill_style)
	
	member_container.add_child(health_bar)
	party_members_container.add_child(member_container)
	party_health_bars[member_id] = health_bar

func update_party_member_health(member_id: String, current_hp: float, max_hp: float):
	"""Update party member health"""
	if not party_health_bars.has(member_id):
		return
	
	var health_bar = party_health_bars[member_id]
	var percentage = (current_hp / max_hp) * 100.0
	health_bar.value = percentage
	
	# Update color based on health
	var fill_style = StyleBoxFlat.new()
	if percentage > 75:
		fill_style.bg_color = Color.GREEN
	elif percentage > 50:
		fill_style.bg_color = Color.YELLOW
	elif percentage > 25:
		fill_style.bg_color = Color.ORANGE
	else:
		fill_style.bg_color = Color.RED
	
	health_bar.add_theme_stylebox_override("fill", fill_style)

func get_party_members() -> Array:
	"""Get current party members"""
	# TODO: Integrate with party system
	return []

# Clear functions
func clear_mechanics_display():
	"""Clear mechanics display"""
	for tracker in active_mechanics.values():
		tracker.queue_free()
	active_mechanics.clear()

func clear_party_display():
	"""Clear party display"""
	for child in party_members_container.get_children():
		child.queue_free()
	party_health_bars.clear()

func clear_all_displays():
	"""Clear all displays"""
	clear_mechanics_display()
	clear_party_display()
	
	for warning in active_warnings:
		warning.queue_free()
	active_warnings.clear()

# Update loop
func _process(delta):
	"""Update UI elements"""
	if not visible:
		return
	
	update_encounter_timer()
	update_enrage_timer()
	update_mechanics_timers()

func update_encounter_timer():
	"""Update encounter timer"""
	var elapsed_time = (Time.get_ticks_msec() / 1000.0) - encounter_start_time
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	encounter_timer.text = "%02d:%02d" % [minutes, seconds]

func update_enrage_timer():
	"""Update enrage timer"""
	var enrage_time = current_boss_data.get("enrage_timer", 600.0)  # 10 minutes default
	var elapsed_time = (Time.get_ticks_msec() / 1000.0) - encounter_start_time
	var remaining_time = enrage_time - elapsed_time
	
	if remaining_time > 0:
		var minutes = int(remaining_time) / 60
		var seconds = int(remaining_time) % 60
		enrage_timer.text = "%02d:%02d" % [minutes, seconds]
		
		# Change color as time runs low
		if remaining_time < 60:
			enrage_timer.add_theme_color_override("font_color", danger_color)
		elif remaining_time < 120:
			enrage_timer.add_theme_color_override("font_color", warning_color)
	else:
		enrage_timer.text = "ENRAGED"
		enrage_timer.add_theme_color_override("font_color", danger_color)

func update_mechanics_timers():
	"""Update mechanics cooldown timers"""
	# This would be updated by the combat system
	pass

# Setup and connections
func setup_connections():
	"""Setup signal connections"""
	if event_bus:
		event_bus.connect("boss_encounter_started", start_boss_encounter)
		event_bus.connect("boss_encounter_ended", end_boss_encounter)
		event_bus.connect("boss_health_changed", update_boss_health)
		event_bus.connect("boss_shield_changed", update_boss_shield)
		event_bus.connect("boss_mechanic_triggered", trigger_boss_mechanic)
		event_bus.connect("party_member_health_changed", update_party_member_health)

# Input handling
func _input(event):
	"""Handle input events"""
	if visible and event.is_action_pressed("toggle_boss_ui"):
		visible = false