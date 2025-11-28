extends CanvasLayer

class_name UIManager

# UI Signals
signal ui_opened(ui_name: String)
signal ui_closed(ui_name: String)
signal ui_toggled(ui_name: String, visible: bool)
signal style_loaded()

# UI References
@onready var hud_container: Control
@onready var menu_container: Control
@onready var popup_container: Control

# UI Components
var main_hud: MainHUD
var minimap: Minimap
var inventory_ui: InventoryUI
var quest_journal: QuestJournal
var pause_menu: PauseMenu
var main_menu: MainMenu
var dialogue_ui: DialogueUI
var crafting_ui: CraftingUI
var skill_tree_ui: SkillTreeUI
var boss_fight_ui: BossFightUI
var shop_ui: ShopUI

# Component status
var components_loaded: Dictionary = {
	"main_hud": false,
	"minimap": false,
	"inventory_ui": false,
	"quest_journal": false,
	"pause_menu": false,
	"main_menu": false,
	"dialogue_ui": false,
	"crafting_ui": false,
	"skill_tree_ui": false,
	"boss_fight_ui": false,
	"shop_ui": false
}

# UI State
var current_open_menus: Array[String] = []
var ui_stack: Array[Control] = []
var is_game_paused: bool = false

# Style Theme
var ui_theme: Theme
var neon_green: Color = Color(0.0, 1.0, 0.549, 1.0) # #00ff8c
var dark_bg: Color = Color(0.0, 0.1, 0.05, 0.9)
var darker_bg: Color = Color(0.0, 0.05, 0.025, 0.95)

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var player_stats: PlayerStats

func _ready():
	setup_ui_containers()
	create_ui_theme()
	load_ui_components()
	connect_events()
	setup_input_handling()
	print("[UIManager] Sistema de UI inicializado")

func setup_ui_containers():
# Setup main UI containers
	# HUD Container (always visible in game)
	hud_container = Control.new()
	hud_container.name = "HUDContainer"
	hud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_container)
	
	# Menu Container (for menus and popups)
	menu_container = Control.new()
	menu_container.name = "MenuContainer"
	menu_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_container)
	
	# Popup Container (for tooltips and notifications)
	popup_container = Control.new()
	popup_container.name = "PopupContainer"
	popup_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_container)

func create_ui_theme():
# Create the futuristic neon theme
	ui_theme = Theme.new()
	
	# Create custom StyleBox for panels
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = dark_bg
	panel_style.border_color = neon_green
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.3)
	panel_style.shadow_size = 4
	panel_style.shadow_offset = Vector2(0, 2)
	ui_theme.set_stylebox("panel", "Panel", panel_style)
	
	# Create button styles
	create_button_styles()
	create_progressbar_styles()
	create_label_styles()
	
	style_loaded.emit()

func create_button_styles():
# Create button styles for the theme
	# Normal button style
	var button_normal = StyleBoxFlat.new()
	button_normal.bg_color = darker_bg
	button_normal.border_color = neon_green
	button_normal.border_width_left = 2
	button_normal.border_width_right = 2
	button_normal.border_width_top = 2
	button_normal.border_width_bottom = 2
	button_normal.corner_radius_top_left = 6
	button_normal.corner_radius_top_right = 6
	button_normal.corner_radius_bottom_left = 6
	button_normal.corner_radius_bottom_right = 6
	ui_theme.set_stylebox("normal", "Button", button_normal)
	
	# Hover button style
	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.2)
	button_hover.border_color = neon_green
	button_hover.border_width_left = 2
	button_hover.border_width_right = 2
	button_hover.border_width_top = 2
	button_hover.border_width_bottom = 2
	button_hover.corner_radius_top_left = 6
	button_hover.corner_radius_top_right = 6
	button_hover.corner_radius_bottom_left = 6
	button_hover.corner_radius_bottom_right = 6
	button_hover.shadow_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.5)
	button_hover.shadow_size = 6
	ui_theme.set_stylebox("hover", "Button", button_hover)
	
	# Pressed button style
	var button_pressed = StyleBoxFlat.new()
	button_pressed.bg_color = Color(neon_green.r, neon_green.g, neon_green.b, 0.4)
	button_pressed.border_color = Color.WHITE
	button_pressed.border_width_left = 2
	button_pressed.border_width_right = 2
	button_pressed.border_width_top = 2
	button_pressed.border_width_bottom = 2
	button_pressed.corner_radius_top_left = 6
	button_pressed.corner_radius_top_right = 6
	button_pressed.corner_radius_bottom_left = 6
	button_pressed.corner_radius_bottom_right = 6
	ui_theme.set_stylebox("pressed", "Button", button_pressed)
	
	# Button font
	ui_theme.set_color("font_color", "Button", neon_green)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "Button", Color.WHITE)

