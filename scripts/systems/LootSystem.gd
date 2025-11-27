extends Node

class_name LootSystem

signal loot_generated(loot_table: Array)
signal item_dropped(item_id: String, position: Vector2)
signal loot_collected(item_id: String, quantity: int)
signal rare_item_found(item_id: String, rarity: String)

# Loot configuration
var base_drop_chance: float = 0.75
var rare_multiplier: float = 0.1
var epic_multiplier: float = 0.05
var legendary_multiplier: float = 0.01

# Rarity levels
enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

var rarity_names = {
	ItemRarity.COMMON: "common",
	ItemRarity.UNCOMMON: "uncommon", 
	ItemRarity.RARE: "rare",
	ItemRarity.EPIC: "epic",
	ItemRarity.LEGENDARY: "legendary"
}

var rarity_colors = {
	ItemRarity.COMMON: Color.WHITE,
	ItemRarity.UNCOMMON: Color.GREEN,
	ItemRarity.RARE: Color.BLUE,
	ItemRarity.EPIC: Color.PURPLE,
	ItemRarity.LEGENDARY: Color.ORANGE
}

# Loot tables cache
var mob_loot_tables: Dictionary = {}
var dungeon_loot_tables: Dictionary = {}
var boss_loot_tables: Dictionary = {}
var global_loot_pools: Dictionary = {}

# Drop instances
var active_drops: Dictionary = {} # drop_id -> DropInstance
var drop_counter: int = 0

# References
@onready var data_loader: DataLoader = get_node("/root/DataLoader")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var game_state: GameState = get_node("/root/GameState")

func _ready():
	await setup_loot_system()
	connect_events()
	print("[LootSystem] Sistema de Loot inicializado")

func setup_loot_system():
	"""Initialize loot system and build loot tables"""
	# Wait for data to be loaded
	if not data_loader.is_fully_loaded():
		await data_loader.all_data_loaded
	
	build_loot_tables()
	setup_global_loot_pools()

func connect_events():
	"""Connect to game events"""
	event_bus.connect("enemy_defeated", _on_enemy_defeated)
	event_bus.connect("boss_defeated", _on_boss_defeated)
	event_bus.connect("container_opened", _on_container_opened)
	event_bus.connect("quest_completed", _on_quest_completed)

func build_loot_tables():
	"""Build loot tables from enemy data"""
	var enemies_data = data_loader.get_all_enemies()
	
	for enemy_id in enemies_data.keys():
		var enemy_data = enemies_data[enemy_id]
		var loot_table = enemy_data.get("loot_table", {})
		
		if not loot_table.is_empty():
			mob_loot_tables[enemy_id] = process_loot_table(loot_table)
	
	print("[LootSystem] Construídas %d tabelas de loot" % mob_loot_tables.size())

func process_loot_table(raw_loot_table: Dictionary) -> Dictionary:
	"""Process and validate a loot table"""
	var processed_table = {
		"guaranteed_drops": [],
		"chance_drops": [],
		"rare_drops": [],
		"currency_range": {"min": 0, "max": 0}
	}
	
	# Process guaranteed drops
	if raw_loot_table.has("guaranteed"):
		for item_data in raw_loot_table.guaranteed:
			processed_table.guaranteed_drops.append({
				"item_id": item_data.get("item_id", ""),
				"quantity": item_data.get("quantity", 1),
				"condition": item_data.get("condition", "")
			})
	
	# Process chance-based drops
	if raw_loot_table.has("chance_drops"):
		for item_data in raw_loot_table.chance_drops:
			processed_table.chance_drops.append({
				"item_id": item_data.get("item_id", ""),
				"chance": item_data.get("chance", 0.1),
				"quantity": item_data.get("quantity", 1),
				"min_level": item_data.get("min_level", 1)
			})
	
	# Process rare drops
	if raw_loot_table.has("rare_drops"):
		for item_data in raw_loot_table.rare_drops:
			processed_table.rare_drops.append({
				"item_id": item_data.get("item_id", ""),
				"rarity": item_data.get("rarity", "rare"),
				"chance": item_data.get("chance", 0.05),
				"quantity": item_data.get("quantity", 1)
			})
	
	# Process currency
	if raw_loot_table.has("currency"):
		var currency = raw_loot_table.currency
		processed_table.currency_range = {
			"min": currency.get("min", 0),
			"max": currency.get("max", 0)
		}
	
	return processed_table

