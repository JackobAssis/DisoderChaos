extends Node2D

class_name NPCController

signal interaction_available(npc_id: String)
signal interaction_unavailable(npc_id: String)
signal movement_completed()
signal activity_changed(activity: Dictionary)

# NPC identification
var npc_id: String = ""
var npc_data: Dictionary = {}
var npc_system: NPCSystem = null

# Visual components
var sprite: Sprite2D
var interaction_area: Area2D
var collision_shape: CollisionShape2D
var nameplate: Label

# Movement and behavior
var movement_type: String = "stationary"
var current_target: Vector2 = Vector2.ZERO
var movement_speed: float = 50.0
var is_moving: bool = false
var interaction_radius: float = 3.0

# Current state
var current_activity: Dictionary = {}
var is_interactable: bool = true
var last_interaction_time: float = 0.0
var interaction_cooldown: float = 1.0

# Patrol system
var patrol_points: Array = []
var current_patrol_index: int = 0
var patrol_wait_time: float = 2.0
var patrol_timer: float = 0.0

# Schedule system
var schedule_data: Dictionary = {}
var current_schedule_activity: String = ""

# Player reference
var player: Node2D = null
var player_in_range: bool = false

func _ready():
	setup_visual_components()
	setup_interaction_area()
	setup_movement_system()

func initialize(id: String, data: Dictionary, system: NPCSystem) -> void:
	npc_id = id
	npc_data = data
	npc_system = system
	
	# Set basic properties
	movement_type = data.get("movement_type", "stationary")
	interaction_radius = data.get("interaction_radius", 3.0)
	
	# Initialize movement data
	match movement_type:
		"patrol":
			patrol_points = data.get("patrol_points", [])
			if patrol_points.size() > 0:
				position = Vector2(patrol_points[0].x * 32, patrol_points[0].y * 32)
		
		"wander":
			# Set initial position and wander radius
			pass
		
		"schedule":
			schedule_data = data.get("schedule", {})
			
		"merchant_route":
			# Initialize merchant route
			pass
		
		_:  # stationary
			# Stay in place
			pass
	
	# Load sprite and visual data
	load_npc_visuals()
	
	# Setup nameplate
	if nameplate:
		nameplate.text = data.get("name", "NPC")

func setup_visual_components() -> void:
	# Main sprite
	sprite = Sprite2D.new()
	sprite.name = "NPCSprite"
	add_child(sprite)
	
	# Nameplate
	nameplate = Label.new()
	nameplate.name = "Nameplate"
	nameplate.position = Vector2(-50, -60)
	nameplate.size = Vector2(100, 20)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.add_theme_color_override("font_color", Color.WHITE)
	nameplate.add_theme_color_override("font_shadow_color", Color.BLACK)
	nameplate.add_theme_constant_override("shadow_offset_x", 1)
	nameplate.add_theme_constant_override("shadow_offset_y", 1)
	add_child(nameplate)

func setup_interaction_area() -> void:
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = interaction_radius * 32  # Convert to pixels
	collision_shape.shape = shape
	
	interaction_area.add_child(collision_shape)
	add_child(interaction_area)
	
	# Connect signals
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)

func setup_movement_system() -> void:
	match movement_type:
		"patrol":
			if patrol_points.size() > 0:
				current_target = Vector2(patrol_points[0].x * 32, patrol_points[0].y * 32)
		
		"wander":
			_start_wander()
		
		_:
			# No special setup needed for other types
			pass

func load_npc_visuals() -> void:
	var sprite_path = npc_data.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		if texture:
			sprite.texture = texture
	else:
		# Use placeholder texture
		sprite.texture = create_placeholder_texture()

func create_placeholder_texture() -> ImageTexture:
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.BLUE)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func _process(delta: float) -> void:
	update_movement(delta)
	update_behavior(delta)
	update_interaction_state()

func update_movement(delta: float) -> void:
	match movement_type:
		"patrol":
			update_patrol_movement(delta)
		
		"wander":
			update_wander_movement(delta)
		
		"schedule":
			update_schedule_movement(delta)
		
		"merchant_route":
			update_merchant_movement(delta)
		
		_:  # stationary, stealth_patrol, duty_patrol
			# Handle special movement types or stay stationary
			pass

func update_patrol_movement(delta: float) -> void:
	if patrol_points.size() == 0:
		return
	
	if patrol_timer > 0:
		patrol_timer -= delta
		return
	
	if is_moving:
		move_toward_target(delta)
		
		if position.distance_to(current_target) < 5.0:
			is_moving = false
			patrol_timer = patrol_wait_time
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			movement_completed.emit()
	else:
		# Start moving to next patrol point
		var next_point = patrol_points[current_patrol_index]
		current_target = Vector2(next_point.x * 32, next_point.y * 32)
		is_moving = true