func create_progressbar_styles():
# Create progress bar styles for HP, Stamina, XP
	# Progress bar background
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color.BLACK
	progress_bg.border_color = neon_green
	progress_bg.border_width_left = 1
	progress_bg.border_width_right = 1
	progress_bg.border_width_top = 1
	progress_bg.border_width_bottom = 1
	progress_bg.corner_radius_top_left = 4
	progress_bg.corner_radius_top_right = 4
	progress_bg.corner_radius_bottom_left = 4
	progress_bg.corner_radius_bottom_right = 4
	ui_theme.set_stylebox("background", "ProgressBar", progress_bg)
	
	# Progress bar fill
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = neon_green
	progress_fill.corner_radius_top_left = 3
	progress_fill.corner_radius_top_right = 3
	progress_fill.corner_radius_bottom_left = 3
	progress_fill.corner_radius_bottom_right = 3
	ui_theme.set_stylebox("fill", "ProgressBar", progress_fill)

func create_label_styles():
# Create label styles
	ui_theme.set_color("font_color", "Label", neon_green)
	ui_theme.set_color("font_shadow_color", "Label", Color.BLACK)

func load_ui_components():
# Load all UI components
	# Wait for player stats reference
	await get_tree().process_frame
	player_stats = game_state.player_stats
	
	# Load HUD
	load_main_hud()
	load_minimap()
	
	# Load Menus (but keep them hidden)
	load_inventory_ui()
	load_quest_journal()
	load_pause_menu()
	load_dialogue_ui()
	load_crafting_ui()
	load_skill_tree_ui()
	load_boss_fight_ui()
	load_shop_ui()
	
	# Mark all components as loaded
	components_loaded["main_hud"] = true
	components_loaded["minimap"] = true
	components_loaded["inventory_ui"] = true
	components_loaded["quest_journal"] = true
	components_loaded["pause_menu"] = true
	components_loaded["dialogue_ui"] = true
	components_loaded["crafting_ui"] = true
	components_loaded["skill_tree_ui"] = true
	components_loaded["boss_fight_ui"] = true
	components_loaded["shop_ui"] = true
	
	print("[UIManager] Todos os componentes de UI carregados")

func load_main_hud():
# Load the main HUD
	var hud_scene = preload("res://scenes/ui/hud/MainHUD.tscn") if ResourceLoader.exists("res://scenes/ui/hud/MainHUD.tscn") else null
	
	if hud_scene:
		main_hud = hud_scene.instantiate()
	else:
		# Create HUD programmatically
		main_hud = preload("res://scripts/ui/hud/MainHUD.gd").new()
	
	main_hud.name = "MainHUD"
	main_hud.theme = ui_theme
	hud_container.add_child(main_hud)
	main_hud.initialize(player_stats)

func load_minimap():
# Load the minimap
	var minimap_scene = preload("res://scenes/ui/hud/Minimap.tscn") if ResourceLoader.exists("res://scenes/ui/hud/Minimap.tscn") else null
	
	if minimap_scene:
		minimap = minimap_scene.instantiate()
	else:
		minimap = preload("res://scripts/ui/hud/Minimap.gd").new()
	
	minimap.name = "Minimap"
	minimap.theme = ui_theme
	hud_container.add_child(minimap)
	minimap.initialize()