func setup_global_loot_pools():
	"""Setup global loot pools for different contexts"""
	global_loot_pools = {
		"consumables": get_items_by_category("consumable"),
		"weapons": get_items_by_category("weapon"),
		"armor": get_items_by_category("armor"),
		"accessories": get_items_by_category("accessory"),
		"materials": get_items_by_category("material"),
		"quest_items": get_items_by_category("quest")
	}
	
	print("[LootSystem] Pools globais configurados")

func get_items_by_category(category: String) -> Array:
	"""Get all items of specific category"""
	var items = []
	var all_items = data_loader.get_all_items()
	
	for item_id in all_items.keys():
		var item_data = all_items[item_id]
		if item_data.get("type", "") == category:
			items.append(item_data)
	
	return items

func generate_loot(source_id: String, source_type: String, player_level: int = 1, bonus_multiplier: float = 1.0) -> Array:
	"""Generate loot from a source"""
	var loot_items = []
	var loot_table = get_loot_table(source_id, source_type)
	
	if loot_table.is_empty():
		return loot_items
	
	# Generate guaranteed drops
	for drop_data in loot_table.guaranteed_drops:
		if check_drop_condition(drop_data.condition, player_level):
			loot_items.append(create_loot_item(drop_data))
	
	# Generate chance-based drops
	for drop_data in loot_table.chance_drops:
		if player_level >= drop_data.min_level:
			var adjusted_chance = drop_data.chance * bonus_multiplier
			if randf() <= adjusted_chance:
				loot_items.append(create_loot_item(drop_data))
	
	# Generate rare drops
	for drop_data in loot_table.rare_drops:
		var rarity_chance = get_rarity_chance(drop_data.rarity) * bonus_multiplier
		if randf() <= rarity_chance:
			var loot_item = create_loot_item(drop_data)
			loot_item["rarity"] = drop_data.rarity
			loot_items.append(loot_item)
			rare_item_found.emit(drop_data.item_id, drop_data.rarity)
	
	# Generate currency
	var currency_amount = generate_currency(loot_table.currency_range, player_level)
	if currency_amount > 0:
		loot_items.append({
			"item_id": "gold",
			"quantity": currency_amount,
			"type": "currency"
		})
	
	loot_generated.emit(loot_items)
	return loot_items

func get_loot_table(source_id: String, source_type: String) -> Dictionary:
	"""Get loot table for source"""
	match source_type:
		"enemy":
			return mob_loot_tables.get(source_id, {})
		"boss":
			return boss_loot_tables.get(source_id, {})
		"dungeon":
			return dungeon_loot_tables.get(source_id, {})
		_:
			return {}

func create_loot_item(drop_data: Dictionary) -> Dictionary:
	"""Create loot item from drop data"""
	return {
		"item_id": drop_data.item_id,
		"quantity": drop_data.quantity,
		"type": "item",
		"rarity": drop_data.get("rarity", "common")
	}

func check_drop_condition(condition: String, player_level: int) -> bool:
	"""Check if drop condition is met"""
	if condition == "":
		return true
	
	# Parse simple conditions
	if condition.begins_with("level_"):
		var required_level = int(condition.substr(6))
		return player_level >= required_level
	
	return true

func get_rarity_chance(rarity: String) -> float:
	"""Get drop chance for rarity level"""
	match rarity:
		"common":
			return base_drop_chance
		"uncommon":
			return base_drop_chance * 0.5
		"rare":
			return rare_multiplier
		"epic":
			return epic_multiplier
		"legendary":
			return legendary_multiplier
		_:
			return base_drop_chance

func generate_currency(currency_range: Dictionary, player_level: int) -> int:
	"""Generate currency amount"""
	var min_amount = currency_range.get("min", 0)
	var max_amount = currency_range.get("max", 0)
	
	if max_amount <= 0:
		return 0
	
	# Scale with player level
	var level_multiplier = 1.0 + (player_level - 1) * 0.1
	min_amount = int(min_amount * level_multiplier)
	max_amount = int(max_amount * level_multiplier)
	
	return randi_range(min_amount, max_amount)

func drop_loot_at_position(loot_items: Array, position: Vector2, spread: float = 50.0):
	"""Drop loot items at world position"""
	for loot_item in loot_items:
		var drop_position = position + Vector2(
			randf_range(-spread, spread),
			randf_range(-spread, spread)
		)
		
		create_loot_drop(loot_item, drop_position)

