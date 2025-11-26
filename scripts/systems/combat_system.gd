extends Node
class_name CombatSystem
# combat_system.gd - Modular combat system for Disorder Chaos
# Handles damage calculation, status effects, and combat flow

# Combat constants
const CRITICAL_CHANCE_BASE = 0.05  # 5% base crit chance
const CRITICAL_MULTIPLIER = 2.0
const DODGE_CHANCE_BASE = 0.1     # 10% base dodge chance

# Status effect types
enum StatusType {
	BUFF,
	DEBUFF,
	DOT,    # Damage over time
	HOT     # Heal over time
}

# Damage types
enum DamageType {
	PHYSICAL,
	MAGICAL,
	TRUE    # Ignores armor/resistances
}

func _ready():
	print("[CombatSystem] Combat system initialized")

# Main combat calculation function
func calculate_damage(attacker: Node, target: Node, skill_id: String) -> Dictionary:
	"""
	Calculate damage from attacker to target using specified skill
	Returns: {amount: int, is_critical: bool, damage_type: DamageType, blocked: bool}
	"""
	var skill_data = DataLoader.get_spell(skill_id)
	if not skill_data:
		push_error("Invalid skill ID: " + skill_id)
		return {"amount": 0, "is_critical": false, "damage_type": DamageType.PHYSICAL, "blocked": false}
	
	# Get base damage from skill
	var base_damage = skill_data.power
	
	# Get attacker's attributes
	var attacker_stats = get_entity_stats(attacker)
	var target_stats = get_entity_stats(target)
	
	# Calculate damage based on skill type
	var final_damage = 0
	var damage_type = DamageType.PHYSICAL
	
	match skill_data.type:
		"physical":
			damage_type = DamageType.PHYSICAL
			final_damage = calculate_physical_damage(base_damage, attacker_stats, target_stats)
		"magical":
			damage_type = DamageType.MAGICAL
			final_damage = calculate_magical_damage(base_damage, attacker_stats, target_stats)
		"true":
			damage_type = DamageType.TRUE
			final_damage = base_damage
	
	# Check for critical hit
	var is_critical = check_critical_hit(attacker_stats)
	if is_critical:
		final_damage = int(final_damage * CRITICAL_MULTIPLIER)
	
	# Check for dodge
	var blocked = check_dodge(target_stats)
	if blocked:
		final_damage = 0
	
	return {
		"amount": final_damage,
		"is_critical": is_critical,
		"damage_type": damage_type,
		"blocked": blocked
	}

func calculate_physical_damage(base_damage: int, attacker_stats: Dictionary, target_stats: Dictionary) -> int:
	"""Calculate physical damage with strength and armor"""
	var strength_bonus = attacker_stats.get("strength", 10) - 10
	var armor_reduction = target_stats.get("armor", 0)
	
	var damage = base_damage + strength_bonus
	damage = max(1, damage - armor_reduction)  # Minimum 1 damage
	
	return damage

func calculate_magical_damage(base_damage: int, attacker_stats: Dictionary, target_stats: Dictionary) -> int:
	"""Calculate magical damage with intelligence and magic resistance"""
	var intelligence_bonus = attacker_stats.get("intelligence", 10) - 10
	var magic_resistance = target_stats.get("magic_resistance", 0)
	
	var damage = base_damage + intelligence_bonus
	damage = max(1, damage - magic_resistance)  # Minimum 1 damage
	
	return damage

func check_critical_hit(attacker_stats: Dictionary) -> bool:
	"""Check if attack is a critical hit"""
	var luck_bonus = (attacker_stats.get("luck", 10) - 10) * 0.01  # 1% per luck point above 10
	var crit_chance = CRITICAL_CHANCE_BASE + luck_bonus
	
	return randf() < crit_chance

func check_dodge(target_stats: Dictionary) -> bool:
	"""Check if attack is dodged"""
	var agility_bonus = (target_stats.get("agility", 10) - 10) * 0.005  # 0.5% per agility point above 10
	var dodge_chance = DODGE_CHANCE_BASE + agility_bonus
	
	return randf() < dodge_chance

func get_entity_stats(entity: Node) -> Dictionary:
	"""Extract stats from an entity (player or enemy)"""
	var stats = {}
	
	if entity.has_method("get_stats"):
		stats = entity.get_stats()
	elif entity.has_method("get_attributes"):
		stats = entity.get_attributes()
	else:
		# Fallback for basic entities
		if "strength" in entity:
			stats["strength"] = entity.strength
		if "agility" in entity:
			stats["agility"] = entity.agility
		if "intelligence" in entity:
			stats["intelligence"] = entity.intelligence
		if "luck" in entity:
			stats["luck"] = entity.luck
	
	return stats

# Apply damage to target
func apply_damage(target: Node, damage_info: Dictionary):
	"""Apply calculated damage to target entity"""
	if not target or not target.has_method("take_damage"):
		push_error("Target cannot take damage")
		return
	
	# Apply the damage
	target.take_damage(damage_info.amount)
	
	# Emit combat events
	EventBus.damage_dealt.emit(
		get_entity_name(target.get_parent() if target.has_method("get_parent") else null),
		get_entity_name(target),
		damage_info.amount,
		damage_info.damage_type
	)
	
	# Show visual effects
	if damage_info.is_critical:
		EventBus.damage_number_requested.emit(target.global_position, damage_info.amount, "critical")
	elif damage_info.blocked:
		EventBus.damage_number_requested.emit(target.global_position, 0, "blocked")
	else:
		EventBus.damage_number_requested.emit(target.global_position, damage_info.amount, "normal")

