extends Node
class_name AIManager
# AIManager.gd - Central management system for all AI entities
# Coordinates AI behavior, handles global AI events, and integrates with game systems

# Global AI settings
@export var global_ai_enabled: bool = true
@export var ai_update_frequency: float = 0.05  # Update every 50ms
@export var max_active_ai: int = 20  # Maximum AI entities updating per frame
@export var ai_performance_optimization: bool = true

# AI entity management
var registered_ai: Array[AIController] = []
var active_ai: Array[AIController] = []
var ai_groups: Dictionary = {}  # Organized by type/faction
var ai_update_queue: Array[AIController] = []
var update_timer: float = 0.0

# Global AI state
var global_alert_level: float = 0.0  # 0.0 = calm, 1.0 = maximum alert
var faction_relations: Dictionary = {}
var ai_difficulty_modifier: float = 1.0
var ai_spawn_limits: Dictionary = {}

# Performance tracking
var ai_performance_stats: Dictionary = {
	"total_ai_count": 0,
	"active_ai_count": 0,
	"average_update_time": 0.0,
	"frame_time_budget": 8.0,  # 8ms budget for AI per frame at 120fps
	"optimization_active": false
}

# Integration with other systems
var climate_manager: Node
var event_manager: Node
var combat_manager: Node
var save_manager: Node

# AI spawning and management
var ai_spawn_pools: Dictionary = {}
var ai_templates: Dictionary = {}

signal ai_registered(ai_controller: AIController)
signal ai_unregistered(ai_controller: AIController)
signal global_alert_changed(new_level: float)
signal ai_faction_relations_changed(faction_a: String, faction_b: String, relation: float)

func _ready():
	print("[AIManager] Initializing AI management system")
	
	# Setup system integration
	setup_system_integration()
	
	# Load AI configuration
	load_ai_configuration()
	
	# Setup faction relationships
	setup_faction_system()
	
	# Initialize AI templates
	initialize_ai_templates()
	
	# Setup performance monitoring
	setup_performance_monitoring()
	
	print("[AIManager] AI management system ready")

func setup_system_integration():
# Setup integration with other game systems
	# Climate system integration
	climate_manager = get_node_or_null("/root/ClimateManager")
	if climate_manager:
		climate_manager.weather_changed.connect(_on_global_weather_changed)
		climate_manager.day_night_changed.connect(_on_day_night_changed)
	
	# Event system integration
	event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		event_manager.dynamic_event_triggered.connect(_on_dynamic_event_triggered)
		event_manager.area_event_started.connect(_on_area_event_started)
	
	# Combat system integration
	combat_manager = get_node_or_null("/root/CombatManager")
	if combat_manager:
		combat_manager.combat_started.connect(_on_combat_started)
		combat_manager.combat_ended.connect(_on_combat_ended)
	
	# Save system integration
	save_manager = get_node_or_null("/root/GameState")

func load_ai_configuration():
# Load AI configuration from data files
	# This would load from JSON configuration files
	ai_difficulty_modifier = 1.0
	
	# Setup spawn limits by AI type
	ai_spawn_limits = {
		"melee": 8,
		"ranged": 6,
		"coward": 10,
		"elite": 3,
		"minion": 15,
		"boss": 1
	}

func setup_faction_system():
# Setup faction relationship system
	# Initialize faction relationships (-1.0 = hostile, 0.0 = neutral, 1.0 = allied)
	faction_relations = {
		"player_enemies": -1.0,
		"enemy_factions": {
			"goblins_orcs": -0.3,    # Goblins vs Orcs (competitive)
			"undead_living": -1.0,   # Undead vs all living
			"beasts_humanoids": 0.2  # Beasts neutral to humanoids
		}
	}

func initialize_ai_templates():
# Initialize AI templates for easy spawning
	ai_templates = {
		"goblin_warrior": {
			"ai_type": "melee",
			"behavior_config": {
				"aggression": 0.7,
				"detection_range": 100.0,
				"attack_range": 50.0,
				"flee_threshold": 0.2
			},
			"faction": "goblins"
		},
		"orc_archer": {
			"ai_type": "ranged",
			"behavior_config": {
				"aggression": 0.6,
				"detection_range": 150.0,
				"attack_range": 120.0,
				"flee_threshold": 0.15
			},
			"faction": "orcs"
		},
		"skeleton_minion": {
			"ai_type": "minion",
			"behavior_config": {
				"aggression": 0.8,
				"detection_range": 80.0,
				"attack_range": 40.0,
				"flee_threshold": 0.0
			},
			"faction": "undead"
		},
		"forest_boss": {
			"ai_type": "boss",
			"behavior_config": {
				"aggression": 0.9,
				"detection_range": 300.0,
				"attack_range": 100.0,
				"phases": 3
			},
			"faction": "forest_guardians"
		}
	}