func update_wander_movement(delta: float) -> void:
	if not is_moving:
		_start_wander()
	else:
		move_toward_target(delta)
		
		if position.distance_to(current_target) < 10.0:
			is_moving = false
			# Wait before next wander
			await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
			if is_inside_tree():  # Check if node still exists
				_start_wander()

func _start_wander() -> void:
	var wander_radius = npc_data.get("wander_radius", 100.0)
	var angle = randf() * TAU
	var distance = randf() * wander_radius
	current_target = position + Vector2(cos(angle), sin(angle)) * distance
	is_moving = true

func update_schedule_movement(delta: float) -> void:
	# Schedule-based movement would move NPC to different locations based on time
	# This would require integration with location system
	pass

func update_merchant_movement(delta: float) -> void:
	# Merchant route movement
	pass

func move_toward_target(delta: float) -> void:
	var direction = (current_target - position).normalized()
	position += direction * movement_speed * delta
	
	# Update sprite facing direction
	if sprite and direction.x != 0:
		sprite.flip_h = direction.x < 0

func update_behavior(delta: float) -> void:
	# Update cooldowns
	if last_interaction_time > 0:
		last_interaction_time -= delta
		if last_interaction_time <= 0:
			is_interactable = true

func update_interaction_state() -> void:
	# Update whether interaction prompt should be shown
	if player_in_range and is_interactable:
		if not has_emitted_interaction_signal:
			interaction_available.emit(npc_id)
			has_emitted_interaction_signal = true
	else:
		if has_emitted_interaction_signal:
			interaction_unavailable.emit(npc_id)
			has_emitted_interaction_signal = false

var has_emitted_interaction_signal: bool = false

func change_activity(activity_data: Dictionary) -> void:
	current_activity = activity_data
	current_schedule_activity = activity_data.get("action", "")
	
	# Update behavior based on activity
	match current_schedule_activity:
		"cooking":
			# Face cooking area, play cooking animation
			pass
		"training":
			# Face training area, play training animation
			pass
		"scouting":
			# Look around, scanning animation
			pass
		"socializing":
			# Face common area
			pass
		"resting":
			# Sit down or lie down animation
			pass
	
	activity_changed.emit(activity_data)

func interact() -> void:
	if not is_interactable:
		return
	
	# Start cooldown
	last_interaction_time = interaction_cooldown
	is_interactable = false
	
	# Notify NPC system to start dialogue
	if npc_system:
		npc_system.start_dialogue(npc_id)

func get_services() -> Dictionary:
	return npc_data.get("services", {})

func has_service(service_type: String) -> bool:
	var services = get_services()
	return services.get(service_type, false)

func get_personality() -> Dictionary:
	return npc_data.get("personality", {})

func get_faction() -> String:
	return npc_data.get("faction", "neutral")

func refresh_dialogue_state() -> void:
	# This would refresh any dialogue state that depends on game conditions
	pass

func _on_interaction_area_entered(body: Node2D) -> void:
	if body.name == "Player" or body.has_method("is_player"):
		player = body
		player_in_range = true

func _on_interaction_area_exited(body: Node2D) -> void:
	if body == player:
		player = null
		player_in_range = false

# Input handling
func _input(event: InputEvent) -> void:
	if not player_in_range or not is_interactable:
		return
	
	if event.is_action_pressed("interact"):
		interact()

# Save/Load functionality
func get_save_data() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"current_activity": current_activity,
		"current_schedule_activity": current_schedule_activity,
		"patrol_index": current_patrol_index,
		"is_moving": is_moving,
		"last_interaction_time": last_interaction_time
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var pos_data = data.position
		position = Vector2(pos_data.x, pos_data.y)
	
	if data.has("current_activity"):
		current_activity = data.current_activity
	
	if data.has("current_schedule_activity"):
		current_schedule_activity = data.current_schedule_activity
	
	if data.has("patrol_index"):
		current_patrol_index = data.patrol_index
	
	if data.has("is_moving"):
		is_moving = data.is_moving
	
	if data.has("last_interaction_time"):
		last_interaction_time = data.last_interaction_time

# Utility functions
func get_npc_id() -> String:
	return npc_id

func get_npc_data() -> Dictionary:
	return npc_data

func get_npc_name() -> String:
	return npc_data.get("name", "Unknown NPC")

func is_player_in_range() -> bool:
	return player_in_range

func set_interactable(interactable: bool) -> void:
	is_interactable = interactable

func get_interaction_radius() -> float:
	return interaction_radius

func set_movement_speed(speed: float) -> void:
	movement_speed = speed

# Debug functions
func debug_show_interaction_area() -> void:
	if interaction_area:
		# Add visual indicator for debugging
		var debug_circle = Node2D.new()
		debug_circle.name = "DebugCircle"
		add_child(debug_circle)