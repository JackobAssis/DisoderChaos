extends Node

class_name PlayerProgression

signal level_up(new_level: int, stat_points: int)
signal skill_unlocked(skill_id: String)
signal attribute_increased(attribute: String, new_value: int)
signal talent_unlocked(talent_id: String)
signal milestone_reached(milestone_id: String)

# Progression configuration
var max_level: int = 100
var base_xp_per_level: int = 100
var xp_multiplier: float = 1.15

# Skill trees
var available_skill_trees: Dictionary = {}
var unlocked_skills: Dictionary = {}
var skill_points: int = 0

# Talents
var available_talents: Dictionary = {}
var unlocked_talents: Dictionary = {}
var talent_points: int = 0

# Milestones
var progression_milestones: Dictionary = {}
var achieved_milestones: Array = []

# Attributes
var base_attributes: Dictionary = {
	"strength": 10,
	"agility": 10, 
	"intelligence": 10,
	"vitality": 10,
	"wisdom": 10,
	"charisma": 10
}

var current_attributes: Dictionary = {}
var attribute_points: int = 0

# Experience sources
var xp_sources: Dictionary = {
	"combat": 1.0,
	"quest": 1.2,
	"discovery": 0.8,
	"crafting": 0.5,
	"social": 0.6
}

# References
@onready var data_loader: DataLoader = get_node("/root/DataLoader")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var game_state: GameState = get_node("/root/GameState")
@onready var player_stats: PlayerStats = get_node("/root/GameState").player_stats

func _ready():
	await setup_progression_system()
	connect_events()
	print("[PlayerProgression] Sistema de Progressão inicializado")

func setup_progression_system():
	"""Initialize progression system"""
	# Wait for data to be loaded
	if not data_loader.is_fully_loaded():
		await data_loader.all_data_loaded
	
	current_attributes = base_attributes.duplicate()
	load_skill_trees()
	load_talents()
	setup_milestones()

func connect_events():
	"""Connect to relevant events"""
	event_bus.connect("enemy_defeated", _on_enemy_defeated)
	event_bus.connect("quest_completed", _on_quest_completed)
	event_bus.connect("location_discovered", _on_location_discovered)
	event_bus.connect("item_crafted", _on_item_crafted)
	event_bus.connect("dialogue_completed", _on_dialogue_completed)
	event_bus.connect("player_level_changed", _on_player_level_changed)

func load_skill_trees():
	"""Load skill trees from data"""
	var skills_data = data_loader.get_data("skills")
	if skills_data:
		available_skill_trees = skills_data
		print("[PlayerProgression] Carregadas %d árvores de habilidades" % available_skill_trees.size())

func load_talents():
	"""Load talents from data"""
	var talents_data = data_loader.get_data("talents")
	if talents_data:
		available_talents = talents_data
		print("[PlayerProgression] Carregados %d talentos" % available_talents.size())

func setup_milestones():
	"""Setup progression milestones"""
	progression_milestones = {
		"first_level": {
			"title": "First Steps",
			"description": "Reach level 2",
			"condition": {"type": "level", "value": 2},
			"rewards": {"attribute_points": 2}
		},
		"apprentice": {
			"title": "Apprentice Adventurer", 
			"description": "Reach level 10",
			"condition": {"type": "level", "value": 10},
			"rewards": {"skill_points": 1, "talent_points": 1}
		},
		"skilled_warrior": {
			"title": "Skilled Warrior",
			"description": "Reach level 25",
			"condition": {"type": "level", "value": 25},
			"rewards": {"attribute_points": 5, "skill_points": 2}
		},
		"expert_adventurer": {
			"title": "Expert Adventurer",
			"description": "Reach level 50",
			"condition": {"type": "level", "value": 50},
			"rewards": {"talent_points": 3, "skill_points": 3}
		},
		"master": {
			"title": "Master",
			"description": "Reach level 75",
			"condition": {"type": "level", "value": 75},
			"rewards": {"attribute_points": 10, "talent_points": 2}
		},
		"legendary_hero": {
			"title": "Legendary Hero",
			"description": "Reach max level",
			"condition": {"type": "level", "value": 100},
			"rewards": {"attribute_points": 20, "talent_points": 5}
		},
		"first_skill": {
			"title": "Learning",
			"description": "Unlock your first skill",
			"condition": {"type": "skill_count", "value": 1},
			"rewards": {"skill_points": 1}
		},
		"skill_master": {
			"title": "Skill Master",
			"description": "Unlock 10 skills",
			"condition": {"type": "skill_count", "value": 10},
			"rewards": {"skill_points": 3, "talent_points": 1}
		},
		"quest_starter": {
			"title": "Quest Starter",
			"description": "Complete your first quest",
			"condition": {"type": "quest_count", "value": 1},
			"rewards": {"attribute_points": 1}
		},
		"quest_hero": {
			"title": "Quest Hero",
			"description": "Complete 25 quests",
			"condition": {"type": "quest_count", "value": 25},
			"rewards": {"skill_points": 2, "talent_points": 1}
		}
	}