func setup_performance_monitoring():
# Setup performance monitoring system
	# Start performance monitoring
	var timer = Timer.new()
	timer.wait_time = 1.0  # Update stats every second
	timer.timeout.connect(update_performance_stats)
	timer.autostart = true
	add_child(timer)

func _process(delta):
# Main AI manager update loop
	if not global_ai_enabled:
		return
	
	update_timer += delta
	
	# Update AI entities based on frequency
	if update_timer >= ai_update_frequency:
		update_ai_entities(delta)
		update_timer = 0.0
	
	# Update global AI state
	update_global_ai_state(delta)

func update_ai_entities(delta: float):
# Update AI entities with performance optimization
	var start_time = Time.get_ticks_msec()
	var time_budget = ai_performance_stats.frame_time_budget
	var updated_count = 0
	
	# Build update queue if empty
	if ai_update_queue.is_empty():
		ai_update_queue = active_ai.duplicate()
		# Prioritize by distance to player or importance
		prioritize_ai_updates()
	
	# Update AI entities within time budget
	while not ai_update_queue.is_empty() and updated_count < max_active_ai:
		var elapsed = Time.get_ticks_msec() - start_time
		if elapsed > time_budget:
			break
		
		var ai = ai_update_queue.pop_front()
		if is_instance_valid(ai) and ai.entity:
			update_single_ai(ai, delta)
			updated_count += 1
	
	# Track performance
	var total_time = Time.get_ticks_msec() - start_time
	ai_performance_stats.average_update_time = lerp(ai_performance_stats.average_update_time, total_time, 0.1)
	
	# Auto-optimize if needed
	if ai_performance_optimization and total_time > time_budget * 1.5:
		optimize_ai_performance()

func prioritize_ai_updates():
# Prioritize AI updates based on importance and distance
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Sort by distance to player (closer entities get priority)
	ai_update_queue.sort_custom(func(a: AIController, b: AIController):
		var dist_a = a.entity.global_position.distance_to(player.global_position)
		var dist_b = b.entity.global_position.distance_to(player.global_position)
		
		# Bosses always get highest priority
		if a.ai_type == AIController.AIType.BOSS:
			dist_a *= 0.1
		if b.ai_type == AIController.AIType.BOSS:
			dist_b *= 0.1
		
		return dist_a < dist_b
	)

func update_single_ai(ai: AIController, delta: float):
# Update a single AI entity
	if not ai or not is_instance_valid(ai):
		return
	
	# Apply global modifiers
	apply_global_ai_modifiers(ai)
	
	# Let AI update itself (it calls its own _process)
	# The AI manager just coordinates and applies global effects

func apply_global_ai_modifiers(ai: AIController):
# Apply global AI modifiers to individual AI
	# Apply global alert level
	if global_alert_level > 0.5:
		ai.senses.alertness_level = lerp(1.0, 2.0, global_alert_level)
	else:
		ai.senses.alertness_level = 1.0
	
	# Apply difficulty modifier
	if ai.combat_component:
		ai.combat_component.damage_modifier = ai_difficulty_modifier
		ai.combat_component.accuracy_modifier = ai_difficulty_modifier

func update_global_ai_state(delta: float):
# Update global AI state
	# Decay global alert level over time
	if global_alert_level > 0.0:
		global_alert_level -= delta * 0.2  # Alert decays over 5 seconds
		global_alert_level = max(0.0, global_alert_level)
	
	# Update active AI list
	update_active_ai_list()

func update_active_ai_list():
# Update list of active AI entities
	active_ai.clear()
	
	for ai in registered_ai:
		if is_instance_valid(ai) and ai.entity and ai.entity.is_inside_tree():
			# Check if AI should be active (within certain distance of player, etc.)
			if should_ai_be_active(ai):
				active_ai.append(ai)
	
	ai_performance_stats.active_ai_count = active_ai.size()

