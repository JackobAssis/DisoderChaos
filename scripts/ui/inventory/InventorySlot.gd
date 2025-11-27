class_name InventorySlot
extends Control

## Slot individual do inventÃ¡rio com suporte a drag & drop

@onready var background: ColorRect
@onready var item_icon: TextureRect
@onready var quantity_label: Label
@onready var rarity_border: ColorRect

var position: Vector2i
var item_data: Dictionary = {}
var is_dragging: bool = false
var drag_threshold: float = 5.0
var drag_start_pos: Vector2

signal item_clicked(slot: InventorySlot)
signal item_right_clicked(slot: InventorySlot)
signal drag_started(slot: InventorySlot)
signal drop_attempted(from_slot: InventorySlot, to_slot: InventorySlot)
signal item_hovered(slot: InventorySlot)
signal item_unhovered(slot: InventorySlot)

func _ready():
	setup_slot_ui()

func setup(pos: Vector2i, size: Vector2):
# Configura slot com posiÃ§Ã£o e tamanho
	position = pos
	custom_minimum_size = size
	
func setup_slot_ui():
# Cria interface do slot
	# Background principal
	background = ColorRect.new()
	background.color = UIThemeManager.Colors.PRIMARY_DARK
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	# Borda de raridade (inicialmente invisÃ­vel)
	rarity_border = ColorRect.new()
	rarity_border.color = Color.TRANSPARENT
	rarity_border.anchors_preset = Control.PRESET_FULL_RECT
	rarity_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rarity_border)
	
	# Ãcone do item
	item_icon = TextureRect.new()
	item_icon.anchors_preset = Control.PRESET_CENTER
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item_icon)
	
	# Label de quantidade
	quantity_label = Label.new()
	quantity_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	quantity_label.offset_left = -30
	quantity_label.offset_top = -20
	quantity_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	quantity_label.add_theme_font_size_override("font_size", 12)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.visible = false
	add_child(quantity_label)
	
	# Conecta eventos de mouse
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent):
# Gerencia input no slot
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				drag_start_pos = event.global_position
				_on_left_click()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_on_right_click()
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and is_dragging:
				_on_drag_end(event.global_position)
	
	elif event is InputEventMouseMotion and has_item():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_dragging:
			var distance = event.global_position.distance_to(drag_start_pos)
			if distance > drag_threshold:
				_start_drag()

func _on_left_click():
# Click esquerdo no slot
	item_clicked.emit(self)

func _on_right_click():
# Click direito no slot
	if has_item():
		item_right_clicked.emit(self)

func _start_drag():
# Inicia drag do item
	if not has_item():
		return
	
	is_dragging = true
	drag_started.emit(self)

func _on_drag_end(global_pos: Vector2):
# Termina drag do item
	if not is_dragging:
		return
	
	is_dragging = false
	
	# Encontra slot de destino
	var target_slot = find_slot_at_position(global_pos)
	if target_slot and target_slot != self:
		drop_attempted.emit(self, target_slot)

func find_slot_at_position(global_pos: Vector2) -> InventorySlot:
# Encontra slot na posiÃ§Ã£o do mouse
	var viewport = get_viewport()
	var nodes_at_pos = []
	
	# Busca por InventorySlot na posiÃ§Ã£o
	for node in get_tree().get_nodes_in_group("inventory_slots"):
		if node is InventorySlot:
			var rect = Rect2(node.global_position, node.size)
			if rect.has_point(global_pos):
				return node
	
	return null

func _on_mouse_entered():
# Mouse entra no slot
	if has_item():
		# Efeito hover
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE * 1.1, 0.1)
		
		item_hovered.emit(self)

func _on_mouse_exited():
# Mouse sai do slot
	if has_item():
		# Remove efeito hover
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)
		
		item_unhovered.emit(self)

