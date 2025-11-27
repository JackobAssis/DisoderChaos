extends Control
class_name HUDController
# hud_controller.gd - Comprehensive HUD management system

@onready var xp_bar: ProgressBar
@onready var health_bar: ProgressBar
@onready var mana_bar: ProgressBar
@onready var level_label: Label
@onready var currency_label: Label
@onready var notification_container: VBoxContainer

# Quick item display
@onready var quick_item_slots: Array[TextureRect]
@onready var quick_item_labels: Array[Label]
@onready var quick_item_cooldowns: Array[ProgressBar]

# Status effect display
@onready var status_effects_container: HBoxContainer

# Minimap
@onready var minimap: Control

# Inventory shortcut
@onready var inventory_button: Button
@onready var settings_button: Button

# Loot pickup notifications
var loot_popup_scene: PackedScene
var active_popups: Array = []

func _ready():
	print("[HUD] HUD Controller initialized")
	setup_hud_elements()
	connect_signals()
	update_all_displays()

func setup_hud_elements():
# Initialize all HUD elements
	# Main bars setup
	setup_main_bars()
	
	# Quick item slots setup
	setup_quick_item_slots()
	
	# Status effects display
	setup_status_effects_display()
	
	# Load loot popup scene
	loot_popup_scene = load("res://ui/popup_notification.tscn")

func setup_main_bars():
# Setup health, mana, and XP bars
	# Find or create health bar
	health_bar = find_child("HealthBar") as ProgressBar
	if not health_bar:
		health_bar = create_progress_bar("health", Color.RED)
		health_bar.position = Vector2(20, 20)
	
	# Find or create mana bar
	mana_bar = find_child("ManaBar") as ProgressBar
	if not mana_bar:
		mana_bar = create_progress_bar("mana", Color.BLUE)
		mana_bar.position = Vector2(20, 50)
	
	# Find or create XP bar
	xp_bar = find_child("XPBar") as ProgressBar
	if not xp_bar:
		xp_bar = create_progress_bar("xp", Color.YELLOW)
		xp_bar.position = Vector2(20, 80)
	
	# Level and currency labels
	level_label = find_child("LevelLabel") as Label
	if not level_label:
		level_label = Label.new()
		level_label.name = "LevelLabel"
		level_label.position = Vector2(200, 20)
		level_label.add_theme_color_override("font_color", Color.WHITE)
		add_child(level_label)
	
	currency_label = find_child("CurrencyLabel") as Label
	if not currency_label:
		currency_label = Label.new()
		currency_label.name = "CurrencyLabel"
		currency_label.position = Vector2(200, 40)
		currency_label.add_theme_color_override("font_color", Color.YELLOW)
		add_child(currency_label)

func create_progress_bar(bar_type: String, color: Color) -> ProgressBar:
# Create a styled progress bar
	var bar = ProgressBar.new()
	bar.name = bar_type.capitalize() + "Bar"
	bar.size = Vector2(150, 20)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	
	# Create custom StyleBox for the bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	bar.add_theme_stylebox_override("fill", style_box)
	
	add_child(bar)
	return bar

func setup_quick_item_slots():
# Setup quick item display slots
	quick_item_slots.clear()
	quick_item_labels.clear()
	quick_item_cooldowns.clear()
	
	var slots_container = find_child("QuickItemsContainer")
	if not slots_container:
		slots_container = HBoxContainer.new()
		slots_container.name = "QuickItemsContainer"
		slots_container.position = Vector2(300, 20)
		add_child(slots_container)
	
	# Create 3 quick item slots
	for i in range(3):
		var slot_container = VBoxContainer.new()
		
		# Item icon slot
		var item_slot = TextureRect.new()
		item_slot.name = "QuickSlot" + str(i)
		item_slot.size = Vector2(32, 32)
		item_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_slot.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent when empty
		
		# Quantity label
		var quantity_label = Label.new()
		quantity_label.name = "QuantityLabel" + str(i)
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity_label.add_theme_color_override("font_color", Color.WHITE)
		quantity_label.add_theme_font_size_override("font_size", 12)
		
		# Cooldown overlay
		var cooldown_bar = ProgressBar.new()
		cooldown_bar.name = "CooldownBar" + str(i)
		cooldown_bar.size = Vector2(32, 4)
		cooldown_bar.max_value = 1.0
		cooldown_bar.value = 0.0
		cooldown_bar.modulate = Color.RED
		cooldown_bar.visible = false
		
		slot_container.add_child(item_slot)
		slot_container.add_child(quantity_label)
		slot_container.add_child(cooldown_bar)
		
		slots_container.add_child(slot_container)
		
		quick_item_slots.append(item_slot)
		quick_item_labels.append(quantity_label)
		quick_item_cooldowns.append(cooldown_bar)

