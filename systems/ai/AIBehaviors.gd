extends Node
class_name AIBehaviors
# AIBehaviors.gd - Ready-to-use AI behavior implementations
# Pre-configured behaviors for different mob types and situations

# Utility class for creating specific AI behaviors
static func create_melee_fighter_ai(entity: Node2D) -> AIController:
	"""Create AI for melee fighter mobs"""
	var ai = AIController.new()
	ai.ai_type = AIController.AIType.MELEE
	ai.detection_range = 120.0
	ai.attack_range = 60.0
	ai.flee_threshold = 0.1
	ai.aggro_timeout = 15.0
	
	entity.add_child(ai)
	
	# Configure aggressive behavior
	setup_melee_behavior_tree(ai)
	setup_melee_state_machine(ai)
	
	return ai

static func setup_melee_behavior_tree(ai: AIController):
	"""Setup behavior tree for melee fighters"""
	var root = AISelector.new("melee_root")
	
	# High priority: flee if critically wounded
	var critical_flee = AISequence.new("critical_flee")
	critical_flee.add_child(AICondition.new("critical_health", 
		func(): return ai.health_component.current_health < ai.health_component.max_health * 0.05))
	critical_flee.add_child(AIAction.new("emergency_flee", 
		func(): return ai.flee_from_target()))
	
	# Combat behavior
	var combat = AISelector.new("combat")
	
	# Attack if in range
	var attack_sequence = AISequence.new("attack")
	attack_sequence.add_child(AICondition.new("has_target", 
		func(): return ai.current_target != null))
	attack_sequence.add_child(AICondition.new("in_melee_range", 
		func(): return ai.current_target != null and ai.entity.global_position.distance_to(ai.current_target.global_position) <= ai.attack_range))
	attack_sequence.add_child(AIAction.new("melee_attack", 
		func(): return execute_melee_attack(ai)))
	
	# Chase target
	var chase_sequence = AISequence.new("chase")
	chase_sequence.add_child(AICondition.new("has_target", 
		func(): return ai.current_target != null))
	chase_sequence.add_child(AIAction.new("charge_target", 
		func(delta): return charge_at_target(ai, delta), true))
	
	combat.add_child(attack_sequence)
	combat.add_child(chase_sequence)
	
	# Idle behavior
	var patrol = AIAction.new("patrol", 
		func(delta): return patrol_area(ai, delta), true)
	
	root.add_child(critical_flee)
	root.add_child(combat)
	root.add_child(patrol)
	
	ai.behavior_tree.set_root(root)

static func setup_melee_state_machine(ai: AIController):
	"""Setup state machine for melee fighters"""
	var fsm = AIStateMachine.create_basic_enemy_fsm(ai.entity)
	
	# Melee fighters are aggressive - shorter patrol, longer pursuit
	var pursuit_state = fsm.states["pursuit"]
	if pursuit_state:
		pursuit_state.max_pursuit_time = 45.0  # Pursue for 45 seconds
	
	ai.state_machine = fsm

static func execute_melee_attack(ai: AIController) -> bool:
	"""Execute melee attack behavior"""
	if not ai.current_target or not ai.combat_component:
		return false
	
	# Face the target
	face_target(ai.entity, ai.current_target)
	
	# Execute attack with short windup
	return ai.combat_component.melee_attack(ai.current_target)

static func charge_at_target(ai: AIController, delta: float) -> bool:
	"""Charge aggressively at target"""
	if not ai.current_target or not ai.movement_component:
		return false
	
	var direction = (ai.current_target.global_position - ai.entity.global_position).normalized()
	var charge_speed = ai.movement_component.base_speed * 1.3  # 30% faster when charging
	
	ai.movement_component.move_direction(direction * charge_speed)
	return true

# Ranged Attacker AI
static func create_ranged_attacker_ai(entity: Node2D) -> AIController:
	"""Create AI for ranged attacker mobs"""
	var ai = AIController.new()
	ai.ai_type = AIController.AIType.RANGED
	ai.detection_range = 200.0
	ai.attack_range = 150.0
	ai.flee_threshold = 0.15
	ai.aggro_timeout = 20.0
	
	entity.add_child(ai)
	
	setup_ranged_behavior_tree(ai)
	setup_ranged_state_machine(ai)
	
	return ai

