extends Node2D
# world_test.gd - Test world scene with player and dungeon integration

var player: PlayerController
var dungeon: DungeonController
var hud: GameHUD

func _ready():
	print("[WorldTest] World test scene initialized")
	setup_world()
	spawn_player()
	setup_dungeon()
	setup_hud()

func setup_world():
	"""Setup world environment"""
	# Create world boundaries
	create_world_boundaries()
	
	# Set camera to follow player
	setup_camera()

func create_world_boundaries():
	"""Create invisible boundaries for the world"""
	var boundary_thickness = 50
	var world_size = Vector2(1000, 800)
	
	# Top boundary
	create_boundary(Vector2(-boundary_thickness, -boundary_thickness), 
					Vector2(world_size.x + boundary_thickness * 2, boundary_thickness))
	
	# Bottom boundary  
	create_boundary(Vector2(-boundary_thickness, world_size.y), 
					Vector2(world_size.x + boundary_thickness * 2, boundary_thickness))
	
	# Left boundary
	create_boundary(Vector2(-boundary_thickness, -boundary_thickness), 
					Vector2(boundary_thickness, world_size.y + boundary_thickness * 2))
	
	# Right boundary
	create_boundary(Vector2(world_size.x, -boundary_thickness), 
					Vector2(boundary_thickness, world_size.y + boundary_thickness * 2))

func create_boundary(pos: Vector2, size: Vector2):
	"""Create a single boundary wall"""
	var boundary = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	shape.size = size
	collision.shape = shape
	collision.position = pos + size / 2
	
	boundary.add_child(collision)
	boundary.collision_layer = 4  # Environment layer
	add_child(boundary)

func setup_camera():
	"""Setup camera to follow player"""
	var camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(1.2, 1.2)  # Slight zoom for better view
	add_child(camera)
	
	# Camera will be attached to player when spawned

func spawn_player():
	"""Spawn the player in the world"""
	var player_scene = preload("res://scenes/player/Player.tscn")
	player = player_scene.instantiate()
	player.position = Vector2(100, 100)  # Starting position
	player.name = "Player"
	add_child(player)
	
	# Attach camera to player
	var camera = get_children().filter(func(child): return child is Camera2D)[0]
	if camera:
		camera.reparent(player)

func setup_dungeon():
	"""Setup the initial dungeon"""
	var dungeon_scene = preload("res://scenes/dungeons/DungeonBase.tscn")
	dungeon = dungeon_scene.instantiate()
	dungeon.position = Vector2.ZERO
	add_child(dungeon)
	
	# Load the starting dungeon
	var starting_dungeon = GameState.current_dungeon_id
	dungeon.load_dungeon(starting_dungeon)

func setup_hud():
	"""Setup the game HUD"""
	hud = preload("res://scenes/ui/GameHUD.tscn").instantiate()
	add_child(hud)
	
	# Ensure HUD is on top
	move_child(hud, get_child_count() - 1)

func _input(event):
	"""Handle world-level input"""
	if event.is_action_pressed("ui_cancel"):
		# Show pause menu or return to main menu
		show_pause_menu()

func show_pause_menu():
	"""Show pause menu"""
	# TODO: Implement proper pause menu
	print("[WorldTest] Pause menu requested")

# TODO: Future enhancements
# - Dynamic world loading based on dungeon connections
# - Weather and environmental effects  
# - NPCs and interactive objects
# - World events and random encounters
# - Day/night cycle
# - Save points and checkpoints