# Experience Management
func award_experience(amount: int, source: String = "combat", multiplier: float = 1.0):
	"""Award experience points to player"""
	var source_multiplier = xp_sources.get(source, 1.0)
	var final_amount = int(amount * source_multiplier * multiplier)
	
	var current_level = player_stats.current_level
	var current_xp = player_stats.experience
	var new_xp = current_xp + final_amount
	
	# Update experience
	player_stats.experience = new_xp
	
	# Check for level up
	check_level_up(current_level, new_xp)
	
	# Emit experience gain event
	event_bus.emit_signal("experience_gained", final_amount, source)
	
	print("[PlayerProgression] +%d XP (%s)" % [final_amount, source])

func check_level_up(current_level: int, total_xp: int):
	"""Check if player leveled up"""
	var required_xp = get_required_xp_for_level(current_level + 1)
	
	while total_xp >= required_xp and current_level < max_level:
		current_level += 1
		required_xp = get_required_xp_for_level(current_level + 1)
		handle_level_up(current_level)

func handle_level_up(new_level: int):
	"""Handle player level up"""
	player_stats.current_level = new_level
	
	# Award points based on level
	var points_awarded = calculate_level_rewards(new_level)
	attribute_points += points_awarded.attribute_points
	skill_points += points_awarded.skill_points
	talent_points += points_awarded.talent_points
	
	# Update stats
	player_stats.level_up_stats(new_level)
	
	# Check milestones
	check_milestones()
	
	# Emit signals
	level_up.emit(new_level, points_awarded.attribute_points)
	event_bus.emit_signal("player_level_changed", new_level)
	
	print("[PlayerProgression] Level Up! Nível %d alcançado" % new_level)

func calculate_level_rewards(level: int) -> Dictionary:
	"""Calculate rewards for leveling up"""
	var rewards = {
		"attribute_points": 1,
		"skill_points": 0,
		"talent_points": 0
	}
	
	# Every 5 levels: skill point
	if level % 5 == 0:
		rewards.skill_points = 1
	
	# Every 10 levels: talent point  
	if level % 10 == 0:
		rewards.talent_points = 1
	
	# Every 25 levels: bonus attribute points
	if level % 25 == 0:
		rewards.attribute_points = 3
	
	return rewards

func get_required_xp_for_level(level: int) -> int:
	"""Calculate XP required for specific level"""
	if level <= 1:
		return 0
	
	var total_xp = 0
	for i in range(2, level + 1):
		var level_xp = int(base_xp_per_level * pow(xp_multiplier, i - 2))
		total_xp += level_xp
	
	return total_xp

func get_xp_for_next_level() -> int:
	"""Get XP needed for next level"""
	var current_level = player_stats.current_level
	var current_xp = player_stats.experience
	var next_level_xp = get_required_xp_for_level(current_level + 1)
	
	return max(0, next_level_xp - current_xp)

func get_level_progress() -> float:
	"""Get progress to next level (0.0 - 1.0)"""
	var current_level = player_stats.current_level
	var current_xp = player_stats.experience
	
	if current_level >= max_level:
		return 1.0
	
	var current_level_xp = get_required_xp_for_level(current_level)
	var next_level_xp = get_required_xp_for_level(current_level + 1)
	var level_xp_range = next_level_xp - current_level_xp
	
	if level_xp_range <= 0:
		return 1.0
	
	var progress_xp = current_xp - current_level_xp
	return clampf(float(progress_xp) / float(level_xp_range), 0.0, 1.0)

