extends Node
class_name QuestSystem
# quest_system.gd - Sistema completo de missões do Disorder Chaos

# Quest data storage
var quest_data: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Array[String] = []
var available_quests: Dictionary = {}

# Quest state tracking
var quest_objectives_progress: Dictionary = {}

# Event connections
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_objective_completed(quest_id: String, objective_id: String)
signal quest_failed(quest_id: String, reason: String)
signal quest_progress_updated(quest_id: String, objective_id: String, progress: int)

func _ready():
	print("[QuestSystem] Quest system initialized")
	load_quest_data()
	connect_game_events()
	setup_quest_timers()

func load_quest_data():
	"""Load quest definitions from JSON"""
	var quest_file = DataLoader.load_data_file("quests.json")
	if quest_file and quest_file.has("quests"):
		quest_data = quest_file.quests
		print("[QuestSystem] Loaded ", quest_data.size(), " quest definitions")
		initialize_available_quests()
	else:
		push_error("[QuestSystem] Failed to load quest data")

func connect_game_events():
	"""Connect to game events for quest progression"""
	# Player actions
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.item_used.connect(_on_item_used)
	EventBus.location_discovered.connect(_on_location_discovered)
	EventBus.npc_talked_to.connect(_on_npc_talked_to)
	
	# Crafting and creation
	if EventBus.has_signal("item_crafted"):
		EventBus.item_crafted.connect(_on_item_crafted)
	else:
		EventBus.add_user_signal("item_crafted")
		EventBus.item_crafted.connect(_on_item_crafted)
	
	# Stealth and infiltration
	if not EventBus.has_signal("stealth_objective_completed"):
		EventBus.add_user_signal("stealth_objective_completed")
		EventBus.add_user_signal("player_detected")
		EventBus.add_user_signal("area_explored")
		EventBus.add_user_signal("survival_time_reached")
	
	EventBus.stealth_objective_completed.connect(_on_stealth_completed)
	EventBus.player_detected.connect(_on_player_detected)
	EventBus.area_explored.connect(_on_area_explored)
	EventBus.survival_time_reached.connect(_on_survival_time_reached)

func setup_quest_timers():
	"""Setup timers for timed quests"""
	var timer = Timer.new()
	timer.name = "QuestTimer"
	timer.timeout.connect(_on_quest_timer_tick)
	timer.wait_time = 1.0  # Check every second
	timer.autostart = true
	add_child(timer)

func initialize_available_quests():
	"""Initialize list of available quests based on player state"""
	for quest_id in quest_data:
		if is_quest_available(quest_id):
			available_quests[quest_id] = quest_data[quest_id]

# Quest Management
func start_quest(quest_id: String) -> bool:
	"""Start a quest if it meets requirements"""
	if not quest_data.has(quest_id):
		print("[QuestSystem] Quest not found: ", quest_id)
		return false
	
	if active_quests.has(quest_id):
		print("[QuestSystem] Quest already active: ", quest_id)
		return false
	
	if not is_quest_available(quest_id):
		print("[QuestSystem] Quest requirements not met: ", quest_id)
		return false
	
	var quest = quest_data[quest_id].duplicate(true)
	quest.started_time = Time.get_ticks_msec()
	quest.status = "active"
	
	# Initialize objective progress
	quest_objectives_progress[quest_id] = {}
	for objective in quest.objectives:
		quest_objectives_progress[quest_id][objective.id] = 0
		objective.completed = false
	
	active_quests[quest_id] = quest
	
	# Remove from available quests
	available_quests.erase(quest_id)
	
	print("[QuestSystem] Started quest: ", quest.name)
	quest_started.emit(quest_id)
	
	# Show notification
	EventBus.ui_notification_shown.emit("Quest Started: " + quest.name, "info")
	
	return true