func setup_status_effects_display():
# Setup status effects display area
	status_effects_container = find_child("StatusEffectsContainer") as HBoxContainer
	if not status_effects_container:
		status_effects_container = HBoxContainer.new()
		status_effects_container.name = "StatusEffectsContainer"
		status_effects_container.position = Vector2(20, 120)
		add_child(status_effects_container)

func connect_signals():
# Connect to game events
	# Player data changes
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)
	EventBus.player_xp_gained.connect(_on_player_xp_gained)
	EventBus.player_level_up.connect(_on_player_level_up)
	
	# Item and loot events
	EventBus.item_looted.connect(_on_item_looted)
	EventBus.item_used.connect(_on_item_used)
	EventBus.item_equipped.connect(_on_item_equipped)
	
	# UI notification events
	EventBus.ui_notification_shown.connect(_on_notification_shown)
	
	# Currency changes
	if GameState.player_data_changed.is_connected(_on_player_data_changed):
		GameState.player_data_changed.disconnect(_on_player_data_changed)
	GameState.player_data_changed.connect(_on_player_data_changed)

func update_all_displays():
# Update all HUD displays with current data
	update_health_display()
	update_mana_display()
	update_xp_display()
	update_level_display()
	update_currency_display()
	update_quick_item_displays()

func update_health_display():
# Update health bar display
	if health_bar and GameState.player_data:
		var current_hp = GameState.player_data.get("current_hp", 100)
		var max_hp = GameState.player_data.get("max_hp", 100)
		
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		
		# Add text overlay showing actual values
		var text = str(current_hp) + "/" + str(max_hp)
		health_bar.tooltip_text = "Health: " + text

func update_mana_display():
# Update mana bar display
	if mana_bar and GameState.player_data:
		var current_mp = GameState.player_data.get("current_mp", 100)
		var max_mp = GameState.player_data.get("max_mp", 100)
		
		mana_bar.max_value = max_mp
		mana_bar.value = current_mp
		
		# Add text overlay showing actual values
		var text = str(current_mp) + "/" + str(max_mp)
		mana_bar.tooltip_text = "Mana: " + text

func update_xp_display():
# Update XP bar display
	if xp_bar and GameState.player_data:
		var current_xp = GameState.player_data.get("experience", 0)
		var level = GameState.player_data.get("level", 1)
		var xp_for_current = GameState.get_required_experience_for_level(level)
		var xp_for_next = GameState.get_required_experience_for_level(level + 1)
		
		var xp_in_current_level = current_xp - xp_for_current
		var xp_needed_for_level = xp_for_next - xp_for_current
		
		xp_bar.max_value = xp_needed_for_level
		xp_bar.value = xp_in_current_level
		
		var text = str(xp_in_current_level) + "/" + str(xp_needed_for_level)
		xp_bar.tooltip_text = "Experience: " + text

func update_level_display():
# Update level label
	if level_label and GameState.player_data:
		var level = GameState.player_data.get("level", 1)
		level_label.text = "Level " + str(level)

func update_currency_display():
# Update currency display
	if currency_label and GameState.player_data:
		var currency = GameState.player_data.get("currency", 0)
		currency_label.text = str(currency) + " coins"

func update_quick_item_displays():
# Update quick item slot displays
	if not GameState.player_data.has("quick_items"):
		return
	
	var quick_items = GameState.player_data.quick_items
	
	for i in range(quick_item_slots.size()):
		var item_slot = quick_item_slots[i]
		var quantity_label = quick_item_labels[i]
		
		if i < quick_items.size() and quick_items[i]:
			var item_id = quick_items[i]
			var item_data = DataLoader.get_item(item_id)
			
			if item_data:
				# Set item icon
				var icon_path = item_data.get("icon", "")
				if icon_path != "" and ResourceLoader.exists(icon_path):
					item_slot.texture = load(icon_path)
				else:
					item_slot.texture = null
				
				item_slot.modulate = Color.WHITE
				
				# Set quantity
				var inventory = GameState.player_data.inventory
				var quantity = 0
				for item in inventory:
					if item.id == item_id:
						quantity = item.quantity
						break
				
				quantity_label.text = str(quantity) if quantity > 1 else ""
				
				# Set tooltip
				item_slot.tooltip_text = get_item_tooltip(item_id)
			else:
				# Clear slot
				item_slot.texture = null
				item_slot.modulate = Color(1, 1, 1, 0.7)
				quantity_label.text = ""
				item_slot.tooltip_text = ""
		else:
			# Empty slot
			item_slot.texture = null
			item_slot.modulate = Color(1, 1, 1, 0.7)
			quantity_label.text = ""
			item_slot.tooltip_text = ""

func get_item_tooltip(item_id: String) -> String:
# Get formatted tooltip for item
	var item_system = get_node("/root/ItemSystem")
	if item_system:
		return item_system.get_item_tooltip(item_id)
	
	var item_data = DataLoader.get_item(item_id)
	if item_data:
		return item_data.name + "\n" + item_data.get("description", "")
	
	return "Unknown Item"

