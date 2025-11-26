extends Node
class_name MathUtils
# math_utils.gd - Mathematical utility functions for game calculations

# Random number generation utilities
static func random_range_int(min_val: int, max_val: int) -> int:
	"""Generate random integer in range [min_val, max_val]"""
	return randi_range(min_val, max_val)

static func random_range_float(min_val: float, max_val: float) -> float:
	"""Generate random float in range [min_val, max_val]"""
	return randf_range(min_val, max_val)

static func weighted_random(weights: Array) -> int:
	"""Return random index based on weights array"""
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for i in range(weights.size()):
		current_weight += weights[i]
		if random_value <= current_weight:
			return i
	
	return weights.size() - 1

# Distance and vector utilities
static func distance_2d(pos1: Vector2, pos2: Vector2) -> float:
	"""Calculate 2D distance between two points"""
	return pos1.distance_to(pos2)

static func direction_to_target(from: Vector2, to: Vector2) -> Vector2:
	"""Get normalized direction vector from one point to another"""
	return (to - from).normalized()

static func is_within_range(pos1: Vector2, pos2: Vector2, range: float) -> bool:
	"""Check if two positions are within specified range"""
	return distance_2d(pos1, pos2) <= range

# Interpolation utilities
static func smooth_approach(current: float, target: float, rate: float, delta: float) -> float:
	"""Smoothly approach target value with exponential decay"""
	return current + (target - current) * (1.0 - exp(-rate * delta))

static func smooth_approach_vector(current: Vector2, target: Vector2, rate: float, delta: float) -> Vector2:
	"""Smoothly approach target vector with exponential decay"""
	return Vector2(
		smooth_approach(current.x, target.x, rate, delta),
		smooth_approach(current.y, target.y, rate, delta)
	)

# Percentage and ratio calculations
static func percentage(value: float, max_value: float) -> float:
	"""Calculate percentage (0-100) of value relative to max"""
	if max_value <= 0:
		return 0.0
	return (value / max_value) * 100.0

static func ratio(value: float, max_value: float) -> float:
	"""Calculate ratio (0-1) of value relative to max"""
	if max_value <= 0:
		return 0.0
	return clamp(value / max_value, 0.0, 1.0)

# Damage and combat calculations
static func calculate_critical_damage(base_damage: int, crit_multiplier: float = 2.0) -> int:
	"""Calculate critical hit damage"""
	return int(base_damage * crit_multiplier)

static func calculate_damage_reduction(damage: int, armor: int) -> int:
	"""Calculate damage after armor reduction"""
	# Simple armor formula: each armor point reduces 1 damage, minimum 1 damage
	return max(1, damage - armor)

static func calculate_percentage_reduction(damage: int, resistance_percent: float) -> int:
	"""Calculate damage after percentage-based resistance"""
	var reduction = clamp(resistance_percent, 0.0, 0.95)  # Max 95% reduction
	return max(1, int(damage * (1.0 - reduction)))

# Level and experience calculations
static func calculate_experience_for_level(level: int) -> int:
	"""Calculate total experience required for a specific level"""
	if level <= 1:
		return 0
	
	# Formula: sum from 2 to level of (level * 100 + (level-1) * 50)
	var total_exp = 0
	for l in range(2, level + 1):
		total_exp += l * 100 + (l - 1) * 50
	
	return total_exp

static func calculate_level_from_experience(experience: int) -> int:
	"""Calculate player level based on total experience"""
	var level = 1
	var required_exp = 0
	
	while required_exp <= experience:
		level += 1
		required_exp = calculate_experience_for_level(level)
	
	return level - 1

# Area and geometry utilities
static func point_in_circle(point: Vector2, center: Vector2, radius: float) -> bool:
	"""Check if point is within circle"""
	return distance_2d(point, center) <= radius

static func point_in_rectangle(point: Vector2, rect_pos: Vector2, rect_size: Vector2) -> bool:
	"""Check if point is within rectangle"""
	return (point.x >= rect_pos.x and point.x <= rect_pos.x + rect_size.x and
			point.y >= rect_pos.y and point.y <= rect_pos.y + rect_size.y)

static func random_point_in_circle(center: Vector2, radius: float) -> Vector2:
	"""Generate random point within circle"""
	var angle = randf() * TAU  # Random angle
	var distance = sqrt(randf()) * radius  # Square root for uniform distribution
	return center + Vector2(cos(angle), sin(angle)) * distance

# Statistical utilities
static func average(values: Array) -> float:
	"""Calculate average of numeric array"""
	if values.is_empty():
		return 0.0
	
	var sum = 0.0
	for value in values:
		sum += value
	
	return sum / values.size()

static func median(values: Array) -> float:
	"""Calculate median of numeric array"""
	if values.is_empty():
		return 0.0
	
	var sorted_values = values.duplicate()
	sorted_values.sort()
	
	var size = sorted_values.size()
	if size % 2 == 1:
		return sorted_values[size / 2]
	else:
		return (sorted_values[size / 2 - 1] + sorted_values[size / 2]) / 2.0

# Utility functions for game balance
static func calculate_stat_scaling(base_stat: int, level: int, growth_rate: float = 1.0) -> int:
	"""Calculate stat value with level scaling"""
	return int(base_stat + (level - 1) * growth_rate)

static func calculate_cooldown_reduction(base_cooldown: float, reduction_percent: float) -> float:
	"""Calculate cooldown after reduction"""
	var reduction = clamp(reduction_percent, 0.0, 0.9)  # Max 90% reduction
	return base_cooldown * (1.0 - reduction)

# TODO: Future mathematical utilities
# - Bezier curve calculations for movement paths
# - Noise functions for procedural generation
# - Advanced interpolation methods (ease-in/out, bounce, etc.)
# - Physics calculations for projectiles and forces
# - Graph theory algorithms for pathfinding
# - Statistical analysis for balance testing