static func setup_ranged_behavior_tree(ai: AIController):
	"""Setup behavior tree for ranged attackers"""
	var root = AISelector.new("ranged_root")
	
	# Flee if target too close
	var flee_close = AISequence.new("flee_close")
	flee_close.add_child(AICondition.new("target_too_close", 
		func(): return ai.current_target != null and ai.entity.global_position.distance_to(ai.current_target.global_position) < 80.0))
	flee_close.add_child(AIAction.new("kite_away", 
		func(delta): return kite_away_from_target(ai, delta), true))
	
	# Attack from range
	var ranged_attack = AISequence.new("ranged_attack")
	ranged_attack.add_child(AICondition.new("has_target", 
		func(): return ai.current_target != null))
	ranged_attack.add_child(AICondition.new("in_range", 
		func(): return ai.current_target != null and ai.entity.global_position.distance_to(ai.current_target.global_position) <= ai.attack_range))
	ranged_attack.add_child(AIAction.new("shoot", 
		func(): return execute_ranged_attack(ai)))
	
	# Move to optimal range
	var position_for_attack = AISequence.new("position")
	position_for_attack.add_child(AICondition.new("has_target", 
		func(): return ai.current_target != null))
	position_for_attack.add_child(AIAction.new("move_to_range", 
		func(delta): return move_to_optimal_range(ai, delta), true))
	
	# Patrol
	var patrol = AIAction.new("patrol", 
		func(delta): return patrol_area(ai, delta), true)
	
	root.add_child(flee_close)
	root.add_child(ranged_attack)
	root.add_child(position_for_attack)
	root.add_child(patrol)
	
	ai.behavior_tree.set_root(root)

static func setup_ranged_state_machine(ai: AIController):
	"""Setup state machine for ranged attackers"""
	var fsm = AIStateMachine.create_basic_enemy_fsm(ai.entity)
	ai.state_machine = fsm

static func execute_ranged_attack(ai: AIController) -> bool:
	"""Execute ranged attack behavior"""
	if not ai.current_target or not ai.combat_component:
		return false
	
	# Check line of sight
	if not ai.senses.has_line_of_sight_to(ai.current_target):
		return false
	
	# Aim at target
	face_target(ai.entity, ai.current_target)
	
	# Fire projectile
	return ai.combat_component.ranged_attack(ai.current_target)

static func kite_away_from_target(ai: AIController, delta: float) -> bool:
	"""Move away from target while maintaining range"""
	if not ai.current_target or not ai.movement_component:
		return false
	
	var direction_away = (ai.entity.global_position - ai.current_target.global_position).normalized()
	var kite_speed = ai.movement_component.base_speed * 0.8  # Slightly slower when kiting
	
	ai.movement_component.move_direction(direction_away * kite_speed)
	return true

static func move_to_optimal_range(ai: AIController, delta: float) -> bool:
	"""Move to optimal attack range"""
	if not ai.current_target or not ai.movement_component:
		return false
	
	var distance = ai.entity.global_position.distance_to(ai.current_target.global_position)
	var optimal_range = ai.attack_range * 0.8  # Stay at 80% of max range
	
	if distance > optimal_range + 20.0:
		# Move closer
		var direction = (ai.current_target.global_position - ai.entity.global_position).normalized()
		ai.movement_component.move_direction(direction * ai.movement_component.base_speed)
	elif distance < optimal_range - 20.0:
		# Move away
		var direction = (ai.entity.global_position - ai.current_target.global_position).normalized()
		ai.movement_component.move_direction(direction * ai.movement_component.base_speed * 0.7)
	
	return true

# Coward Mob AI
static func create_coward_mob_ai(entity: Node2D) -> AIController:
	"""Create AI for coward mobs that flee easily"""
	var ai = AIController.new()
	ai.ai_type = AIController.AIType.COWARD
	ai.detection_range = 100.0
	ai.attack_range = 40.0
	ai.flee_threshold = 0.5  # Flee at 50% health
	ai.aggro_timeout = 5.0   # Short aggro
	
	entity.add_child(ai)
	
	setup_coward_behavior_tree(ai)
	setup_coward_state_machine(ai)
	
	return ai