func should_ai_be_active(ai: AIController) -> bool:
# Check if AI should be actively updating
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return true  # No player, keep all AI active
	
	# Always keep bosses active
	if ai.ai_type == AIController.AIType.BOSS:
		return true
	
	# Distance-based activation
	var distance = ai.entity.global_position.distance_to(player.global_position)
	var activation_range = 500.0  # Active within 500 units
	
	return distance <= activation_range

func optimize_ai_performance():
# Optimize AI performance when frame budget is exceeded
	print("[AIManager] Optimizing AI performance")
	
	# Reduce max active AI
	max_active_ai = max(5, max_active_ai - 2)
	
	# Increase update frequency (update less often)
	ai_update_frequency = min(0.1, ai_update_frequency + 0.01)
	
	ai_performance_stats.optimization_active = true

func update_performance_stats():
# Update performance statistics
	ai_performance_stats.total_ai_count = registered_ai.size()
	
	# Reset optimization if performance is good
	if ai_performance_stats.average_update_time < ai_performance_stats.frame_time_budget * 0.8:
		if ai_performance_stats.optimization_active:
			# Gradually restore performance
			max_active_ai = min(20, max_active_ai + 1)
			ai_update_frequency = max(0.05, ai_update_frequency - 0.005)
			ai_performance_stats.optimization_active = false

# AI Registration and Management
func register_ai(ai_controller: AIController):
# Register an AI controller with the manager
	if ai_controller not in registered_ai:
		registered_ai.append(ai_controller)
		
		# Add to appropriate group
		var ai_type_key = AIController.AIType.keys()[ai_controller.ai_type]
		if not ai_type_key in ai_groups:
			ai_groups[ai_type_key] = []
		ai_groups[ai_type_key].append(ai_controller)
		
		# Connect to AI signals
		connect_ai_signals(ai_controller)
		
		ai_registered.emit(ai_controller)
		print("[AIManager] Registered AI: ", ai_controller.entity.name if ai_controller.entity else "unknown")

func unregister_ai(ai_controller: AIController):
# Unregister an AI controller
	if ai_controller in registered_ai:
		registered_ai.erase(ai_controller)
		active_ai.erase(ai_controller)
		ai_update_queue.erase(ai_controller)
		
		# Remove from groups
		for group in ai_groups.values():
			group.erase(ai_controller)
		
		# Disconnect signals
		disconnect_ai_signals(ai_controller)
		
		ai_unregistered.emit(ai_controller)
		print("[AIManager] Unregistered AI: ", ai_controller.entity.name if ai_controller.entity else "unknown")

func connect_ai_signals(ai: AIController):
# Connect to AI signals for coordination
	ai.target_acquired.connect(_on_ai_target_acquired.bind(ai))
	ai.target_lost.connect(_on_ai_target_lost.bind(ai))
	ai.state_changed.connect(_on_ai_state_changed.bind(ai))

func disconnect_ai_signals(ai: AIController):
# Disconnect from AI signals
	if ai.target_acquired.is_connected(_on_ai_target_acquired):
		ai.target_acquired.disconnect(_on_ai_target_acquired)
	if ai.target_lost.is_connected(_on_ai_target_lost):
		ai.target_lost.disconnect(_on_ai_target_lost)
	if ai.state_changed.is_connected(_on_ai_state_changed):
		ai.state_changed.disconnect(_on_ai_state_changed)

# AI Spawning
func spawn_ai_from_template(template_name: String, position: Vector2, entity_scene: PackedScene) -> AIController:
# Spawn AI from template configuration
	if not template_name in ai_templates:
		push_error("AI template not found: " + template_name)
		return null
	
	var template = ai_templates[template_name]
	var ai_type_name = template.ai_type
	
	# Check spawn limits
	if not can_spawn_ai_type(ai_type_name):
		return null
	
	# Create entity
	var entity = entity_scene.instantiate()
	entity.global_position = position
	get_tree().current_scene.add_child(entity)
	
	# Create and configure AI
	var ai = create_ai_from_template(template, entity)
	
	if ai:
		register_ai(ai)
	
	return ai