func complete_quest(quest_id: String):
	"""Complete a quest and give rewards"""
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	quest.status = "completed"
	quest.completed_time = Time.get_ticks_msec()
	
	# Give rewards
	give_quest_rewards(quest)
	
	# Move to completed quests
	completed_quests.append(quest_id)
	active_quests.erase(quest_id)
	quest_objectives_progress.erase(quest_id)
	
	print("[QuestSystem] Completed quest: ", quest.name)
	quest_completed.emit(quest_id, quest.rewards)
	
	# Show notification
	EventBus.ui_notification_shown.emit("Quest Completed: " + quest.name, "success")
	
	# Check for newly available quests
	check_newly_available_quests()

func fail_quest(quest_id: String, reason: String):
	"""Fail a quest"""
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	quest.status = "failed"
	
	active_quests.erase(quest_id)
	quest_objectives_progress.erase(quest_id)
	
	print("[QuestSystem] Failed quest: ", quest.name, " - Reason: ", reason)
	quest_failed.emit(quest_id, reason)
	
	# Show notification
	EventBus.ui_notification_shown.emit("Quest Failed: " + quest.name, "error")

func give_quest_rewards(quest: Dictionary):
	"""Give rewards to player"""
	var rewards = quest.get("rewards", {})
	
	# Experience
	if rewards.has("xp"):
		GameState.gain_experience(rewards.xp)
	
	# Currency
	if rewards.has("currency"):
		GameState.player_data.currency += rewards.currency
	
	# Items
	if rewards.has("items"):
		for item_reward in rewards.items:
			GameState.add_item_to_inventory(item_reward.id, item_reward.quantity)
	
	# Faction reputation
	if rewards.has("faction_reputation"):
		for faction in rewards.faction_reputation:
			modify_faction_reputation(faction, rewards.faction_reputation[faction])
	
	# Unlock features
	if rewards.has("unlock_features"):
		for feature in rewards.unlock_features:
			unlock_game_feature(feature)

func modify_faction_reputation(faction_id: String, amount: int):
	"""Modify reputation with a faction"""
	if not GameState.player_data.has("faction_reputation"):
		GameState.player_data.faction_reputation = {}
	
	if not GameState.player_data.faction_reputation.has(faction_id):
		GameState.player_data.faction_reputation[faction_id] = 0
	
	GameState.player_data.faction_reputation[faction_id] += amount
	
	# Clamp reputation values
	GameState.player_data.faction_reputation[faction_id] = clamp(
		GameState.player_data.faction_reputation[faction_id], 
		-1000, 
		1000
	)
	
	print("[QuestSystem] Faction reputation updated: ", faction_id, " ", amount)

func unlock_game_feature(feature_id: String):
	"""Unlock a game feature"""
	if not GameState.player_data.has("unlocked_features"):
		GameState.player_data.unlocked_features = []
	
	if feature_id not in GameState.player_data.unlocked_features:
		GameState.player_data.unlocked_features.append(feature_id)
		print("[QuestSystem] Unlocked feature: ", feature_id)

# Quest Requirements
func is_quest_available(quest_id: String) -> bool:
	"""Check if quest is available to start"""
	if not quest_data.has(quest_id):
		return false
	
	var quest = quest_data[quest_id]
	
	# Check if already completed and not repeatable
	if quest_id in completed_quests and not quest.get("repeatable", false):
		return false
	
	# Check level requirement
	if quest.has("level_requirement"):
		if GameState.player_data.level < quest.level_requirement:
			return false
	
	# Check prerequisites
	if quest.has("prerequisites"):
		for prereq in quest.prerequisites:
			if prereq not in completed_quests:
				return false
	
	# Check faction requirements
	if quest.has("faction_requirements"):
		for faction in quest.faction_requirements:
			var required_standing = quest.faction_requirements[faction]
			var current_reputation = get_faction_reputation(faction)
			
			if not meets_reputation_requirement(current_reputation, required_standing):
				return false
	
	return true

