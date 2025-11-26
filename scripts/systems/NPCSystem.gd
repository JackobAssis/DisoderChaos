extends Node

class_name NPCSystem

signal npc_spawned(npc_id: String, npc_node: Node2D)
signal npc_despawned(npc_id: String)
signal npc_interaction_started(npc_id: String)
signal npc_interaction_ended(npc_id: String)

# Core data structures
var npcs_data: Dictionary = {}
var dialogue_trees: Dictionary = {}
var active_npcs: Dictionary = {} # npc_id -> NPCController
var npc_schedules: Dictionary = {} # npc_id -> current schedule state

# Location tracking
var player_location: String = ""
var location_npcs: Dictionary = {} # location -> Array[npc_ids]

# Time and conditions
var current_time: int = 12 # 0-23 hours
var current_weather: String = "clear"
var player_level: int = 1

# References
@onready var quest_system: QuestSystem = get_node("/root/QuestSystem") if has_node("/root/QuestSystem") else null
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")

func _ready():
	load_npc_data()
	load_dialogue_data()
	setup_event_connections()
	setup_location_tracking()
	
	# Start NPC systems
	start_schedule_timer()
	
	print("[NPCSystem] Sistema de NPCs inicializado com ", npcs_data.size(), " NPCs carregados")

func load_npc_data() -> void:
	var data = DataLoader.load_data_file("data/npcs.json")
	if data and data.has("npcs"):
		npcs_data = data.npcs
		print("[NPCSystem] Carregados ", npcs_data.size(), " NPCs")
	else:
		print("[NPCSystem] ERRO: Não foi possível carregar dados dos NPCs")

func load_dialogue_data() -> void:
	var data = DataLoader.load_data_file("data/dialogues.json")
	if data and data.has("dialogue_trees"):
		dialogue_trees = data.dialogue_trees
		print("[NPCSystem] Carregadas ", dialogue_trees.size(), " árvores de diálogo")
	else:
		print("[NPCSystem] ERRO: Não foi possível carregar dados de diálogos")

func setup_event_connections() -> void:
	# Player events
	event_bus.connect("player_location_changed", _on_player_location_changed)
	event_bus.connect("time_changed", _on_time_changed)
	event_bus.connect("weather_changed", _on_weather_changed)
	event_bus.connect("player_level_changed", _on_player_level_changed)
	
	# Quest events
	event_bus.connect("quest_completed", _on_quest_completed)
	event_bus.connect("faction_reputation_changed", _on_faction_reputation_changed)
	
	# NPC interaction events
	event_bus.connect("npc_interaction_requested", _on_npc_interaction_requested)

func setup_location_tracking() -> void:
	# Initialize location-based NPC tracking
	for npc_id in npcs_data.keys():
		var npc_data = npcs_data[npc_id]
		var location = npc_data.get("location", "")
		
		if not location_npcs.has(location):
			location_npcs[location] = []
		location_npcs[location].append(npc_id)

func start_schedule_timer() -> void:
	var timer = Timer.new()
	timer.timeout.connect(_update_npc_schedules)
	timer.wait_time = 60.0 # Update every minute
	timer.autostart = true
	add_child(timer)

func spawn_npc(npc_id: String) -> NPCController:
	if not npcs_data.has(npc_id):
		print("[NPCSystem] ERRO: NPC não encontrado: ", npc_id)
		return null
	
	if active_npcs.has(npc_id):
		print("[NPCSystem] NPC já está ativo: ", npc_id)
		return active_npcs[npc_id]
	
	var npc_data = npcs_data[npc_id]
	
	# Check spawn conditions
	if not check_spawn_conditions(npc_data):
		return null
	
	# Create NPC controller
	var npc_controller = preload("res://scripts/systems/NPCController.gd").new()
	npc_controller.initialize(npc_id, npc_data, self)
	
	# Add to active NPCs
	active_npcs[npc_id] = npc_controller
	
	# Initialize schedule if needed
	if npc_data.get("movement_type") == "schedule":
		init_npc_schedule(npc_id, npc_data)
	
	npc_spawned.emit(npc_id, npc_controller)
	print("[NPCSystem] NPC spawned: ", npc_id)
	
	return npc_controller

func despawn_npc(npc_id: String) -> void:
	if not active_npcs.has(npc_id):
		return
	
	var npc_controller = active_npcs[npc_id]
	npc_controller.queue_free()
	active_npcs.erase(npc_id)
	
	if npc_schedules.has(npc_id):
		npc_schedules.erase(npc_id)
	
	npc_despawned.emit(npc_id)
	print("[NPCSystem] NPC despawned: ", npc_id)