func load_inventory_ui():
# Load inventory interface
	inventory_ui = preload("res://scripts/ui/menus/InventoryUI.gd").new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.theme = ui_theme
	inventory_ui.visible = false
	menu_container.add_child(inventory_ui)

func load_quest_journal():
# Load quest journal
	quest_journal = preload("res://scripts/ui/menus/QuestJournal.gd").new()
	quest_journal.name = "QuestJournal"
	quest_journal.theme = ui_theme
	quest_journal.visible = false
	menu_container.add_child(quest_journal)

func load_pause_menu():
# Load pause menu
	pause_menu = preload("res://scripts/ui/menus/PauseMenu.gd").new()
	pause_menu.name = "PauseMenu"
	pause_menu.theme = ui_theme
	pause_menu.visible = false
	menu_container.add_child(pause_menu)

func load_dialogue_ui():
# Load dialogue interface
	dialogue_ui = preload("res://scripts/ui/menus/DialogueUI.gd").new()
	dialogue_ui.name = "DialogueUI"
	dialogue_ui.theme = ui_theme
	dialogue_ui.visible = false
	popup_container.add_child(dialogue_ui)

func load_crafting_ui():
# Load crafting interface
	crafting_ui = preload("res://scripts/ui/menus/CraftingUI.gd").new()
	crafting_ui.name = "CraftingUI"
	crafting_ui.theme = ui_theme
	crafting_ui.visible = false
	menu_container.add_child(crafting_ui)

func load_skill_tree_ui():
# Load skill tree interface
	skill_tree_ui = preload("res://scripts/ui/menus/SkillTreeUI.gd").new()
	skill_tree_ui.name = "SkillTreeUI"
	skill_tree_ui.theme = ui_theme
	skill_tree_ui.visible = false
	menu_container.add_child(skill_tree_ui)

func load_boss_fight_ui():
# Load boss fight interface
	boss_fight_ui = preload("res://scripts/ui/menus/BossFightUI.gd").new()
	boss_fight_ui.name = "BossFightUI"
	boss_fight_ui.theme = ui_theme
	boss_fight_ui.visible = false
	hud_container.add_child(boss_fight_ui)  # Boss UI goes in HUD container

func load_shop_ui():
# Load shop interface
	shop_ui = preload("res://scripts/ui/menus/ShopUI.gd").new()
	shop_ui.name = "ShopUI"
	shop_ui.theme = ui_theme
	shop_ui.visible = false
	menu_container.add_child(shop_ui)

func connect_events():
# Connect to game events
	event_bus.connect("dialogue_ui_show", _on_dialogue_show)
	event_bus.connect("dialogue_ui_hide", _on_dialogue_hide)
	event_bus.connect("player_health_changed", _on_player_health_changed)
	event_bus.connect("player_stamina_changed", _on_player_stamina_changed)
	event_bus.connect("experience_gained", _on_experience_gained)
	event_bus.connect("buff_applied", _on_buff_applied)
	event_bus.connect("buff_removed", _on_buff_removed)
	
	# New UI systems events
	event_bus.connect("boss_encounter_started", _on_boss_encounter_started)
	event_bus.connect("boss_encounter_ended", _on_boss_encounter_ended)
	event_bus.connect("shop_opened", _on_shop_opened)
	event_bus.connect("shop_closed", _on_shop_closed)
	event_bus.connect("crafting_station_opened", _on_crafting_station_opened)

func setup_input_handling():
# Setup input handling for UI
	set_process_unhandled_input(true)

func _unhandled_input(event):
# Handle UI input
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if is_any_menu_open():
			close_top_ui()
		else:
			toggle_pause_menu()
	elif event.is_action_pressed("open_inventory"):
		toggle_inventory()
	elif event.is_action_pressed("open_journal"):
		toggle_quest_journal()
	elif event.is_action_pressed("toggle_map"):
		toggle_minimap_fullscreen()
	elif event.is_action_pressed("open_crafting"):
		toggle_crafting()
	elif event.is_action_pressed("open_skills"):
		toggle_skill_tree()

