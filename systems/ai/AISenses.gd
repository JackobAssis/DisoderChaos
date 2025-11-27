extends Node
class_name AISenses
# AISenses.gd - AI perception system with vision, hearing, and environmental awareness
# Supports configurable field of view, sound detection, and climate integration

# Vision properties
@export var vision_range: float = 150.0
@export var vision_angle: float = 90.0  # Degrees
@export var vision_layers: int = 1  # Physics layers to check
@export var peripheral_vision_range: float = 50.0  # Shorter range peripheral vision

# Hearing properties
@export var hearing_range: float = 100.0
@export var footstep_detection_range: float = 80.0
@export var sound_memory_duration: float = 5.0

# Environmental sensitivity
@export var light_sensitivity: float = 1.0
@export var weather_sensitivity: float = 1.0

# Current modifiers
var vision_range_modifier: float = 1.0
var hearing_range_modifier: float = 1.0
var alertness_level: float = 1.0  # 0.5 = reduced, 1.0 = normal, 2.0 = heightened

# Internal state
var entity: Node2D
var detected_targets: Array = []
var heard_sounds: Array = []
var last_seen_positions: Dictionary = {}
var sound_memory: Array = []

# Raycasting
var vision_raycast: RayCast2D
var space_state: PhysicsDirectSpaceState2D

# Climate integration
var climate_manager: Node
var current_light_level: float = 1.0
var current_weather_effect: float = 1.0

# Detection tracking
var detection_timers: Dictionary = {}
var detection_threshold: float = 1.0  # Seconds to confirm detection
var peripheral_detection_threshold: float = 2.0

signal target_detected(target: Node)
signal target_lost(target: Node)
signal sound_heard(position: Vector2, sound_type: String)
signal suspicious_sound(position: Vector2)
signal line_of_sight_broken(target: Node)
signal line_of_sight_established(target: Node)

func _ready():
	# Setup raycasting
	setup_raycasting()
	
	# Connect to climate system
	setup_climate_integration()
	
	print("[AISenses] Perception system ready")

func setup(parent_entity: Node2D, detection_range: float):
# Initialize senses for specific entity
	entity = parent_entity
	vision_range = detection_range
	
	# Get physics space
	space_state = entity.get_world_2d().direct_space_state
	
	print("[AISenses] Configured for entity: ", entity.name)

func setup_raycasting():
# Setup raycasting for line of sight checks
	vision_raycast = RayCast2D.new()
	vision_raycast.enabled = true
	vision_raycast.collision_mask = vision_layers
	add_child(vision_raycast)

func setup_climate_integration():
# Setup integration with climate system
	climate_manager = get_node_or_null("/root/ClimateManager")
	if climate_manager:
		climate_manager.weather_changed.connect(_on_weather_changed)
		climate_manager.light_level_changed.connect(_on_light_level_changed)

func update_perception(delta: float):
# Main perception update loop
	if not entity or not space_state:
		return
	
	# Update environmental factors
	update_environmental_factors()
	
	# Update vision
	update_vision_detection(delta)
	
	# Update hearing
	update_hearing_detection(delta)
	
	# Clean up old detections
	cleanup_old_detections(delta)

func update_environmental_factors():
# Update environmental factors affecting perception
	if climate_manager:
		current_light_level = climate_manager.get_light_level()
		current_weather_effect = get_weather_perception_effect()
	
	# Apply modifiers based on environment
	var effective_vision_modifier = vision_range_modifier
	effective_vision_modifier *= (0.5 + current_light_level * 0.5)  # Light affects vision
	effective_vision_modifier *= current_weather_effect  # Weather affects vision
	
	var effective_hearing_modifier = hearing_range_modifier
	effective_hearing_modifier *= current_weather_effect  # Weather affects hearing

func get_weather_perception_effect() -> float:
# Get weather effect on perception
	if not climate_manager:
		return 1.0
	
	var weather = climate_manager.get_current_weather()
	match weather:
		"clear":
			return 1.0
		"cloudy":
			return 0.9
		"rain":
			return 0.6  # Rain reduces both vision and hearing
		"heavy_rain":
			return 0.4
		"fog":
			return 0.2  # Fog severely limits vision
		"storm":
			return 0.3  # Storm affects both vision and hearing
		"snow":
			return 0.7
		"blizzard":
			return 0.3
		_:
			return 1.0

