extends Node

## Sistema central de dados JSON para balanceamento do jogo Disorder Chaos
## Carrega e gerencia todos os dados de configuração do jogo

# === DADOS CARREGADOS ===
var classes: Dictionary = {}
var items: Dictionary = {}
var mobs: Dictionary = {}
var skills: Dictionary = {}
var quests: Dictionary = {}
var economy: Dictionary = {}
var loot_tables: Dictionary = {}
var crafting_recipes: Dictionary = {}

# === STATUS DE CARREGAMENTO ===
var is_loaded: bool = false
var loading_errors: Array[String] = []

# === CAMINHOS DOS ARQUIVOS ===
var data_paths: Dictionary = {
	"classes": "res://data/classes.json",
	"items": "res://data/items.json",
	"mobs": "res://data/mobs.json",
	"skills": "res://data/skills.json",
	"quests": "res://data/quests.json",
	"economy": "res://data/economy.json",
	"loot_tables": "res://data/loot_tables.json",
	"crafting": "res://data/crafting/recipes.json"
}

signal data_loaded
signal data_loading_failed(errors: Array[String])

func _ready():
	print("[GameDatabase] Inicializando sistema de dados...")
	load_all_data()

# === CARREGAMENTO DE DADOS ===

func load_all_data():
	"""Carrega todos os arquivos JSON de dados"""
	loading_errors.clear()
	
	print("[GameDatabase] Carregando dados do jogo...")
	
	# Carrega cada arquivo de dados
	classes = load_json_file(data_paths.classes, "classes")
	items = load_json_file(data_paths.items, "items")
	mobs = load_json_file(data_paths.mobs, "mobs")
	skills = load_json_file(data_paths.skills, "skills")
	quests = load_json_file(data_paths.quests, "quests")
	economy = load_json_file(data_paths.economy, "economy")
	loot_tables = load_json_file(data_paths.loot_tables, "loot_tables")
	crafting_recipes = load_json_file(data_paths.crafting, "crafting")
	
	# Valida dados carregados
	validate_loaded_data()
	
	if loading_errors.is_empty():
		is_loaded = true
		print("[GameDatabase] Todos os dados carregados com sucesso!")
		data_loaded.emit()
	else:
		print("[GameDatabase] Falha ao carregar alguns dados:")
		for error in loading_errors:
			print("  - ", error)
		data_loading_failed.emit(loading_errors)