# Attribute Management
func increase_attribute(attribute: String, points: int) -> bool:
	"""Increase player attribute"""
	if attribute_points < points:
		print("[PlayerProgression] Pontos de atributo insuficientes")
		return false
	
	if not current_attributes.has(attribute):
		print("[PlayerProgression] Atributo inválido: %s" % attribute)
		return false
	
	# Increase attribute
	current_attributes[attribute] += points
	attribute_points -= points
	
	# Update player stats
	player_stats.update_attribute(attribute, current_attributes[attribute])
	
	# Emit signal
	attribute_increased.emit(attribute, current_attributes[attribute])
	
	print("[PlayerProgression] %s aumentado para %d" % [attribute, current_attributes[attribute]])
	return true

func get_attribute_cost(attribute: String, current_value: int) -> int:
	"""Get cost to increase attribute"""
	# Cost increases with current value
	var base_cost = 1
	var scaling_cost = max(0, (current_value - 20) / 5)
	return base_cost + scaling_cost

# Skill Management
func unlock_skill(skill_id: String) -> bool:
	"""Unlock a skill"""
	if skill_points <= 0:
		print("[PlayerProgression] Pontos de habilidade insuficientes")
		return false
	
	if unlocked_skills.has(skill_id):
		print("[PlayerProgression] Habilidade já desbloqueada: %s" % skill_id)
		return false
	
	var skill_data = get_skill_data(skill_id)
	if not skill_data:
		print("[PlayerProgression] Habilidade não encontrada: %s" % skill_id)
		return false
	
	# Check prerequisites
	if not check_skill_prerequisites(skill_id):
		print("[PlayerProgression] Pré-requisitos não atendidos para: %s" % skill_id)
		return false
	
	# Unlock skill
	unlocked_skills[skill_id] = {
		"unlocked_at": Time.get_time_dict_from_system(),
		"level": 1
	}
	
	skill_points -= 1
	
	# Apply skill effects
	apply_skill_effects(skill_id)
	
	# Check milestones
	check_milestones()
	
	# Emit signal
	skill_unlocked.emit(skill_id)
	
	print("[PlayerProgression] Habilidade desbloqueada: %s" % skill_id)
	return true

func get_skill_data(skill_id: String) -> Dictionary:
	"""Get skill data"""
	for tree_id in available_skill_trees.keys():
		var tree = available_skill_trees[tree_id]
		if tree.has("skills") and tree.skills.has(skill_id):
			return tree.skills[skill_id]
	return {}

func check_skill_prerequisites(skill_id: String) -> bool:
	"""Check if skill prerequisites are met"""
	var skill_data = get_skill_data(skill_id)
	if not skill_data.has("prerequisites"):
		return true
	
	var prerequisites = skill_data.prerequisites
	
	# Check level requirement
	if prerequisites.has("level"):
		if player_stats.current_level < prerequisites.level:
			return false
	
	# Check required skills
	if prerequisites.has("skills"):
		for required_skill in prerequisites.skills:
			if not unlocked_skills.has(required_skill):
				return false
	
	# Check attribute requirements
	if prerequisites.has("attributes"):
		for attribute in prerequisites.attributes:
			var required_value = prerequisites.attributes[attribute]
			if current_attributes[attribute] < required_value:
				return false
	
	return true

func apply_skill_effects(skill_id: String):
	"""Apply skill effects to player"""
	var skill_data = get_skill_data(skill_id)
	if not skill_data.has("effects"):
		return
	
	var effects = skill_data.effects
	
	# Apply stat bonuses
	if effects.has("stat_bonuses"):
		for stat in effects.stat_bonuses:
			var bonus = effects.stat_bonuses[stat]
			player_stats.add_permanent_bonus(stat, bonus)
	
	# Apply special abilities
	if effects.has("abilities"):
		for ability_id in effects.abilities:
			player_stats.add_ability(ability_id)