func get_faction_reputation(faction_id: String) -> int:
	"""Get current reputation with faction"""
	if GameState.player_data.has("faction_reputation"):
		return GameState.player_data.faction_reputation.get(faction_id, 0)
	return 0

func meets_reputation_requirement(current_rep: int, requirement: String) -> bool:
	"""Check if current reputation meets requirement"""
	match requirement:
		"hostile":
			return current_rep <= -500
		"unfriendly":
			return current_rep <= -100 and current_rep > -500
		"neutral":
			return current_rep >= -100 and current_rep <= 100
		"friendly":
			return current_rep >= 100 and current_rep < 500
		"honored":
			return current_rep >= 500
		_:
			return true

func check_newly_available_quests():
	"""Check for quests that became available after completion"""
	for quest_id in quest_data:
		if not available_quests.has(quest_id) and not active_quests.has(quest_id):
			if is_quest_available(quest_id):
				available_quests[quest_id] = quest_data[quest_id]
				print("[QuestSystem] New quest available: ", quest_data[quest_id].name)

# Objective Progress Tracking
func update_objective_progress(quest_id: String, objective_id: String, progress: int):
	"""Update progress for a specific objective"""
	if not active_quests.has(quest_id):
		return
	
	if not quest_objectives_progress[quest_id].has(objective_id):
		return
	
	quest_objectives_progress[quest_id][objective_id] += progress
	
	var quest = active_quests[quest_id]
	var objective = find_objective(quest, objective_id)
	
	if objective:
		var current_progress = quest_objectives_progress[quest_id][objective_id]
		var required_amount = objective.required_amount
		
		quest_progress_updated.emit(quest_id, objective_id, current_progress)
		
		# Check if objective is completed
		if current_progress >= required_amount and not objective.completed:
			objective.completed = true
			quest_objective_completed.emit(quest_id, objective_id)
			print("[QuestSystem] Objective completed: ", objective.description)
			
			# Check if all objectives are completed
			if are_all_objectives_completed(quest):
				complete_quest(quest_id)

func find_objective(quest: Dictionary, objective_id: String) -> Dictionary:
	"""Find objective in quest by ID"""
	for obj in quest.objectives:
		if obj.id == objective_id:
			return obj
	return {}

func are_all_objectives_completed(quest: Dictionary) -> bool:
	"""Check if all objectives in quest are completed"""
	for obj in quest.objectives:
		if not obj.completed:
			return false
	return true

# Event Handlers
func _on_enemy_defeated(enemy_type: String, enemy_level: int):
	"""Handle enemy defeat for kill objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "kill" and obj.target == enemy_type:
				update_objective_progress(quest_id, obj.id, 1)

func _on_item_collected(item_id: String, quantity: int):
	"""Handle item collection for collect objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "collect" and obj.target == item_id:
				update_objective_progress(quest_id, obj.id, quantity)

func _on_item_used(item_id: String):
	"""Handle item usage for use_item objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "use_item" and obj.target == item_id:
				update_objective_progress(quest_id, obj.id, 1)

func _on_item_crafted(item_id: String, quantity: int):
	"""Handle item crafting for craft objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "craft" and obj.target == item_id:
				update_objective_progress(quest_id, obj.id, quantity)

func _on_npc_talked_to(npc_id: String):
	"""Handle NPC conversation for talk objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "talk" and obj.target == npc_id:
				update_objective_progress(quest_id, obj.id, 1)

func _on_location_discovered(location_id: String):
	"""Handle location discovery for explore objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "explore" and obj.target == location_id:
				update_objective_progress(quest_id, obj.id, 1)

func _on_area_explored(area_id: String, percentage: int):
	"""Handle area exploration percentage"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "explore" and obj.target == area_id:
				quest_objectives_progress[quest_id][obj.id] = percentage
				if percentage >= obj.required_amount:
					obj.completed = true
					quest_objective_completed.emit(quest_id, obj.id)

func _on_stealth_completed(objective_type: String, target: String):
	"""Handle stealth objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == objective_type and obj.target == target:
				update_objective_progress(quest_id, obj.id, 1)

