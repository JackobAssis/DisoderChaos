extends Node

class_name DungeonSystem

signal dungeon_loaded(dungeon_id: String)
signal dungeon_unloaded(dungeon_id: String)
signal fragment_discovered(fragment_id: String)
signal player_entered_dungeon(dungeon_id: String)
signal player_exited_dungeon(dungeon_id: String)

# Current dungeon state
var current_dungeon: Dictionary = {}
var current_dungeon_id: String = ""
var current_dungeon_scene: Node2D = null

# Fragment connection system
var discovered_fragments: Array = []
var unlocked_connections: Dictionary = {}
var fragment_map: Dictionary = {}

# Dungeon instances and caching
var loaded_dungeons: Dictionary = {} # dungeon_id -> DungeonInstance
var dungeon_cache: Dictionary = {} # Pre-processed dungeon data

# Environment and spawning
var active_spawners: Array = []
var environment_effects: Array = []
var dungeon_entities: Array = []

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var data_loader: DataLoader = get_node("/root/DataLoader")

func _ready():
	await setup_dungeon_system()
	connect_events()
	print("[DungeonSystem] Sistema de Dungeons inicializado")

func setup_dungeon_system():
	"""Initialize dungeon system and load fragment map"""
	# Wait for data to be loaded
	if not data_loader.is_fully_loaded():
		await data_loader.all_data_loaded
	
	build_fragment_map()
	load_player_progress()

func connect_events():
	"""Connect to relevant game events"""
	event_bus.connect("player_moved", _on_player_moved)
	event_bus.connect("entity_spawned", _on_entity_spawned)
	event_bus.connect("entity_destroyed", _on_entity_destroyed)

func build_fragment_map():
	"""Build the fragment connection map from dungeon data"""
	var dungeons_data = data_loader.get_all_dungeons()
	
	for dungeon_id in dungeons_data.keys():
		var dungeon_data = dungeons_data[dungeon_id]
		fragment_map[dungeon_id] = {
			"connections": dungeon_data.get("connections", []),
			"requirements": dungeon_data.get("entry_requirements", {}),
			"position": dungeon_data.get("map_position", {"x": 0, "y": 0}),
			"discovered": false,
			"unlocked": false
		}
	
	print("[DungeonSystem] Fragment map built with %d dungeons" % fragment_map.size())

func load_player_progress():
	"""Load player's dungeon discovery progress"""
	var save_data = game_state.get_dungeon_progress()
	
	if save_data.has("discovered_fragments"):
		discovered_fragments = save_data.discovered_fragments
	
	if save_data.has("unlocked_connections"):
		unlocked_connections = save_data.unlocked_connections
	
	# Update fragment map with player progress
	for fragment_id in discovered_fragments:
		if fragment_map.has(fragment_id):
			fragment_map[fragment_id].discovered = true
	
	print("[DungeonSystem] Loaded progress: %d discovered, %d unlocked" % [discovered_fragments.size(), unlocked_connections.size()])

func load_dungeon(dungeon_id: String) -> bool:
	"""Load a specific dungeon by ID"""
	print("[DungeonSystem] Loading dungeon: %s" % dungeon_id)
	
	# Check if dungeon exists
	var dungeon_data = data_loader.get_dungeon(dungeon_id)
	if not dungeon_data:
		print("[DungeonSystem] ❌ Dungeon not found: %s" % dungeon_id)
		return false
	
	# Check entry requirements
	if not check_entry_requirements(dungeon_id, dungeon_data):
		print("[DungeonSystem] ❌ Entry requirements not met for: %s" % dungeon_id)
		return false
	
	# Unload current dungeon if any
	if current_dungeon_scene:
		unload_current_dungeon()
	
	# Create dungeon instance
	var dungeon_instance = create_dungeon_instance(dungeon_data)
	if not dungeon_instance:
		print("[DungeonSystem] ❌ Failed to create dungeon instance: %s" % dungeon_id)
		return false
	
	# Set as current dungeon
	current_dungeon = dungeon_data
	current_dungeon_id = dungeon_id
	current_dungeon_scene = dungeon_instance
	
	# Add to scene tree
	get_tree().current_scene.add_child(dungeon_instance)
	
	# Setup dungeon systems
	setup_dungeon_environment(dungeon_data)
	setup_dungeon_spawners(dungeon_data)
	setup_dungeon_exits(dungeon_data)
	
	# Mark as discovered
	discover_fragment(dungeon_id)
	
	dungeon_loaded.emit(dungeon_id)
	player_entered_dungeon.emit(dungeon_id)
	
	print("[DungeonSystem] ✅ Dungeon loaded successfully: %s" % dungeon_id)
	return true