func update_status_effects(status_effects: Array):
# Update status effect display
	# Clear existing status effect displays
	for child in status_effects_container.get_children():
		child.queue_free()
	
	# Create new status effect icons
	for effect in status_effects:
		var effect_icon = TextureRect.new()
		effect_icon.size = Vector2(24, 24)
		effect_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Try to load effect icon
		var icon_path = "res://assets/ui/effects/" + effect.id + ".png"
		if ResourceLoader.exists(icon_path):
			effect_icon.texture = load(icon_path)
		
		# Add tooltip with effect details
		var tooltip = effect.get("name", effect.id).capitalize()
		if effect.has("remaining_time"):
			tooltip += "\nRemaining: " + str(int(effect.remaining_time)) + "s"
		
		effect_icon.tooltip_text = tooltip
		status_effects_container.add_child(effect_icon)

func _process(delta):
# Update HUD elements that need frame updates
	update_item_cooldowns(delta)
	update_popup_positions(delta)

func update_item_cooldowns(delta):
# Update quick item cooldown displays
	if not GameState.player_data.has("quick_items"):
		return
	
	var quick_items = GameState.player_data.quick_items
	var item_system = get_node("/root/ItemSystem")
	
	if not item_system:
		return
	
	for i in range(quick_item_cooldowns.size()):
		var cooldown_bar = quick_item_cooldowns[i]
		
		if i < quick_items.size() and quick_items[i]:
			var item_id = quick_items[i]
			var item_data = DataLoader.get_item(item_id)
			
			if item_data and item_data.has("cooldown"):
				var remaining = item_system.get_cooldown_remaining(item_id)
				var max_cooldown = item_data.cooldown
				
				if remaining > 0:
					cooldown_bar.value = remaining / max_cooldown
					cooldown_bar.visible = true
				else:
					cooldown_bar.visible = false
			else:
				cooldown_bar.visible = false
		else:
			cooldown_bar.visible = false

func update_popup_positions(delta):
# Update loot popup positions and cleanup expired ones
	for i in range(active_popups.size() - 1, -1, -1):
		var popup = active_popups[i]
		if is_instance_valid(popup):
			# Move popup upward
			popup.position.y -= 50 * delta
			popup.modulate.a = max(0, popup.modulate.a - 0.5 * delta)
			
			# Remove when invisible
			if popup.modulate.a <= 0:
				popup.queue_free()
				active_popups.remove_at(i)
		else:
			active_popups.remove_at(i)

# Signal handlers
func _on_player_health_changed(new_health: int):
# Handle player health changes
	update_health_display()

func _on_player_mana_changed(new_mana: int):
# Handle player mana changes
	update_mana_display()

func _on_player_xp_gained(amount: int):
# Handle XP gain
	update_xp_display()
	show_xp_popup("+" + str(amount) + " XP")

func _on_player_level_up(new_level: int):
# Handle level up
	update_all_displays()
	show_level_up_popup(new_level)

func _on_item_looted(item_id: String, quantity: int):
# Handle item pickup
	var item_data = DataLoader.get_item(item_id)
	if item_data:
		var text = "Looted: " + item_data.name
		if quantity > 1:
			text += " x" + str(quantity)
		show_loot_popup(text)

func _on_item_used(item_id: String):
# Handle item usage
	update_quick_item_displays()

func _on_item_equipped(item_id: String, slot_type: String):
# Handle item equipment
	update_quick_item_displays()

func _on_notification_shown(message: String, type: String):
# Handle notification display
	show_notification_popup(message, type)

func _on_player_data_changed():
# Handle player data changes
	update_all_displays()

# Popup functions
func show_loot_popup(text: String):
# Show loot pickup popup
	if loot_popup_scene:
		var popup = loot_popup_scene.instantiate()
		popup.setup_notification(text, "loot")
		popup.position = Vector2(400, 300)  # Center area
		add_child(popup)
		active_popups.append(popup)

func show_xp_popup(text: String):
# Show XP gain popup
	if loot_popup_scene:
		var popup = loot_popup_scene.instantiate()
		popup.setup_notification(text, "xp")
		popup.position = Vector2(450, 250)
		add_child(popup)
		active_popups.append(popup)

func show_level_up_popup(new_level: int):
# Show level up popup
	if loot_popup_scene:
		var popup = loot_popup_scene.instantiate()
		popup.setup_notification("LEVEL UP! Level " + str(new_level), "level_up")
		popup.position = Vector2(400, 200)
		add_child(popup)
		active_popups.append(popup)

func show_notification_popup(message: String, type: String):
# Show general notification popup
	if loot_popup_scene:
		var popup = loot_popup_scene.instantiate()
		popup.setup_notification(message, type)
		popup.position = Vector2(500, 100)
		add_child(popup)
		active_popups.append(popup)

# TODO: Future enhancements
# - Minimap implementation
# - Chat system integration
# - Quest tracker display
# - Action bar for skills/spells
# - Equipment paper doll display
# - Damage number display system
