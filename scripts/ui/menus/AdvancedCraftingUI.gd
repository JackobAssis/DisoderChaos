class_name AdvancedCraftingUI
extends Control

## Sistema avanÃ§ado de crafting com preview, materiais e chance de sucesso

@onready var recipe_list: ItemList = $Background/MainContainer/RecipePanel/RecipeList
@onready var recipe_search: LineEdit = $Background/MainContainer/RecipePanel/SearchInput
@onready var category_buttons: HBoxContainer = $Background/MainContainer/RecipePanel/CategoryButtons

# Preview do resultado
@onready var result_preview: Control = $Background/MainContainer/PreviewPanel/ResultPreview
@onready var result_icon: TextureRect = $Background/MainContainer/PreviewPanel/ResultPreview/Icon
@onready var result_name: Label = $Background/MainContainer/PreviewPanel/ResultPreview/Name
@onready var result_stats: VBoxContainer = $Background/MainContainer/PreviewPanel/ResultPreview/Stats

# Materiais necessÃ¡rios
@onready var materials_container: VBoxContainer = $Background/MainContainer/MaterialsPanel/MaterialsList
@onready var craft_button: Button = $Background/MainContainer/MaterialsPanel/CraftButton

# Chance de sucesso e informaÃ§Ãµes
@onready var success_bar: ProgressBar = $Background/MainContainer/CraftingInfo/SuccessChance/ProgressBar
@onready var success_label: Label = $Background/MainContainer/CraftingInfo/SuccessChance/Label
@onready var craft_time_label: Label = $Background/MainContainer/CraftingInfo/CraftTime
@onready var xp_reward_label: Label = $Background/MainContainer/CraftingInfo/XPReward

# EstaÃ§Ã£o de crafting
@onready var station_icon: TextureRect = $Background/MainContainer/StationInfo/Icon
@onready var station_name: Label = $Background/MainContainer/StationInfo/Name
@onready var station_level: Label = $Background/MainContainer/StationInfo/Level

# Sistema de crafting
var crafting_data: Dictionary = {}
var current_recipe: Dictionary = {}
var current_category: String = "all"
var player_crafting_level: int = 1
var available_stations: Array[String] = ["workbench", "forge", "alchemy_table"]

# Filtros de categoria
var categories: Dictionary = {
	"all": "Todos",
	"weapons": "Armas", 
	"armor": "Armaduras",
	"consumables": "ConsumÃ­veis",
	"materials": "Materiais",
	"special": "Especiais"
}

signal item_crafted(recipe_id: String, result_item: Dictionary)
signal crafting_failed(recipe_id: String, reason: String)
signal recipe_selected(recipe: Dictionary)

func _ready():
	setup_ui_theme()
	setup_connections()
	setup_categories()
	load_crafting_data()
	refresh_recipes()

func setup_ui_theme():
# Aplica tema dark fantasy
	# Background principal
	var bg = $Background as ColorRect
	if bg:
		bg.color = UIThemeManager.Colors.BG_POPUP
	
	# PainÃ©is
	var panels = [$Background/MainContainer/RecipePanel, 
				  $Background/MainContainer/PreviewPanel,
				  $Background/MainContainer/MaterialsPanel,
				  $Background/MainContainer/CraftingInfo,
				  $Background/MainContainer/StationInfo]
	
	for panel in panels:
		if panel is Panel:
			panel.add_theme_stylebox_override("panel", 
				UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	
	# Lista de receitas
	recipe_list.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.PRIMARY_DARK))
	
	# Search input
	recipe_search.add_theme_stylebox_override("normal", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.PRIMARY_DARK))
	recipe_search.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	
	# BotÃ£o de craft
	craft_button.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.SUCCESS_GREEN,
			UIThemeManager.Colors.ACCENT_GOLD,
			UIThemeManager.Colors.TECH_ORANGE
		))
	craft_button.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	
	# Barra de sucesso
	success_bar.add_theme_stylebox_override("fill", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.SUCCESS_GREEN))
	success_bar.add_theme_stylebox_override("background", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.PRIMARY_DARK))

