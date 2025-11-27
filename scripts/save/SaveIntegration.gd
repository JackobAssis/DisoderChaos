extends Node
class_name SaveIntegration
# SaveIntegration.gd - Integrates SaveManager with game systems
# Handles auto-save triggers, system coordination, and save validation

# References to game systems
var save_manager: SaveManager
var game_state: Node

# Auto-save configuration
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var auto_save_timer: Timer
var auto_save_on_events: bool = true

# Save triggers
var save_on_level_up: bool = true
var save_on_dungeon_change: bool = true
var save_on_quest_complete: bool = true
var save_on_significant_progress: bool = true

# Performance monitoring
var last_save_time: float = 0.0
var save_frequency_limit: float = 30.0  # Minimum 30 seconds between manual saves

func _ready():
	print("[SaveIntegration] Initializing save system integration")
	
	# Get references
	game_state = get_node("/root/GameState")
	
	# Setup auto-save timer
	setup_auto_save_timer()
	
	# Connect to EventBus signals
	connect_event_signals()
	
	print("[SaveIntegration] Save integration ready")

func setup_auto_save_timer():
	"""Setup the auto-save timer"""
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.autostart = auto_save_enabled
	auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	add_child(auto_save_timer)
	
	print("[SaveIntegration] Auto-save timer configured: ", auto_save_interval, "s interval")

func connect_event_signals():
	"""Connect to relevant EventBus signals for auto-save triggers"""
	if auto_save_on_events:
		# Player progression events
		if save_on_level_up:
			EventBus.player_level_up.connect(_on_player_level_up)
		
		# World progression events  
		if save_on_dungeon_change:
			EventBus.dungeon_changed.connect(_on_dungeon_changed)
			EventBus.dungeon_completed.connect(_on_dungeon_completed)
		
		# Quest events (when implemented)
		if save_on_quest_complete:
			# EventBus.quest_completed.connect(_on_quest_completed)
			pass
		
		# Other significant events
		if save_on_significant_progress:
			EventBus.enemy_defeated.connect(_on_enemy_defeated)
			EventBus.chest_opened.connect(_on_chest_opened)
			EventBus.item_equipped.connect(_on_item_equipped)
	
	print("[SaveIntegration] Connected to EventBus signals for auto-save triggers")

# Auto-save trigger handlers
func _on_auto_save_timer_timeout():
	"""Handle periodic auto-save"""
	if auto_save_enabled and game_state:
		print("[SaveIntegration] Triggering periodic auto-save")
		EventBus.auto_save_triggered.emit()
		await game_state.auto_save()

func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
	"""Handle auto-save on level up"""
	print("[SaveIntegration] Level up detected, triggering auto-save")
	EventBus.auto_save_triggered.emit()
	await game_state.auto_save()

func _on_dungeon_changed(dungeon_id: String):
	"""Handle auto-save on dungeon change"""
	print("[SaveIntegration] Dungeon change detected: ", dungeon_id, ", triggering auto-save")
	EventBus.auto_save_triggered.emit()
	await game_state.auto_save()

func _on_dungeon_completed(dungeon_id: String):
	"""Handle auto-save on dungeon completion"""
	print("[SaveIntegration] Dungeon completed: ", dungeon_id, ", triggering auto-save")
	EventBus.auto_save_triggered.emit()
	await game_state.auto_save()

func _on_quest_completed(quest_id: String):
	"""Handle auto-save on quest completion"""
	print("[SaveIntegration] Quest completed: ", quest_id, ", triggering auto-save")
	EventBus.auto_save_triggered.emit()
	await game_state.auto_save()

func _on_enemy_defeated(enemy_id: String, loot: Array):
	"""Handle auto-save on significant enemy defeat"""
	# Only auto-save for boss enemies or important encounters
	var enemy_data = DataLoader.get_enemy(enemy_id)
	if enemy_data and ("boss" in enemy_data.get("tags", []) or enemy_data.get("level", 0) > 10):
		print("[SaveIntegration] Important enemy defeated: ", enemy_id, ", triggering auto-save")
		EventBus.auto_save_triggered.emit()
		await game_state.auto_save()

func _on_chest_opened(chest_id: String, contents: Array):
	"""Handle auto-save on significant chest opening"""
	# Only auto-save for treasure chests with valuable items
	var has_valuable_item = false
	for item in contents:
		var item_data = DataLoader.get_item(item.get("id", ""))
		if item_data and item_data.get("rarity", "common") in ["rare", "epic", "legendary"]:
			has_valuable_item = true
			break
	
	if has_valuable_item:
		print("[SaveIntegration] Valuable chest opened: ", chest_id, ", triggering auto-save")
		EventBus.auto_save_triggered.emit()
		await game_state.auto_save()

