extends Control

class_name Minimap

# Minimap Components
@onready var minimap_frame: Panel
@onready var minimap_viewport: SubViewport
@onready var minimap_camera: Camera2D
@onready var minimap_mask: Control
@onready var fog_of_war: Control

# Icons and overlays
var player_icon: Control
var npc_icons: Dictionary = {} # npc_id -> icon
var enemy_icons: Dictionary = {} # enemy_id -> icon  
var item_icons: Dictionary = {} # item_id -> icon
var poi_icons: Dictionary = {} # point_of_interest_id -> icon

# Minimap settings
var minimap_size: Vector2 = Vector2(200, 200)
var minimap_radius: float = 100.0
var zoom_level: float = 1.0
var max_zoom: float = 3.0
var min_zoom: float = 0.5
var is_fullscreen: bool = false

# Fog of War
var explored_areas: Array[Vector2] = []
var fog_resolution: int = 32
var fog_grid: Array[Array] = []
var exploration_radius: float = 50.0

# Colors
var player_color: Color = Color(0.0, 1.0, 0.549, 1.0) # Neon green
var npc_color: Color = Color.BLUE
var enemy_color: Color = Color.RED
var item_color: Color = Color.YELLOW
var poi_color: Color = Color.CYAN
var fog_color: Color = Color(0.0, 0.0, 0.0, 0.8)
var explored_color: Color = Color(0.2, 0.2, 0.2, 0.3)

# References
var player_node: Node2D
var current_dungeon: String = ""
var dungeon_data: Dictionary = {}

@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")

func _ready():
	setup_minimap_ui()
	connect_events()
	initialize_fog_of_war()
	print("[Minimap] Minimap inicializado")

func initialize():
# Initialize minimap system
	find_player_node()
	setup_minimap_camera()
	start_minimap_updates()

func setup_minimap_ui():
# Setup minimap UI components
	# Set minimap position (top-right corner)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -minimap_size.x - 20
	offset_right = -20
	offset_top = 20
	offset_bottom = minimap_size.y + 20
	
	# Create circular frame
	create_minimap_frame()
	create_minimap_viewport()
	create_player_icon()
	create_fog_overlay()

func create_minimap_frame():
# Create the circular minimap frame
	minimap_frame = Panel.new()
	minimap_frame.name = "MinimapFrame"
	minimap_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(minimap_frame)
	
	# Create circular style
	var style = StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = player_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = minimap_radius
	style.corner_radius_top_right = minimap_radius
	style.corner_radius_bottom_left = minimap_radius
	style.corner_radius_bottom_right = minimap_radius
	minimap_frame.add_theme_stylebox_override("panel", style)
	
	# Add click detection
	minimap_frame.gui_input.connect(_on_minimap_input)

func create_minimap_viewport():
# Create viewport for minimap rendering
	minimap_viewport = SubViewport.new()
	minimap_viewport.name = "MinimapViewport"
	minimap_viewport.size = Vector2i(int(minimap_size.x), int(minimap_size.y))
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_frame.add_child(minimap_viewport)
	
	# Create minimap camera
	minimap_camera = Camera2D.new()
	minimap_camera.name = "MinimapCamera"
	minimap_camera.enabled = true
	minimap_viewport.add_child(minimap_camera)

func create_player_icon():
# Create player icon on minimap
	player_icon = Control.new()
	player_icon.name = "PlayerIcon"
	player_icon.custom_minimum_size = Vector2(8, 8)
	player_icon.anchor_left = 0.5
	player_icon.anchor_right = 0.5
	player_icon.anchor_top = 0.5
	player_icon.anchor_bottom = 0.5
	player_icon.offset_left = -4
	player_icon.offset_right = 4
	player_icon.offset_top = -4
	player_icon.offset_bottom = 4
	
	var icon_panel = Panel.new()
	icon_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_icon.add_child(icon_panel)
	
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = player_color
	icon_style.corner_radius_top_left = 4
	icon_style.corner_radius_top_right = 4
	icon_style.corner_radius_bottom_left = 4
	icon_style.corner_radius_bottom_right = 4
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	minimap_frame.add_child(player_icon)

func create_fog_overlay():
# Create fog of war overlay
	fog_of_war = Control.new()
	fog_of_war.name = "FogOfWar"
	fog_of_war.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_of_war.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_of_war.draw.connect(_draw_fog_of_war)
	minimap_frame.add_child(fog_of_war)