func setup_connections():
# Conecta todos os sinais
	recipe_list.item_selected.connect(_on_recipe_selected)
	recipe_search.text_changed.connect(_on_search_changed)
	craft_button.pressed.connect(_on_craft_pressed)
	
	if EventBus:
		EventBus.player_crafting_level_changed.connect(_on_crafting_level_changed)
		EventBus.crafting_station_available.connect(_on_station_available)
		EventBus.inventory_changed.connect(_on_inventory_changed)

func setup_categories():
# Cria botÃµes de categoria
	for category_id in categories:
		var btn = Button.new()
		btn.text = categories[category_id]
		btn.add_theme_stylebox_override("normal", 
			UIThemeManager.create_button_style(
				UIThemeManager.Colors.PRIMARY_DARK,
				UIThemeManager.Colors.PRIMARY_NAVY,
				UIThemeManager.Colors.CYBER_CYAN
			))
		btn.pressed.connect(func(): set_category(category_id))
		category_buttons.add_child(btn)

func load_crafting_data():
# Carrega dados de crafting do arquivo JSON
	var file = FileAccess.open("res://data/crafting/recipes.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		
		if parse_result == OK:
			crafting_data = json.data
		else:
			print("Erro ao carregar recipes.json: ", json.get_error_message())
	else:
		print("Arquivo recipes.json nÃ£o encontrado!")

func set_category(category: String):
# Define categoria ativa
	current_category = category
	
	# Atualiza visual dos botÃµes
	for btn in category_buttons.get_children():
		btn.modulate = Color.WHITE
	
	# Destaca botÃ£o ativo
	var active_index = categories.keys().find(category)
	if active_index >= 0 and active_index < category_buttons.get_child_count():
		category_buttons.get_child(active_index).modulate = UIThemeManager.Colors.CYBER_CYAN
	
	refresh_recipes()

func refresh_recipes():
# Atualiza lista de receitas
	recipe_list.clear()
	
	if not crafting_data.has("recipes"):
		return
	
	var recipes = crafting_data.recipes
	var search_text = recipe_search.text.to_lower()
	
	for recipe_id in recipes:
		var recipe = recipes[recipe_id]
		
		# Filtro por categoria
		if current_category != "all" and recipe.get("category", "") != current_category:
			continue
		
		# Filtro por busca
		if search_text != "" and not recipe.get("name", "").to_lower().contains(search_text):
			continue
		
		# Verifica se player pode ver esta receita
		if not can_see_recipe(recipe):
			continue
		
		# Adiciona Ã  lista
		var display_name = recipe.get("name", recipe_id)
		var level_req = recipe.get("level_requirement", 1)
		
		if level_req > player_crafting_level:
			display_name += " (NÃ­vel " + str(level_req) + ")"
			recipe_list.add_item(display_name, null, false)  # Desabilitado
		else:
			recipe_list.add_item(display_name)
		
		# Armazena ID da receita no item
		var item_index = recipe_list.get_item_count() - 1
		recipe_list.set_item_metadata(item_index, recipe_id)

func can_see_recipe(recipe: Dictionary) -> bool:
# Verifica se player pode ver esta receita
	# Verifica descoberta da receita
	if recipe.get("requires_discovery", false):
		return false  # TODO: Implementar sistema de descoberta
	
	# Verifica nÃ­vel mÃ­nimo para visualizar
	var min_level = recipe.get("visibility_level", 1)
	return player_crafting_level >= min_level

func _on_recipe_selected(index: int):
# Receita foi selecionada
	var recipe_id = recipe_list.get_item_metadata(index)
	if recipe_id and crafting_data.recipes.has(recipe_id):
		current_recipe = crafting_data.recipes[recipe_id]
		current_recipe["id"] = recipe_id
		update_preview()
		recipe_selected.emit(current_recipe)

func update_preview():
# Atualiza preview da receita
	if current_recipe.is_empty():
		clear_preview()
		return
	
	update_result_preview()
	update_materials_list()
	update_crafting_info()
	update_station_info()

func update_result_preview():
# Atualiza preview do item resultado
	var result = current_recipe.get("result", {})
	
	# Ãcone
	if result.has("icon"):
		result_icon.texture = load(result.icon) if result.icon is String else result.icon
	
	# Nome com cor de raridade
	result_name.text = result.get("name", "Item Desconhecido")
	var rarity_color = get_rarity_color(result.get("rarity", "common"))
	result_name.add_theme_color_override("font_color", rarity_color)
	
	# Stats do item
	update_result_stats(result)

func update_result_stats(result: Dictionary):
# Atualiza stats do item resultado
	# Limpa stats antigas
	for child in result_stats.get_children():
		child.queue_free()
	
	var stats = result.get("stats", {})
	if not stats.is_empty():
		# TÃ­tulo
		var title = Label.new()
		title.text = "Atributos:"
		title.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
		result_stats.add_child(title)
		
		# Stats individuais
		for stat_name in stats:
			var stat_container = HBoxContainer.new()
			
			var name_label = Label.new()
			name_label.text = stat_name.capitalize() + ":"
			name_label.custom_minimum_size.x = 80
			name_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
			stat_container.add_child(name_label)
			
			var value_label = Label.new()
			value_label.text = "+" + str(stats[stat_name])
			value_label.add_theme_color_override("font_color", UIThemeManager.Colors.SUCCESS_GREEN)
			stat_container.add_child(value_label)
			
			result_stats.add_child(stat_container)
	
	# DescriÃ§Ã£o
	if result.has("description"):
		var desc_label = Label.new()
		desc_label.text = result.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size.x = 200
		desc_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
		result_stats.add_child(desc_label)

func update_materials_list():
# Atualiza lista de materiais necessÃ¡rios
	# Limpa materiais antigos
	for child in materials_container.get_children():
		child.queue_free()
	
	var materials = current_recipe.get("materials", [])
	var can_craft = true
	
	for material in materials:
		var material_row = create_material_row(material)
		materials_container.add_child(material_row)
		
		if not has_enough_material(material):
			can_craft = false
	
	# Atualiza botÃ£o de craft
	craft_button.disabled = not can_craft
	craft_button.text = "Criar" if can_craft else "Materiais Insuficientes"

func create_material_row(material: Dictionary) -> HBoxContainer:
# Cria linha para um material
	var container = HBoxContainer.new()
	
	# Ãcone do material
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	if material.has("icon"):
		icon.texture = load(material.icon) if material.icon is String else material.icon
	container.add_child(icon)
	
	# Nome e quantidade
	var info_container = VBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = material.get("name", "Material")
	name_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	info_container.add_child(name_label)
	
	var quantity_label = Label.new()
	var required = material.get("quantity", 1)
	var available = get_material_count(material.get("id", ""))
	
	quantity_label.text = str(available) + "/" + str(required)
	var color = UIThemeManager.Colors.SUCCESS_GREEN if available >= required else UIThemeManager.Colors.ERROR_RED
	quantity_label.add_theme_color_override("font_color", color)
	info_container.add_child(quantity_label)
	
	container.add_child(info_container)
	
	return container

func has_enough_material(material: Dictionary) -> bool:
# Verifica se tem material suficiente
	var required = material.get("quantity", 1)
	var available = get_material_count(material.get("id", ""))
	return available >= required

func get_material_count(item_id: String) -> int:
# Retorna quantidade de material disponÃ­vel
	# TODO: Integrar com sistema de inventÃ¡rio
	return 10  # Placeholder

func update_crafting_info():
# Atualiza informaÃ§Ãµes de crafting
	# Chance de sucesso
	var base_chance = current_recipe.get("base_success_chance", 100)
	var level_bonus = calculate_level_bonus()
	var station_bonus = calculate_station_bonus()
	
	var total_chance = min(100, base_chance + level_bonus + station_bonus)
	
	success_bar.value = total_chance
	success_label.text = str(total_chance) + "% de Sucesso"
	
	if total_chance < 50:
		success_label.add_theme_color_override("font_color", UIThemeManager.Colors.ERROR_RED)
	elif total_chance < 80:
		success_label.add_theme_color_override("font_color", UIThemeManager.Colors.WARNING_ORANGE)
	else:
		success_label.add_theme_color_override("font_color", UIThemeManager.Colors.SUCCESS_GREEN)
	
	# Tempo de craft
	var craft_time = current_recipe.get("craft_time", 5.0)
	craft_time_label.text = "Tempo: " + str(craft_time) + "s"
	
	# XP reward
	var xp_reward = current_recipe.get("xp_reward", 10)
	xp_reward_label.text = "XP: +" + str(xp_reward)
	xp_reward_label.add_theme_color_override("font_color", UIThemeManager.Colors.XP_YELLOW)

func calculate_level_bonus() -> float:
# Calcula bÃ´nus de nÃ­vel
	var recipe_level = current_recipe.get("level_requirement", 1)
	var level_diff = player_crafting_level - recipe_level
	return max(0, level_diff * 2)  # +2% por nÃ­vel acima do necessÃ¡rio

func calculate_station_bonus() -> float:
# Calcula bÃ´nus da estaÃ§Ã£o de crafting
	var required_station = current_recipe.get("required_station", "")
	if required_station in available_stations:
		return 10  # +10% com estaÃ§Ã£o adequada
	return 0

func update_station_info():
# Atualiza informaÃ§Ãµes da estaÃ§Ã£o
	var required_station = current_recipe.get("required_station", "workbench")
	
	# Ãcone da estaÃ§Ã£o
	var station_data = get_station_data(required_station)
	if station_data.has("icon"):
		station_icon.texture = load(station_data.icon)
	
	# Nome
	station_name.text = station_data.get("name", required_station.capitalize())
	
	# NÃ­vel
	var station_level_req = current_recipe.get("station_level", 1)
	station_level.text = "NÃ­vel " + str(station_level_req)
	
	# Cor baseada na disponibilidade
	var color = UIThemeManager.Colors.SUCCESS_GREEN if required_station in available_stations else UIThemeManager.Colors.ERROR_RED
	station_name.add_theme_color_override("font_color", color)

func get_station_data(station_id: String) -> Dictionary:
# Retorna dados da estaÃ§Ã£o de crafting
	var stations = {
		"workbench": {"name": "Bancada de Trabalho", "icon": "res://assets/icons/stations/workbench.png"},
		"forge": {"name": "Forja", "icon": "res://assets/icons/stations/forge.png"},
		"alchemy_table": {"name": "Mesa de Alquimia", "icon": "res://assets/icons/stations/alchemy.png"},
		"enchanting_table": {"name": "Mesa de Encantamento", "icon": "res://assets/icons/stations/enchanting.png"}
	}
	
	return stations.get(station_id, {"name": station_id.capitalize(), "icon": ""})

func clear_preview():
# Limpa preview quando nenhuma receita estÃ¡ selecionada
	result_icon.texture = null
	result_name.text = "Selecione uma receita"
	result_name.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
	
	for child in result_stats.get_children():
		child.queue_free()
	
	for child in materials_container.get_children():
		child.queue_free()
	
	craft_button.disabled = true
	craft_button.text = "Selecione uma receita"

func _on_craft_pressed():
# BotÃ£o de craft pressionado
	if current_recipe.is_empty():
		return
	
	start_crafting()

func start_crafting():
# Inicia processo de crafting
	# Verifica materiais novamente
	if not check_materials():
		return
	
	# Consome materiais
	consume_materials()
	
	# Calcula sucesso
	var success_chance = success_bar.value
	var success = randf() * 100.0 <= success_chance
	
	if success:
		craft_success()
	else:
		craft_failure()

func check_materials() -> bool:
# Verifica se ainda tem todos os materiais
	var materials = current_recipe.get("materials", [])
	
	for material in materials:
		if not has_enough_material(material):
			return false
	
	return true

func consume_materials():
# Consome materiais do inventÃ¡rio
	var materials = current_recipe.get("materials", [])
	
	for material in materials:
		var item_id = material.get("id", "")
		var quantity = material.get("quantity", 1)
		# TODO: Remover do inventÃ¡rio
		print("Consumindo: ", quantity, "x ", item_id)

func craft_success():
# Crafting bem-sucedido
	var result = current_recipe.get("result", {})
	var quantity = result.get("quantity", 1)
	
	# Adiciona item ao inventÃ¡rio
	# TODO: Integrar com inventÃ¡rio
	print("Crafting success: ", quantity, "x ", result.get("name", "Item"))
	
	# XP reward
	var xp = current_recipe.get("xp_reward", 10)
	if EventBus:
		EventBus.player_gained_crafting_xp.emit(xp)
	
	item_crafted.emit(current_recipe.id, result)
	
	# Feedback visual
	show_craft_success_effect()

func craft_failure():
# Crafting falhou
	var reason = "Falha no processo de criaÃ§Ã£o"
	
	# Chance de retornar alguns materiais
	var return_chance = 0.5
	if randf() <= return_chance:
		reason = "Falha parcial - alguns materiais retornados"
		# TODO: Retornar 50% dos materiais
	
	crafting_failed.emit(current_recipe.id, reason)
	
	# Feedback visual
	show_craft_failure_effect()

func show_craft_success_effect():
# Efeito visual de sucesso
	var effect_label = Label.new()
	effect_label.text = "SUCESSO!"
	effect_label.position = craft_button.global_position
	effect_label.add_theme_color_override("font_color", UIThemeManager.Colors.SUCCESS_GREEN)
	effect_label.add_theme_font_size_override("font_size", 24)
	effect_label.z_index = 1000
	get_tree().current_scene.add_child(effect_label)
	
	var tween = create_tween()
	tween.parallel().tween_property(effect_label, "position", effect_label.position + Vector2(0, -50), 1.5)
	tween.parallel().tween_property(effect_label, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_callback(effect_label.queue_free)

func show_craft_failure_effect():
# Efeito visual de falha
	var effect_label = Label.new()
	effect_label.text = "FALHOU!"
	effect_label.position = craft_button.global_position
	effect_label.add_theme_color_override("font_color", UIThemeManager.Colors.ERROR_RED)
	effect_label.add_theme_font_size_override("font_size", 24)
	effect_label.z_index = 1000
	get_tree().current_scene.add_child(effect_label)
	
	var tween = create_tween()
	tween.parallel().tween_property(effect_label, "position", effect_label.position + Vector2(0, -50), 1.5)
	tween.parallel().tween_property(effect_label, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_callback(effect_label.queue_free)

func get_rarity_color(rarity: String) -> Color:
# Retorna cor da raridade
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)
		"epic": return Color(0.6, 0.3, 0.9)
		"rare": return Color(0.0, 0.5, 1.0)
		"uncommon": return Color(0.0, 1.0, 0.0)
		_: return UIThemeManager.Colors.TEXT_PRIMARY

# === EVENT HANDLERS ===
func _on_search_changed(text: String):
# Busca foi alterada
	refresh_recipes()

func _on_crafting_level_changed(new_level: int):
# NÃ­vel de crafting do player mudou
	player_crafting_level = new_level
	refresh_recipes()
	if not current_recipe.is_empty():
		update_crafting_info()

func _on_station_available(station_id: String):
# Nova estaÃ§Ã£o de crafting disponÃ­vel
	if station_id not in available_stations:
		available_stations.append(station_id)
		if not current_recipe.is_empty():
			update_station_info()
			update_crafting_info()

func _on_inventory_changed():
# InventÃ¡rio foi alterado
	if not current_recipe.is_empty():
		update_materials_list()

# === PUBLIC INTERFACE ===
func set_player_crafting_level(level: int):
# Define nÃ­vel de crafting do player
	player_crafting_level = level
	refresh_recipes()

func add_available_station(station_id: String):
# Adiciona estaÃ§Ã£o disponÃ­vel
	if station_id not in available_stations:
		available_stations.append(station_id)

func remove_available_station(station_id: String):
# Remove estaÃ§Ã£o disponÃ­vel
	available_stations.erase(station_id)
