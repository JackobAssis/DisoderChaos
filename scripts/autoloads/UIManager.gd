# ============================================================================
# UIManager.gd
# Sistema central de gerenciamento da UI do jogo
# ============================================================================
extends Node

# ReferÃªncias para as UIs principais
var game_hud: GameHUD
var pause_menu: PauseMenu
var options_menu: OptionsMenu
var inventory_ui: AdvancedInventoryUI
var equipment_ui: EquipmentUI
var crafting_ui: AdvancedCraftingUI
var popup_manager: PopupManager

# Estados da UI
var is_any_menu_open: bool = false
var is_game_paused: bool = false
var current_menu: String = ""

# Sistema de camadas da UI (Z-index)
enum UILayer {
	HUD = 1,
	MENU = 10,
	POPUP = 20,
	TOOLTIP = 30,
	NOTIFICATION = 40
}

# ============================================================================
# INICIALIZAÃ‡ÃƒO
# ============================================================================

func _ready():
	# Configurar o autoload
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Conectar sinais do EventBus
	_connect_event_signals()
	
	# Aguardar que a cena principal carregue
	await get_tree().process_frame
	_initialize_ui_systems()

func _connect_event_signals():
	EventBus.menu_requested.connect(_on_menu_requested)
	EventBus.menu_closed.connect(_on_menu_closed)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_unpaused.connect(_on_game_unpaused)
	EventBus.popup_requested.connect(_on_popup_requested)

func _initialize_ui_systems():
	# Aguardar que a cena principal seja carregada
	var main_scene = get_tree().current_scene
	if not main_scene:
		await get_tree().current_scene_changed
		main_scene = get_tree().current_scene
	
	# Tentar encontrar ou criar as UIs principais
	_setup_hud_system(main_scene)
	_setup_menu_systems(main_scene)
	_setup_popup_system(main_scene)

# ============================================================================
# CONFIGURAÃ‡ÃƒO DOS SISTEMAS
# ============================================================================

func _setup_hud_system(main_scene: Node):
	# Procurar HUD existente ou criar novo
	game_hud = _find_or_create_ui(main_scene, "GameHUD", "res://scenes/ui/hud/GameHUD.tscn")
	
	if game_hud:
		game_hud.z_index = UILayer.HUD
		print("âœ… HUD sistema configurado")

func _setup_menu_systems(main_scene: Node):
	var ui_container = _get_or_create_ui_container(main_scene)
	
	# Menu de pausa
	pause_menu = _find_or_create_ui(ui_container, "PauseMenu", "res://scenes/ui/menus/PauseMenu.tscn")
	if pause_menu:
		pause_menu.z_index = UILayer.MENU
		pause_menu.visible = false
	
	# Menu de opÃ§Ãµes
	options_menu = _find_or_create_ui(ui_container, "OptionsMenu", "res://scenes/ui/menus/OptionsMenu.tscn")
	if options_menu:
		options_menu.z_index = UILayer.MENU
		options_menu.visible = false
	
	# InventÃ¡rio
	inventory_ui = _find_or_create_ui(ui_container, "InventoryUI", "res://scenes/ui/menus/AdvancedInventoryUI.tscn")
	if inventory_ui:
		inventory_ui.z_index = UILayer.MENU
		inventory_ui.visible = false
	
	# Equipamentos
	equipment_ui = _find_or_create_ui(ui_container, "EquipmentUI", "res://scenes/ui/menus/EquipmentUI.tscn")
	if equipment_ui:
		equipment_ui.z_index = UILayer.MENU
		equipment_ui.visible = false
	
	# Crafting
	crafting_ui = _find_or_create_ui(ui_container, "CraftingUI", "res://scenes/ui/menus/AdvancedCraftingUI.tscn")
	if crafting_ui:
		crafting_ui.z_index = UILayer.MENU
		crafting_ui.visible = false
	
	print("âœ… Sistemas de menu configurados")

func _setup_popup_system(main_scene: Node):
	# PopupManager sempre no topo
	popup_manager = _find_or_create_ui(main_scene, "PopupManager", "")
	if not popup_manager:
		popup_manager = preload("res://scripts/ui/popups/PopupManager.gd").new()
		popup_manager.name = "PopupManager"
		main_scene.add_child(popup_manager)
	
	popup_manager.z_index = UILayer.POPUP
	print("âœ… Sistema de popup configurado")

func _get_or_create_ui_container(parent: Node) -> CanvasLayer:
	var ui_container = parent.find_child("UIContainer", false)
	
	if not ui_container:
		ui_container = CanvasLayer.new()
		ui_container.name = "UIContainer"
		ui_container.layer = UILayer.MENU
		parent.add_child(ui_container)
	
	return ui_container

func _find_or_create_ui(parent: Node, ui_name: String, scene_path: String = "") -> Node:
	var ui_node = parent.find_child(ui_name, true)
	
	if not ui_node and scene_path != "" and ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		if scene:
			ui_node = scene.instantiate()
			ui_node.name = ui_name
			parent.add_child(ui_node)
	
	return ui_node

# ============================================================================
# CONTROLE DE INPUT
# ============================================================================

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		toggle_pause_menu()
	
	elif event.is_action_pressed("open_inventory"):
		toggle_menu("inventory")
	
	elif event.is_action_pressed("open_character"):
		toggle_menu("equipment")
	
	elif event.is_action_pressed("open_crafting"):
		toggle_menu("crafting")
	
	elif event.is_action_pressed("close_all_menus"):
		close_all_menus()