func connect_events():
# Connect to game events
	event_bus.connect("player_moved", _on_player_moved)
	event_bus.connect("dungeon_changed", _on_dungeon_changed)
	event_bus.connect("npc_spawned", _on_npc_spawned)
	event_bus.connect("npc_despawned", _on_npc_despawned)
	event_bus.connect("enemy_spawned", _on_enemy_spawned)
	event_bus.connect("enemy_defeated", _on_enemy_defeated)
	event_bus.connect("item_dropped", _on_item_dropped)
	event_bus.connect("item_collected", _on_item_collected)

func find_player_node():
# Find player node in scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		print("[Minimap] Player node encontrado: ", player_node.name)
	else:
		print("[Minimap] AVISO: Player node nÃ£o encontrado")

func setup_minimap_camera():
# Setup minimap camera to follow player
	if not minimap_camera or not player_node:
		return
	
	minimap_camera.global_position = player_node.global_position
	minimap_camera.zoom = Vector2.ONE * zoom_level

func start_minimap_updates():
# Start minimap update loop
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update 10 times per second
	timer.timeout.connect(update_minimap)
	timer.autostart = true
	add_child(timer)

func initialize_fog_of_war():
# Initialize fog of war system
	# Create fog grid
	fog_grid = []
	for x in range(fog_resolution):
		fog_grid.append([])
		for y in range(fog_resolution):
			fog_grid[x].append(false)  # false = unexplored

# Core update functions
func update_minimap():
# Update minimap display
	if not player_node or not minimap_camera:
		return
	
	# Update camera position
	minimap_camera.global_position = player_node.global_position
	
	# Update fog of war
	update_fog_exploration()
	
	# Update icon positions
	update_icon_positions()

func update_fog_exploration():
# Update fog of war based on player position
	if not player_node:
		return
	
	var player_pos = player_node.global_position
	var grid_x = int((player_pos.x / 100.0) + fog_resolution / 2)
	var grid_y = int((player_pos.y / 100.0) + fog_resolution / 2)
	
	# Explore area around player
	for x in range(max(0, grid_x - 2), min(fog_resolution, grid_x + 3)):
		for y in range(max(0, grid_y - 2), min(fog_resolution, grid_y + 3)):
			var distance = Vector2(x - grid_x, y - grid_y).length()
			if distance <= exploration_radius / 50.0:
				fog_grid[x][y] = true
	
	fog_of_war.queue_redraw()

func update_icon_positions():
# Update positions of all minimap icons
	update_npc_icons()
	update_enemy_icons()
	update_item_icons()
	update_poi_icons()

func update_npc_icons():
# Update NPC icon positions
	for npc_id in npc_icons.keys():
		var icon = npc_icons[npc_id]
		var npc_node = get_node_or_null(npc_id)
		if npc_node and is_position_visible(npc_node.global_position):
			var screen_pos = world_to_minimap_position(npc_node.global_position)
			icon.position = screen_pos
			icon.visible = true
		else:
			icon.visible = false

func update_enemy_icons():
# Update enemy icon positions
	for enemy_id in enemy_icons.keys():
		var icon = enemy_icons[enemy_id]
		var enemy_node = get_node_or_null(enemy_id)
		if enemy_node and is_position_visible(enemy_node.global_position):
			var screen_pos = world_to_minimap_position(enemy_node.global_position)
			icon.position = screen_pos
			icon.visible = true
		else:
			icon.visible = false

func update_item_icons():
# Update item icon positions
	for item_id in item_icons.keys():
		var icon = item_icons[item_id]
		var item_node = get_node_or_null(item_id)
		if item_node and is_position_visible(item_node.global_position):
			var screen_pos = world_to_minimap_position(item_node.global_position)
			icon.position = screen_pos
			icon.visible = true
		else:
			icon.visible = false

func update_poi_icons():
# Update point of interest icon positions
	for poi_id in poi_icons.keys():
		var icon = poi_icons[poi_id]
		# POIs are usually static, get position from data
		var poi_data = get_poi_data(poi_id)
		if poi_data and is_position_visible(poi_data.position):
			var screen_pos = world_to_minimap_position(poi_data.position)
			icon.position = screen_pos
			icon.visible = true
		else:
			icon.visible = false