func update_vision_detection(delta: float):
# Update visual target detection
	var potential_targets = get_potential_targets()
	
	for target in potential_targets:
		var detection_result = check_visual_detection(target)
		
		if detection_result.detected:
			handle_target_detection(target, detection_result, delta)
		else:
			handle_target_loss(target, delta)

func get_potential_targets() -> Array:
# Get potential targets within maximum detection range
	var targets = []
	var max_range = vision_range * vision_range_modifier * alertness_level
	
	# Get all bodies in the area
	var query = PhysicsPointQueryParameters2D.new()
	query.position = entity.global_position
	query.collision_mask = vision_layers
	
	# This would be replaced with proper area detection
	# For now, we'll use a simple approach
	var nearby_entities = get_tree().get_nodes_in_group("detectable")
	
	for potential_target in nearby_entities:
		if potential_target == entity:
			continue
			
		var distance = entity.global_position.distance_to(potential_target.global_position)
		if distance <= max_range:
			targets.append(potential_target)
	
	return targets

func check_visual_detection(target: Node2D) -> Dictionary:
# Check if target is visually detectable
	var result = {
		"detected": false,
		"confidence": 0.0,
		"detection_type": "none",
		"distance": 0.0
	}
	
	if not target:
		return result
	
	var target_position = target.global_position
	var entity_position = entity.global_position
	var distance = entity_position.distance_to(target_position)
	
	result.distance = distance
	
	# Check range
	var effective_vision_range = vision_range * vision_range_modifier * alertness_level
	if distance > effective_vision_range:
		return result
	
	# Check field of view
	var to_target = (target_position - entity_position).normalized()
	var entity_facing = get_entity_facing_direction()
	var angle_to_target = rad_to_deg(entity_facing.angle_to(to_target))
	
	var is_in_fov = abs(angle_to_target) <= vision_angle / 2.0
	var is_in_peripheral = distance <= peripheral_vision_range * vision_range_modifier
	
	if not is_in_fov and not is_in_peripheral:
		return result
	
	# Check line of sight
	var has_line_of_sight = check_line_of_sight(entity_position, target_position)
	if not has_line_of_sight:
		return result
	
	# Calculate detection confidence
	var confidence = calculate_visual_confidence(target, distance, is_in_fov)
	
	if confidence > 0.3:  # Minimum confidence threshold
		result.detected = true
		result.confidence = confidence
		result.detection_type = "peripheral" if not is_in_fov else "direct"
	
	return result

func get_entity_facing_direction() -> Vector2:
# Get the direction the entity is facing
	# This would depend on how the entity stores its facing direction
	# For now, assume it's looking right by default
	if entity.has_method("get_facing_direction"):
		return entity.get_facing_direction()
	else:
		return Vector2.RIGHT

func check_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
# Check if there's a clear line of sight between two positions
	if not vision_raycast or not space_state:
		return true  # Assume clear if no raycasting available
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = from_pos
	query.to = to_pos
	query.collision_mask = vision_layers
	query.exclude = [entity]  # Don't collide with self
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func calculate_visual_confidence(target: Node2D, distance: float, is_in_fov: bool) -> float:
# Calculate confidence level for visual detection
	var confidence = 1.0
	
	# Distance factor
	var effective_range = vision_range * vision_range_modifier
	var distance_factor = 1.0 - (distance / effective_range)
	confidence *= distance_factor
	
	# Field of view factor
	if not is_in_fov:
		confidence *= 0.5  # Peripheral vision is less reliable
	
	# Light level factor
	confidence *= (0.3 + current_light_level * 0.7)
	
	# Weather factor
	confidence *= current_weather_effect
	
	# Alertness factor
	confidence *= alertness_level
	
	# Target visibility factors
	if target.has_method("get_visibility_modifier"):
		confidence *= target.get_visibility_modifier()
	
	# Target movement factor (moving targets are easier to spot)
	if target.has_method("get_velocity"):
		var velocity = target.get_velocity()
		if velocity.length() > 10.0:
			confidence *= 1.2  # Moving targets are more noticeable
	
	return clamp(confidence, 0.0, 1.0)