# Additional event handlers for new systems
func _on_boss_encounter_started(boss_id: String):
# Handle boss encounter start
	show_boss_fight_ui()

func _on_boss_encounter_ended(victory: bool):
# Handle boss encounter end
	hide_boss_fight_ui()

func _on_shop_opened(shop_id: String, npc_data: Dictionary = {}):
# Handle shop opening
	open_shop(shop_id, npc_data)

func _on_shop_closed():
# Handle shop closing
	close_shop()

func _on_crafting_station_opened(station_id: String):
# Handle crafting station interaction
	open_crafting()

# UI Toggle Functions
func toggle_pause_menu():
# Toggle pause menu
	if not components_loaded.get("pause_menu", false):
		return
	
	if pause_menu.visible:
		close_pause_menu()
	else:
		open_pause_menu()

func open_pause_menu():
# Open pause menu
	if not components_loaded.get("pause_menu", false) or pause_menu.visible:
		return
	
	pause_menu.show()
	get_tree().paused = true
	is_game_paused = true
	add_to_ui_stack(pause_menu)
	ui_opened.emit("pause_menu")
	event_bus.emit_signal("game_paused")

func close_pause_menu():
# Close pause menu
	if not pause_menu or not pause_menu.visible:
		return
	
	pause_menu.hide()
	get_tree().paused = false
	is_game_paused = false
	remove_from_ui_stack(pause_menu)
	ui_closed.emit("pause_menu")
	event_bus.emit_signal("game_resumed")

func toggle_inventory():
# Toggle inventory
	if not components_loaded.get("inventory_ui", false):
		return
	
	if inventory_ui.visible:
		close_inventory()
	else:
		open_inventory()

func open_inventory():
# Open inventory
	if not components_loaded.get("inventory_ui", false) or inventory_ui.visible:
		return
	
	inventory_ui.show()
	add_to_ui_stack(inventory_ui)
	ui_opened.emit("inventory")

func close_inventory():
# Close inventory
	if not inventory_ui or not inventory_ui.visible:
		return
	
	inventory_ui.hide()
	remove_from_ui_stack(inventory_ui)
	ui_closed.emit("inventory")

func toggle_quest_journal():
# Toggle quest journal
	if not components_loaded.get("quest_journal", false):
		return
	
	if quest_journal.visible:
		close_quest_journal()
	else:
		open_quest_journal()

func open_quest_journal():
# Open quest journal
	if not components_loaded.get("quest_journal", false) or quest_journal.visible:
		return
	
	quest_journal.show()
	add_to_ui_stack(quest_journal)
	ui_opened.emit("quest_journal")

func close_quest_journal():
# Close quest journal
	if not quest_journal or not quest_journal.visible:
		return
	
	quest_journal.hide()
	remove_from_ui_stack(quest_journal)
	ui_closed.emit("quest_journal")

func toggle_dialogue_ui():
# Toggle dialogue UI
	if not components_loaded.get("dialogue_ui", false):
		return
	
	if dialogue_ui.visible:
		close_dialogue_ui()
	else:
		# Dialogue UI should be opened by DialogueSystem, not directly
		pass

func open_dialogue_ui():
# Open dialogue UI
	if not components_loaded.get("dialogue_ui", false) or dialogue_ui.visible:
		return
	
	dialogue_ui.show()
	add_to_ui_stack(dialogue_ui)
	ui_opened.emit("dialogue_ui")

func close_dialogue_ui():
# Close dialogue UI
	if not dialogue_ui or not dialogue_ui.visible:
		return
	
	dialogue_ui.hide()
	remove_from_ui_stack(dialogue_ui)
	ui_closed.emit("dialogue_ui")

# New UI Systems Toggle Functions
func toggle_crafting():
# Toggle crafting UI
	if not components_loaded.get("crafting_ui", false):
		return
	
	if crafting_ui.visible:
		close_crafting()
	else:
		open_crafting()