func world_to_minimap_position(world_pos: Vector2) -> Vector2:
# Convert world position to minimap screen position
	if not player_node:
		return Vector2.ZERO
	
	var relative_pos = world_pos - player_node.global_position
	var screen_pos = relative_pos * zoom_level
	
	# Scale to minimap size and center
	screen_pos = screen_pos * (minimap_size / 200.0) + minimap_size / 2
	
	return screen_pos

func is_position_visible(world_pos: Vector2) -> bool:
# Check if position should be visible on minimap
	if not player_node:
		return false
	
	var distance = world_pos.distance_to(player_node.global_position)
	var view_range = 100.0 / zoom_level
	
	return distance <= view_range

func get_poi_data(poi_id: String) -> Dictionary:
# Get point of interest data
	# TODO: Integrate with dungeon/world data
	return {}

# Icon management functions
func add_npc_icon(npc_id: String, npc_position: Vector2):
# Add NPC icon to minimap
	if npc_icons.has(npc_id):
		return
	
	var icon = create_minimap_icon(npc_color, 6)
	npc_icons[npc_id] = icon
	minimap_frame.add_child(icon)

func add_enemy_icon(enemy_id: String, enemy_position: Vector2):
# Add enemy icon to minimap
	if enemy_icons.has(enemy_id):
		return
	
	var icon = create_minimap_icon(enemy_color, 5)
	enemy_icons[enemy_id] = icon
	minimap_frame.add_child(icon)

func add_item_icon(item_id: String, item_position: Vector2):
# Add item icon to minimap
	if item_icons.has(item_id):
		return
	
	var icon = create_minimap_icon(item_color, 4)
	item_icons[item_id] = icon
	minimap_frame.add_child(icon)

func add_poi_icon(poi_id: String, poi_position: Vector2, poi_type: String):
# Add point of interest icon to minimap
	if poi_icons.has(poi_id):
		return
	
	var color = poi_color
	match poi_type:
		"dungeon_entrance": color = Color.PURPLE
		"shop": color = Color.GOLD
		"quest_giver": color = Color.ORANGE
		"boss": color = Color.DARK_RED
	
	var icon = create_minimap_icon(color, 8)
	poi_icons[poi_id] = icon
	minimap_frame.add_child(icon)