# Talent Management  
func unlock_talent(talent_id: String) -> bool:
	"""Unlock a talent"""
	if talent_points <= 0:
		print("[PlayerProgression] Pontos de talento insuficientes")
		return false
	
	if unlocked_talents.has(talent_id):
		print("[PlayerProgression] Talento já desbloqueado: %s" % talent_id)
		return false
	
	var talent_data = available_talents.get(talent_id, {})
	if talent_data.is_empty():
		print("[PlayerProgression] Talento não encontrado: %s" % talent_id)
		return false
	
	# Check prerequisites
	if not check_talent_prerequisites(talent_id):
		print("[PlayerProgression] Pré-requisitos não atendidos para talento: %s" % talent_id)
		return false
	
	# Unlock talent
	unlocked_talents[talent_id] = {
		"unlocked_at": Time.get_time_dict_from_system()
	}
	
	talent_points -= 1
	
	# Apply talent effects
	apply_talent_effects(talent_id)
	
	# Emit signal
	talent_unlocked.emit(talent_id)
	
	print("[PlayerProgression] Talento desbloqueado: %s" % talent_id)
	return true

func check_talent_prerequisites(talent_id: String) -> bool:
	"""Check if talent prerequisites are met"""
	var talent_data = available_talents[talent_id]
	if not talent_data.has("requirements"):
		return true
	
	var requirements = talent_data.requirements
	
	# Check level requirement
	if requirements.has("level"):
		if player_stats.current_level < requirements.level:
			return false
	
	# Check skill requirements
	if requirements.has("skills"):
		for skill_id in requirements.skills:
			if not unlocked_skills.has(skill_id):
				return false
	
	return true

func apply_talent_effects(talent_id: String):
	"""Apply talent effects to player"""
	var talent_data = available_talents[talent_id]
	if not talent_data.has("effects"):
		return
	
	var effects = talent_data.effects
	
	# Apply global bonuses
	if effects.has("bonuses"):
		for bonus_type in effects.bonuses:
			var bonus_value = effects.bonuses[bonus_type]
			player_stats.add_talent_bonus(bonus_type, bonus_value)

# Milestone Management
func check_milestones():
	"""Check and award milestones"""
	for milestone_id in progression_milestones.keys():
		if milestone_id in achieved_milestones:
			continue
		
		var milestone = progression_milestones[milestone_id]
		if check_milestone_condition(milestone.condition):
			award_milestone(milestone_id, milestone)

func check_milestone_condition(condition: Dictionary) -> bool:
	"""Check if milestone condition is met"""
	match condition.type:
		"level":
			return player_stats.current_level >= condition.value
		"skill_count":
			return unlocked_skills.size() >= condition.value
		"quest_count":
			var completed_quests = game_state.get_completed_quest_count()
			return completed_quests >= condition.value
		_:
			return false

func award_milestone(milestone_id: String, milestone_data: Dictionary):
	"""Award milestone rewards"""
	achieved_milestones.append(milestone_id)
	
	var rewards = milestone_data.get("rewards", {})
	
	# Award points
	if rewards.has("attribute_points"):
		attribute_points += rewards.attribute_points
	
	if rewards.has("skill_points"):
		skill_points += rewards.skill_points
		
	if rewards.has("talent_points"):
		talent_points += rewards.talent_points
	
	# Emit signal
	milestone_reached.emit(milestone_id)
	
	print("[PlayerProgression] Marco alcançado: %s" % milestone_data.get("title", milestone_id))

# Event Handlers
func _on_enemy_defeated(enemy_id: String, position: Vector2, player_level: int):
	"""Handle enemy defeat for XP"""
	var enemy_data = data_loader.get_enemy(enemy_id)
	if enemy_data:
		var base_xp = enemy_data.get("xp_reward", 10)
		award_experience(base_xp, "combat")

func _on_quest_completed(quest_id: String):
	"""Handle quest completion for XP"""
	var quest_data = data_loader.get_quest(quest_id)
	if quest_data:
		var quest_xp = quest_data.get("xp_reward", 50)
		award_experience(quest_xp, "quest")

func _on_location_discovered(location_id: String):
	"""Handle location discovery for XP"""
	award_experience(25, "discovery")