func create_loot_drop(loot_item: Dictionary, position: Vector2) -> Node2D:
	"""Create physical loot drop in world"""
	drop_counter += 1
	var drop_id = "drop_" + str(drop_counter)
	
	var drop_instance = create_drop_node(loot_item, position)
	drop_instance.name = drop_id
	
	# Add to current scene
	get_tree().current_scene.add_child(drop_instance)
	
	# Track active drop
	active_drops[drop_id] = {
		"loot_item": loot_item,
		"position": position,
		"creation_time": Time.get_time_dict_from_system(),
		"node": drop_instance
	}
	
	item_dropped.emit(loot_item.item_id, position)
	return drop_instance

func create_drop_node(loot_item: Dictionary, position: Vector2) -> Area2D:
	"""Create the visual drop node"""
	var drop_area = Area2D.new()
	drop_area.position = position
	
	# Visual sprite
	var sprite = Sprite2D.new()
	sprite.texture = get_item_icon(loot_item.item_id)
	drop_area.add_child(sprite)
	
	# Collision for pickup
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 24
	collision.shape = shape
	drop_area.add_child(collision)
	
	# Rarity glow effect
	add_rarity_effect(drop_area, loot_item.get("rarity", "common"))
	
	# Connect pickup signal
	drop_area.body_entered.connect(_on_loot_pickup.bind(loot_item, drop_area))
	
	return drop_area

func get_item_icon(item_id: String) -> Texture2D:
	"""Get item icon texture"""
	var item_data = data_loader.get_item(item_id)
	if item_data and item_data.has("icon_path"):
		var icon_path = item_data.icon_path
		if ResourceLoader.exists(icon_path):
			return load(icon_path)
	
	# Return placeholder based on item type
	return create_item_placeholder_icon(item_id)