func check_spawn_conditions(npc_data: Dictionary) -> bool:
	var conditions = npc_data.get("spawn_conditions", {})
	
	# Time range check
	if conditions.has("time_range"):
		var time_range = conditions.time_range
		var start_time = time_range[0]
		var end_time = time_range[1]
		
		if start_time <= end_time:
			if current_time < start_time or current_time > end_time:
				return false
		else:  # Night time span (e.g., 22-6)
			if current_time < start_time and current_time > end_time:
				return false
	
	# Weather check
	if conditions.has("weather"):
		var weather_req = conditions.weather
		if weather_req != "any" and current_weather not in weather_req:
			return false
	
	# Faction reputation check
	if conditions.has("faction_reputation"):
		var rep_reqs = conditions.faction_reputation
		for faction in rep_reqs.keys():
			var required_rep = rep_reqs[faction]
			var current_rep = get_faction_reputation(faction)
			if current_rep < required_rep:
				return false
	
	# Level check
	if conditions.has("level"):
		if player_level < conditions.level:
			return false
	
	return true

func get_faction_reputation(faction: String) -> int:
	if quest_system:
		return quest_system.get_faction_reputation(faction)
	return 0

func init_npc_schedule(npc_id: String, npc_data: Dictionary) -> void:
	var schedule_data = npc_data.get("schedule", {})
	
	npc_schedules[npc_id] = {
		"schedule": schedule_data,
		"current_activity": "",
		"activity_start_time": 0,
		"last_update": current_time
	}
	
	update_npc_activity(npc_id)

func update_npc_activity(npc_id: String) -> void:
	if not npc_schedules.has(npc_id):
		return
	
	var schedule_info = npc_schedules[npc_id]
	var schedule = schedule_info.schedule
	
	# Find appropriate activity for current time
	var best_time = -1
	var current_activity = ""
	
	for time_key in schedule.keys():
		var time_hour = int(time_key)
		if time_hour <= current_time and time_hour > best_time:
			best_time = time_hour
			current_activity = time_key
	
	if current_activity != "" and current_activity != schedule_info.current_activity:
		schedule_info.current_activity = current_activity
		schedule_info.activity_start_time = current_time
		
		# Notify NPC controller about activity change
		if active_npcs.has(npc_id):
			var npc_controller = active_npcs[npc_id]
			var activity_data = schedule[current_activity]
			npc_controller.change_activity(activity_data)

func update_location_npcs(location: String) -> void:
	if not location_npcs.has(location):
		return
	
	var location_npc_ids = location_npcs[location]
	
	for npc_id in location_npc_ids:
		var npc_data = npcs_data[npc_id]
		
		# Try to spawn NPCs that should be in this location
		if check_spawn_conditions(npc_data):
			if not active_npcs.has(npc_id):
				spawn_npc(npc_id)
		else:
			# Despawn NPCs that no longer meet conditions
			if active_npcs.has(npc_id):
				despawn_npc(npc_id)

func get_npc_dialogue_tree(npc_id: String) -> Dictionary:
	var npc_data = npcs_data.get(npc_id, {})
	var tree_id = npc_data.get("dialogue_tree", "")
	
	if tree_id != "" and dialogue_trees.has(tree_id):
		return dialogue_trees[tree_id]
	
	return {}

func start_dialogue(npc_id: String) -> void:
	if not active_npcs.has(npc_id):
		print("[NPCSystem] ERRO: Tentativa de diálogo com NPC inativo: ", npc_id)
		return
	
	var dialogue_tree = get_npc_dialogue_tree(npc_id)
	if dialogue_tree.is_empty():
		print("[NPCSystem] ERRO: Árvore de diálogo não encontrada para NPC: ", npc_id)
		return
	
	# Create dialogue system if it doesn't exist
	var dialogue_system = get_dialogue_system()
	if dialogue_system:
		npc_interaction_started.emit(npc_id)
		dialogue_system.start_dialogue(npc_id, dialogue_tree)

func get_dialogue_system() -> DialogueSystem:
	# Try to get existing dialogue system
	var dialogue_system = get_node_or_null("/root/DialogueSystem")
	if dialogue_system:
		return dialogue_system
	
	# Create dialogue system if it doesn't exist
	dialogue_system = preload("res://scripts/systems/DialogueSystem.gd").new()
	dialogue_system.name = "DialogueSystem"
	get_tree().root.add_child(dialogue_system)
	
	return dialogue_system

func get_npc_services(npc_id: String) -> Dictionary:
	var npc_data = npcs_data.get(npc_id, {})
	return npc_data.get("services", {})

func is_npc_available_for_service(npc_id: String, service_type: String) -> bool:
	var services = get_npc_services(npc_id)
	return services.get(service_type, false)

func get_npcs_at_location(location: String) -> Array:
	var result = []
	
	if not location_npcs.has(location):
		return result
	
	for npc_id in location_npcs[location]:
		if active_npcs.has(npc_id):
			result.append(npc_id)
	
	return result