func _on_item_crafted(item_id: String, quantity: int):
	"""Handle item crafting for XP"""
	var item_data = data_loader.get_item(item_id)
	if item_data:
		var craft_xp = item_data.get("craft_xp", 5) * quantity
		award_experience(craft_xp, "crafting")

func _on_dialogue_completed(npc_id: String, dialogue_id: String):
	"""Handle dialogue completion for XP"""
	award_experience(15, "social")

func _on_player_level_changed(new_level: int):
	"""Handle player level change"""
	check_milestones()

# Utility Functions
func get_available_skills_for_tree(tree_id: String) -> Array:
	"""Get available skills in a tree"""
	var available = []
	
	if not available_skill_trees.has(tree_id):
		return available
	
	var tree = available_skill_trees[tree_id]
	if not tree.has("skills"):
		return available
	
	for skill_id in tree.skills.keys():
		if not unlocked_skills.has(skill_id) and check_skill_prerequisites(skill_id):
			available.append(skill_id)
	
	return available

func get_skill_tree_progress(tree_id: String) -> Dictionary:
	"""Get progress for skill tree"""
	if not available_skill_trees.has(tree_id):
		return {}
	
	var tree = available_skill_trees[tree_id]
	var total_skills = tree.get("skills", {}).size()
	var unlocked_count = 0
	
	for skill_id in tree.skills.keys():
		if unlocked_skills.has(skill_id):
			unlocked_count += 1
	
	return {
		"total": total_skills,
		"unlocked": unlocked_count,
		"progress": float(unlocked_count) / float(total_skills) if total_skills > 0 else 0.0
	}

func get_progression_summary() -> Dictionary:
	"""Get complete progression summary"""
	return {
		"level": player_stats.current_level,
		"experience": player_stats.experience,
		"experience_to_next": get_xp_for_next_level(),
		"level_progress": get_level_progress(),
		"attribute_points": attribute_points,
		"skill_points": skill_points,
		"talent_points": talent_points,
		"unlocked_skills": unlocked_skills.size(),
		"unlocked_talents": unlocked_talents.size(),
		"achieved_milestones": achieved_milestones.size(),
		"attributes": current_attributes.duplicate()
	}

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"current_attributes": current_attributes,
		"attribute_points": attribute_points,
		"skill_points": skill_points,
		"talent_points": talent_points,
		"unlocked_skills": unlocked_skills,
		"unlocked_talents": unlocked_talents,
		"achieved_milestones": achieved_milestones
	}

func load_save_data(data: Dictionary):
	"""Load progression save data"""
	current_attributes = data.get("current_attributes", base_attributes.duplicate())
	attribute_points = data.get("attribute_points", 0)
	skill_points = data.get("skill_points", 0)
	talent_points = data.get("talent_points", 0)
	unlocked_skills = data.get("unlocked_skills", {})
	unlocked_talents = data.get("unlocked_talents", {})
	achieved_milestones = data.get("achieved_milestones", [])
	
	# Reapply unlocked skill effects
	for skill_id in unlocked_skills.keys():
		apply_skill_effects(skill_id)
	
	# Reapply talent effects
	for talent_id in unlocked_talents.keys():
		apply_talent_effects(talent_id)
	
	print("[PlayerProgression] Dados de progressão carregados")

# Debug Functions
func debug_add_xp(amount: int):
	"""Debug: Add XP to player"""
	award_experience(amount, "debug")

func debug_add_points(attr: int = 0, skill: int = 0, talent: int = 0):
	"""Debug: Add progression points"""
	attribute_points += attr
	skill_points += skill
	talent_points += talent

func debug_unlock_skill(skill_id: String):
	"""Debug: Force unlock skill"""
	var old_points = skill_points
	skill_points = max(1, skill_points)
	unlock_skill(skill_id)
	if old_points == 0:
		skill_points = 0

func debug_set_level(level: int):
	"""Debug: Set player level"""
	if level >= 1 and level <= max_level:
		player_stats.current_level = level
		player_stats.experience = get_required_xp_for_level(level)
		player_stats.level_up_stats(level)
		event_bus.emit_signal("player_level_changed", level)