func update_hearing_detection(delta: float):
# Update auditory detection
	# Check for footsteps
	check_footstep_detection()
	
	# Check for other sounds
	check_ambient_sound_detection()
	
	# Update sound memory
	update_sound_memory(delta)

func check_footstep_detection():
# Check for footstep detection
	var effective_hearing_range = footstep_detection_range * hearing_range_modifier * alertness_level
	effective_hearing_range *= current_weather_effect
	
	# Find moving entities within hearing range
	var nearby_entities = get_tree().get_nodes_in_group("player")  # Primarily detect player
	nearby_entities += get_tree().get_nodes_in_group("enemies")
	
	for potential_source in nearby_entities:
		if potential_source == entity:
			continue
		
		var distance = entity.global_position.distance_to(potential_source.global_position)
		if distance > effective_hearing_range:
			continue
		
		# Check if entity is moving
		var is_moving = false
		if potential_source.has_method("get_velocity"):
			var velocity = potential_source.get_velocity()
			is_moving = velocity.length() > 20.0  # Minimum movement speed to make noise
		
		if is_moving:
			var sound_confidence = calculate_hearing_confidence(potential_source, distance)
			if sound_confidence > 0.4:  # Hearing threshold
				register_sound(potential_source.global_position, "footsteps", sound_confidence)

func check_ambient_sound_detection():
# Check for other environmental sounds
	# This would integrate with a sound manager system
	# For now, we'll check for sounds emitted by other entities
	pass

func calculate_hearing_confidence(source: Node2D, distance: float) -> float:
# Calculate confidence for hearing detection
	var confidence = 1.0
	
	# Distance factor
	var effective_range = hearing_range * hearing_range_modifier
	var distance_factor = 1.0 - (distance / effective_range)
	confidence *= distance_factor
	
	# Weather factor (rain/storm makes hearing harder)
	confidence *= current_weather_effect
	
	# Alertness factor
	confidence *= alertness_level
	
	# Source volume factor
	if source.has_method("get_noise_level"):
		confidence *= source.get_noise_level()
	
	return clamp(confidence, 0.0, 1.0)