func _on_item_equipped(item_id: String, slot: String):
	"""Handle auto-save on equipment change"""
	# Only auto-save for weapon/armor changes, not accessories
	if slot in ["weapon", "armor"]:
		print("[SaveIntegration] Equipment changed: ", item_id, " in ", slot, ", triggering auto-save")
		EventBus.auto_save_triggered.emit()
		await game_state.auto_save()

# Manual save coordination
func request_manual_save(slot: int = 0, force: bool = false) -> bool:
	"""Request a manual save with frequency limiting"""
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Check save frequency limit
	if not force and (current_timestamp - last_save_time) < save_frequency_limit:
		var time_remaining = save_frequency_limit - (current_timestamp - last_save_time)
		print("[SaveIntegration] Save frequency limit active. Wait ", time_remaining, " seconds.")
		EventBus.show_notification("Please wait before saving again", "warning")
		return false
	
	print("[SaveIntegration] Manual save requested for slot ", slot)
	last_save_time = current_timestamp
	
	var result = await game_state.save_game(slot, true)
	return result

func request_quick_save() -> bool:
	"""Request a quick save"""
	print("[SaveIntegration] Quick save requested")
	var result = await game_state.quick_save()
	if result:
		EventBus.show_notification("Quick save completed", "success")
	else:
		EventBus.show_notification("Quick save failed", "error")
	return result

# Configuration methods
func set_auto_save_enabled(enabled: bool):
	"""Enable or disable auto-save"""
	auto_save_enabled = enabled
	if auto_save_timer:
		if enabled:
			auto_save_timer.start()
		else:
			auto_save_timer.stop()
	
	print("[SaveIntegration] Auto-save ", "enabled" if enabled else "disabled")

func set_auto_save_interval(interval: float):
	"""Set auto-save interval in seconds"""
	auto_save_interval = max(60.0, interval)  # Minimum 1 minute
	if auto_save_timer:
		auto_save_timer.wait_time = auto_save_interval
	
	print("[SaveIntegration] Auto-save interval set to ", auto_save_interval, " seconds")

func configure_auto_save_triggers(level_up: bool, dungeon_change: bool, quest_complete: bool, significant_progress: bool):
	"""Configure which events trigger auto-save"""
	save_on_level_up = level_up
	save_on_dungeon_change = dungeon_change
	save_on_quest_complete = quest_complete
	save_on_significant_progress = significant_progress
	
	print("[SaveIntegration] Auto-save triggers configured")

# Save system status
func get_save_system_status() -> Dictionary:
	"""Get current status of the save system"""
	return {
		"auto_save_enabled": auto_save_enabled,
		"auto_save_interval": auto_save_interval,
		"last_save_time": last_save_time,
		"save_triggers": {
			"level_up": save_on_level_up,
			"dungeon_change": save_on_dungeon_change,
			"quest_complete": save_on_quest_complete,
			"significant_progress": save_on_significant_progress
		},
		"timer_active": auto_save_timer.time_left if auto_save_timer else 0.0
	}

# Backup and recovery
func create_emergency_backup() -> bool:
	"""Create an emergency backup of current game state"""
	if game_state:
		print("[SaveIntegration] Creating emergency backup")
		return await game_state.save_game(997, true)  # Use slot 997 for emergency backups
	return false

func validate_save_integrity(slot: int) -> Dictionary:
	"""Validate the integrity of a save file"""
	if not save_manager:
		save_manager = game_state.save_manager if game_state else null
	
	if save_manager:
		return save_manager.validate_save_file(slot)
	else:
		return {"valid": false, "error": "SaveManager not available"}

# Debug utilities
func force_auto_save():
	"""Force an immediate auto-save (debug function)"""
	print("[SaveIntegration] [DEBUG] Forcing auto-save")
	if game_state:
		await game_state.auto_save()

func print_save_stats():
	"""Print save system statistics (debug function)"""
	var status = get_save_system_status()
	print("[SaveIntegration] [DEBUG] Save System Status:")
	print("  Auto-save enabled: ", status.auto_save_enabled)
	print("  Auto-save interval: ", status.auto_save_interval, "s")
	print("  Last manual save: ", status.last_save_time)
	print("  Timer remaining: ", status.timer_active, "s")
	print("  Triggers: ", status.save_triggers)

# Cleanup
func _exit_tree():
	"""Cleanup when node is removed"""
	if auto_save_timer:
		auto_save_timer.queue_free()
	print("[SaveIntegration] Save integration cleanup completed")