func get_npcs_with_service(service_type: String) -> Array:
	var result = []
	
	for npc_id in active_npcs.keys():
		if is_npc_available_for_service(npc_id, service_type):
			result.append(npc_id)
	
	return result

func get_npc_data(npc_id: String) -> Dictionary:
	return npcs_data.get(npc_id, {})

func get_active_npc(npc_id: String) -> NPCController:
	return active_npcs.get(npc_id)

func _update_npc_schedules() -> void:
	for npc_id in npc_schedules.keys():
		update_npc_activity(npc_id)

# Event handlers
func _on_player_location_changed(new_location: String) -> void:
	player_location = new_location
	update_location_npcs(new_location)
	
	# Update NPCs based on distance
	_update_npc_visibility()

func _on_time_changed(new_time: int) -> void:
	current_time = new_time
	
	# Update NPC spawn conditions
	_update_npc_availability()

func _on_weather_changed(new_weather: String) -> void:
	current_weather = new_weather
	_update_npc_availability()

func _on_player_level_changed(new_level: int) -> void:
	player_level = new_level
	_update_npc_availability()

func _on_quest_completed(quest_id: String, _reward: Dictionary) -> void:
	# Some NPCs might have different dialogue after certain quests
	_refresh_npc_dialogues()

func _on_faction_reputation_changed(faction: String, _new_reputation: int) -> void:
	# Update NPC availability based on reputation changes
	_update_npc_availability()

func _on_npc_interaction_requested(npc_id: String) -> void:
	start_dialogue(npc_id)

func _update_npc_availability() -> void:
	# Check all NPCs in current location for spawn/despawn conditions
	update_location_npcs(player_location)
	
	# Update NPCs in nearby locations as well
	var nearby_locations = _get_nearby_locations()
	for location in nearby_locations:
		update_location_npcs(location)

func _update_npc_visibility() -> void:
	# Update which NPCs should be visible based on player location
	# This would integrate with the rendering system
	pass

func _refresh_npc_dialogues() -> void:
	# Refresh dialogue states for all active NPCs
	# This ensures dialogue reflects current game state
	for npc_id in active_npcs.keys():
		var npc_controller = active_npcs[npc_id]
		npc_controller.refresh_dialogue_state()

func _get_nearby_locations() -> Array:
	# This would return locations near the player
	# For now, return empty array - implement based on your map system
	return []

# Save/Load functionality
func get_save_data() -> Dictionary:
	var save_data = {
		"current_time": current_time,
		"current_weather": current_weather,
		"player_location": player_location,
		"npc_schedules": npc_schedules,
		"active_npcs": {}
	}
	
	# Save NPC states
	for npc_id in active_npcs.keys():
		var npc_controller = active_npcs[npc_id]
		save_data.active_npcs[npc_id] = npc_controller.get_save_data()
	
	return save_data

func load_save_data(data: Dictionary) -> void:
	if data.has("current_time"):
		current_time = data.current_time
	
	if data.has("current_weather"):
		current_weather = data.current_weather
	
	if data.has("player_location"):
		player_location = data.player_location
	
	if data.has("npc_schedules"):
		npc_schedules = data.npc_schedules
	
	# Restore active NPCs
	if data.has("active_npcs"):
		for npc_id in data.active_npcs.keys():
			var npc_save_data = data.active_npcs[npc_id]
			var npc_controller = spawn_npc(npc_id)
			if npc_controller:
				npc_controller.load_save_data(npc_save_data)

# Utility functions
func get_all_npcs() -> Dictionary:
	return npcs_data

func get_active_npcs() -> Dictionary:
	return active_npcs

func is_npc_active(npc_id: String) -> bool:
	return active_npcs.has(npc_id)

func force_spawn_npc(npc_id: String) -> NPCController:
	# Spawn NPC regardless of conditions (for debugging/testing)
	if not npcs_data.has(npc_id):
		return null
	
	var npc_data = npcs_data[npc_id]
	var npc_controller = preload("res://scripts/systems/NPCController.gd").new()
	npc_controller.initialize(npc_id, npc_data, self)
	
	active_npcs[npc_id] = npc_controller
	npc_spawned.emit(npc_id, npc_controller)
	
	return npc_controller

func force_despawn_npc(npc_id: String) -> void:
	despawn_npc(npc_id)

# Debug functions
func debug_print_active_npcs() -> void:
	print("[NPCSystem] NPCs Ativos:")
	for npc_id in active_npcs.keys():
		var npc_data = npcs_data[npc_id]
		print("  - ", npc_id, " (", npc_data.name, ") em ", npc_data.location)

func debug_print_location_npcs(location: String) -> void:
	print("[NPCSystem] NPCs em ", location, ":")
	var npcs_at_location = get_npcs_at_location(location)
	for npc_id in npcs_at_location:
		var npc_data = npcs_data[npc_id]
		print("  - ", npc_id, " (", npc_data.name, ")")