func set_item(data: Dictionary, texture: Texture2D = null):
# Define item no slot
	item_data = data
	
	# Ãcone
	if texture:
		item_icon.texture = texture
	elif data.has("icon"):
		item_icon.texture = load(data.icon) if data.icon is String else data.icon
	
	# Quantidade
	var quantity = data.get("quantity", 1)
	if quantity > 1:
		quantity_label.text = str(quantity)
		quantity_label.visible = true
	else:
		quantity_label.visible = false
	
	# Borda de raridade
	var rarity = data.get("rarity", "common")
	var rarity_color = get_rarity_color(rarity)
	
	if rarity != "common":
		rarity_border.color = rarity_color
		rarity_border.color.a = 0.8
		
		# Efeito glow para itens raros
		if rarity in ["epic", "legendary"]:
			UIThemeManager.apply_glow_effect(rarity_border, rarity_color)
	else:
		rarity_border.color = Color.TRANSPARENT
	
	# Adiciona ao grupo para drag & drop
	add_to_group("inventory_slots")

func clear_item():
# Remove item do slot
	item_data = {}
	item_icon.texture = null
	quantity_label.visible = false
	rarity_border.color = Color.TRANSPARENT
	
	# Remove do grupo
	remove_from_group("inventory_slots")

func has_item() -> bool:
# Verifica se slot tem item
	return not item_data.is_empty()

func can_stack_with(other_data: Dictionary) -> bool:
# Verifica se pode empilhar com outro item
	if not has_item():
		return true
	
	# Deve ser o mesmo item e ter propriedade stackable
	return (item_data.get("id", "") == other_data.get("id", "") and 
			item_data.get("stackable", false) and
			get_current_stack_size() < get_max_stack_size())

func get_current_stack_size() -> int:
# Retorna quantidade atual empilhada
	return item_data.get("quantity", 1)

func get_max_stack_size() -> int:
# Retorna mÃ¡ximo que pode empilhar
	return item_data.get("max_stack", 1)

func add_to_stack(quantity: int) -> int:
# Adiciona quantidade ao stack, retorna sobra
	if not item_data.get("stackable", false):
		return quantity
	
	var current = get_current_stack_size()
	var max_stack = get_max_stack_size()
	var can_add = min(quantity, max_stack - current)
	
	if can_add > 0:
		item_data["quantity"] = current + can_add
		
		# Atualiza UI
		if item_data["quantity"] > 1:
			quantity_label.text = str(item_data["quantity"])
			quantity_label.visible = true
		else:
			quantity_label.visible = false
	
	return quantity - can_add

func remove_from_stack(quantity: int) -> int:
# Remove quantidade do stack, retorna quanto foi removido
	var current = get_current_stack_size()
	var to_remove = min(quantity, current)
	
	item_data["quantity"] = current - to_remove
	
	# Atualiza UI
	if item_data["quantity"] > 1:
		quantity_label.text = str(item_data["quantity"])
	elif item_data["quantity"] == 1:
		quantity_label.visible = false
	else:
		# Stack vazio, remove item
		clear_item()
	
	return to_remove

func get_rarity_color(rarity: String) -> Color:
# Retorna cor da raridade
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)  # Dourado
		"epic": return Color(0.6, 0.3, 0.9)       # Roxo
		"rare": return Color(0.0, 0.5, 1.0)       # Azul
		"uncommon": return Color(0.0, 1.0, 0.0)   # Verde
		_: return Color.WHITE                       # Comum

func highlight_as_valid_drop():
# Destaca slot como destino vÃ¡lido
	background.color = UIThemeManager.Colors.SUCCESS_GREEN * 0.3

func highlight_as_invalid_drop():
# Destaca slot como destino invÃ¡lido
	background.color = UIThemeManager.Colors.ERROR_RED * 0.3

func clear_highlight():
# Remove destaque
	background.color = UIThemeManager.Colors.PRIMARY_DARK

func play_pickup_animation():
# AnimaÃ§Ã£o ao pegar item
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func play_drop_animation():
# AnimaÃ§Ã£o ao dropar item
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", 5, 0.1)
	tween.tween_property(self, "rotation_degrees", -5, 0.1)
	tween.tween_property(self, "rotation_degrees", 0, 0.1)

func get_item_tooltip_text() -> String:
# Retorna texto para tooltip
	if not has_item():
		return ""
	
	var tooltip = item_data.get("name", "Item Desconhecido")
	
	if item_data.has("rarity"):
		tooltip += "\n[" + item_data.rarity.capitalize() + "]"
	
	if get_current_stack_size() > 1:
		tooltip += "\nQuantidade: " + str(get_current_stack_size())
	
	if item_data.has("description"):
		tooltip += "\n" + item_data.description
	
	return tooltip
