extends Node2D
class_name DungeonController
# dungeon_controller.gd - Controls dungeon logic, spawning, and progression

# Dungeon configuration
var dungeon_id: String = ""
var dungeon_data: Dictionary = {}

# Spawning system
var spawn_timer: Timer
var enemies_spawned: Array = []
var max_enemies: int = 5
var spawn_interval: float = 10.0

# Dungeon state
var is_cleared: bool = false
var enemies_defeated: int = 0
var total_enemies_to_defeat: int = 10

# Exit system
var exit_area: Area2D
var exit_unlocked: bool = false

# Loot system
var loot_spawned: Array = []

func _ready():
	print("[Dungeon] Dungeon controller initialized")
	setup_spawn_system()
	setup_exit_area()
	connect_signals()

func setup_spawn_system():
	"""Initialize enemy spawn system"""
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_spawn_enemy)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = false
	add_child(spawn_timer)

func setup_exit_area():
	"""Setup dungeon exit area"""
	exit_area = Area2D.new()
	exit_area.name = "ExitArea"
	var exit_collision = CollisionShape2D.new()
	var exit_shape = RectangleShape2D.new()
	exit_shape.size = Vector2(64, 64)
	
	exit_collision.shape = exit_shape
	exit_area.add_child(exit_collision)
	add_child(exit_area)
	
	# Connect exit signals
	exit_area.body_entered.connect(_on_exit_area_entered)
	
	# Create visual indicator for exit
	create_exit_visual()

func connect_signals():
	"""Connect to event bus signals"""
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.dungeon_changed.connect(_on_dungeon_changed)

func load_dungeon(dungeon_id_param: String):
	"""Load and configure dungeon from data"""
	dungeon_id = dungeon_id_param
	dungeon_data = DataLoader.get_dungeon(dungeon_id)
	
	if not dungeon_data:
		push_error("Failed to load dungeon: " + dungeon_id)
		return false
	
	print("[Dungeon] Loading dungeon: ", dungeon_data.name)
	
	# Configure dungeon parameters
	configure_dungeon()
	
	# Set exit position
	if "exit_position" in dungeon_data:
		var exit_pos = dungeon_data.exit_position
		exit_area.global_position = Vector2(exit_pos.x, exit_pos.y)
	
	# Start spawning enemies
	start_dungeon()
	
	# Notify that dungeon was entered
	EventBus.dungeon_entered.emit(dungeon_id)
	
	return true

func configure_dungeon():
	"""Configure dungeon based on loaded data"""
	# Set difficulty-based parameters
	var difficulty = dungeon_data.get("difficulty", 1)
	max_enemies = min(3 + difficulty * 2, 10)
	total_enemies_to_defeat = 5 + difficulty * 3
	spawn_interval = max(5.0, 15.0 - difficulty * 2.0)
	
	# Update spawn timer
	spawn_timer.wait_time = spawn_interval
	
	print("[Dungeon] Configured for difficulty ", difficulty)
	print("  Max enemies: ", max_enemies)
	print("  Enemies to defeat: ", total_enemies_to_defeat)
	print("  Spawn interval: ", spawn_interval, " seconds")

func start_dungeon():
	"""Begin dungeon encounter"""
	is_cleared = false
	enemies_defeated = 0
	exit_unlocked = false
	
	# Clear existing enemies
	clear_existing_enemies()
	
	# Spawn initial enemies
	spawn_initial_enemies()
	
	# Start spawn timer
	spawn_timer.start()
	
	EventBus.ui_notification_shown.emit("Entered " + dungeon_data.name, "info")

func spawn_initial_enemies():
	"""Spawn initial set of enemies"""
	var initial_spawns = min(max_enemies / 2, 3)
	for i in initial_spawns:
		_spawn_enemy()

func _spawn_enemy():
	"""Spawn a single enemy"""
	if enemies_spawned.size() >= max_enemies:
		return
	
	if not "enemy_pool" in dungeon_data or dungeon_data.enemy_pool.is_empty():
		push_warning("No enemies defined for dungeon: " + dungeon_id)
		return
	
	# Select random enemy from pool
	var enemy_types = dungeon_data.enemy_pool
	var enemy_type = enemy_types[randi() % enemy_types.size()]
	
	# Get spawn position
	var spawn_position = get_spawn_position()
	
	# Create enemy
	var enemy = create_enemy(enemy_type, spawn_position)
	if enemy:
		enemies_spawned.append(enemy)
		add_child(enemy)
		
		EventBus.enemy_spawned.emit(enemy_type, spawn_position)
		print("[Dungeon] Spawned ", enemy_type, " at ", spawn_position)