func _on_player_detected():
	"""Handle player detection for stealth failure"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for failure_condition in quest.get("failure_conditions", []):
			if failure_condition.type == "detected_during_stealth":
				handle_quest_failure(quest_id, failure_condition)

func _on_survival_time_reached(time_seconds: int):
	"""Handle survival time objectives"""
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			if obj.type == "survive":
				quest_objectives_progress[quest_id][obj.id] = time_seconds
				if time_seconds >= obj.required_amount and not obj.completed:
					obj.completed = true
					quest_objective_completed.emit(quest_id, obj.id)

func handle_quest_failure(quest_id: String, failure_condition: Dictionary):
	"""Handle quest failure conditions"""
	match failure_condition.penalty:
		"quest_failure":
			fail_quest(quest_id, failure_condition.type)
		"lose_progress":
			reset_quest_progress(quest_id)
		"faction_reputation_loss":
			# Apply reputation penalty
			for faction in GameState.player_data.get("faction_reputation", {}):
				modify_faction_reputation(faction, -50)
		"reduced_rewards":
			# Mark quest for reduced rewards
			active_quests[quest_id].reduced_rewards = true

func reset_quest_progress(quest_id: String):
	"""Reset progress for a quest"""
	if quest_objectives_progress.has(quest_id):
		for obj_id in quest_objectives_progress[quest_id]:
			quest_objectives_progress[quest_id][obj_id] = 0
		
		var quest = active_quests[quest_id]
		for obj in quest.objectives:
			obj.completed = false

func _on_quest_timer_tick():
	"""Handle timed quest updates"""
	var current_time = Time.get_ticks_msec()
	var quests_to_fail = []
	
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		
		# Check time limit
		if quest.has("time_limit") and quest.time_limit > 0:
			var elapsed = (current_time - quest.started_time) / 1000.0
			if elapsed >= quest.time_limit:
				quests_to_fail.append(quest_id)
	
	# Fail timed out quests
	for quest_id in quests_to_fail:
		fail_quest(quest_id, "time_limit_exceeded")

# Utility Functions
func get_active_quests() -> Dictionary:
	"""Get all active quests"""
	return active_quests.duplicate(true)

func get_available_quests() -> Dictionary:
	"""Get all available quests"""
	return available_quests.duplicate(true)

func get_completed_quests() -> Array[String]:
	"""Get list of completed quest IDs"""
	return completed_quests.duplicate()

func get_quest_progress(quest_id: String) -> Dictionary:
	"""Get progress for a specific quest"""
	if quest_objectives_progress.has(quest_id):
		return quest_objectives_progress[quest_id].duplicate(true)
	return {}

func is_quest_completed(quest_id: String) -> bool:
	"""Check if quest is completed"""
	return quest_id in completed_quests

func is_quest_active(quest_id: String) -> bool:
	"""Check if quest is active"""
	return active_quests.has(quest_id)

func get_quest_data(quest_id: String) -> Dictionary:
	"""Get quest data by ID"""
	return quest_data.get(quest_id, {})

# Save/Load System Integration
func save_quest_state() -> Dictionary:
	"""Save quest system state"""
	return {
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"quest_objectives_progress": quest_objectives_progress
	}

func load_quest_state(save_data: Dictionary):
	"""Load quest system state"""
	if save_data.has("active_quests"):
		active_quests = save_data.active_quests
	
	if save_data.has("completed_quests"):
		completed_quests = save_data.completed_quests
	
	if save_data.has("quest_objectives_progress"):
		quest_objectives_progress = save_data.quest_objectives_progress
	
	# Rebuild available quests
	initialize_available_quests()

# TODO: Future enhancements
# - Quest chains and storylines
# - Dynamic quest generation
# - Seasonal and event quests
# - Multi-player quest sharing
# - Quest difficulty scaling
# - Achievement integration