func open_crafting():
# Open crafting UI
	if not components_loaded.get("crafting_ui", false) or crafting_ui.visible:
		return
	
	crafting_ui.show()
	add_to_ui_stack(crafting_ui)
	ui_opened.emit("crafting")

func close_crafting():
# Close crafting UI
	if not crafting_ui or not crafting_ui.visible:
		return
	
	crafting_ui.hide()
	remove_from_ui_stack(crafting_ui)
	ui_closed.emit("crafting")

func toggle_skill_tree():
# Toggle skill tree UI
	if not components_loaded.get("skill_tree_ui", false):
		return
	
	if skill_tree_ui.visible:
		close_skill_tree()
	else:
		open_skill_tree()

func open_skill_tree():
# Open skill tree UI
	if not components_loaded.get("skill_tree_ui", false) or skill_tree_ui.visible:
		return
	
	skill_tree_ui.show()
	add_to_ui_stack(skill_tree_ui)
	ui_opened.emit("skill_tree")

func close_skill_tree():
# Close skill tree UI
	if not skill_tree_ui or not skill_tree_ui.visible:
		return
	
	skill_tree_ui.hide()
	remove_from_ui_stack(skill_tree_ui)
	ui_closed.emit("skill_tree")

func toggle_boss_fight():
# Toggle boss fight UI
	if not components_loaded.get("boss_fight_ui", false):
		return
	
	boss_fight_ui.visible = not boss_fight_ui.visible
	ui_toggled.emit("boss_fight", boss_fight_ui.visible)

func show_boss_fight_ui():
# Show boss fight UI
	if not components_loaded.get("boss_fight_ui", false):
		return
	
	boss_fight_ui.visible = true
	ui_opened.emit("boss_fight")

func hide_boss_fight_ui():
# Hide boss fight UI
	if not components_loaded.get("boss_fight_ui", false):
		return
	
	boss_fight_ui.visible = false
	ui_closed.emit("boss_fight")

func toggle_shop():
# Toggle shop UI
	if not components_loaded.get("shop_ui", false):
		return
	
	if shop_ui.visible:
		close_shop()
	else:
		# Shop should be opened by NPC interaction with shop_id
		pass

func open_shop(shop_id: String = "", npc_data: Dictionary = {}):
# Open shop UI
	if not components_loaded.get("shop_ui", false) or shop_ui.visible:
		return
	
	if shop_id != "":
		shop_ui.open_shop(shop_id, npc_data)
	add_to_ui_stack(shop_ui)
	ui_opened.emit("shop")

func close_shop():
# Close shop UI
	if not shop_ui or not shop_ui.visible:
		return
	
	shop_ui.close_shop()
	remove_from_ui_stack(shop_ui)
	ui_closed.emit("shop")

func toggle_minimap_fullscreen():
# Toggle minimap fullscreen mode
	if components_loaded.get("minimap", false) and minimap:
		minimap.toggle_fullscreen()

# UI Stack Management
func add_to_ui_stack(ui_element: Control):
# Add UI element to stack
	if ui_element not in ui_stack:
		ui_stack.append(ui_element)

func remove_from_ui_stack(ui_element: Control):
# Remove UI element from stack
	if ui_element in ui_stack:
		ui_stack.erase(ui_element)

func close_top_ui():
# Close the topmost UI element
	if ui_stack.size() > 0:
		var top_ui = ui_stack[-1]
		if top_ui == pause_menu:
			close_pause_menu()
		elif top_ui == inventory_ui:
			close_inventory()
		elif top_ui == quest_journal:
			close_quest_journal()
		elif top_ui == crafting_ui:
			close_crafting()
		elif top_ui == skill_tree_ui:
			close_skill_tree()
		elif top_ui == shop_ui:
			close_shop()

## Removed duplicate close_all_menus (detailed version kept later)

# Event Handlers
func _on_dialogue_show(dialogue_data: Dictionary):
# Show dialogue UI
	if dialogue_ui:
		dialogue_ui.show_dialogue(dialogue_data)