# ============================================================================
# GERENCIAMENTO DE MENUS
# ============================================================================

func toggle_pause_menu():
	if is_game_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if is_game_paused:
		return
	
	close_all_menus()
	is_game_paused = true
	get_tree().paused = true
	
	if pause_menu:
		pause_menu.visible = true
		current_menu = "pause"
		is_any_menu_open = true
	
	EventBus.game_paused.emit()
	print("ðŸŽ® Jogo pausado")

func resume_game():
	if not is_game_paused:
		return
	
	is_game_paused = false
	get_tree().paused = false
	
	if pause_menu:
		pause_menu.visible = false
	
	current_menu = ""
	is_any_menu_open = false
	
	EventBus.game_unpaused.emit()
	print("ðŸŽ® Jogo retomado")

func toggle_menu(menu_name: String):
	if is_game_paused:
		resume_game()
		return
	
	if current_menu == menu_name:
		close_menu(menu_name)
	else:
		open_menu(menu_name)

func open_menu(menu_name: String):
	# Fechar menu anterior se houver
	if is_any_menu_open:
		close_current_menu()
	
	var menu_node: Control = null
	
	match menu_name:
		"inventory":
			menu_node = inventory_ui
		"equipment":
			menu_node = equipment_ui
		"crafting":
			menu_node = crafting_ui
		"options":
			menu_node = options_menu
	
	if menu_node:
		menu_node.visible = true
		current_menu = menu_name
		is_any_menu_open = true
		
		# Aplicar tema se necessÃ¡rio
		if menu_node.has_method("apply_theme"):
			menu_node.apply_theme()
		
		EventBus.menu_opened.emit(menu_name)
		print("ðŸ“‹ Menu aberto: ", menu_name)

func close_menu(menu_name: String):
	var menu_node: Control = null
	
	match menu_name:
		"inventory":
			menu_node = inventory_ui
		"equipment":
			menu_node = equipment_ui
		"crafting":
			menu_node = crafting_ui
		"options":
			menu_node = options_menu
		"pause":
			resume_game()
			return
	
	if menu_node:
		menu_node.visible = false
		
		if current_menu == menu_name:
			current_menu = ""
			is_any_menu_open = false
		
		EventBus.menu_closed.emit(menu_name)
		print("ðŸ“‹ Menu fechado: ", menu_name)

func close_current_menu():
	if current_menu != "":
		close_menu(current_menu)

func close_all_menus():
	var menus = ["inventory", "equipment", "crafting", "options"]
	
	for menu_name in menus:
		close_menu(menu_name)
	
	current_menu = ""
	is_any_menu_open = false

# ============================================================================
# EVENTOS DO EVENTBUS
# ============================================================================

func _on_menu_requested(menu_name: String):
	open_menu(menu_name)

func _on_menu_closed(menu_name: String):
	close_menu(menu_name)

func _on_game_paused():
	pause_game()

func _on_game_unpaused():
	resume_game()

func _on_popup_requested(popup_type: String, data: Dictionary):
	if popup_manager:
		popup_manager.show_popup(popup_type, data)

# ============================================================================
# UTILIDADES
# ============================================================================

func is_blocking_input() -> bool:
	return is_any_menu_open or is_game_paused or (popup_manager and popup_manager.has_active_popups())

func get_current_menu() -> String:
	return current_menu

func is_menu_open(menu_name: String) -> bool:
	return current_menu == menu_name

func refresh_all_uis():
# Atualizar todas as UIs com dados mais recentes
	if game_hud and game_hud.has_method("refresh_ui"):
		game_hud.refresh_ui()
	
	if inventory_ui and inventory_ui.has_method("refresh_inventory"):
		inventory_ui.refresh_inventory()
	
	if equipment_ui and equipment_ui.has_method("refresh_equipment"):
		equipment_ui.refresh_equipment()
	
	if crafting_ui and crafting_ui.has_method("refresh_recipes"):
		crafting_ui.refresh_recipes()

func apply_theme_to_all():
# Aplicar tema atualizado a todas as UIs
	var all_uis = [game_hud, pause_menu, options_menu, inventory_ui, equipment_ui, crafting_ui]
	
	for ui in all_uis:
		if ui and ui.has_method("apply_theme"):
			ui.apply_theme()

# ============================================================================
# DEBUG
# ============================================================================

func _on_debug_info_requested():
	print("=== UI MANAGER DEBUG INFO ===")
	print("Game Paused: ", is_game_paused)
	print("Any Menu Open: ", is_any_menu_open)
	print("Current Menu: ", current_menu)
	print("HUD Active: ", game_hud != null and game_hud.visible)
	print("Popup Active: ", popup_manager != null and popup_manager.has_active_popups())
	print("===========================")

# ============================================================================
# NOTIFICAÃ‡Ã•ES
# ============================================================================

func show_notification(message: String, type: String = "info", duration: float = 3.0):
# Mostrar notificaÃ§Ã£o temporÃ¡ria na tela
	if popup_manager:
		popup_manager.show_popup("notification", {
			"message": message,
			"type": type,
			"duration": duration
		})

func show_tooltip(text: String, position: Vector2):
# Mostrar tooltip na posiÃ§Ã£o especificada
	if popup_manager:
		popup_manager.show_popup("tooltip", {
			"text": text,
			"position": position
		})

func hide_tooltip():
# Esconder tooltip ativo
	if popup_manager:
		popup_manager.hide_popup("tooltip")