func get_spawn_position() -> Vector2:
	"""Get a valid spawn position for enemies"""
	if "spawn_points" in dungeon_data and not dungeon_data.spawn_points.is_empty():
		# Use predefined spawn points
		var spawn_points = dungeon_data.spawn_points
		var spawn_point = spawn_points[randi() % spawn_points.size()]
		return Vector2(spawn_point.x, spawn_point.y)
	else:
		# Generate random position
		# TODO: Add proper bounds checking and collision avoidance
		var x = randf_range(50, 450)
		var y = randf_range(50, 350)
		return Vector2(x, y)

func create_enemy(enemy_type: String, position: Vector2) -> Node:
	"""Create and configure an enemy"""
	# TODO: Load proper enemy scenes based on type
	# For now, create a basic enemy placeholder
	
	var enemy = CharacterBody2D.new()
	enemy.name = enemy_type + "_" + str(randi() % 1000)
	enemy.global_position = position
	
	# Add basic enemy script
	var script_path = "res://scripts/entities/basic_enemy.gd"
	if FileAccess.file_exists(script_path):
		var enemy_script = load(script_path)
		enemy.set_script(enemy_script)
	
	# Configure enemy based on type
	configure_enemy(enemy, enemy_type)
	
	return enemy

func configure_enemy(enemy: Node, enemy_type: String):
	"""Configure enemy based on its type"""
	# Set basic properties based on enemy type
	match enemy_type:
		"slime":
			enemy.set("max_health", 30)
			enemy.set("damage", 5)
			enemy.set("move_speed", 50.0)
		"wolf":
			enemy.set("max_health", 50)
			enemy.set("damage", 8)
			enemy.set("move_speed", 120.0)
		"skeleton":
			enemy.set("max_health", 60)
			enemy.set("damage", 10)
			enemy.set("move_speed", 80.0)
		_:
			# Default enemy stats
			enemy.set("max_health", 40)
			enemy.set("damage", 6)
			enemy.set("move_speed", 100.0)
	
	# Apply difficulty scaling
	if "difficulty" in dungeon_data:
		var difficulty = dungeon_data.difficulty
		var scale_factor = 1.0 + (difficulty - 1) * 0.3
		
		if enemy.has_method("scale_stats"):
			enemy.scale_stats(scale_factor)

func clear_existing_enemies():
	"""Remove all existing enemies"""
	for enemy in enemies_spawned:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_spawned.clear()

func check_dungeon_completion():
	"""Check if dungeon clearing conditions are met"""
	if enemies_defeated >= total_enemies_to_defeat:
		complete_dungeon()

func complete_dungeon():
	"""Handle dungeon completion"""
	if is_cleared:
		return
	
	is_cleared = true
	spawn_timer.stop()
	
	# Unlock exit
	exit_unlocked = true
	
	# Spawn loot
	spawn_completion_loot()
	
	# Clear remaining enemies
	clear_existing_enemies()
	
	# Notify completion
	EventBus.dungeon_completed.emit(dungeon_id)
	EventBus.ui_notification_shown.emit("Dungeon Cleared! Exit unlocked.", "success")
	
	print("[Dungeon] Completed dungeon: ", dungeon_data.name)

func spawn_completion_loot():
	"""Spawn loot for completing dungeon"""
	if not "loot_table" in dungeon_data:
		return
	
	var loot_table = dungeon_data.loot_table
	var loot_count = randi_range(1, 3)  # Random amount of loot
	
	for i in loot_count:
		var loot_item = loot_table[randi() % loot_table.size()]
		spawn_loot_item(loot_item, get_loot_spawn_position())

func spawn_loot_item(item_id: String, position: Vector2):
	"""Spawn a loot item at position"""
	# TODO: Create proper loot item scene
	# For now, just add to player inventory automatically
	GameState.add_item_to_inventory(item_id, 1)
	EventBus.item_collected.emit(item_id)
	
	print("[Dungeon] Dropped loot: ", item_id)