static func setup_coward_behavior_tree(ai: AIController):
	"""Setup behavior tree for coward mobs"""
	var root = AISelector.new("coward_root")
	
	# Flee if health low or outnumbered
	var flee_behavior = AISequence.new("flee")
	flee_behavior.add_child(AICondition.new("should_flee", 
		func(): return should_coward_flee(ai)))
	flee_behavior.add_child(AIAction.new("flee_and_call_help", 
		func(delta): return flee_and_call_for_help(ai, delta), true))
	
	# Cautious attack (only if healthy and target isolated)
	var cautious_attack = AISequence.new("cautious_attack")
	cautious_attack.add_child(AICondition.new("safe_to_attack", 
		func(): return is_safe_to_attack(ai)))
	cautious_attack.add_child(AIAction.new("quick_attack", 
		func(): return execute_coward_attack(ai)))
	
	# Hide and observe
	var hide_behavior = AIAction.new("hide", 
		func(delta): return hide_from_threats(ai, delta), true)
	
	root.add_child(flee_behavior)
	root.add_child(cautious_attack)
	root.add_child(hide_behavior)
	
	ai.behavior_tree.set_root(root)

static func setup_coward_state_machine(ai: AIController):
	"""Setup state machine for coward mobs"""
	var fsm = AIStateMachine.create_coward_fsm(ai.entity)
	ai.state_machine = fsm

static func should_coward_flee(ai: AIController) -> bool:
	"""Check if coward should flee"""
	if not ai.health_component:
		return false
	
	var health_pct = ai.health_component.current_health / float(ai.health_component.max_health)
	if health_pct <= ai.flee_threshold:
		return true
	
	# Also flee if outnumbered
	if ai.current_target:
		var nearby_enemies = get_nearby_enemies(ai.entity, 100.0)
		var nearby_allies = get_nearby_allies(ai.entity, 100.0)
		if nearby_enemies.size() > nearby_allies.size() + 1:
			return true
	
	return false

static func flee_and_call_for_help(ai: AIController, delta: float) -> bool:
	"""Flee while calling for help"""
	if not ai.movement_component:
		return false
	
	# Call for help
	call_nearby_allies_for_help(ai)
	
	# Flee toward allies if possible
	var allies = get_nearby_allies(ai.entity, 200.0)
	if not allies.is_empty():
		var closest_ally = allies[0]
		var direction = (closest_ally.global_position - ai.entity.global_position).normalized()
		ai.movement_component.move_direction(direction * ai.movement_component.base_speed * 1.5)
	else:
		# Flee away from target
		return ai.flee_from_target()
	
	return true

static func is_safe_to_attack(ai: AIController) -> bool:
	"""Check if it's safe for coward to attack"""
	if not ai.current_target:
		return false
	
	# Only attack if health is good
	var health_pct = ai.health_component.current_health / float(ai.health_component.max_health)
	if health_pct < 0.8:
		return false
	
	# Only attack if target is isolated or we have allies
	var nearby_allies = get_nearby_allies(ai.entity, 80.0)
	var target_allies = get_nearby_allies(ai.current_target, 80.0)
	
	return nearby_allies.size() >= target_allies.size()

static func execute_coward_attack(ai: AIController) -> bool:
	"""Execute quick, cautious attack"""
	if not ai.current_target or not ai.combat_component:
		return false
	
	# Quick hit-and-run attack
	face_target(ai.entity, ai.current_target)
	var attack_result = ai.combat_component.melee_attack(ai.current_target)
	
	# Immediately back away after attack
	if attack_result:
		var direction_away = (ai.entity.global_position - ai.current_target.global_position).normalized()
		ai.movement_component.move_direction(direction_away * ai.movement_component.base_speed)
	
	return attack_result

static func hide_from_threats(ai: AIController, delta: float) -> bool:
	"""Hide from threats"""
	# Move to cover or away from line of sight
	if ai.current_target and ai.movement_component:
		# Find hiding spots (this would integrate with environment system)
		var hide_direction = get_hiding_direction(ai)
		ai.movement_component.move_direction(hide_direction * ai.movement_component.base_speed * 0.5)
		return true
	
	return patrol_area(ai, delta)

# Elite Mob AI
static func create_elite_mob_ai(entity: Node2D) -> AIController:
	"""Create AI for elite mobs with advanced tactics"""
	var ai = AIController.new()
	ai.ai_type = AIController.AIType.ELITE
	ai.detection_range = 180.0
	ai.attack_range = 80.0
	ai.flee_threshold = 0.0  # Never flee
	ai.aggro_timeout = 60.0  # Long memory
	
	entity.add_child(ai)
	
	setup_elite_behavior_tree(ai)
	setup_elite_state_machine(ai)
	
	return ai

