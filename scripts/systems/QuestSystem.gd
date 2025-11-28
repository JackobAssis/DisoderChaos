extends Node

class_name QuestSystemScript

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal quest_objective_updated(quest_id: String, objective_id: String, progress: int)
signal quest_available(quest_id: String)
signal quest_turned_in(quest_id: String, rewards: Dictionary)

# Quest states
enum QuestState {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED,
	TURNED_IN
}

# Objective types
enum ObjectiveType {
	KILL,
	COLLECT,
	INTERACT,
	REACH_AREA,
	TALK_TO_NPC,
	CRAFT_ITEM,
	LEVEL_UP,
	CUSTOM
}

# Quest data
var all_quests: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Array = []
var failed_quests: Array = []
var turned_in_quests: Array = []
var available_quests: Array = []

# Quest objectives tracking
var objective_progress: Dictionary = {} # quest_id -> {objective_id -> progress}
var quest_timers: Dictionary = {} # quest_id -> timer_data

# Quest categories
var quest_categories: Dictionary = {
	"main": "Main Story",
	"side": "Side Quests", 
	"daily": "Daily Quests",
	"guild": "Guild Quests",
	"exploration": "Exploration",
	"crafting": "Crafting Quests"
}

# References
@onready var data_loader: DataLoader = get_node("/root/DataLoader")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var game_state: GameState = get_node("/root/GameState")

func _ready():
	await setup_quest_system()
	connect_events()
	print("[QuestSystem] Sistema de Quests inicializado")

func setup_quest_system():
# Initialize quest system
	# Wait for data to be loaded
	if not data_loader.is_fully_loaded():
		await data_loader.all_data_loaded
	
	load_all_quests()
	update_available_quests()

func connect_events():
# Connect to game events for quest tracking
	# Combat events
	event_bus.connect("enemy_defeated", _on_enemy_defeated)
	event_bus.connect("boss_defeated", _on_boss_defeated)
	
	# Item events
	event_bus.connect("item_collected", _on_item_collected)
	event_bus.connect("item_crafted", _on_item_crafted)
	
	# Social events
	event_bus.connect("npc_talked", _on_npc_talked)
	event_bus.connect("dialogue_completed", _on_dialogue_completed)
	
	# Exploration events
	event_bus.connect("area_entered", _on_area_entered)
	event_bus.connect("location_discovered", _on_location_discovered)
	
	# Player events
	event_bus.connect("player_level_changed", _on_player_level_changed)
	
	# Interaction events
	event_bus.connect("object_interacted", _on_object_interacted)

func load_all_quests():
# Load all quest data
	all_quests = data_loader.get_all_quests()
	print("[QuestSystem] Carregadas %d quests" % all_quests.size())

func update_available_quests():
# Update list of available quests based on requirements
	available_quests.clear()
	
	for quest_id in all_quests.keys():
		if is_quest_available(quest_id):
			available_quests.append(quest_id)
			quest_available.emit(quest_id)

func is_quest_available(quest_id: String) -> bool:
# Check if quest is available to start
	# Skip if already active, completed, or failed
	if quest_id in active_quests or quest_id in completed_quests:
		return false
	
	var quest_data = all_quests.get(quest_id, {})
	if quest_data.is_empty():
		return false
	
	# Check requirements
	var requirements = quest_data.get("requirements", {})
	
	# Level requirement
	if requirements.has("level"):
		if game_state.player_stats.current_level < requirements.level:
			return false
	
	# Prerequisite quests
	if requirements.has("prerequisite_quests"):
		for prereq_quest in requirements.prerequisite_quests:
			if prereq_quest not in completed_quests:
				return false
	
	# Required items
	if requirements.has("required_items"):
		for item_requirement in requirements.required_items:
			var item_id = item_requirement.get("item_id", "")
			var required_count = item_requirement.get("count", 1)
			if not game_state.has_item(item_id, required_count):
				return false
	
	# Location requirement
	if requirements.has("location"):
		var required_location = requirements.location
		if game_state.current_location != required_location:
			return false
	
	# Reputation requirement
	if requirements.has("reputation"):
		for faction in requirements.reputation:
			var required_rep = requirements.reputation[faction]
			var current_rep = game_state.get_reputation(faction)
			if current_rep < required_rep:
				return false
	
	return true

