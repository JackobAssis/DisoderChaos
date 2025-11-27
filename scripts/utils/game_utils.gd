extends Node
class_name GameUtils
# game_utils.gd - General utility functions for game development

# String formatting utilities
static func format_time(seconds: float) -> String:
# Format seconds into MM:SS format
	var minutes = int(seconds) / 60
	var remaining_seconds = int(seconds) % 60
	return "%02d:%02d" % [minutes, remaining_seconds]

static func format_large_number(number: int) -> String:
# Format large numbers with K, M, B suffixes
	if number >= 1000000000:
		return "%.1fB" % (number / 1000000000.0)
	elif number >= 1000000:
		return "%.1fM" % (number / 1000000.0)
	elif number >= 1000:
		return "%.1fK" % (number / 1000.0)
	else:
		return str(number)

static func capitalize_words(text: String) -> String:
# Capitalize first letter of each word
	var words = text.split(" ")
	var capitalized_words = []
	
	for word in words:
		if word.length() > 0:
			capitalized_words.append(word[0].to_upper() + word.substr(1).to_lower())
	
	return " ".join(capitalized_words)

# Color utilities
static func get_rarity_color(rarity: String) -> Color:
# Get color associated with item rarity
	match rarity.to_lower():
		"common":
			return Color.WHITE
		"uncommon":
			return Color.GREEN
		"rare":
			return Color.BLUE
		"epic":
			return Color.PURPLE
		"legendary":
			return Color.ORANGE
		"mythic":
			return Color.RED
		_:
			return Color.GRAY

static func get_damage_type_color(damage_type: String) -> Color:
# Get color for damage type
	match damage_type.to_lower():
		"physical":
			return Color.ORANGE
		"magical":
			return Color.CYAN
		"fire":
			return Color.RED
		"ice":
			return Color.LIGHT_BLUE
		"poison":
			return Color.GREEN
		"holy":
			return Color.YELLOW
		"shadow":
			return Color.PURPLE
		_:
			return Color.WHITE

# Save/Load utilities
static func save_json_file(data: Dictionary, file_path: String) -> bool:
# Save dictionary to JSON file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + file_path)
		return false
	
	file.store_string(JSON.stringify(data))
	file.close()
	return true

static func load_json_file(file_path: String) -> Dictionary:
# Load dictionary from JSON file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("File not found: " + file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON: " + file_path)
		return {}
	
	return json.data

# Node utilities
static func find_child_by_class(parent: Node, class_name: String) -> Node:
# Find first child node of specific class
	for child in parent.get_children():
		if child.get_script() and child.get_script().get_global_name() == class_name:
			return child
	return null

static func find_all_children_by_class(parent: Node, class_name: String) -> Array:
# Find all child nodes of specific class
	var found_nodes = []
	for child in parent.get_children():
		if child.get_script() and child.get_script().get_global_name() == class_name:
			found_nodes.append(child)
	return found_nodes

static func safe_connect(signal_source: Object, signal_name: String, callable_target: Callable) -> bool:
# Safely connect signal with error checking
	if not signal_source.has_signal(signal_name):
		push_warning("Signal not found: " + signal_name)
		return false
	
	if signal_source.is_connected(signal_name, callable_target):
		push_warning("Signal already connected: " + signal_name)
		return false
	
	signal_source.connect(signal_name, callable_target)
	return true

# Array utilities
static func shuffle_array(array: Array) -> Array:
# Shuffle array and return new shuffled copy
	var shuffled = array.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled

static func get_random_element(array: Array):
# Get random element from array
	if array.is_empty():
		return null
	return array[randi() % array.size()]

static func remove_duplicates(array: Array) -> Array:
# Remove duplicate elements from array
	var unique_array = []
	for element in array:
		if element not in unique_array:
			unique_array.append(element)
	return unique_array

# Validation utilities
static func is_valid_email(email: String) -> bool:
# Basic email validation
	var regex = RegEx.new()
	regex.compile("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$")
	return regex.search(email) != null

static func is_valid_name(name: String) -> bool:
# Validate character/player name
	if name.length() < 3 or name.length() > 20:
		return false
	
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z][a-zA-Z0-9_]*$")
	return regex.search(name) != null

static func sanitize_string(text: String) -> String:
# Remove potentially harmful characters from string
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9 _-]")
	return regex.sub(text, "", true)

# Scene management utilities
static func change_scene_safe(scene_path: String) -> bool:
# Safely change scene with error handling
	if not ResourceLoader.exists(scene_path):
		push_error("Scene not found: " + scene_path)
		return false
	
	var scene_resource = load(scene_path)
	if not scene_resource:
		push_error("Failed to load scene: " + scene_path)
		return false
	
	get_tree().change_scene_to_packed(scene_resource)
	return true

static func preload_scene(scene_path: String) -> PackedScene:
# Preload scene with error handling
	if not ResourceLoader.exists(scene_path):
		push_error("Scene not found: " + scene_path)
		return null
	
	return load(scene_path)

# Debug utilities
static func print_node_tree(node: Node, indent: int = 0):
# Print node hierarchy for debugging
	var indent_str = ""
	for i in indent:
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		print_node_tree(child, indent + 1)

static func log_performance(function_name: String, start_time: int):
# Log function performance time
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	print("[PERF] " + function_name + " took " + str(duration) + "ms")

# Input utilities
static func get_input_vector() -> Vector2:
# Get normalized movement input vector
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	
	return input_vector.normalized()

static func is_any_action_pressed(actions: Array) -> bool:
# Check if any of the specified actions are pressed
	for action in actions:
		if Input.is_action_pressed(action):
			return true
	return false

# Screen and viewport utilities
static func get_viewport_size() -> Vector2:
# Get current viewport size
	return get_viewport().get_visible_rect().size

static func screen_to_world(screen_pos: Vector2, camera: Camera2D) -> Vector2:
# Convert screen position to world position
	return camera.get_global_mouse_position()

static func world_to_screen(world_pos: Vector2, camera: Camera2D) -> Vector2:
# Convert world position to screen position
	return camera.to_screen_coordinates(world_pos)

# Audio utilities
static func play_sound_2d(sound_path: String, position: Vector2, volume: float = 0.0):
# Play 2D positioned sound effect
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = load(sound_path)
	audio_player.global_position = position
	audio_player.volume_db = volume
	
	# Add to scene tree temporarily
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	
	# Remove after playing
	audio_player.finished.connect(audio_player.queue_free)

# TODO: Future utility functions
# - Encryption/decryption for save files
# - Compression utilities for large data
# - Network utilities for multiplayer
# - Localization helpers
# - Advanced logging system
# - Performance monitoring tools
# - Memory management utilities