static func setup_elite_behavior_tree(ai: AIController):
	"""Setup behavior tree for elite mobs"""
	var root = AISelector.new("elite_root")
	
	# Tactical positioning
	var tactical_combat = AISequence.new("tactical_combat")
	tactical_combat.add_child(AICondition.new("has_target", 
		func(): return ai.current_target != null))
	tactical_combat.add_child(AIAction.new("tactical_position", 
		func(delta): return execute_tactical_positioning(ai, delta), true))
	
	# Combo attacks
	var combo_attack = AISequence.new("combo_attack")
	combo_attack.add_child(AICondition.new("can_combo", 
		func(): return can_execute_combo(ai)))
	combo_attack.add_child(AIAction.new("execute_combo", 
		func(): return execute_combo_attack(ai)))
	
	# Area control
	var area_control = AISequence.new("area_control")
	area_control.add_child(AICondition.new("should_control_area", 
		func(): return should_control_area(ai)))
	area_control.add_child(AIAction.new("control_area", 
		func(delta): return execute_area_control(ai, delta), true))
	
	# Advanced patrol
	var elite_patrol = AIAction.new("elite_patrol", 
		func(delta): return elite_patrol_behavior(ai, delta), true)
	
	root.add_child(tactical_combat)
	root.add_child(combo_attack)
	root.add_child(area_control)
	root.add_child(elite_patrol)
	
	ai.behavior_tree.set_root(root)

static func setup_elite_state_machine(ai: AIController):
	"""Setup state machine for elite mobs"""
	var fsm = AIStateMachine.create_basic_enemy_fsm(ai.entity)
	
	# Elite mobs have longer pursuit and more aggressive behavior
	if "pursuit" in fsm.states:
		fsm.states["pursuit"].max_pursuit_time = 120.0  # 2 minutes
	
	ai.state_machine = fsm

static func execute_tactical_positioning(ai: AIController, delta: float) -> bool:
	"""Execute tactical positioning"""
	if not ai.current_target or not ai.movement_component:
		return false
	
	# Position to flank or use environment
	var tactical_position = calculate_tactical_position(ai)
	var direction = (tactical_position - ai.entity.global_position).normalized()
	
	ai.movement_component.move_direction(direction * ai.movement_component.base_speed)
	return true

static func calculate_tactical_position(ai: AIController) -> Vector2:
	"""Calculate optimal tactical position"""
	if not ai.current_target:
		return ai.entity.global_position
	
	# Try to flank target
	var to_target = ai.current_target.global_position - ai.entity.global_position
	var flank_direction = Vector2(-to_target.y, to_target.x).normalized()  # Perpendicular
	var flank_distance = 100.0
	
	# Choose left or right flank based on environment
	var left_flank = ai.entity.global_position + flank_direction * flank_distance
	var right_flank = ai.entity.global_position - flank_direction * flank_distance
	
	# Return the flank position that's not blocked (simplified)
	return left_flank if randf() > 0.5 else right_flank

static func can_execute_combo(ai: AIController) -> bool:
	"""Check if elite can execute combo attack"""
	if not ai.current_target or not ai.combat_component:
		return false
	
	# Check if target is in range and enough time has passed since last combo
	var distance = ai.entity.global_position.distance_to(ai.current_target.global_position)
	return distance <= ai.attack_range and ai.state_timer > 3.0

static func execute_combo_attack(ai: AIController) -> bool:
	"""Execute combo attack sequence"""
	if not ai.current_target or not ai.combat_component:
		return false
	
	# Execute a series of attacks (this would be expanded with actual combo system)
	face_target(ai.entity, ai.current_target)
	
	# Primary attack
	var primary_hit = ai.combat_component.melee_attack(ai.current_target)
	
	# Secondary attack after short delay
	if primary_hit:
		await ai.get_tree().create_timer(0.3).timeout
		ai.combat_component.special_attack(ai.current_target, "combo_follow_up")
	
	return primary_hit

static func should_control_area(ai: AIController) -> bool:
	"""Check if elite should focus on area control"""
	# Control area when multiple enemies present or when defending key position
	var nearby_enemies = get_nearby_enemies(ai.entity, 150.0)
	return nearby_enemies.size() > 1