func create_dungeon_instance(dungeon_data: Dictionary) -> Node2D:
	"""Create a dungeon instance from data"""
	var dungeon_scene = Node2D.new()
	dungeon_scene.name = "Dungeon_" + dungeon_data.id
	
	# Create terrain layer
	var terrain_layer = create_terrain_layer(dungeon_data)
	dungeon_scene.add_child(terrain_layer)
	
	# Create decoration layer
	var decoration_layer = create_decoration_layer(dungeon_data)
	dungeon_scene.add_child(decoration_layer)
	
	# Create entity layer
	var entity_layer = Node2D.new()
	entity_layer.name = "EntityLayer"
	dungeon_scene.add_child(entity_layer)
	
	# Create UI layer
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	dungeon_scene.add_child(ui_layer)
	
	return dungeon_scene

func create_terrain_layer(dungeon_data: Dictionary) -> Node2D:
	"""Create terrain from dungeon data"""
	var terrain_layer = Node2D.new()
	terrain_layer.name = "TerrainLayer"
	
	# Get terrain data
	var terrain = dungeon_data.get("terrain", {})
	var width = terrain.get("width", 50)
	var height = terrain.get("height", 50)
	var tile_size = terrain.get("tile_size", 32)
	
	# Create basic terrain grid
	for x in range(width):
		for y in range(height):
			var tile = create_terrain_tile(terrain, x, y, tile_size)
			if tile:
				terrain_layer.add_child(tile)
	
	return terrain_layer

func create_terrain_tile(terrain_data: Dictionary, x: int, y: int, tile_size: int) -> Node2D:
	"""Create individual terrain tile"""
	var tile_type = get_tile_type(terrain_data, x, y)
	
	if tile_type == "empty":
		return null
	
	var tile = StaticBody2D.new()
	tile.name = "Tile_%d_%d" % [x, y]
	tile.position = Vector2(x * tile_size, y * tile_size)
	
	# Create sprite
	var sprite = Sprite2D.new()
	sprite.texture = get_tile_texture(tile_type)
	tile.add_child(sprite)
	
	# Create collision if solid
	if is_tile_solid(tile_type):
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(tile_size, tile_size)
		collision.shape = shape
		tile.add_child(collision)
	
	return tile

func get_tile_type(terrain_data: Dictionary, x: int, y: int) -> String:
	"""Get tile type at position"""
	var tiles = terrain_data.get("tiles", [])
	
	# Simple pattern for now - can be enhanced with actual tile maps
	if x == 0 or y == 0 or x >= 49 or y >= 49:
		return "wall"
	else:
		return "floor"

func get_tile_texture(tile_type: String) -> Texture2D:
	"""Get texture for tile type"""
	match tile_type:
		"wall":
			return create_placeholder_texture(Color.GRAY)
		"floor":
			return create_placeholder_texture(Color.DARK_GRAY)
		"water":
			return create_placeholder_texture(Color.BLUE)
		"lava":
			return create_placeholder_texture(Color.RED)
		_:
			return create_placeholder_texture(Color.WHITE)