func register_sound(position: Vector2, sound_type: String, confidence: float):
# Register a detected sound
	var sound_data = {
		"position": position,
		"type": sound_type,
		"confidence": confidence,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	heard_sounds.append(sound_data)
	sound_memory.append(sound_data)
	
	# Emit signal
	sound_heard.emit(position, sound_type)
	
	# If confidence is low, emit suspicious sound signal
	if confidence < 0.7:
		suspicious_sound.emit(position)

func update_sound_memory(delta: float):
# Update and clean old sounds from memory
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Remove old sounds from memory
	for i in range(sound_memory.size() - 1, -1, -1):
		var sound = sound_memory[i]
		if current_time - sound.timestamp > sound_memory_duration:
			sound_memory.remove_at(i)
	
	# Clear current frame sounds
	heard_sounds.clear()

func handle_target_detection(target: Node2D, detection_result: Dictionary, delta: float):
# Handle target detection with confirmation
	var target_id = target.get_instance_id()
	
	# Initialize detection timer if needed
	if not detection_timers.has(target_id):
		detection_timers[target_id] = 0.0
	
	# Accumulate detection time
	detection_timers[target_id] += delta * detection_result.confidence
	
	# Check if detection is confirmed
	var threshold = detection_threshold
	if detection_result.detection_type == "peripheral":
		threshold = peripheral_detection_threshold
	
	if detection_timers[target_id] >= threshold:
		# Confirmed detection
		if target not in detected_targets:
			detected_targets.append(target)
			last_seen_positions[target_id] = target.global_position
			target_detected.emit(target)
			line_of_sight_established.emit(target)
		else:
			# Update last seen position
			last_seen_positions[target_id] = target.global_position

func handle_target_loss(target: Node2D, delta: float):
# Handle loss of target detection
	var target_id = target.get_instance_id()
	
	if target in detected_targets:
		# Decay detection timer
		if detection_timers.has(target_id):
			detection_timers[target_id] -= delta * 2.0  # Lose detection faster than gaining it
			
			if detection_timers[target_id] <= 0.0:
				# Lost target
				detected_targets.erase(target)
				detection_timers.erase(target_id)
				target_lost.emit(target)
				line_of_sight_broken.emit(target)

func cleanup_old_detections(delta: float):
# Clean up old detection timers
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Remove detection timers for targets that no longer exist
	for target_id in detection_timers.keys():
		var target = instance_from_id(target_id)
		if not target or not is_instance_valid(target):
			detection_timers.erase(target_id)
			last_seen_positions.erase(target_id)

# Public API
func can_see_target(target: Node2D) -> bool:
# Check if target is currently visible
	return target in detected_targets

func get_last_seen_position(target: Node2D) -> Vector2:
# Get last known position of target
	var target_id = target.get_instance_id()
	return last_seen_positions.get(target_id, Vector2.ZERO)

func increase_alertness(multiplier: float = 2.0):
# Increase alertness level
	alertness_level = multiplier
	print("[AISenses] Alertness increased to: ", alertness_level)

func reset_alertness():
# Reset alertness to normal level
	alertness_level = 1.0
	print("[AISenses] Alertness reset to normal")

func set_vision_range(new_range: float):
# Set vision range
	vision_range = new_range

func set_vision_angle(new_angle: float):
# Set vision angle in degrees
	vision_angle = clamp(new_angle, 30.0, 360.0)

func set_hearing_range(new_range: float):
# Set hearing range
	hearing_range = new_range

func get_detected_targets() -> Array:
# Get all currently detected targets
	return detected_targets.duplicate()

func get_recent_sounds(max_age: float = 3.0) -> Array:
# Get recent sounds within specified age
	var current_time = Time.get_ticks_msec() / 1000.0
	var recent_sounds = []
	
	for sound in sound_memory:
		if current_time - sound.timestamp <= max_age:
			recent_sounds.append(sound)
	
	return recent_sounds

func has_line_of_sight_to(target: Node2D) -> bool:
# Check if there's line of sight to specific target
	if not target:
		return false
	
	return check_line_of_sight(entity.global_position, target.global_position)

# Environmental integration
func _on_weather_changed(weather_type: String):
# Handle weather changes
	current_weather_effect = get_weather_perception_effect()
	print("[AISenses] Weather changed, perception effect: ", current_weather_effect)

func _on_light_level_changed(light_level: float):
# Handle light level changes
	current_light_level = light_level
	print("[AISenses] Light level changed: ", light_level)

# Special abilities
func detect_stealth_targets() -> Array:
# Special detection for stealthed/invisible targets
	var stealth_targets = []
	
	# This would integrate with a stealth system
	# Check for movement disturbances, partial visibility, etc.
	
	return stealth_targets

func detect_magic_auras() -> Array:
# Detect magical auras if entity has magical senses
	var magic_targets = []
	
	# This would integrate with a magic system
	# Check for magical signatures, spell effects, etc.
	
	return magic_targets

# Debug functions
func debug_draw_vision_cone():
# Draw vision cone for debugging
	if not entity:
		return
	
	# This would be implemented with debug drawing
	pass

func debug_draw_hearing_range():
# Draw hearing range for debugging
	if not entity:
		return
	
	# This would be implemented with debug drawing
	pass

func get_perception_debug_info() -> Dictionary:
# Get debug information about perception
	return {
		"entity_name": entity.name if entity else "None",
		"vision_range": vision_range,
		"effective_vision_range": vision_range * vision_range_modifier * alertness_level,
		"vision_angle": vision_angle,
		"hearing_range": hearing_range,
		"effective_hearing_range": hearing_range * hearing_range_modifier * alertness_level,
		"alertness_level": alertness_level,
		"detected_targets": detected_targets.size(),
		"light_level": current_light_level,
		"weather_effect": current_weather_effect,
		"recent_sounds": heard_sounds.size()
	}

# Cleanup
func _exit_tree():
# Cleanup when senses are removed
	if vision_raycast:
		vision_raycast.queue_free()
	
	detected_targets.clear()
	heard_sounds.clear()
	sound_memory.clear()
	detection_timers.clear()
	last_seen_positions.clear()
	
	print("[AISenses] Perception system cleaned up")