static func execute_area_control(ai: AIController, delta: float) -> bool:
	"""Execute area control tactics"""
	# Move to central position to control multiple enemies
	var nearby_enemies = get_nearby_enemies(ai.entity, 150.0)
	if nearby_enemies.is_empty():
		return false
	
	# Calculate center point of all enemies
	var center_point = Vector2.ZERO
	for enemy in nearby_enemies:
		center_point += enemy.global_position
	center_point /= nearby_enemies.size()
	
	# Move toward center to control area
	var direction = (center_point - ai.entity.global_position).normalized()
	ai.movement_component.move_direction(direction * ai.movement_component.base_speed)
	
	return true

static func elite_patrol_behavior(ai: AIController, delta: float) -> bool:
	"""Elite patrol with awareness"""
	# Elite mobs patrol more systematically and check hiding spots
	return patrol_area(ai, delta)  # Enhanced version would check corners, etc.

# Minion AI (for boss fights)
static func create_minion_ai(entity: Node2D, boss: Node2D) -> AIController:
	"""Create AI for boss minions"""
	var ai = AIController.new()
	ai.ai_type = AIController.AIType.MINION
	ai.detection_range = 120.0
	ai.attack_range = 50.0
	ai.flee_threshold = 0.2
	ai.aggro_timeout = 30.0
	
	entity.add_child(ai)
	
	setup_minion_behavior_tree(ai, boss)
	setup_minion_state_machine(ai)
	
	return ai

static func setup_minion_behavior_tree(ai: AIController, boss: Node2D):
	"""Setup behavior tree for minions"""
	var root = AISelector.new("minion_root")
	
	# Protect boss is highest priority
	var protect_boss = AISequence.new("protect_boss")
	protect_boss.add_child(AICondition.new("boss_threatened", 
		func(): return is_boss_threatened(boss)))
	protect_boss.add_child(AIAction.new("protect_boss", 
		func(delta): return execute_boss_protection(ai, boss, delta), true))
	
	# Swarm tactics
	var swarm_attack = AISequence.new("swarm_attack")
	swarm_attack.add_child(AICondition.new("has_target", 
		func(): return ai.current_target != null))
	swarm_attack.add_child(AIAction.new("swarm_target", 
		func(delta): return execute_swarm_tactics(ai, delta), true))
	
	# Stay near boss
	var stay_near_boss = AIAction.new("stay_near_boss", 
		func(delta): return stay_near_master(ai, boss, delta), true)
	
	root.add_child(protect_boss)
	root.add_child(swarm_attack)
	root.add_child(stay_near_boss)
	
	ai.behavior_tree.set_root(root)

static func setup_minion_state_machine(ai: AIController):
	"""Setup state machine for minions"""
	var fsm = AIStateMachine.create_basic_enemy_fsm(ai.entity)
	ai.state_machine = fsm

static func is_boss_threatened(boss: Node2D) -> bool:
	"""Check if boss is being threatened"""
	if not boss or not boss.has_method("get_health_percentage"):
		return false
	
	# Boss is threatened if health is low or under heavy attack
	var health_pct = boss.get_health_percentage()
	return health_pct < 0.5

static func execute_boss_protection(ai: AIController, boss: Node2D, delta: float) -> bool:
	"""Execute boss protection behavior"""
	if not boss or not ai.movement_component:
		return false
	
	# Position between boss and threats
	var threats = get_nearby_enemies(boss, 100.0)
	if threats.is_empty():
		return stay_near_master(ai, boss, delta)
	
	var primary_threat = threats[0]  # Closest threat
	var intercept_position = boss.global_position + (primary_threat.global_position - boss.global_position) * 0.5
	
	var direction = (intercept_position - ai.entity.global_position).normalized()
	ai.movement_component.move_direction(direction * ai.movement_component.base_speed * 1.2)
	
	return true

static func execute_swarm_tactics(ai: AIController, delta: float) -> bool:
	"""Execute swarm attack tactics"""
	if not ai.current_target or not ai.movement_component:
		return false
	
	# Attack with other minions in coordinated fashion
	var other_minions = get_nearby_allies(ai.entity, 80.0)
	
	if other_minions.size() >= 2:
		# Coordinate attack from different angles
		var angle_offset = randf_range(-PI/3, PI/3)  # 60-degree spread
		var to_target = (ai.current_target.global_position - ai.entity.global_position).normalized()
		var rotated_direction = to_target.rotated(angle_offset)
		
		ai.movement_component.move_direction(rotated_direction * ai.movement_component.base_speed)
	else:
		# Direct attack if alone
		return charge_at_target(ai, delta)
	
	return true