func start_quest(quest_id: String, quest_giver_id: String = "") -> bool:
# Start a quest
	if quest_id in active_quests:
		print("[QuestSystem] Quest jÃ¡ estÃ¡ ativa: %s" % quest_id)
		return false
	
	if not is_quest_available(quest_id):
		print("[QuestSystem] Quest nÃ£o disponÃ­vel: %s" % quest_id)
		return false
	
	var quest_data = all_quests.get(quest_id, {})
	if quest_data.is_empty():
		print("[QuestSystem] Quest nÃ£o encontrada: %s" % quest_id)
		return false
	
	# Initialize quest
	active_quests[quest_id] = {
		"state": QuestState.ACTIVE,
		"start_time": Time.get_time_dict_from_system(),
		"quest_giver": quest_giver_id,
		"data": quest_data
	}
	
	# Initialize objectives
	initialize_quest_objectives(quest_id, quest_data)
	
	# Setup quest timer if needed
	setup_quest_timer(quest_id, quest_data)
	
	# Remove from available quests
	if quest_id in available_quests:
		available_quests.erase(quest_id)
	
	# Consume required items if any
	consume_quest_requirements(quest_data)
	
	# Emit signal
	quest_started.emit(quest_id)
	print("[QuestSystem] Quest iniciada: %s" % quest_data.get("title", quest_id))
	
	return true

func initialize_quest_objectives(quest_id: String, quest_data: Dictionary):
# Initialize quest objectives tracking
	if not quest_data.has("objectives"):
		return
	
	objective_progress[quest_id] = {}
	
	for objective in quest_data.objectives:
		var objective_id = objective.get("id", "")
		objective_progress[quest_id][objective_id] = {
			"current": 0,
			"target": objective.get("target", 1),
			"completed": false
		}

func setup_quest_timer(quest_id: String, quest_data: Dictionary):
# Setup quest timer if quest is time-limited
	if not quest_data.has("time_limit"):
		return
	
	var time_limit = quest_data.time_limit
	quest_timers[quest_id] = {
		"duration": time_limit,
		"start_time": Time.get_time_dict_from_system(),
		"timer": null
	}
	
	# Create timer
	var timer = Timer.new()
	timer.wait_time = time_limit
	timer.one_shot = true
	timer.timeout.connect(_on_quest_timer_expired.bind(quest_id))
	add_child(timer)
	timer.start()
	
	quest_timers[quest_id].timer = timer

func consume_quest_requirements(quest_data: Dictionary):
# Consume items required to start quest
	var requirements = quest_data.get("requirements", {})
	
	if requirements.has("consumed_items"):
		for item_requirement in requirements.consumed_items:
			var item_id = item_requirement.get("item_id", "")
			var count = item_requirement.get("count", 1)
			game_state.remove_item_from_inventory(item_id, count)

func update_quest_objective(objective_type: int, target_data: Dictionary, quest_id: String = ""):
# Update quest objective progress
	# Se quest_id não fornecido, atualizar todas as quests ativas
	var quests_to_check = [quest_id] if quest_id != "" else active_quests.keys()
	
	for q_id in quests_to_check:
		if not active_quests.has(q_id):
			continue
		
		if not objective_progress.has(q_id):
			continue
		
		var quest_data = active_quests[q_id].data
		var objectives = quest_data.get("objectives", [])
	
	for objective in objectives:
		if matches_objective(objective, objective_type, target_data):
			var objective_id = objective.get("id", "")
			update_objective_progress(quest_id, objective_id, objective, target_data)

