extends Node
# EventBus.gd - Global event system for decoupled communication
# All game events should be routed through this system

# Player events
signal player_created(player_data)
signal player_hp_changed(current_hp, max_hp)
signal player_mp_changed(current_mp, max_mp)
signal player_level_up(level, hp_gain, mp_gain)
signal player_died()
signal player_respawned()
signal player_moved(position)

# Combat events
signal combat_started(participants)
signal combat_ended(winner)
signal damage_dealt(attacker, target, amount, damage_type)
signal heal_applied(target, amount)
signal skill_used(caster, skill_id, target)
signal status_effect_applied(target, effect_id, duration)
signal status_effect_removed(target, effect_id)

# Item and inventory events
signal item_collected(item_id)
signal item_dropped(item_id, position)
signal item_used(item_id)
signal item_equipped(item_id, slot)
signal item_unequipped(item_id, slot)
signal inventory_updated(inventory)

# Dungeon and world events
signal dungeon_changed(dungeon_id)
signal dungeon_completed(dungeon_id)
signal dungeon_entered(dungeon_id)
signal dungeon_exited(dungeon_id)
signal enemy_spawned(enemy_id, position)
signal enemy_defeated(enemy_id, loot)
signal chest_opened(chest_id, contents)
signal door_unlocked(door_id)
signal lever_activated(lever_id)

# UI events
signal ui_menu_opened(menu_name)
signal ui_menu_closed(menu_name)
signal ui_button_pressed(button_name)
signal ui_dialog_shown(text, speaker)
signal ui_notification_shown(message, type)

# Game state events
signal game_loaded()
signal game_saved(slot)
signal game_paused()
signal game_resumed()
signal settings_changed(settings)
signal save_deleted(slot)
signal auto_save_triggered()
signal save_corruption_detected(slot, backup_restored)

# AI system events
signal ai_target_detected(ai_entity, target)
signal ai_combat_started(ai_entity, target)
signal ai_reinforcements_called(position, faction)
signal ai_boss_phase_changed(boss, phase)
signal ai_global_alert_triggered(level)
signal ai_faction_relations_changed(faction_a, faction_b, relation)

# Mount system events
signal mount_summoned(entity: Entity, mount: Mount)
signal mount_dismissed(entity: Entity, mount: Mount)
signal mount_stamina_changed(entity: Entity, current: float, maximum: float)
signal mount_skill_used(entity: Entity, skill_id: String)
signal mount_unlocked(entity: Entity, mount: Mount)
signal mount_dash_performed(entity: Entity, mount: Mount)
signal mount_speed_changed(entity: Entity, old_speed: float, new_speed: float)

# Pet system events
signal pet_summoned(entity: Entity, pet: Pet)
signal pet_dismissed(entity: Entity, pet: Pet)
signal pet_level_up(entity: Entity, pet: Pet, new_level: int)
signal pet_xp_gained(entity: Entity, pet: Pet, xp_amount: int)
signal pet_unlocked(entity: Entity, pet: Pet)
signal pet_ability_used(entity: Entity, pet: Pet, ability_id: String)
signal pet_died(entity: Entity, pet: Pet)

# Network events (for future multiplayer)
signal player_connected(player_id)
signal player_disconnected(player_id)
signal network_error(error_message)

# Audio events
signal sound_play_requested(sound_id, position)
signal music_changed(track_id)
signal audio_volume_changed(channel, volume)

func _ready():
	print("[EventBus] Event system initialized")

# Utility functions for common event patterns
func show_damage_number(position: Vector2, damage: int, type: String = "normal"):
	"""Request to show floating damage number"""
	damage_number_requested.emit(position, damage, type)

func show_notification(message: String, type: String = "info"):
	"""Show a notification to the player"""
	ui_notification_shown.emit(message, type)

func play_sound(sound_id: String, global_position: Vector2 = Vector2.ZERO):
	"""Request to play a sound effect"""
	sound_play_requested.emit(sound_id, global_position)

func log_combat_action(attacker_name: String, action: String, target_name: String = ""):
	"""Log a combat action for UI display"""
	if target_name.is_empty():
		combat_log_updated.emit(attacker_name + " " + action)
	else:
		combat_log_updated.emit(attacker_name + " " + action + " " + target_name)

# Extended signals for specific game systems
signal damage_number_requested(position, damage, type)
signal combat_log_updated(message)
signal quest_updated(quest_id, status)
signal achievement_unlocked(achievement_id)
signal tutorial_triggered(tutorial_id)

# Area/trigger events
signal area_entered(area_id, entity)
signal area_exited(area_id, entity)
signal trigger_activated(trigger_id, activator)

# Economy events
signal shop_opened(shop_id)
signal item_bought(item_id, price)
signal item_sold(item_id, price)
signal currency_changed(amount, type)

func _input(event):
	"""Handle global input events that need to be broadcasted"""
	if event.is_action_pressed("ui_cancel"):
		ui_escape_pressed.emit()

signal ui_escape_pressed()

# Debug events (only in debug builds)
signal debug_command_entered(command, args)
signal debug_value_changed(key, value)

func debug_log(message: String):
	"""Debug logging function"""
	if OS.is_debug_build():
		print("[DEBUG] " + message)
		debug_message_logged.emit(message)

signal debug_message_logged(message)

# TODO: Future event categories to implement
# - Weather system events
# - Day/night cycle events  
# - Dynamic quest events
# - Faction reputation events
# - PvP zone events
# - Guild/party events
# - Market/auction events
# - Environmental hazard events