static func stay_near_master(ai: AIController, master: Node2D, delta: float) -> bool:
	"""Stay near master/boss"""
	if not master or not ai.movement_component:
		return false
	
	var distance = ai.entity.global_position.distance_to(master.global_position)
	var desired_distance = 100.0  # Stay within 100 units
	
	if distance > desired_distance:
		# Move closer to master
		var direction = (master.global_position - ai.entity.global_position).normalized()
		ai.movement_component.move_direction(direction * ai.movement_component.base_speed)
	else:
		# Circle around master
		var angle = atan2(ai.entity.global_position.y - master.global_position.y, 
						 ai.entity.global_position.x - master.global_position.x)
		angle += delta * 0.5  # Slow circle
		
		var circle_position = master.global_position + Vector2(cos(angle), sin(angle)) * desired_distance
		var direction = (circle_position - ai.entity.global_position).normalized()
		ai.movement_component.move_direction(direction * ai.movement_component.base_speed * 0.5)
	
	return true

# Utility functions
static func face_target(entity: Node2D, target: Node2D):
	"""Make entity face the target"""
	if not entity or not target:
		return
	
	var direction = (target.global_position - entity.global_position).normalized()
	
	# Set facing direction if entity supports it
	if entity.has_method("set_facing_direction"):
		entity.set_facing_direction(direction)
	elif entity.has_method("look_at"):
		entity.look_at(target.global_position)

static func patrol_area(ai: AIController, delta: float) -> bool:
	"""Basic patrol behavior"""
	if not ai.movement_component:
		return false
	
	# Simple patrol - move in a pattern or to random points
	if not ai.has_meta("patrol_target"):
		# Generate new patrol point
		var patrol_offset = Vector2(randf_range(-ai.patrol_radius, ai.patrol_radius), 
								   randf_range(-ai.patrol_radius, ai.patrol_radius))
		ai.set_meta("patrol_target", ai.entity.global_position + patrol_offset)
	
	var patrol_target = ai.get_meta("patrol_target")
	var distance = ai.entity.global_position.distance_to(patrol_target)
	
	if distance < 20.0:
		# Reached patrol point, choose new one
		ai.remove_meta("patrol_target")
		return true
	
	# Move toward patrol point
	var direction = (patrol_target - ai.entity.global_position).normalized()
	ai.movement_component.move_direction(direction * ai.movement_component.base_speed * 0.6)
	
	return true

static func get_nearby_enemies(entity: Node2D, radius: float) -> Array:
	"""Get nearby enemy entities"""
	var enemies = []
	var space_state = entity.get_world_2d().direct_space_state
	
	# This would be replaced with proper spatial queries
	var potential_enemies = entity.get_tree().get_nodes_in_group("player")
	potential_enemies += entity.get_tree().get_nodes_in_group("enemies")
	
	for enemy in potential_enemies:
		if enemy == entity:
			continue
		
		var distance = entity.global_position.distance_to(enemy.global_position)
		if distance <= radius:
			enemies.append(enemy)
	
	return enemies

static func get_nearby_allies(entity: Node2D, radius: float) -> Array:
	"""Get nearby allied entities"""
	var allies = []
	
	# This would check faction/team affiliation
	var potential_allies = entity.get_tree().get_nodes_in_group("enemies")  # Same faction
	
	for ally in potential_allies:
		if ally == entity:
			continue
		
		var distance = entity.global_position.distance_to(ally.global_position)
		if distance <= radius:
			allies.append(ally)
	
	return allies

static func call_nearby_allies_for_help(ai: AIController):
	"""Call nearby allies for assistance"""
	var allies = get_nearby_allies(ai.entity, 150.0)
	
	for ally in allies:
		if ally.has_method("receive_help_call"):
			ally.receive_help_call(ai.current_target, ai.entity.global_position)

static func get_hiding_direction(ai: AIController) -> Vector2:
	"""Get direction toward hiding spot"""
	# This would integrate with environment/cover system
	# For now, return direction away from target with some randomness
	if ai.current_target:
		var away_direction = (ai.entity.global_position - ai.current_target.global_position).normalized()
		var random_offset = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		return (away_direction + random_offset).normalized()
	else:
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()