func matches_objective(objective: Dictionary, objective_type: ObjectiveType, target_data: Dictionary) -> bool:
# Check if target matches objective
	var obj_type = get_objective_type(objective.get("type", ""))
	
	if obj_type != objective_type:
		return false
	
	# Check specific target matching
	match objective_type:
		ObjectiveType.KILL:
			var target_enemy = objective.get("target", "")
			var killed_enemy = target_data.get("enemy_id", "")
			return target_enemy == "" or target_enemy == killed_enemy
		
		ObjectiveType.COLLECT:
			var target_item = objective.get("target", "")
			var collected_item = target_data.get("item_id", "")
			return target_item == collected_item
		
		ObjectiveType.TALK_TO_NPC:
			var target_npc = objective.get("target", "")
			var talked_npc = target_data.get("npc_id", "")
			return target_npc == talked_npc
		
		ObjectiveType.REACH_AREA:
			var target_area = objective.get("target", "")
			var current_area = target_data.get("area_id", "")
			return target_area == current_area
		
		ObjectiveType.INTERACT:
			var target_object = objective.get("target", "")
			var interacted_object = target_data.get("object_id", "")
			return target_object == interacted_object
		
		ObjectiveType.CRAFT_ITEM:
			var target_item = objective.get("target", "")
			var crafted_item = target_data.get("item_id", "")
			return target_item == crafted_item
		
		ObjectiveType.LEVEL_UP:
			var target_level = objective.get("target", 1)
			var current_level = target_data.get("level", 0)
			return current_level >= target_level
		
		ObjectiveType.CUSTOM:
			# Custom objectives need special handling
			return check_custom_objective(objective, target_data)
		
		_:
			return false

func get_objective_type(type_string: String) -> ObjectiveType:
# Convert string to ObjectiveType enum
	match type_string.to_lower():
		"kill":
			return ObjectiveType.KILL
		"collect":
			return ObjectiveType.COLLECT
		"interact":
			return ObjectiveType.INTERACT
		"reach_area":
			return ObjectiveType.REACH_AREA
		"talk_to_npc":
			return ObjectiveType.TALK_TO_NPC
		"craft_item":
			return ObjectiveType.CRAFT_ITEM
		"level_up":
			return ObjectiveType.LEVEL_UP
		"custom":
			return ObjectiveType.CUSTOM
		_:
			return ObjectiveType.CUSTOM

func update_objective_progress(quest_id: String, objective_id: String, objective: Dictionary, target_data: Dictionary):
# Update progress for specific objective
	var progress_data = objective_progress[quest_id][objective_id]
	
	if progress_data.completed:
		return
	
	var increment = target_data.get("amount", 1)
	progress_data.current = min(progress_data.current + increment, progress_data.target)
	
	# Check if objective completed
	if progress_data.current >= progress_data.target:
		progress_data.completed = true
		print("[QuestSystem] Objetivo completado: %s - %s" % [quest_id, objective_id])
	
	# Emit progress signal
	quest_objective_updated.emit(quest_id, objective_id, progress_data.current)
	
	# Check if quest completed
	check_quest_completion(quest_id)

func check_custom_objective(objective: Dictionary, target_data: Dictionary) -> bool:
# Check custom objective conditions
	var condition = objective.get("condition", "")
	
	match condition:
		"money_spent":
			var target_amount = objective.get("target", 100)
			var spent_amount = target_data.get("amount", 0)
			return spent_amount >= target_amount
		
		"reputation_gained":
			var target_faction = objective.get("faction", "")
			var target_amount = objective.get("target", 10)
			var gained_faction = target_data.get("faction", "")
			var gained_amount = target_data.get("amount", 0)
			return target_faction == gained_faction and gained_amount >= target_amount
		
		"time_survived":
			var target_time = objective.get("target", 300)  # seconds
			var survived_time = target_data.get("time", 0)
			return survived_time >= target_time
		
		_:
			return false

func check_quest_completion(quest_id: String):
# Check if all quest objectives are completed
	if not objective_progress.has(quest_id):
		return
	
	var all_completed = true
	for objective_id in objective_progress[quest_id].keys():
		if not objective_progress[quest_id][objective_id].completed:
			all_completed = false
			break
	
	if all_completed:
		complete_quest(quest_id)