func create_minimap_icon(color: Color, size: int) -> Control:
# Create a minimap icon
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -size / 2
	icon.offset_right = size / 2
	icon.offset_top = -size / 2
	icon.offset_bottom = size / 2
	
	var icon_panel = Panel.new()
	icon_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(icon_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = size / 2
	style.corner_radius_top_right = size / 2
	style.corner_radius_bottom_left = size / 2
	style.corner_radius_bottom_right = size / 2
	icon_panel.add_theme_stylebox_override("panel", style)
	
	return icon

func remove_npc_icon(npc_id: String):
# Remove NPC icon from minimap
	if npc_icons.has(npc_id):
		npc_icons[npc_id].queue_free()
		npc_icons.erase(npc_id)

func remove_enemy_icon(enemy_id: String):
# Remove enemy icon from minimap
	if enemy_icons.has(enemy_id):
		enemy_icons[enemy_id].queue_free()
		enemy_icons.erase(enemy_id)

func remove_item_icon(item_id: String):
# Remove item icon from minimap
	if item_icons.has(item_id):
		item_icons[item_id].queue_free()
		item_icons.erase(item_id)

# Zoom and navigation functions
func zoom_in():
# Zoom in on minimap
	zoom_level = min(zoom_level * 1.5, max_zoom)
	if minimap_camera:
		minimap_camera.zoom = Vector2.ONE * zoom_level

func zoom_out():
# Zoom out on minimap
	zoom_level = max(zoom_level / 1.5, min_zoom)
	if minimap_camera:
		minimap_camera.zoom = Vector2.ONE * zoom_level

func toggle_fullscreen():
# Toggle minimap fullscreen mode
	is_fullscreen = not is_fullscreen
	
	if is_fullscreen:
		# Expand to larger size
		anchor_left = 0.2
		anchor_right = 0.8
		anchor_top = 0.2
		anchor_bottom = 0.8
		offset_left = 0
		offset_right = 0
		offset_top = 0
		offset_bottom = 0
	else:
		# Return to corner position
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.0
		anchor_bottom = 0.0
		offset_left = -minimap_size.x - 20
		offset_right = -20
		offset_top = 20
		offset_bottom = minimap_size.y + 20

# Drawing functions
func _draw_fog_of_war():
# Draw fog of war overlay
	var cell_size = minimap_size / fog_resolution
	
	for x in range(fog_resolution):
		for y in range(fog_resolution):
			if not fog_grid[x][y]:
				var pos = Vector2(x * cell_size.x, y * cell_size.y)
				var rect = Rect2(pos, cell_size)
				fog_of_war.draw_rect(rect, fog_color)

# Event handlers
func _on_player_moved(new_position: Vector2):
# Handle player movement
	# Update is handled in update_minimap()
	pass

func _on_dungeon_changed(dungeon_id: String):
# Handle dungeon change
	current_dungeon = dungeon_id
	# Clear all dynamic icons
	clear_all_icons()
	# Load dungeon-specific POIs
	load_dungeon_pois(dungeon_id)

func _on_npc_spawned(npc_id: String, position: Vector2):
# Handle NPC spawn
	add_npc_icon(npc_id, position)

func _on_npc_despawned(npc_id: String):
# Handle NPC despawn
	remove_npc_icon(npc_id)

func _on_enemy_spawned(enemy_id: String, position: Vector2):
# Handle enemy spawn
	add_enemy_icon(enemy_id, position)

func _on_enemy_defeated(enemy_id: String):
# Handle enemy defeat
	remove_enemy_icon(enemy_id)

func _on_item_dropped(item_id: String, position: Vector2):
# Handle item drop
	add_item_icon(item_id, position)

func _on_item_collected(item_id: String):
# Handle item collection
	remove_item_icon(item_id)

func _on_minimap_input(event: InputEvent):
# Handle minimap input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Calculate world position from click
			var click_pos = event.position
			var world_pos = minimap_to_world_position(click_pos)
			
			# Emit navigation request
			event_bus.emit_signal("minimap_navigation_requested", world_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_fullscreen()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()

func minimap_to_world_position(minimap_pos: Vector2) -> Vector2:
# Convert minimap position to world position
	if not player_node:
		return Vector2.ZERO
	
	# Convert screen position to relative position
	var relative_pos = (minimap_pos - minimap_size / 2) / zoom_level
	relative_pos = relative_pos / (minimap_size / 200.0)
	
	# Add to player position
	return player_node.global_position + relative_pos

func clear_all_icons():
# Clear all dynamic icons
	for icon in npc_icons.values():
		icon.queue_free()
	for icon in enemy_icons.values():
		icon.queue_free()
	for icon in item_icons.values():
		icon.queue_free()
	
	npc_icons.clear()
	enemy_icons.clear()
	item_icons.clear()

func load_dungeon_pois(dungeon_id: String):
# Load points of interest for current dungeon
	var dungeon_data = DataLoader.load_json_data("res://data/dungeons/" + dungeon_id + ".json")
	if not dungeon_data:
		return
	
	var pois = dungeon_data.get("points_of_interest", [])
	for poi in pois:
		var poi_id = poi.get("id", "")
		var position = Vector2(poi.get("x", 0), poi.get("y", 0))
		var type = poi.get("type", "generic")
		
		if poi_id != "":
			add_poi_icon(poi_id, position, type)

func update_minimap_display():
# Update minimap display (renomeado para evitar duplicação)
	if not player_node or not minimap_camera:
		return
	
	# Update camera position
	minimap_camera.global_position = player_node.global_position
	
	# Update fog of war
	update_fog_of_war(player_node.global_position)
	
	# Update icon positions
	update_icon_positions()

func update_fog_of_war(player_pos: Vector2):
# Update fog of war based on player position
	# Convert world position to fog grid coordinates
	var grid_x = int((player_pos.x + 1000) / 2000.0 * fog_resolution)
	var grid_y = int((player_pos.y + 1000) / 2000.0 * fog_resolution)
	
	# Reveal area around player
	var reveal_radius = 3
	for x in range(max(0, grid_x - reveal_radius), min(fog_resolution, grid_x + reveal_radius + 1)):
		for y in range(max(0, grid_y - reveal_radius), min(fog_resolution, grid_y + reveal_radius + 1)):
			var distance = Vector2(x - grid_x, y - grid_y).length()
			if distance <= reveal_radius:
				fog_grid[x][y] = true
	
	# Redraw fog
	if fog_of_war:
		fog_of_war.queue_redraw()

func _draw_fog_of_war():
# Draw fog of war overlay
	if not fog_of_war:
		return
	
	var cell_size = minimap_size / fog_resolution
	
	for x in range(fog_resolution):
		for y in range(fog_resolution):
			if not fog_grid[x][y]:  # Unexplored
				var rect = Rect2(Vector2(x, y) * cell_size, cell_size)
				fog_of_war.draw_rect(rect, fog_color)

func update_icon_positions():
# Update positions of all icons
	if not player_node:
		return
	
	var player_world_pos = player_node.global_position
	
	# Update NPC icons
	for npc_id in npc_icons.keys():
		var icon = npc_icons[npc_id]
		var npc_node = get_npc_node(npc_id)
		if npc_node and icon:
			var relative_pos = npc_node.global_position - player_world_pos
			var minimap_pos = world_to_minimap_pos(relative_pos)
			icon.position = minimap_pos
			icon.visible = is_position_in_minimap(minimap_pos)
	
	# Update enemy icons
	for enemy_id in enemy_icons.keys():
		var icon = enemy_icons[enemy_id]
		var enemy_node = get_enemy_node(enemy_id)
		if enemy_node and icon:
			var relative_pos = enemy_node.global_position - player_world_pos
			var minimap_pos = world_to_minimap_pos(relative_pos)
			icon.position = minimap_pos
			icon.visible = is_position_in_minimap(minimap_pos)

func world_to_minimap_pos(world_relative_pos: Vector2) -> Vector2:
# Convert world position relative to player to minimap position
	var scale_factor = zoom_level * 0.1
	var minimap_pos = world_relative_pos * scale_factor
	minimap_pos += minimap_size * 0.5  # Center on minimap
	return minimap_pos

func is_position_in_minimap(pos: Vector2) -> bool:
# Check if position is within minimap bounds
	var center = minimap_size * 0.5
	var distance = pos.distance_to(center)
	return distance <= minimap_radius

# Icon Management
func add_npc_icon(npc_id: String, position: Vector2):
# Add NPC icon to minimap
	if npc_icons.has(npc_id):
		return
	
	var icon = create_minimap_icon(npc_color, 6)
	icon.name = "NPC_" + npc_id
	npc_icons[npc_id] = icon
	minimap_frame.add_child(icon)

func remove_npc_icon(npc_id: String):
# Remove NPC icon from minimap
	if npc_icons.has(npc_id):
		var icon = npc_icons[npc_id]
		icon.queue_free()
		npc_icons.erase(npc_id)

func add_enemy_icon(enemy_id: String, position: Vector2):
# Add enemy icon to minimap
	if enemy_icons.has(enemy_id):
		return
	
	var icon = create_minimap_icon(enemy_color, 5)
	icon.name = "Enemy_" + enemy_id
	enemy_icons[enemy_id] = icon
	minimap_frame.add_child(icon)

func remove_enemy_icon(enemy_id: String):
# Remove enemy icon from minimap
	if enemy_icons.has(enemy_id):
		var icon = enemy_icons[enemy_id]
		icon.queue_free()
		enemy_icons.erase(enemy_id)

func add_item_icon(item_id: String, position: Vector2):
# Add item icon to minimap
	if item_icons.has(item_id):
		return
	
	var icon = create_minimap_icon(item_color, 4)
	icon.name = "Item_" + item_id
	item_icons[item_id] = icon
	minimap_frame.add_child(icon)

func remove_item_icon(item_id: String):
# Remove item icon from minimap
	if item_icons.has(item_id):
		var icon = item_icons[item_id]
		icon.queue_free()
		item_icons.erase(item_id)

func create_minimap_icon(color: Color, size: int) -> Control:
# Create a minimap icon
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -size/2
	icon.offset_right = size/2
	icon.offset_top = -size/2
	icon.offset_bottom = size/2
	
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = size/2
	style.corner_radius_top_right = size/2
	style.corner_radius_bottom_left = size/2
	style.corner_radius_bottom_right = size/2
	panel.add_theme_stylebox_override("panel", style)
	
	return icon

# Input Handling
func _on_minimap_input(event: InputEvent):
# Handle minimap input
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if mouse_event.double_click:
					toggle_fullscreen()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()

func zoom_in():
# Zoom in minimap
	zoom_level = min(zoom_level * 1.2, max_zoom)
	if minimap_camera:
		minimap_camera.zoom = Vector2.ONE * zoom_level

func zoom_out():
# Zoom out minimap
	zoom_level = max(zoom_level * 0.8, min_zoom)
	if minimap_camera:
		minimap_camera.zoom = Vector2.ONE * zoom_level

func toggle_fullscreen():
# Toggle fullscreen mode
	is_fullscreen = not is_fullscreen
	
	if is_fullscreen:
		# Expand to center of screen
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		size = Vector2(400, 400)
		minimap_radius = 200.0
	else:
		# Return to corner
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.0
		anchor_bottom = 0.0
		offset_left = -minimap_size.x - 20
		offset_right = -20
		offset_top = 20
		offset_bottom = minimap_size.y + 20
		minimap_radius = 100.0
	
	# Update frame style
	update_minimap_frame_style()

func update_minimap_frame_style():
# Update minimap frame style
	if not minimap_frame:
		return
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = player_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = minimap_radius
	style.corner_radius_top_right = minimap_radius
	style.corner_radius_bottom_left = minimap_radius
	style.corner_radius_bottom_right = minimap_radius
	minimap_frame.add_theme_stylebox_override("panel", style)

# Event Handlers
func _on_player_moved(new_position: Vector2):
# Handle player movement
	update_fog_of_war(new_position)

func _on_dungeon_changed(dungeon_id: String):
# Handle dungeon change
	current_dungeon = dungeon_id
	clear_all_icons()
	reset_fog_of_war()

func _on_npc_spawned(npc_id: String, position: Vector2):
# Handle NPC spawn
	add_npc_icon(npc_id, position)

func _on_npc_despawned(npc_id: String):
# Handle NPC despawn
	remove_npc_icon(npc_id)

func _on_enemy_spawned(enemy_id: String, position: Vector2):
# Handle enemy spawn
	add_enemy_icon(enemy_id, position)

func _on_enemy_defeated(enemy_id: String, position: Vector2, player_level: int):
# Handle enemy defeat
	remove_enemy_icon(enemy_id)

func _on_item_dropped(item_id: String, position: Vector2):
# Handle item drop
	add_item_icon(item_id, position)

func _on_item_collected(item_id: String, quantity: int):
# Handle item collection
	remove_item_icon(item_id)

# Utility Functions
func clear_all_icons():
# Clear all minimap icons
	for npc_id in npc_icons.keys():
		remove_npc_icon(npc_id)
	
	for enemy_id in enemy_icons.keys():
		remove_enemy_icon(enemy_id)
	
	for item_id in item_icons.keys():
		remove_item_icon(item_id)

func reset_fog_of_war():
# Reset fog of war for new dungeon
	for x in range(fog_resolution):
		for y in range(fog_resolution):
			fog_grid[x][y] = false
	
	if fog_of_war:
		fog_of_war.queue_redraw()

func get_npc_node(npc_id: String) -> Node2D:
# Get NPC node by ID
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.has_method("get_npc_id") and npc.get_npc_id() == npc_id:
			return npc
	return null

func get_enemy_node(enemy_id: String) -> Node2D:
# Get enemy node by ID
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("get_enemy_id") and enemy.get_enemy_id() == enemy_id:
			return enemy
	return null

# Save/Load Support
func get_exploration_data() -> Dictionary:
# Get exploration data for saving
	return {
		"dungeon": current_dungeon,
		"explored_areas": explored_areas,
		"fog_grid": fog_grid
	}

func load_exploration_data(data: Dictionary):
# Load exploration data from save
	if data.has("dungeon"):
		current_dungeon = data.dungeon
	
	if data.has("explored_areas"):
		explored_areas = data.explored_areas
	
	if data.has("fog_grid"):
		fog_grid = data.fog_grid
		if fog_of_war:
			fog_of_war.queue_redraw()

# Debug Functions
func debug_reveal_all():
# Debug: Reveal entire map
	for x in range(fog_resolution):
		for y in range(fog_resolution):
			fog_grid[x][y] = true
	
	if fog_of_war:
		fog_of_war.queue_redraw()

func debug_hide_all():
# Debug: Hide entire map
	reset_fog_of_war()

func debug_add_test_icons():
# Debug: Add test icons
	add_npc_icon("test_npc", Vector2.ZERO)
	add_enemy_icon("test_enemy", Vector2(100, 100))
	add_item_icon("test_item", Vector2(-100, -100))