func get_loot_spawn_position() -> Vector2:
	"""Get position to spawn loot"""
	# Spawn near the center or at specific loot points
	return Vector2(250, 200) + Vector2(randf_range(-50, 50), randf_range(-50, 50))

func attempt_exit_dungeon():
	"""Attempt to exit the current dungeon"""
	if not exit_unlocked:
		EventBus.ui_notification_shown.emit("Exit is locked. Clear the dungeon first!", "warning")
		return false
	
	# Get connected dungeons
	if not "connections" in dungeon_data or dungeon_data.connections.is_empty():
		EventBus.ui_notification_shown.emit("No connected areas found.", "warning")
		return false
	
	# For now, go to first connected dungeon
	var next_dungeon = dungeon_data.connections[0]
	change_to_dungeon(next_dungeon)
	
	return true

func change_to_dungeon(target_dungeon_id: String):
	"""Change to another dungeon"""
	EventBus.dungeon_exited.emit(dungeon_id)
	GameState.change_dungeon(target_dungeon_id)
	
	# TODO: Implement proper scene transition
	print("[Dungeon] Changing to dungeon: ", target_dungeon_id)

# Signal handlers
func _on_enemy_defeated(enemy_id: String, loot: Array):
	"""Handle enemy defeat"""
	enemies_defeated += 1
	
	# Remove from active enemies list
	for i in range(enemies_spawned.size() - 1, -1, -1):
		var enemy = enemies_spawned[i]
		if not is_instance_valid(enemy) or enemy.name == enemy_id:
			enemies_spawned.remove_at(i)
			break
	
	# Spawn enemy loot
	for loot_item in loot:
		GameState.add_item_to_inventory(loot_item, 1)
		EventBus.item_collected.emit(loot_item)
	
	# Check completion
	check_dungeon_completion()
	
	print("[Dungeon] Enemy defeated. Progress: ", enemies_defeated, "/", total_enemies_to_defeat)

func _on_dungeon_changed(new_dungeon_id: String):
	"""Handle dungeon change notification"""
	if new_dungeon_id != dungeon_id:
		load_dungeon(new_dungeon_id)

func _on_exit_area_entered(body):
	"""Handle player entering exit area"""
	if body.name == "Player" or body.has_method("get_player_data"):
		attempt_exit_dungeon()

# Dungeon event system
func trigger_dungeon_event(event_type: String, data: Dictionary = {}):
	"""Trigger special dungeon events"""
	match event_type:
		"boss_spawn":
			spawn_boss_enemy()
		"treasure_room":
			open_treasure_room()
		"trap_activation":
			activate_trap(data)
		"environmental_hazard":
			trigger_hazard(data)
		_:
			print("[Dungeon] Unknown event type: ", event_type)

func spawn_boss_enemy():
	"""Spawn a boss enemy for this dungeon"""
	# TODO: Implement boss spawning system
	pass

func open_treasure_room():
	"""Open access to treasure room"""
	# TODO: Implement treasure room mechanics
	pass

func activate_trap(data: Dictionary):
	"""Activate environmental trap"""
	# TODO: Implement trap system
	pass

func trigger_hazard(data: Dictionary):
	"""Trigger environmental hazard"""
	# TODO: Implement environmental hazards
	pass

# Utility methods
func get_dungeon_progress() -> float:
	"""Get completion progress as percentage"""
	return float(enemies_defeated) / float(total_enemies_to_defeat)

func get_active_enemy_count() -> int:
	"""Get number of currently active enemies"""
	return enemies_spawned.size()

func is_dungeon_completed() -> bool:
	"""Check if dungeon is completed"""
	return is_cleared

# TODO: Future enhancements
# - Procedural dungeon generation
# - Boss encounter system
# - Environmental puzzles and traps
# - Dynamic difficulty adjustment
# - Multi-level dungeons