func complete_quest(quest_id: String):
# Complete a quest
	if not active_quests.has(quest_id):
		return
	
	# Update quest state
	active_quests[quest_id].state = QuestState.COMPLETED
	active_quests[quest_id].completion_time = Time.get_time_dict_from_system()
	
	# Add to completed quests
	if quest_id not in completed_quests:
		completed_quests.append(quest_id)
	
	# Clean up timer
	if quest_timers.has(quest_id):
		cleanup_quest_timer(quest_id)
	
	# Emit completion signal
	quest_completed.emit(quest_id)
	
	var quest_data = active_quests[quest_id].data
	print("[QuestSystem] Quest completada: %s" % quest_data.get("title", quest_id))
	
	# Update available quests (completion might unlock new ones)
	update_available_quests()

func fail_quest(quest_id: String, reason: String = ""):
# Fail a quest
	if not active_quests.has(quest_id):
		return
	
	# Update quest state
	active_quests[quest_id].state = QuestState.FAILED
	active_quests[quest_id].failure_reason = reason
	active_quests[quest_id].failure_time = Time.get_time_dict_from_system()
	
	# Add to failed quests
	if quest_id not in failed_quests:
		failed_quests.append(quest_id)
	
	# Clean up timer
	if quest_timers.has(quest_id):
		cleanup_quest_timer(quest_id)
	
	# Remove from active quests
	active_quests.erase(quest_id)
	
	# Emit failure signal
	quest_failed.emit(quest_id)
	
	print("[QuestSystem] Quest falhada: %s (%s)" % [quest_id, reason])

func turn_in_quest(quest_id: String, npc_id: String = "") -> Dictionary:
# Turn in a completed quest for rewards
	if not active_quests.has(quest_id):
		return {}
	
	var quest_instance = active_quests[quest_id]
	if quest_instance.state != QuestState.COMPLETED:
		print("[QuestSystem] Quest nÃ£o completada: %s" % quest_id)
		return {}
	
	var quest_data = quest_instance.data
	var rewards = quest_data.get("rewards", {})
	
	# Give rewards
	var awarded_rewards = award_quest_rewards(rewards)
	
	# Update quest state
	quest_instance.state = QuestState.TURNED_IN
	quest_instance.turn_in_time = Time.get_time_dict_from_system()
	quest_instance.turned_in_to = npc_id
	
	# Add to turned in quests
	if quest_id not in turned_in_quests:
		turned_in_quests.append(quest_id)
	
	# Remove from active quests
	active_quests.erase(quest_id)
	
	# Clean up objective progress
	if objective_progress.has(quest_id):
		objective_progress.erase(quest_id)
	
	# Emit turn-in signal
	quest_turned_in.emit(quest_id, awarded_rewards)
	
	print("[QuestSystem] Quest entregue: %s" % quest_data.get("title", quest_id))
	
	# Update available quests
	update_available_quests()
	
	return awarded_rewards

func award_quest_rewards(rewards: Dictionary) -> Dictionary:
# Award quest rewards to player
	var awarded = {}
	
	# Experience
	if rewards.has("experience"):
		var xp = rewards.experience
		game_state.player_stats.add_experience(xp)
		awarded["experience"] = xp
	
	# Currency
	if rewards.has("currency"):
		var money = rewards.currency
		game_state.modify_currency(money)
		awarded["currency"] = money
	
	# Items
	if rewards.has("items"):
		awarded["items"] = []
		for item_data in rewards.items:
			var item_id = item_data.get("item_id", "")
			var quantity = item_data.get("quantity", 1)
			if game_state.add_item_to_inventory(item_id, quantity):
				awarded["items"].append({"item_id": item_id, "quantity": quantity})
	
	# Reputation
	if rewards.has("reputation"):
		awarded["reputation"] = []
		for faction in rewards.reputation:
			var rep_gain = rewards.reputation[faction]
			game_state.modify_reputation(faction, rep_gain)
			awarded["reputation"].append({"faction": faction, "amount": rep_gain})
	
	return awarded

func cleanup_quest_timer(quest_id: String):
# Clean up quest timer
	if quest_timers.has(quest_id):
		var timer_data = quest_timers[quest_id]
		if timer_data.timer:
			timer_data.timer.queue_free()
		quest_timers.erase(quest_id)

# Event handlers for quest tracking
func _on_enemy_defeated(enemy_id: String, position: Vector2, player_level: int):
# Track enemy defeats for kill objectives
	update_quest_objective(ObjectiveType.KILL, {"enemy_id": enemy_id, "amount": 1})