func _on_dialogue_hide():
# Hide dialogue UI
	if dialogue_ui:
		dialogue_ui.hide_dialogue()

func _on_player_health_changed(current_hp: int, max_hp: int):
# Update health display
	if main_hud:
		main_hud.update_health(current_hp, max_hp)

func _on_player_stamina_changed(current_stamina: float, max_stamina: float):
# Update stamina display
	if main_hud:
		main_hud.update_stamina(current_stamina, max_stamina)

func _on_experience_gained(amount: int, source: String):
# Show XP gain notification
	if main_hud:
		main_hud.show_xp_gain(amount)

func _on_buff_applied(buff_id: String, duration: float):
# Show buff application
	if main_hud:
		main_hud.add_buff_icon(buff_id, duration)

func _on_buff_removed(buff_id: String):
# Remove buff icon
	if main_hud:
		main_hud.remove_buff_icon(buff_id)

# Utility Functions
func get_ui_theme() -> Theme:
# Get the UI theme
	return ui_theme

func is_any_menu_open() -> bool:
# Check if any menu is open
	return ui_stack.size() > 0

func is_component_loaded(component_name: String) -> bool:
# Check if a component is loaded
	return components_loaded.get(component_name, false)

func get_neon_green_color() -> Color:
# Get the neon green color
	return neon_green

func get_dark_background_color() -> Color:
# Get the dark background color
	return dark_bg

func get_darker_background_color() -> Color:
# Get the darker background color
	return darker_bg

func close_all_menus():
# Close all open menus
	if pause_menu and pause_menu.visible:
		close_pause_menu()
	if inventory_ui and inventory_ui.visible:
		close_inventory()
	if quest_journal and quest_journal.visible:
		close_quest_journal()
	if dialogue_ui and dialogue_ui.visible:
		close_dialogue_ui()

# Debug Functions
func debug_show_all_ui():
# Debug: Show all UI components
	print("[UIManager] Debug: Showing all UI components")
	if components_loaded.get("main_hud", false):
		main_hud.debug_show_all_elements()
	if components_loaded.get("minimap", false):
		minimap.debug_show_test_data()
	if components_loaded.get("inventory_ui", false):
		inventory_ui.debug_populate_test_items()
	if components_loaded.get("quest_journal", false):
		quest_journal.debug_populate_test_quests()
	if components_loaded.get("dialogue_ui", false):
		dialogue_ui.debug_start_test_dialogue()

func debug_toggle_all_panels():
# Debug: Toggle all menu panels
	print("[UIManager] Debug: Toggling all panels")
	toggle_inventory()
	await get_tree().create_timer(0.5).timeout
	toggle_quest_journal()
	await get_tree().create_timer(0.5).timeout
	toggle_pause_menu()

func debug_test_ui_animations():
# Debug: Test UI animations
	print("[UIManager] Debug: Testing UI animations")
	if main_hud:
		main_hud.debug_animate_all_bars()

func debug_print_ui_status():
# Debug: Print UI status
	print("[UIManager] UI Component Status:")
	for component in components_loaded:
		var status = "âœ“ Loaded" if components_loaded[component] else "âœ— Not Loaded"
		print("  %s: %s" % [component.capitalize(), status])
	
	print("[UIManager] Open Menus: %d" % ui_stack.size())
	for ui in ui_stack:
		print("  - %s" % ui.name)
	
	print("[UIManager] Game Paused: %s" % str(is_game_paused))

# Debug Functions
func debug_toggle_hud():
# Debug: Toggle HUD visibility
	if main_hud:
		main_hud.visible = not main_hud.visible

func debug_show_all_uis():
# Debug: Show all UI components
	open_inventory()
	open_quest_journal()
	open_pause_menu()

func debug_style_test():
# Debug: Test UI styles
	print("[UIManager] Testing UI styles...")
	print("Neon Green: ", neon_green)
	print("Dark BG: ", dark_bg)
	print("Theme loaded: ", ui_theme != null)