func create_ai_from_template(template: Dictionary, entity: Node2D) -> AIController:
# Create AI controller from template
	var ai: AIController
	
	match template.ai_type:
		"melee":
			ai = AIBehaviors.create_melee_fighter_ai(entity)
		"ranged":
			ai = AIBehaviors.create_ranged_attacker_ai(entity)
		"coward":
			ai = AIBehaviors.create_coward_mob_ai(entity)
		"elite":
			ai = AIBehaviors.create_elite_mob_ai(entity)
		"minion":
			var boss = find_nearest_boss(entity.global_position)
			ai = AIBehaviors.create_minion_ai(entity, boss)
		"boss":
			ai = BossAI.new()
			entity.add_child(ai)
		_:
			push_error("Unknown AI type: " + template.ai_type)
			return null
	
	# Apply template configuration
	if "behavior_config" in template:
		apply_behavior_config(ai, template.behavior_config)
	
	return ai

func apply_behavior_config(ai: AIController, config: Dictionary):
# Apply behavior configuration to AI
	for property in config:
		if ai.has_method("set_" + property):
			ai.call("set_" + property, config[property])
		elif property in ai:
			ai.set(property, config[property])

func can_spawn_ai_type(ai_type: String) -> bool:
# Check if more AI of this type can be spawned
	var current_count = get_ai_count_by_type(ai_type)
	var limit = ai_spawn_limits.get(ai_type, 999)
	
	return current_count < limit

func get_ai_count_by_type(ai_type: String) -> int:
# Get count of AI entities by type
	var count = 0
	for ai in registered_ai:
		var type_name = AIController.AIType.keys()[ai.ai_type].to_lower()
		if type_name == ai_type.to_lower():
			count += 1
	return count

func find_nearest_boss(position: Vector2) -> Node2D:
# Find nearest boss entity for minions
	var nearest_boss = null
	var nearest_distance = INF
	
	for ai in registered_ai:
		if ai.ai_type == AIController.AIType.BOSS:
			var distance = position.distance_to(ai.entity.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_boss = ai.entity
	
	return nearest_boss

# Global AI Events
func trigger_global_alert(alert_level: float, duration: float = 10.0):
# Trigger global alert that affects all AI
	global_alert_level = max(global_alert_level, alert_level)
	global_alert_changed.emit(global_alert_level)
	
	# Alert duration timer
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): global_alert_level *= 0.5)  # Reduce by half after duration
	add_child(timer)
	timer.start()
	
	print("[AIManager] Global alert triggered: ", alert_level)

func set_ai_difficulty(modifier: float):
# Set global AI difficulty modifier
	ai_difficulty_modifier = clamp(modifier, 0.1, 3.0)
	print("[AIManager] AI difficulty set to: ", ai_difficulty_modifier)

func pause_all_ai():
# Pause all AI entities
	for ai in registered_ai:
		ai.set_process(false)

func resume_all_ai():
# Resume all AI entities
	for ai in registered_ai:
		ai.set_process(true)

# Faction System
func set_faction_relation(faction_a: String, faction_b: String, relation: float):
# Set relationship between two factions
	var key = faction_a + "_" + faction_b
	faction_relations[key] = clamp(relation, -1.0, 1.0)
	ai_faction_relations_changed.emit(faction_a, faction_b, relation)

func get_faction_relation(faction_a: String, faction_b: String) -> float:
# Get relationship between two factions
	var key1 = faction_a + "_" + faction_b
	var key2 = faction_b + "_" + faction_a
	
	if key1 in faction_relations:
		return faction_relations[key1]
	elif key2 in faction_relations:
		return faction_relations[key2]
	else:
		return 0.0  # Neutral by default

# Signal Handlers
func _on_ai_target_acquired(ai: AIController, target: Node):
# Handle AI acquiring target
	# Coordinate with nearby AI of same faction
	alert_nearby_allies(ai, target)

func _on_ai_target_lost(ai: AIController):
# Handle AI losing target
	pass

func _on_ai_state_changed(ai: AIController, from_state: AIController.AIState, to_state: AIController.AIState):
# Handle AI state changes
	# Track global AI behavior patterns
	if to_state == AIController.AIState.ATTACK:
		trigger_global_alert(0.3, 5.0)  # Moderate alert when combat starts