func _on_boss_defeated(boss_id: String, position: Vector2, player_level: int):
# Track boss defeats for kill objectives
	update_quest_objective(ObjectiveType.KILL, {"enemy_id": boss_id, "amount": 1})

func _on_item_collected(item_id: String, quantity: int):
# Track item collection for collect objectives
	update_quest_objective(ObjectiveType.COLLECT, {"item_id": item_id, "amount": quantity})

func _on_item_crafted(item_id: String, quantity: int):
# Track item crafting for craft objectives
	update_quest_objective(ObjectiveType.CRAFT_ITEM, {"item_id": item_id, "amount": quantity})

func _on_npc_talked(npc_id: String):
# Track NPC conversations for talk objectives
	update_quest_objective(ObjectiveType.TALK_TO_NPC, {"npc_id": npc_id, "amount": 1})

func _on_dialogue_completed(npc_id: String, dialogue_id: String):
# Track dialogue completion for talk objectives
	update_quest_objective(ObjectiveType.TALK_TO_NPC, {"npc_id": npc_id, "amount": 1})

func _on_area_entered(area_id: String):
# Track area entry for reach objectives
	update_quest_objective(ObjectiveType.REACH_AREA, {"area_id": area_id, "amount": 1})

func _on_location_discovered(location_id: String):
# Track location discovery for reach objectives
	update_quest_objective(ObjectiveType.REACH_AREA, {"area_id": location_id, "amount": 1})

func _on_player_level_changed(new_level: int):
# Track level changes for level objectives
	update_quest_objective(ObjectiveType.LEVEL_UP, {"level": new_level, "amount": 1})

func _on_object_interacted(object_id: String):
# Track object interactions for interact objectives
	update_quest_objective(ObjectiveType.INTERACT, {"object_id": object_id, "amount": 1})

func _on_quest_timer_expired(quest_id: String):
# Handle quest timer expiration
	fail_quest(quest_id, "Time limit exceeded")

# Utility functions
func get_quest_progress(quest_id: String) -> Dictionary:
# Get progress for specific quest
	if not objective_progress.has(quest_id):
		return {}
	
	var progress = {}
	for objective_id in objective_progress[quest_id].keys():
		var obj_data = objective_progress[quest_id][objective_id]
		progress[objective_id] = {
			"current": obj_data.current,
			"target": obj_data.target,
			"completed": obj_data.completed,
			"progress_percent": float(obj_data.current) / float(obj_data.target) * 100.0
		}
	
	return progress

func get_quest_by_category(category: String) -> Array:
# Get quests by category
	var quests = []
	
	for quest_id in all_quests.keys():
		var quest_data = all_quests[quest_id]
		if quest_data.get("category", "side") == category:
			quests.append(quest_id)
	
	return quests

func get_active_quests_summary() -> Array:
# Get summary of all active quests
	var summary = []
	
	for quest_id in active_quests.keys():
		var quest_instance = active_quests[quest_id]
		var quest_data = quest_instance.data
		var progress = get_quest_progress(quest_id)
		
		summary.append({
			"quest_id": quest_id,
			"title": quest_data.get("title", quest_id),
			"description": quest_data.get("description", ""),
			"category": quest_data.get("category", "side"),
			"progress": progress,
			"state": quest_instance.state
		})
	
	return summary

func is_quest_completed(quest_id: String) -> bool:
# Check if quest is completed
	return quest_id in completed_quests

func is_quest_active(quest_id: String) -> bool:
# Check if quest is active
	return quest_id in active_quests

func get_completed_quest_count() -> int:
# Get number of completed quests
	return completed_quests.size()

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"active_quests": serialize_active_quests(),
		"completed_quests": completed_quests,
		"failed_quests": failed_quests,
		"turned_in_quests": turned_in_quests,
		"objective_progress": objective_progress,
		"quest_timers": serialize_quest_timers()
	}