# Dungeon transition system
func create_exit_visual():
	"""Create visual indicator for dungeon exit"""
	var exit_sprite = Sprite2D.new()
	exit_sprite.name = "ExitVisual"
	
	# Try to load exit texture
	var exit_texture_path = "res://assets/environment/portal_exit.png"
	if ResourceLoader.exists(exit_texture_path):
		exit_sprite.texture = load(exit_texture_path)
	else:
		# Create a simple colored rectangle as fallback
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.CYAN)
		var texture = ImageTexture.new()
		texture.set_image(image)
		exit_sprite.texture = texture
	
	exit_area.add_child(exit_sprite)
	
	# Add glow effect when unlocked
	if exit_unlocked:
		add_exit_glow_effect(exit_sprite)

func add_exit_glow_effect(sprite: Sprite2D):
	"""Add glowing effect to exit portal"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate", Color.WHITE * 1.3, 1.0)
	tween.tween_property(sprite, "modulate", Color.WHITE * 0.8, 1.0)

func unlock_exit():
	"""Unlock the dungeon exit"""
	exit_unlocked = true
	print("[Dungeon] Exit unlocked!")
	
	# Update visual effect
	var exit_visual = exit_area.find_child("ExitVisual")
	if exit_visual:
		add_exit_glow_effect(exit_visual)
	
	# Show notification
	EventBus.ui_notification_shown.emit("Exit portal activated!", "success")

func _on_exit_area_entered(body):
	"""Handle player entering exit area"""
	if body.name == "Player" and exit_unlocked:
		initiate_dungeon_transition()
	elif body.name == "Player" and not exit_unlocked:
		EventBus.ui_notification_shown.emit("Exit is locked. Defeat more enemies!", "warning")

func initiate_dungeon_transition():
	"""Start transition to next dungeon or world map"""
	print("[Dungeon] Initiating dungeon transition...")
	
	# Save current game state
	save_dungeon_progress()
	
	# Determine next destination
	var next_destination = get_next_destination()
	
	# Start transition effect
	start_transition_effect(next_destination)

func save_dungeon_progress():
	"""Save current dungeon progress and player state"""
	# Update player position for save
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameState.player_data.position = {
			"x": player.global_position.x,
			"y": player.global_position.y
		}
	
	# Save dungeon completion state
	if not GameState.player_data.has("completed_dungeons"):
		GameState.player_data.completed_dungeons = []
	
	if dungeon_id not in GameState.player_data.completed_dungeons:
		GameState.player_data.completed_dungeons.append(dungeon_id)
	
	# Save game state
	GameState.save_game()
	print("[Dungeon] Game state saved before transition")

func get_next_destination() -> String:
	"""Determine the next destination after leaving dungeon"""
	# Check if there's a specified next dungeon
	if dungeon_data.has("next_dungeon"):
		var next_dungeon = dungeon_data.next_dungeon
		
		# Check if player meets requirements for next dungeon
		if check_dungeon_requirements(next_dungeon):
			return next_dungeon
	
	# Check for dungeon progression chains
	var progression_chain = get_dungeon_progression_chain()
	var current_index = progression_chain.find(dungeon_id)
	
	if current_index >= 0 and current_index < progression_chain.size() - 1:
		var next_dungeon = progression_chain[current_index + 1]
		if check_dungeon_requirements(next_dungeon):
			return next_dungeon
	
	# Default: return to world map or town
	return "world_map"

func get_dungeon_progression_chain() -> Array:
	"""Get the dungeon progression chain"""
	# This could be loaded from data files
	return [
		"goblin_cave",
		"dark_forest",
		"skeleton_crypt",
		"dragon_lair"
	]

func check_dungeon_requirements(dungeon_id_param: String) -> bool:
	"""Check if player meets requirements for a dungeon"""
	var target_dungeon = DataLoader.get_dungeon(dungeon_id_param)
	if not target_dungeon:
		return false
	
	# Check level requirement
	if target_dungeon.has("min_level"):
		if GameState.player_data.level < target_dungeon.min_level:
			return false
	
	# Check prerequisite dungeons
	if target_dungeon.has("prerequisites"):
		var completed_dungeons = GameState.player_data.get("completed_dungeons", [])
		for prerequisite in target_dungeon.prerequisites:
			if prerequisite not in completed_dungeons:
				return false
	
	return true

func start_transition_effect(destination: String):
	"""Start visual transition effect"""
	print("[Dungeon] Starting transition to: ", destination)
	
	# Create fade-out effect
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	fade_rect.size = get_viewport().size
	get_tree().current_scene.add_child(fade_rect)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	
	# Change scene after fade completes
	tween.tween_callback(change_to_destination.bind(destination)).set_delay(1.0)

func change_to_destination(destination: String):
	"""Change to the destination scene"""
	var scene_path = get_scene_path_for_destination(destination)
	
	if scene_path != "" and ResourceLoader.exists(scene_path):
		print("[Dungeon] Loading scene: ", scene_path)
		get_tree().change_scene_to_file(scene_path)
	else:
		print("[Dungeon] Scene not found for destination: ", destination)
		# Fallback to main menu or world map
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func get_scene_path_for_destination(destination: String) -> String:
	"""Get scene file path for destination"""
	var scene_paths = {
		"world_map": "res://scenes/world_map.tscn",
		"town": "res://scenes/town.tscn",
		"goblin_cave": "res://scenes/dungeons/goblin_cave.tscn",
		"dark_forest": "res://scenes/dungeons/dark_forest.tscn",
		"skeleton_crypt": "res://scenes/dungeons/skeleton_crypt.tscn",
		"dragon_lair": "res://scenes/dungeons/dragon_lair.tscn",
		"free_zone": "res://scenes/free_zone.tscn"
	}
	
	return scene_paths.get(destination, "")

# Multi-dungeon navigation
func create_dungeon_transition_point(transition_data: Dictionary):
	"""Create a transition point to another dungeon"""
	var transition_area = Area2D.new()
	transition_area.name = "DungeonTransition_" + transition_data.get("target", "unknown")
	
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	collision.shape = shape
	transition_area.add_child(collision)
	
	# Set position
	if transition_data.has("position"):
		var pos = transition_data.position
		transition_area.global_position = Vector2(pos.x, pos.y)
	
	# Create visual indicator
	var visual = Sprite2D.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.PURPLE)
	var texture = ImageTexture.new()
	texture.set_image(image)
	visual.texture = texture
	transition_area.add_child(visual)
	
	# Connect signal for transition
	var target_dungeon = transition_data.get("target", "")
	transition_area.body_entered.connect(_on_dungeon_transition_entered.bind(target_dungeon))
	
	add_child(transition_area)
	print("[Dungeon] Created transition point to: ", target_dungeon)

func _on_dungeon_transition_entered(target_dungeon: String, body):
	"""Handle transition to another dungeon"""
	if body.name == "Player":
		if check_dungeon_requirements(target_dungeon):
			# Save progress and transition
			save_dungeon_progress()
			start_transition_effect(target_dungeon)
		else:
			EventBus.ui_notification_shown.emit("You don't meet the requirements for that area", "warning")

# Dungeon state management
func save_current_dungeon_state():
	"""Save current dungeon state for later return"""
	var dungeon_state = {
		"dungeon_id": dungeon_id,
		"enemies_defeated": enemies_defeated,
		"is_cleared": is_cleared,
		"exit_unlocked": exit_unlocked,
		"loot_spawned": loot_spawned,
		"timestamp": Time.get_ticks_msec()
	}
	
	if not GameState.player_data.has("dungeon_states"):
		GameState.player_data.dungeon_states = {}
	
	GameState.player_data.dungeon_states[dungeon_id] = dungeon_state

func load_dungeon_state():
	"""Load previously saved dungeon state"""
	if not GameState.player_data.has("dungeon_states"):
		return
	
	var dungeon_state = GameState.player_data.dungeon_states.get(dungeon_id)
	if not dungeon_state:
		return
	
	# Restore dungeon state
	enemies_defeated = dungeon_state.get("enemies_defeated", 0)
	is_cleared = dungeon_state.get("is_cleared", false)
	exit_unlocked = dungeon_state.get("exit_unlocked", false)
	loot_spawned = dungeon_state.get("loot_spawned", [])
	
	print("[Dungeon] Restored dungeon state for: ", dungeon_id)

func clear_dungeon_state():
	"""Clear saved dungeon state (when completed)"""
	if GameState.player_data.has("dungeon_states"):
		GameState.player_data.dungeon_states.erase(dungeon_id)
# - Special event rooms (shops, NPCs, etc.)
# - Dungeon-specific mechanics and hazards
# - Player choice branching paths