func create_item_placeholder_icon(item_id: String) -> ImageTexture:
	"""Create placeholder icon for item"""
	var color = Color.WHITE
	
	if item_id == "gold":
		color = Color.YELLOW
	else:
		var item_data = data_loader.get_item(item_id)
		if item_data:
			match item_data.get("type", ""):
				"weapon":
					color = Color.RED
				"armor":
					color = Color.BLUE
				"consumable":
					color = Color.GREEN
				"accessory":
					color = Color.PURPLE
				_:
					color = Color.WHITE
	
	var image = Image.create(24, 24, false, Image.FORMAT_RGB8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func add_rarity_effect(drop_node: Node2D, rarity: String):
	"""Add visual effect based on rarity"""
	# Add a simple colored outline or glow
	var effect_sprite = Sprite2D.new()
	effect_sprite.modulate = get_rarity_color(rarity)
	effect_sprite.modulate.a = 0.5
	effect_sprite.scale = Vector2(1.2, 1.2)
	effect_sprite.z_index = -1
	
	# Create simple glow texture
	var glow_texture = create_glow_texture(get_rarity_color(rarity))
	effect_sprite.texture = glow_texture
	
	drop_node.add_child(effect_sprite)

func get_rarity_color(rarity: String) -> Color:
	"""Get color for item rarity"""
	match rarity:
		"common":
			return Color.WHITE
		"uncommon":
			return Color.GREEN
		"rare":
			return Color.BLUE
		"epic":
			return Color.PURPLE
		"legendary":
			return Color.ORANGE
		_:
			return Color.WHITE

func create_glow_texture(color: Color) -> ImageTexture:
	"""Create glow effect texture"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func collect_loot(loot_item: Dictionary) -> bool:
	"""Add loot to player inventory"""
	var item_id = loot_item.item_id
	var quantity = loot_item.quantity
	
	if item_id == "gold":
		# Add currency
		game_state.modify_currency(quantity)
		loot_collected.emit(item_id, quantity)
		return true
	else:
		# Add item to inventory
		var success = game_state.add_item_to_inventory(item_id, quantity)
		if success:
			loot_collected.emit(item_id, quantity)
		return success

func generate_quest_reward_loot(quest_id: String, player_level: int) -> Array:
	"""Generate loot for quest completion"""
	var quest_data = data_loader.get_quest(quest_id)
	if not quest_data:
		return []
	
	var reward_items = []
	var rewards = quest_data.get("rewards", {})
	
	# Fixed items
	if rewards.has("items"):
		for item_data in rewards.items:
			reward_items.append({
				"item_id": item_data.get("item_id", ""),
				"quantity": item_data.get("quantity", 1),
				"type": "item"
			})
	
	# Random items from pool
	if rewards.has("random_items"):
		var random_config = rewards.random_items
		var pool = random_config.get("pool", "consumables")
		var count = random_config.get("count", 1)
		
		reward_items.append_array(generate_random_items(pool, count, player_level))
	
	return reward_items

func generate_random_items(pool_name: String, count: int, player_level: int) -> Array:
	"""Generate random items from pool"""
	var items = []
	var pool = global_loot_pools.get(pool_name, [])
	
	if pool.is_empty():
		return items
	
	for i in range(count):
		var random_item = pool[randi() % pool.size()]
		items.append({
			"item_id": random_item.id,
			"quantity": 1,
			"type": "item"
		})
	
	return items

# Event handlers
func _on_enemy_defeated(enemy_id: String, position: Vector2, player_level: int):
	"""Handle enemy defeat and generate loot"""
	var loot_items = generate_loot(enemy_id, "enemy", player_level)
	if loot_items.size() > 0:
		drop_loot_at_position(loot_items, position)

func _on_boss_defeated(boss_id: String, position: Vector2, player_level: int):
	"""Handle boss defeat with bonus loot"""
	var bonus_multiplier = 2.0  # Bosses have better loot
	var loot_items = generate_loot(boss_id, "boss", player_level, bonus_multiplier)
	if loot_items.size() > 0:
		drop_loot_at_position(loot_items, position, 100.0)  # Larger spread

func _on_container_opened(container_id: String, position: Vector2, player_level: int):
	"""Handle container opening"""
	var loot_items = generate_loot(container_id, "container", player_level)
	if loot_items.size() > 0:
		drop_loot_at_position(loot_items, position, 30.0)

func _on_quest_completed(quest_id: String, player_level: int):
	"""Handle quest completion rewards"""
	var reward_items = generate_quest_reward_loot(quest_id, player_level)
	
	# Add rewards directly to inventory
	for reward in reward_items:
		collect_loot(reward)

func _on_loot_pickup(loot_item: Dictionary, drop_node: Node2D, body: Node2D):
	"""Handle loot pickup by player"""
	if not body.has_method("is_player"):
		return
	
	if collect_loot(loot_item):
		# Remove from active drops
		var drop_id = drop_node.name
		if active_drops.has(drop_id):
			active_drops.erase(drop_id)
		
		# Remove visual node
		drop_node.queue_free()

# Utility functions
func get_total_loot_value(loot_items: Array) -> int:
	"""Calculate total value of loot"""
	var total_value = 0
	
	for loot_item in loot_items:
		if loot_item.item_id == "gold":
			total_value += loot_item.quantity
		else:
			var item_data = data_loader.get_item(loot_item.item_id)
			if item_data:
				var item_value = item_data.get("value", 1)
				total_value += item_value * loot_item.quantity
	
	return total_value

func clear_all_drops():
	"""Clear all active loot drops"""
	for drop_id in active_drops.keys():
		var drop_data = active_drops[drop_id]
		if drop_data.node:
			drop_data.node.queue_free()
	
	active_drops.clear()

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"active_drops": serialize_active_drops()
	}

func serialize_active_drops() -> Array:
	"""Serialize active drops for saving"""
	var serialized_drops = []
	
	for drop_id in active_drops.keys():
		var drop_data = active_drops[drop_id]
		serialized_drops.append({
			"drop_id": drop_id,
			"loot_item": drop_data.loot_item,
			"position": {"x": drop_data.position.x, "y": drop_data.position.y},
			"creation_time": drop_data.creation_time
		})
	
	return serialized_drops

func load_save_data(data: Dictionary):
	"""Load loot system save data"""
	if data.has("active_drops"):
		restore_active_drops(data.active_drops)

func restore_active_drops(serialized_drops: Array):
	"""Restore active drops from save data"""
	clear_all_drops()
	
	for drop_data in serialized_drops:
		var position = Vector2(drop_data.position.x, drop_data.position.y)
		var loot_item = drop_data.loot_item
		create_loot_drop(loot_item, position)

# Debug functions
func debug_generate_test_loot(enemy_id: String, position: Vector2):
	"""Debug: Generate test loot"""
	var loot_items = generate_loot(enemy_id, "enemy", 10, 2.0)
	drop_loot_at_position(loot_items, position)

func debug_spawn_rare_item(item_id: String, position: Vector2, rarity: String = "legendary"):
	"""Debug: Spawn specific rare item"""
	var loot_item = {
		"item_id": item_id,
		"quantity": 1,
		"rarity": rarity
	}
	create_loot_drop(loot_item, position)