func serialize_active_quests() -> Dictionary:
# Serialize active quests for saving
	var serialized = {}
	
	for quest_id in active_quests.keys():
		var quest_instance = active_quests[quest_id]
		serialized[quest_id] = {
			"state": quest_instance.state,
			"start_time": quest_instance.start_time,
			"quest_giver": quest_instance.get("quest_giver", ""),
			"completion_time": quest_instance.get("completion_time", {}),
			"failure_reason": quest_instance.get("failure_reason", "")
		}
	
	return serialized

func serialize_quest_timers() -> Dictionary:
# Serialize quest timers for saving
	var serialized = {}
	
	for quest_id in quest_timers.keys():
		var timer_data = quest_timers[quest_id]
		serialized[quest_id] = {
			"duration": timer_data.duration,
			"start_time": timer_data.start_time
		}
	
	return serialized

func load_save_data(data: Dictionary):
# Load quest save data
	completed_quests = data.get("completed_quests", [])
	failed_quests = data.get("failed_quests", [])
	turned_in_quests = data.get("turned_in_quests", [])
	objective_progress = data.get("objective_progress", {})
	
	# Restore active quests
	var saved_active = data.get("active_quests", {})
	for quest_id in saved_active.keys():
		var saved_quest = saved_active[quest_id]
		var quest_data = all_quests.get(quest_id, {})
		
		if not quest_data.is_empty():
			active_quests[quest_id] = {
				"state": saved_quest.get("state", QuestState.ACTIVE),
				"start_time": saved_quest.get("start_time", {}),
				"quest_giver": saved_quest.get("quest_giver", ""),
				"data": quest_data
			}
			
			if saved_quest.has("completion_time"):
				active_quests[quest_id]["completion_time"] = saved_quest.completion_time
			
			if saved_quest.has("failure_reason"):
				active_quests[quest_id]["failure_reason"] = saved_quest.failure_reason
	
	# Restore quest timers
	var saved_timers = data.get("quest_timers", {})
	for quest_id in saved_timers.keys():
		if quest_id in active_quests:
			var timer_data = saved_timers[quest_id]
			restore_quest_timer(quest_id, timer_data)
	
	update_available_quests()
	print("[QuestSystem] Dados de quest carregados")

func restore_quest_timer(quest_id: String, timer_data: Dictionary):
# Restore quest timer from save data
	var duration = timer_data.get("duration", 0)
	var start_time = timer_data.get("start_time", {})
	
	# Calculate remaining time
	var current_time = Time.get_time_dict_from_system()
	var elapsed = calculate_time_difference(start_time, current_time)
	var remaining = duration - elapsed
	
	if remaining > 0:
		quest_timers[quest_id] = {
			"duration": duration,
			"start_time": start_time,
			"timer": null
		}
		
		# Create new timer with remaining time
		var timer = Timer.new()
		timer.wait_time = remaining
		timer.one_shot = true
		timer.timeout.connect(_on_quest_timer_expired.bind(quest_id))
		add_child(timer)
		timer.start()
		
		quest_timers[quest_id].timer = timer
	else:
		# Timer already expired
		fail_quest(quest_id, "Time limit exceeded")

func calculate_time_difference(start_time: Dictionary, end_time: Dictionary) -> float:
# Calculate time difference in seconds
	var start_unix = Time.get_unix_time_from_datetime_dict(start_time)
	var end_unix = Time.get_unix_time_from_datetime_dict(end_time)
	return end_unix - start_unix

# Debug functions
func debug_start_quest(quest_id: String):
# Debug: Start quest without requirements
	if all_quests.has(quest_id):
		start_quest(quest_id, "debug")

func debug_complete_quest(quest_id: String):
# Debug: Force complete quest
	if active_quests.has(quest_id):
		complete_quest(quest_id)

func debug_add_quest_progress(quest_id: String, objective_id: String, amount: int):
# Debug: Add progress to quest objective
	if objective_progress.has(quest_id) and objective_progress[quest_id].has(objective_id):
		var progress_data = objective_progress[quest_id][objective_id]
		progress_data.current = min(progress_data.current + amount, progress_data.target)
		
		if progress_data.current >= progress_data.target:
			progress_data.completed = true
		
		quest_objective_updated.emit(quest_id, objective_id, progress_data.current)
		check_quest_completion(quest_id)
