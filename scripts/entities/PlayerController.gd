extends CharacterBody2D

class_name PlayerController

signal health_changed(new_health: int, max_health: int)
signal stamina_changed(new_stamina: float, max_stamina: float)
signal position_changed(new_position: Vector2)
signal died()
signal leveled_up(new_level: int)

# Movement constants
const SPEED = 300.0
const ACCELERATION = 1500.0
const FRICTION = 1200.0

# Player state
var is_moving = false
var is_running = false
var is_casting = false
var is_interacting = false
var is_in_combat = false

# Health and Stamina (placeholders - will integrate with full systems later)
var current_health: int = 100
var max_health: int = 100
var current_stamina: float = 100.0
var max_stamina: float = 100.0

# Stamina costs
var running_stamina_cost = 20.0 # per second
var dodge_stamina_cost = 25.0
var interaction_stamina_cost = 5.0

# Player components
@onready var sprite: Sprite2D = $PlayerSprite
@onready var collision: CollisionShape2D = $PlayerCollision
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_stats: PlayerStats = $PlayerStats
@onready var equipment_system: EquipmentSystem = $EquipmentSystem

# References
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")

# Input handling
var input_vector: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN

func _ready():
	name = "Player"
	setup_player()
	connect_signals()
	
	print("[PlayerController] Player initialized")

func setup_player():
	"""Initialize player components and stats"""
	# Create placeholder sprite if none exists
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "PlayerSprite"
		add_child(sprite)
		sprite.texture = create_player_texture()
	
	# Create placeholder collision if none exists
	if not collision:
		collision = CollisionShape2D.new()
		collision.name = "PlayerCollision"
		var shape = CapsuleShape2D.new()
		shape.radius = 16
		shape.height = 32
		collision.shape = shape
		add_child(collision)
	
	# Initialize stats from race/class data
	if player_stats:
		player_stats.initialize_from_character_creation()
		sync_stats_with_player_stats()
	
	# Initialize equipment
	if equipment_system:
		equipment_system.initialize()