func _on_global_weather_changed(weather_type: String):
# Handle global weather changes affecting AI
	print("[AIManager] Weather changed to: ", weather_type, " - updating AI behavior")
	
	# Apply weather effects to all AI
	for ai in registered_ai:
		if ai.senses:
			# Weather already handled by individual AI, but we could add global effects here
			pass

func _on_day_night_changed(is_night: bool):
# Handle day/night cycle affecting AI
	var light_modifier = 0.3 if is_night else 1.0
	
	for ai in registered_ai:
		if ai.senses:
			ai.senses.current_light_level = light_modifier

func _on_dynamic_event_triggered(event_type: String, event_data: Dictionary):
# Handle dynamic events affecting AI
	match event_type:
		"monster_invasion":
			trigger_global_alert(0.8, 30.0)
		"boss_awakening":
			trigger_global_alert(1.0, 60.0)
		"area_cleared":
			global_alert_level *= 0.3  # Calm down after area cleared

func _on_area_event_started(area_name: String, event_type: String):
# Handle area-specific events
	# Increase alert for AI in specific area
	pass

func _on_combat_started(participants: Array):
# Handle combat start
	trigger_global_alert(0.4, 8.0)

func _on_combat_ended(winner: String):
# Handle combat end
	# Reduce alert when combat ends
	global_alert_level *= 0.7

func alert_nearby_allies(ai: AIController, target: Node):
# Alert nearby allies about target
	var nearby_allies = []
	
	for other_ai in registered_ai:
		if other_ai == ai or not is_instance_valid(other_ai):
			continue
		
		var distance = ai.entity.global_position.distance_to(other_ai.entity.global_position)
		if distance <= 150.0:  # 150 unit alert range
			nearby_allies.append(other_ai)
	
	# Alert allies
	for ally in nearby_allies:
		if ally.has_method("receive_ally_alert"):
			ally.receive_ally_alert(target, ai.entity.global_position)

# Save/Load Integration
func get_ai_manager_save_data() -> Dictionary:
# Get AI manager save data
	var save_data = {
		"global_alert_level": global_alert_level,
		"ai_difficulty_modifier": ai_difficulty_modifier,
		"faction_relations": faction_relations,
		"ai_spawn_limits": ai_spawn_limits,
		"registered_ai_count": registered_ai.size()
	}
	
	# Save individual AI states
	save_data["ai_entities"] = []
	for ai in registered_ai:
		if ai.has_method("get_save_data"):
			var ai_data = ai.get_save_data()
			ai_data["entity_position"] = ai.entity.global_position
			save_data["ai_entities"].append(ai_data)
	
	return save_data

func load_ai_manager_save_data(data: Dictionary):
# Load AI manager save data
	if "global_alert_level" in data:
		global_alert_level = data.global_alert_level
	if "ai_difficulty_modifier" in data:
		ai_difficulty_modifier = data.ai_difficulty_modifier
	if "faction_relations" in data:
		faction_relations = data.faction_relations
	if "ai_spawn_limits" in data:
		ai_spawn_limits = data.ai_spawn_limits

# Debug and Utilities
func get_ai_statistics() -> Dictionary:
# Get AI system statistics
	var stats = ai_performance_stats.duplicate()
	stats["registered_ai"] = registered_ai.size()
	stats["ai_by_type"] = {}
	
	for type_key in ai_groups:
		stats["ai_by_type"][type_key] = ai_groups[type_key].size()
	
	stats["global_alert_level"] = global_alert_level
	stats["difficulty_modifier"] = ai_difficulty_modifier
	
	return stats

func debug_print_ai_info():
# Print debug information about all AI
	print("[AIManager] === AI Debug Info ===")
	print("Total registered: ", registered_ai.size())
	print("Active AI: ", active_ai.size())
	print("Global alert: ", global_alert_level)
	print("Difficulty modifier: ", ai_difficulty_modifier)
	
	for type_key in ai_groups:
		print("  ", type_key, ": ", ai_groups[type_key].size())
	
	print("Performance stats: ", ai_performance_stats)

# Cleanup
func _exit_tree():
# Cleanup when AI manager is removed
	for ai in registered_ai:
		if is_instance_valid(ai):
			unregister_ai(ai)
	
	registered_ai.clear()
	active_ai.clear()
	ai_groups.clear()
	ai_update_queue.clear()
	
	print("[AIManager] AI manager cleaned up")