func create_placeholder_texture(color: Color) -> ImageTexture:
	"""Create a placeholder texture with given color"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func is_tile_solid(tile_type: String) -> bool:
	"""Check if tile type is solid"""
	return tile_type in ["wall", "rock", "tree"]

func create_decoration_layer(dungeon_data: Dictionary) -> Node2D:
	"""Create decorative elements"""
	var decoration_layer = Node2D.new()
	decoration_layer.name = "DecorationLayer"
	
	var decorations = dungeon_data.get("decorations", [])
	
	for decoration_data in decorations:
		var decoration = create_decoration(decoration_data)
		if decoration:
			decoration_layer.add_child(decoration)
	
	return decoration_layer

func create_decoration(decoration_data: Dictionary) -> Node2D:
	"""Create individual decoration object"""
	var decoration = Node2D.new()
	decoration.name = decoration_data.get("name", "Decoration")
	
	var pos = decoration_data.get("position", {"x": 0, "y": 0})
	decoration.position = Vector2(pos.x, pos.y)
	
	var sprite = Sprite2D.new()
	sprite.texture = create_placeholder_texture(Color.GREEN)
	decoration.add_child(sprite)
	
	return decoration

func setup_dungeon_environment(dungeon_data: Dictionary):
	"""Setup environmental effects and lighting"""
	var environment = dungeon_data.get("environment", {})
	
	# Lighting
	var lighting = environment.get("lighting", "normal")
	setup_dungeon_lighting(lighting)
	
	# Weather/Climate effects
	var climate = environment.get("climate", "neutral")
	setup_climate_effects(climate)
	
	# Ambient sounds
	var ambient = environment.get("ambient_sound", "")
	if ambient != "":
		setup_ambient_sound(ambient)

func setup_dungeon_lighting(lighting_type: String):
	"""Setup dungeon lighting"""
	# This would integrate with a lighting system
	match lighting_type:
		"dark":
			print("[DungeonSystem] Setting up dark lighting")
		"bright":
			print("[DungeonSystem] Setting up bright lighting")
		"flickering":
			print("[DungeonSystem] Setting up flickering lighting")
		_:
			print("[DungeonSystem] Setting up normal lighting")

func setup_climate_effects(climate_type: String):
	"""Setup climate effects"""
	# This would integrate with the climate system
	match climate_type:
		"cold":
			print("[DungeonSystem] Applying cold climate effects")
		"hot":
			print("[DungeonSystem] Applying hot climate effects")
		"humid":
			print("[DungeonSystem] Applying humid climate effects")
		_:
			print("[DungeonSystem] Normal climate")

func setup_ambient_sound(sound_id: String):
	"""Setup ambient sounds"""
	print("[DungeonSystem] Setting up ambient sound: %s" % sound_id)

func setup_dungeon_spawners(dungeon_data: Dictionary):
	"""Setup enemy and item spawners"""
	var spawners = dungeon_data.get("spawners", [])
	active_spawners.clear()
	
	for spawner_data in spawners:
		var spawner = create_spawner(spawner_data)
		if spawner:
			active_spawners.append(spawner)
			current_dungeon_scene.get_node("EntityLayer").add_child(spawner)

func create_spawner(spawner_data: Dictionary) -> Node2D:
	"""Create an entity spawner"""
	var spawner = Node2D.new()
	spawner.name = "Spawner_" + spawner_data.get("type", "generic")
	
	var pos = spawner_data.get("position", {"x": 100, "y": 100})
	spawner.position = Vector2(pos.x, pos.y)
	
	# Add spawner script/logic here
	# This would integrate with enemy/item systems
	
	return spawner

func setup_dungeon_exits(dungeon_data: Dictionary):
	"""Setup exits and connections to other dungeons"""
	var exits = dungeon_data.get("exits", [])
	
	for exit_data in exits:
		var exit_portal = create_exit_portal(exit_data)
		if exit_portal:
			current_dungeon_scene.get_node("EntityLayer").add_child(exit_portal)

func create_exit_portal(exit_data: Dictionary) -> Area2D:
	"""Create an exit portal to another dungeon"""
	var portal = Area2D.new()
	portal.name = "ExitPortal_" + exit_data.get("destination", "unknown")
	
	var pos = exit_data.get("position", {"x": 400, "y": 300})
	portal.position = Vector2(pos.x, pos.y)
	
	# Visual representation
	var sprite = Sprite2D.new()
	sprite.texture = create_placeholder_texture(Color.CYAN)
	sprite.scale = Vector2(2, 2)
	portal.add_child(sprite)
	
	# Collision area
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 64
	collision.shape = shape
	portal.add_child(collision)
	
	# Connect portal interaction
	portal.body_entered.connect(_on_exit_portal_entered.bind(exit_data))
	
	return portal

func check_entry_requirements(dungeon_id: String, dungeon_data: Dictionary) -> bool:
	"""Check if player meets dungeon entry requirements"""
	var requirements = dungeon_data.get("entry_requirements", {})
	
	# Level requirement
	if requirements.has("min_level"):
		var player_level = game_state.get_player_level()
		if player_level < requirements.min_level:
			print("[DungeonSystem] Level too low: %d < %d" % [player_level, requirements.min_level])
			return false
	
	# Quest requirement
	if requirements.has("required_quest"):
		var quest_id = requirements.required_quest
		if not game_state.is_quest_completed(quest_id):
			print("[DungeonSystem] Required quest not completed: %s" % quest_id)
			return false
	
	# Item requirement
	if requirements.has("required_item"):
		var item_id = requirements.required_item
		if not game_state.has_item(item_id):
			print("[DungeonSystem] Required item not possessed: %s" % item_id)
			return false
	
	return true

func discover_fragment(fragment_id: String):
	"""Mark a fragment as discovered"""
	if fragment_id in discovered_fragments:
		return
	
	discovered_fragments.append(fragment_id)
	
	if fragment_map.has(fragment_id):
		fragment_map[fragment_id].discovered = true
	
	fragment_discovered.emit(fragment_id)
	save_progress()
	
	print("[DungeonSystem] Fragment discovered: %s" % fragment_id)

func unlock_connection(from_fragment: String, to_fragment: String):
	"""Unlock connection between fragments"""
	var connection_key = from_fragment + "->" + to_fragment
	unlocked_connections[connection_key] = true
	
	save_progress()
	print("[DungeonSystem] Connection unlocked: %s" % connection_key)

func unload_current_dungeon():
	"""Unload the currently loaded dungeon"""
	if not current_dungeon_scene:
		return
	
	# Cleanup active systems
	cleanup_dungeon_systems()
	
	# Remove from scene
	current_dungeon_scene.queue_free()
	current_dungeon_scene = null
	
	dungeon_unloaded.emit(current_dungeon_id)
	player_exited_dungeon.emit(current_dungeon_id)
	
	print("[DungeonSystem] Dungeon unloaded: %s" % current_dungeon_id)
	
	current_dungeon_id = ""
	current_dungeon = {}

func cleanup_dungeon_systems():
	"""Cleanup dungeon-specific systems"""
	# Clear spawners
	active_spawners.clear()
	
	# Clear environment effects
	environment_effects.clear()
	
	# Clear entities
	dungeon_entities.clear()

# Event handlers
func _on_player_moved(new_position: Vector2):
	"""Handle player movement within dungeon"""
	# This could trigger area-based events, spawns, etc.
	pass

func _on_entity_spawned(entity_id: String):
	"""Handle entity spawn in dungeon"""
	dungeon_entities.append(entity_id)

func _on_entity_destroyed(entity_id: String):
	"""Handle entity destruction in dungeon"""
	var index = dungeon_entities.find(entity_id)
	if index >= 0:
		dungeon_entities.remove_at(index)

func _on_exit_portal_entered(exit_data: Dictionary, body: Node2D):
	"""Handle player entering exit portal"""
	if body.name == "Player" or body.has_method("is_player"):
		var destination = exit_data.get("destination", "")
		if destination != "":
			print("[DungeonSystem] Player entering portal to: %s" % destination)
			load_dungeon(destination)

# Fragment map and connections
func get_fragment_map() -> Dictionary:
	"""Get the complete fragment map"""
	return fragment_map

func get_discovered_fragments() -> Array:
	"""Get list of discovered fragments"""
	return discovered_fragments

func get_available_connections(fragment_id: String) -> Array:
	"""Get available connections from a fragment"""
	if not fragment_map.has(fragment_id):
		return []
	
	var connections = fragment_map[fragment_id].connections
	var available = []
	
	for connection in connections:
		var destination = connection.get("destination", "")
		if destination != "" and is_connection_unlocked(fragment_id, destination):
			available.append(connection)
	
	return available

func is_connection_unlocked(from_fragment: String, to_fragment: String) -> bool:
	"""Check if connection between fragments is unlocked"""
	var connection_key = from_fragment + "->" + to_fragment
	return unlocked_connections.get(connection_key, false)

# Save/Load
func save_progress():
	"""Save dungeon progress"""
	var save_data = {
		"discovered_fragments": discovered_fragments,
		"unlocked_connections": unlocked_connections,
		"current_dungeon_id": current_dungeon_id
	}
	
	game_state.save_dungeon_progress(save_data)

func get_save_data() -> Dictionary:
	"""Get dungeon system save data"""
	return {
		"current_dungeon_id": current_dungeon_id,
		"discovered_fragments": discovered_fragments,
		"unlocked_connections": unlocked_connections,
		"fragment_map": fragment_map
	}

func load_save_data(data: Dictionary):
	"""Load dungeon system save data"""
	if data.has("discovered_fragments"):
		discovered_fragments = data.discovered_fragments
	
	if data.has("unlocked_connections"):
		unlocked_connections = data.unlocked_connections
	
	if data.has("fragment_map"):
		fragment_map = data.fragment_map
	
	# Reload current dungeon if needed
	if data.has("current_dungeon_id") and data.current_dungeon_id != "":
		load_dungeon(data.current_dungeon_id)

# Utility functions
func get_current_dungeon_id() -> String:
	"""Get current dungeon ID"""
	return current_dungeon_id

func is_in_dungeon() -> bool:
	"""Check if player is currently in a dungeon"""
	return current_dungeon_scene != null

func get_dungeon_entities() -> Array:
	"""Get all entities in current dungeon"""
	return dungeon_entities

# Debug functions
func debug_unlock_all_fragments():
	"""Debug: Unlock all fragments"""
	var all_dungeons = data_loader.get_all_dungeons()
	for dungeon_id in all_dungeons.keys():
		discover_fragment(dungeon_id)

func debug_print_fragment_map():
	"""Debug: Print fragment map"""
	print("[DungeonSystem] Fragment Map:")
	for fragment_id in fragment_map.keys():
		var fragment = fragment_map[fragment_id]
		print("  %s: discovered=%s, connections=%d" % [fragment_id, fragment.discovered, fragment.connections.size()])