func create_player_texture() -> ImageTexture:
	"""Create placeholder player texture"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.BLUE)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func connect_signals():
	"""Connect relevant signals"""
	if player_stats:
		player_stats.connect("health_changed", _on_health_changed)
		player_stats.connect("stamina_changed", _on_stamina_changed)
		player_stats.connect("level_changed", _on_level_changed)
	
	# Connect to event bus
	event_bus.connect("damage_taken", _on_damage_taken)
	event_bus.connect("healing_received", _on_healing_received)

func _physics_process(delta):
	"""Main physics update loop"""
	if is_casting or is_interacting:
		return
	
	handle_input()
	update_movement(delta)
	update_stamina(delta)
	update_animations()
	
	# Emit position change for other systems
	position_changed.emit(global_position)

func handle_input():
	"""Process player input"""
	# Movement input
	input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	
	input_vector = input_vector.normalized()
	
	# Update facing direction
	if input_vector != Vector2.ZERO:
		last_direction = input_vector
	
	# Running toggle
	is_running = Input.is_action_pressed("run") and current_stamina > 10.0
	
	# Interaction
	if Input.is_action_just_pressed("interact"):
		try_interact()
	
	# Dodge/Roll
	if Input.is_action_just_pressed("dodge"):
		try_dodge()

func update_movement(delta):
	"""Update player movement and velocity"""
	if input_vector != Vector2.ZERO:
		is_moving = true
		
		# Calculate target speed
		var target_speed = SPEED
		if is_running and current_stamina > 0:
			target_speed *= 1.5
		
		# Apply acceleration
		velocity = velocity.move_toward(input_vector * target_speed, ACCELERATION * delta)
		
		# Consume stamina for running
		if is_running:
			consume_stamina(running_stamina_cost * delta)
	else:
		is_moving = false
		
		# Apply friction
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	move_and_slide()

func update_stamina(delta):
	"""Update stamina regeneration"""
	if current_stamina < max_stamina and not is_running:
		var regen_rate = 25.0  # Stamina per second
		current_stamina = min(current_stamina + regen_rate * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

func update_animations():
	"""Update player animations based on state"""
	if not animation_player:
		return
	
	if is_moving:
		if is_running:
			animation_player.play("run_" + get_direction_string())
		else:
			animation_player.play("walk_" + get_direction_string())
	else:
		animation_player.play("idle_" + get_direction_string())

func get_direction_string() -> String:
	"""Get direction string for animations"""
	var abs_x = abs(last_direction.x)
	var abs_y = abs(last_direction.y)
	
	if abs_x > abs_y:
		return "right" if last_direction.x > 0 else "left"
	else:
		return "down" if last_direction.y > 0 else "up"

func try_interact():
	"""Attempt interaction with nearby objects"""
	if is_interacting or current_stamina < interaction_stamina_cost:
		return
	
	# Check for nearby interactable objects
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = 4  # Interactable layer
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var body = result["collider"]
		if body.has_method("interact"):
			start_interaction()
			body.interact(self)
			consume_stamina(interaction_stamina_cost)
			break

func try_dodge():
	"""Attempt dodge roll"""
	if current_stamina < dodge_stamina_cost or is_casting:
		return
	
	perform_dodge()

func perform_dodge():
	"""Perform dodge roll"""
	is_interacting = true  # Prevent other actions during dodge
	consume_stamina(dodge_stamina_cost)
	
	# Add dodge velocity
	var dodge_force = 400.0
	velocity += last_direction * dodge_force
	
	# Play dodge animation
	if animation_player:
		animation_player.play("dodge_" + get_direction_string())
	
	# End dodge after short duration
	await get_tree().create_timer(0.5).timeout
	is_interacting = false

func start_interaction():
	"""Start interaction state"""
	is_interacting = true
	velocity = Vector2.ZERO

func end_interaction():
	"""End interaction state"""
	is_interacting = false

func consume_stamina(amount: float):
	"""Consume stamina amount"""
	current_stamina = max(current_stamina - amount, 0.0)
	stamina_changed.emit(current_stamina, max_stamina)
	
	if current_stamina <= 0:
		is_running = false  # Stop running when out of stamina

func take_damage(amount: int, damage_type: String = "physical"):
	"""Take damage"""
	if player_stats:
		player_stats.take_damage(amount, damage_type)
	else:
		# Fallback damage handling
		current_health = max(current_health - amount, 0)
		health_changed.emit(current_health, max_health)
		
		if current_health <= 0:
			die()

func heal(amount: int):
	"""Heal player"""
	if player_stats:
		player_stats.heal(amount)
	else:
		# Fallback healing
		current_health = min(current_health + amount, max_health)
		health_changed.emit(current_health, max_health)

func die():
	"""Handle player death"""
	is_interacting = true  # Stop all actions
	velocity = Vector2.ZERO
	
	if animation_player:
		animation_player.play("death")
	
	died.emit()
	print("[PlayerController] Player died")

func sync_stats_with_player_stats():
	"""Sync local stats with PlayerStats component"""
	if not player_stats:
		return
	
	current_health = player_stats.get_current_health()
	max_health = player_stats.get_max_health()
	current_stamina = player_stats.get_current_stamina()
	max_stamina = player_stats.get_max_stamina()

# Event handlers
func _on_health_changed(new_health: int, max_health_value: int):
	"""Handle health change from PlayerStats"""
	current_health = new_health
	max_health = max_health_value
	health_changed.emit(current_health, max_health)

func _on_stamina_changed(new_stamina: float, max_stamina_value: float):
	"""Handle stamina change from PlayerStats"""
	current_stamina = new_stamina
	max_stamina = max_stamina_value
	stamina_changed.emit(current_stamina, max_stamina)

func _on_level_changed(new_level: int):
	"""Handle level change from PlayerStats"""
	leveled_up.emit(new_level)
	print("[PlayerController] Player leveled up to level %d" % new_level)

func _on_damage_taken(amount: int, source: String):
	"""Handle damage from event bus"""
	take_damage(amount)

func _on_healing_received(amount: int, source: String):
	"""Handle healing from event bus"""
	heal(amount)

# Utility methods
func get_player_position() -> Vector2:
	"""Get player position"""
	return global_position

func get_facing_direction() -> Vector2:
	"""Get the direction player is facing"""
	return last_direction

func is_player() -> bool:
	"""Helper method to identify this as player"""
	return true

func get_current_health() -> int:
	"""Get current health"""
	return current_health

func get_max_health() -> int:
	"""Get maximum health"""
	return max_health

func get_current_stamina() -> float:
	"""Get current stamina"""
	return current_stamina

func get_max_stamina() -> float:
	"""Get maximum stamina"""
	return max_stamina

func get_player_stats() -> PlayerStats:
	"""Get PlayerStats component"""
	return player_stats

func get_equipment_system() -> EquipmentSystem:
	"""Get EquipmentSystem component"""
	return equipment_system

# Save/Load functionality
func get_save_data() -> Dictionary:
	"""Get player save data"""
	var save_data = {
		"position": {"x": global_position.x, "y": global_position.y},
		"current_health": current_health,
		"current_stamina": current_stamina,
		"last_direction": {"x": last_direction.x, "y": last_direction.y}
	}
	
	if player_stats:
		save_data["stats"] = player_stats.get_save_data()
	
	if equipment_system:
		save_data["equipment"] = equipment_system.get_save_data()
	
	return save_data

func load_save_data(data: Dictionary):
	"""Load player save data"""
	if data.has("position"):
		var pos = data.position
		global_position = Vector2(pos.x, pos.y)
	
	if data.has("current_health"):
		current_health = data.current_health
	
	if data.has("current_stamina"):
		current_stamina = data.current_stamina
	
	if data.has("last_direction"):
		var dir = data.last_direction
		last_direction = Vector2(dir.x, dir.y)
	
	if data.has("stats") and player_stats:
		player_stats.load_save_data(data.stats)
	
	if data.has("equipment") and equipment_system:
		equipment_system.load_save_data(data.equipment)
	
	# Update UI
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)

# Debug methods
func debug_heal_full():
	"""Debug: Heal to full"""
	heal(max_health)
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)

func debug_damage(amount: int):
	"""Debug: Take specific damage"""
	take_damage(amount)

func debug_teleport(target_position: Vector2):
	"""Debug: Teleport to position"""
	global_position = target_position
	position_changed.emit(global_position)