func apply_heal(target: Node, heal_amount: int):
	"""Apply healing to target entity"""
	if not target or not target.has_method("heal"):
		push_error("Target cannot be healed")
		return
	
	var actual_heal = target.heal(heal_amount)
	
	# Emit heal event
	EventBus.heal_applied.emit(target, actual_heal)
	EventBus.damage_number_requested.emit(target.global_position, actual_heal, "heal")

# Status effect system
func apply_status_effect(target: Node, effect_id: String, duration: float, source: Node = null):
	"""Apply a status effect to target"""
	if not target.has_method("add_status_effect"):
		push_warning("Target does not support status effects")
		return
	
	var effect_data = create_status_effect(effect_id, duration, source)
	target.add_status_effect(effect_data)
	
	EventBus.status_effect_applied.emit(target, effect_id, duration)

func remove_status_effect(target: Node, effect_id: String):
	"""Remove a status effect from target"""
	if not target.has_method("remove_status_effect"):
		return
	
	target.remove_status_effect(effect_id)
	EventBus.status_effect_removed.emit(target, effect_id)

func create_status_effect(effect_id: String, duration: float, source: Node = null) -> Dictionary:
	"""Create a status effect data structure"""
	return {
		"id": effect_id,
		"duration": duration,
		"remaining_time": duration,
		"source": source,
		"stacks": 1
	}

# Skill usage validation
func can_use_skill(caster: Node, skill_id: String) -> bool:
	"""Check if entity can use a skill"""
	var skill_data = DataLoader.get_spell(skill_id)
	if not skill_data:
		return false
	
	# Check mana/energy cost
	if skill_data.has("cost") and skill_data.cost > 0:
		if caster.has_method("get_current_mp"):
			if caster.get_current_mp() < skill_data.cost:
				return false
	
	# Check cooldown
	if caster.has_method("is_skill_on_cooldown"):
		if caster.is_skill_on_cooldown(skill_id):
			return false
	
	# Check requirements
	if skill_data.has("requirements"):
		if not check_skill_requirements(caster, skill_data.requirements):
			return false
	
	return true

func check_skill_requirements(caster: Node, requirements: Dictionary) -> bool:
	"""Check if caster meets skill requirements"""
	for requirement in requirements:
		match requirement:
			"behind_target":
				# TODO: Implement position-based requirements
				pass
			_:
				# Check attribute requirements
				if caster.has_method("get_attribute"):
					if caster.get_attribute(requirement) < requirements[requirement]:
						return false
	
	return true

func use_skill(caster: Node, skill_id: String, target: Node = null):
	"""Execute a skill usage"""
	if not can_use_skill(caster, skill_id):
		return false
	
	var skill_data = DataLoader.get_spell(skill_id)
	
	# Consume mana/energy
	if skill_data.has("cost") and skill_data.cost > 0:
		if caster.has_method("consume_mp"):
			caster.consume_mp(skill_data.cost)
	
	# Start cooldown
	if caster.has_method("start_skill_cooldown"):
		caster.start_skill_cooldown(skill_id, skill_data.get("cooldown", 1.0))
	
	# Apply skill effects
	match skill_data.type:
		"physical", "magical":
			if target:
				var damage_info = calculate_damage(caster, target, skill_id)
				apply_damage(target, damage_info)
		"buff":
			apply_skill_effects(caster, skill_data)
		"heal":
			if target:
				apply_heal(target, skill_data.power)
	
	# Emit skill used event
	EventBus.skill_used.emit(caster, skill_id, target)
	return true

func apply_skill_effects(target: Node, skill_data: Dictionary):
	"""Apply non-damage skill effects"""
	if not skill_data.has("effects"):
		return
	
	for effect_id in skill_data.effects:
		var duration = skill_data.get("duration", 10.0)
		apply_status_effect(target, effect_id, duration)

# Utility functions
func get_entity_name(entity: Node) -> String:
	"""Get display name of entity"""
	if not entity:
		return "Unknown"
	
	if entity.has_method("get_display_name"):
		return entity.get_display_name()
	elif "entity_name" in entity:
		return entity.entity_name
	else:
		return entity.name

# Area of Effect damage
func apply_aoe_damage(center_position: Vector2, radius: float, damage: int, source: Node, exclude_source: bool = true):
	"""Apply damage to all entities in an area"""
	var space_state = source.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	query.shape = circle_shape
	query.transform.origin = center_position
	query.collision_mask = 0b1111  # Check all relevant layers
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var target = result.collider
		if exclude_source and target == source:
			continue
		
		if target.has_method("take_damage"):
			apply_damage(target, {"amount": damage, "is_critical": false, "damage_type": DamageType.TRUE, "blocked": false})

# TODO: Future enhancements
# - Elemental damage types and resistances
# - Complex status effect interactions
# - Combo system for chained attacks
# - Environmental hazards integration
# - Damage reflection mechanics
# - Group combat coordination
# - Dynamic difficulty scaling
# - Combat statistics tracking