func load_json_file(path: String, data_type: String) -> Dictionary:
	"""Carrega arquivo JSON individual"""
	if not FileAccess.file_exists(path):
		loading_errors.append("Arquivo não encontrado: " + path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		loading_errors.append("Não foi possível abrir: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		loading_errors.append("Erro de JSON em " + path + ": " + json.get_error_message())
		return {}
	
	print("[GameDatabase] Carregado: ", data_type, " (", path, ")")
	return json.data

func validate_loaded_data():
	"""Valida integridade dos dados carregados"""
	# Valida referências entre dados
	validate_item_references()
	validate_quest_references()
	validate_crafting_references()
	validate_loot_table_references()

func validate_item_references():
	"""Valida referências de itens"""
	# Verifica se crafting recipes referenciam itens válidos
	for recipe_id in crafting_recipes.get("recipes", {}):
		var recipe = crafting_recipes.recipes[recipe_id]
		
		# Valida materiais
		for material in recipe.get("materials", []):
			var item_id = material.get("id", "")
			if item_id != "" and not items.has(item_id):
				loading_errors.append("Receita " + recipe_id + " referencia item inexistente: " + item_id)
		
		# Valida resultado
		var result_id = recipe.get("result", {}).get("id", "")
		if result_id != "" and not items.has(result_id):
			loading_errors.append("Receita " + recipe_id + " produz item inexistente: " + result_id)

func validate_quest_references():
	"""Valida referências de quests"""
	for quest_id in quests:
		var quest = quests[quest_id]
		
		# Valida recompensas de itens
		for reward in quest.get("rewards", {}).get("items", []):
			var item_id = reward.get("id", "")
			if item_id != "" and not items.has(item_id):
				loading_errors.append("Quest " + quest_id + " oferece item inexistente: " + item_id)

func validate_crafting_references():
	"""Valida referências de crafting"""
	for recipe_id in crafting_recipes.get("recipes", {}):
		var recipe = crafting_recipes.recipes[recipe_id]
		
		# Valida estação de crafting
		var station = recipe.get("required_station", "")
		if station != "" and not economy.get("crafting_stations", {}).has(station):
			loading_errors.append("Receita " + recipe_id + " requer estação inexistente: " + station)

func validate_loot_table_references():
	"""Valida referências de loot tables"""
	for table_id in loot_tables:
		var table = loot_tables[table_id]
		
		for drop in table.get("drops", []):
			var item_id = drop.get("item_id", "")
			if item_id != "" and not items.has(item_id):
				loading_errors.append("Loot table " + table_id + " contém item inexistente: " + item_id)

# === GETTERS DE DADOS ===

func get_item(item_id: String) -> Dictionary:
	"""Retorna dados de um item"""
	return items.get(item_id, {})

func get_mob(mob_id: String) -> Dictionary:
	"""Retorna dados de um mob"""
	return mobs.get(mob_id, {})

func get_class(class_id: String) -> Dictionary:
	"""Retorna dados de uma classe"""
	return classes.get(class_id, {})

func get_skill(skill_id: String) -> Dictionary:
	"""Retorna dados de uma skill"""
	return skills.get(skill_id, {})

func get_quest(quest_id: String) -> Dictionary:
	"""Retorna dados de uma quest"""
	return quests.get(quest_id, {})

func get_loot_table(table_id: String) -> Dictionary:
	"""Retorna loot table"""
	return loot_tables.get(table_id, {})

func get_crafting_recipe(recipe_id: String) -> Dictionary:
	"""Retorna receita de crafting"""
	return crafting_recipes.get("recipes", {}).get(recipe_id, {})

# === GETTERS ESPECÍFICOS ===

func get_items_by_type(item_type: String) -> Array[Dictionary]:
	"""Retorna todos os itens de um tipo específico"""
	var filtered_items: Array[Dictionary] = []
	
	for item_id in items:
		var item = items[item_id]
		if item.get("type", "") == item_type:
			var item_data = item.duplicate()
			item_data["id"] = item_id
			filtered_items.append(item_data)
	
	return filtered_items

func get_items_by_rarity(rarity: String) -> Array[Dictionary]:
	"""Retorna todos os itens de uma raridade específica"""
	var filtered_items: Array[Dictionary] = []
	
	for item_id in items:
		var item = items[item_id]
		if item.get("rarity", "common") == rarity:
			var item_data = item.duplicate()
			item_data["id"] = item_id
			filtered_items.append(item_data)
	
	return filtered_items

func get_mobs_by_level_range(min_level: int, max_level: int) -> Array[Dictionary]:
	"""Retorna mobs dentro de uma faixa de nível"""
	var filtered_mobs: Array[Dictionary] = []
	
	for mob_id in mobs:
		var mob = mobs[mob_id]
		var mob_level = mob.get("level", 1)
		if mob_level >= min_level and mob_level <= max_level:
			var mob_data = mob.duplicate()
			mob_data["id"] = mob_id
			filtered_mobs.append(mob_data)
	
	return filtered_mobs

func get_quests_by_level(player_level: int) -> Array[Dictionary]:
	"""Retorna quests apropriadas para o nível do player"""
	var available_quests: Array[Dictionary] = []
	
	for quest_id in quests:
		var quest = quests[quest_id]
		var min_level = quest.get("level_requirement", 1)
		var max_level = quest.get("max_level", 999)
		
		if player_level >= min_level and player_level <= max_level:
			var quest_data = quest.duplicate()
			quest_data["id"] = quest_id
			available_quests.append(quest_data)
	
	return available_quests

func get_crafting_recipes_by_category(category: String) -> Array[Dictionary]:
	"""Retorna receitas de crafting por categoria"""
	var filtered_recipes: Array[Dictionary] = []
	
	for recipe_id in crafting_recipes.get("recipes", {}):
		var recipe = crafting_recipes.recipes[recipe_id]
		if recipe.get("category", "") == category:
			var recipe_data = recipe.duplicate()
			recipe_data["id"] = recipe_id
			filtered_recipes.append(recipe_data)
	
	return filtered_recipes

func get_skills_by_tree(tree_name: String) -> Array[Dictionary]:
	"""Retorna skills de uma árvore específica"""
	var tree_skills: Array[Dictionary] = []
	
	for skill_id in skills:
		var skill = skills[skill_id]
		if skill.get("tree", "") == tree_name:
			var skill_data = skill.duplicate()
			skill_data["id"] = skill_id
			tree_skills.append(skill_data)
	
	return tree_skills

# === ECONOMIA ===

func get_item_base_price(item_id: String) -> int:
	"""Retorna preço base de um item"""
	var item = get_item(item_id)
	if item.has("base_price"):
		return item.base_price
	
	# Fallback para cálculo baseado em raridade
	var rarity = item.get("rarity", "common")
	var base_values = economy.get("base_prices", {})
	return base_values.get(rarity, 1)

func get_current_item_price(item_id: String, market_modifier: float = 1.0) -> int:
	"""Retorna preço atual considerando fatores econômicos"""
	var base_price = get_item_base_price(item_id)
	var item = get_item(item_id)
	
	# Modificadores econômicos
	var rarity_multiplier = economy.get("rarity_multipliers", {}).get(item.get("rarity", "common"), 1.0)
	var type_multiplier = economy.get("type_multipliers", {}).get(item.get("type", "misc"), 1.0)
	
	var final_price = base_price * rarity_multiplier * type_multiplier * market_modifier
	return max(1, int(final_price))

func get_shop_modifier(shop_type: String) -> float:
	"""Retorna modificador de preço para tipo de loja"""
	var shop_modifiers = economy.get("shop_modifiers", {})
	return shop_modifiers.get(shop_type, 1.0)

# === LOOT GENERATION ===

func generate_loot(table_id: String) -> Array[Dictionary]:
	"""Gera loot baseado em uma tabela"""
	var table = get_loot_table(table_id)
	if table.is_empty():
		return []
	
	var generated_loot: Array[Dictionary] = []
	var drops = table.get("drops", [])
	
	for drop in drops:
		var chance = drop.get("chance", 100.0)
		if randf() * 100.0 <= chance:
			var item_id = drop.get("item_id", "")
			var quantity_min = drop.get("quantity_min", 1)
			var quantity_max = drop.get("quantity_max", 1)
			var quantity = randi_range(quantity_min, quantity_max)
			
			if item_id != "":
				var item_data = get_item(item_id).duplicate()
				if not item_data.is_empty():
					item_data["id"] = item_id
					item_data["quantity"] = quantity
					generated_loot.append(item_data)
	
	return generated_loot

# === UTILITIES ===

func reload_data():
	"""Recarrega todos os dados (útil para desenvolvimento)"""
	is_loaded = false
	load_all_data()

func get_data_summary() -> Dictionary:
	"""Retorna resumo dos dados carregados"""
	return {
		"items_count": items.size(),
		"mobs_count": mobs.size(),
		"classes_count": classes.size(),
		"skills_count": skills.size(),
		"quests_count": quests.size(),
		"recipes_count": crafting_recipes.get("recipes", {}).size(),
		"loot_tables_count": loot_tables.size(),
		"is_loaded": is_loaded,
		"loading_errors": loading_errors
	}

func search_items(search_term: String) -> Array[Dictionary]:
	"""Busca itens por nome ou descrição"""
	var results: Array[Dictionary] = []
	var term = search_term.to_lower()
	
	for item_id in items:
		var item = items[item_id]
		var name = item.get("name", "").to_lower()
		var description = item.get("description", "").to_lower()
		
		if term in name or term in description:
			var item_data = item.duplicate()
			item_data["id"] = item_id
			results.append(item_data)
	
	return results

func get_random_item_by_rarity(rarity: String) -> Dictionary:
	"""Retorna item aleatório de uma raridade"""
	var items_of_rarity = get_items_by_rarity(rarity)
	if items_of_rarity.is_empty():
		return {}
	
	var random_index = randi() % items_of_rarity.size()
	return items_of_rarity[random_index]

# === VALIDATION HELPERS ===

func validate_item_id(item_id: String) -> bool:
	"""Verifica se item ID existe"""
	return items.has(item_id)

func validate_mob_id(mob_id: String) -> bool:
	"""Verifica se mob ID existe"""
	return mobs.has(mob_id)

func validate_skill_id(skill_id: String) -> bool:
	"""Verifica se skill ID existe"""
	return skills.has(skill_id)

func validate_quest_id(quest_id: String) -> bool:
	"""Verifica se quest ID existe"""
	return quests.has(quest_id)

# === DEBUG FUNCTIONS ===

func print_data_summary():
	"""Imprime resumo dos dados para debug"""
	var summary = get_data_summary()
	print("=== GAME DATABASE SUMMARY ===")
	print("Loaded: ", summary.is_loaded)
	print("Items: ", summary.items_count)
	print("Mobs: ", summary.mobs_count)
	print("Classes: ", summary.classes_count)
	print("Skills: ", summary.skills_count)
	print("Quests: ", summary.quests_count)
	print("Recipes: ", summary.recipes_count)
	print("Loot Tables: ", summary.loot_tables_count)
	
	if not summary.loading_errors.is_empty():
		print("Errors: ")
		for error in summary.loading_errors:
			print("  - ", error)

func export_data_to_json(file_path: String):
	"""Exporta todos os dados para um arquivo JSON (backup/debug)"""
	var all_data = {
		"classes": classes,
		"items": items,
		"mobs": mobs,
		"skills": skills,
		"quests": quests,
		"economy": economy,
		"loot_tables": loot_tables,
		"crafting_recipes": crafting_recipes
	}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(all_data, "\t"))
		file.close()
		print("Dados exportados para: ", file_path)
	else:
		print("Erro ao exportar dados para: ", file_path)