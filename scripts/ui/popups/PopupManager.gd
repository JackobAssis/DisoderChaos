class_name PopupManager
extends Control

## Sistema central para gerenciar popups (mensagens, tutoriais, recompensas)

@onready var popup_container: Control = $PopupContainer

# Templates de popup
var message_popup_scene: PackedScene
var tutorial_popup_scene: PackedScene  
var reward_popup_scene: PackedScene
var confirmation_popup_scene: PackedScene

# Queue de popups
var popup_queue: Array[Dictionary] = []
var current_popup: Control = null
var is_popup_active: bool = false

# Configurações
var max_popup_duration: float = 10.0
var auto_close_delay: float = 3.0

signal popup_shown(popup_type: String, popup_data: Dictionary)
signal popup_closed(popup_type: String, result: Variant)
signal popup_confirmed(popup_id: String, confirmed: bool)

func _ready():
	setup_popup_manager()
	setup_connections()

func setup_popup_manager():
	"""Configura o sistema de popups"""
	# Container para popups
	popup_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Conecta com EventBus
	if EventBus:
		EventBus.show_message_popup.connect(show_message)
		EventBus.show_tutorial_popup.connect(show_tutorial)
		EventBus.show_reward_popup.connect(show_reward)
		EventBus.show_confirmation_popup.connect(show_confirmation)

func setup_connections():
	"""Conecta sinais"""
	pass

# === TIPOS DE POPUP ===

func show_message(title: String, text: String, type: String = "info", duration: float = 3.0):
	"""Mostra popup de mensagem simples"""
	var popup_data = {
		"type": "message",
		"title": title,
		"text": text,
		"message_type": type,
		"duration": duration
	}
	
	queue_popup(popup_data)

func show_tutorial(title: String, text: String, image_path: String = "", skip_button: bool = true):
	"""Mostra popup de tutorial"""
	var popup_data = {
		"type": "tutorial", 
		"title": title,
		"text": text,
		"image": image_path,
		"skippable": skip_button
	}
	
	queue_popup(popup_data)

func show_reward(title: String, items: Array[Dictionary], xp: int = 0, gold: int = 0):
	"""Mostra popup de recompensas"""
	var popup_data = {
		"type": "reward",
		"title": title,
		"items": items,
		"xp": xp,
		"gold": gold
	}
	
	queue_popup(popup_data)

func show_confirmation(title: String, text: String, confirm_text: String = "Confirmar", cancel_text: String = "Cancelar", popup_id: String = ""):
	"""Mostra popup de confirmação"""
	var popup_data = {
		"type": "confirmation",
		"title": title,
		"text": text,
		"confirm_text": confirm_text,
		"cancel_text": cancel_text,
		"popup_id": popup_id if popup_id != "" else generate_popup_id()
	}
	
	queue_popup(popup_data)

# === QUEUE MANAGEMENT ===

func queue_popup(popup_data: Dictionary):
	"""Adiciona popup à fila"""
	popup_queue.append(popup_data)
	process_queue()

func process_queue():
	"""Processa próximo popup na fila"""
	if is_popup_active or popup_queue.is_empty():
		return
	
	var popup_data = popup_queue.pop_front()
	create_and_show_popup(popup_data)

func create_and_show_popup(popup_data: Dictionary):
	"""Cria e mostra popup baseado no tipo"""
	match popup_data.type:
		"message":
			current_popup = create_message_popup(popup_data)
		"tutorial":
			current_popup = create_tutorial_popup(popup_data)
		"reward":
			current_popup = create_reward_popup(popup_data)
		"confirmation":
			current_popup = create_confirmation_popup(popup_data)
		_:
			print("Tipo de popup desconhecido: ", popup_data.type)
			return
	
	if current_popup:
		popup_container.add_child(current_popup)
		animate_popup_in(current_popup)
		is_popup_active = true
		popup_shown.emit(popup_data.type, popup_data)

# === CRIAÇÃO DE POPUPS ===

func create_message_popup(data: Dictionary) -> Control:
	"""Cria popup de mensagem"""
	var popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	
	# Popup panel
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	panel.custom_minimum_size = Vector2(400, 200)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-200, -100)
	popup.add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	panel.add_child(vbox)
	
	# Ícone baseado no tipo
	var icon_container = HBoxContainer.new()
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon = create_message_icon(data.get("message_type", "info"))
	icon_container.add_child(icon)
	vbox.add_child(icon_container)
	
	# Título
	var title = Label.new()
	title.text = data.get("title", "Mensagem")
	title.add_theme_color_override("font_color", get_message_color(data.get("message_type", "info")))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Espaçador
	vbox.add_child(Control.new())
	
	# Texto
	var text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.text = data.get("text", "")
	text_label.fit_content = true
	text_label.custom_minimum_size.y = 80
	vbox.add_child(text_label)
	
	# Auto-close timer se especificado
	var duration = data.get("duration", 0.0)
	if duration > 0:
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.timeout.connect(func(): close_current_popup("timeout"))
		popup.add_child(timer)
		timer.start()
	
	# Click para fechar
	overlay.gui_input.connect(func(event): 
		if event is InputEventMouseButton and event.pressed:
			close_current_popup("clicked"))
	
	return popup

func create_tutorial_popup(data: Dictionary) -> Control:
	"""Cria popup de tutorial"""
	var popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	
	# Popup panel (maior que message)
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	panel.custom_minimum_size = Vector2(600, 400)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-300, -200)
	popup.add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30
	vbox.offset_right = -30
	vbox.offset_top = 30
	vbox.offset_bottom = -30
	panel.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	
	var title = Label.new()
	title.text = data.get("title", "Tutorial")
	title.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	# Botão skip se permitido
	if data.get("skippable", true):
		var skip_btn = Button.new()
		skip_btn.text = "Pular"
		skip_btn.add_theme_stylebox_override("normal", 
			UIThemeManager.create_button_style(
				UIThemeManager.Colors.WARNING_ORANGE,
				UIThemeManager.Colors.ERROR_RED,
				UIThemeManager.Colors.ACCENT_GOLD
			))
		skip_btn.pressed.connect(func(): close_current_popup("skipped"))
		header.add_child(skip_btn)
	
	vbox.add_child(header)
	
	# Imagem se fornecida
	var image_path = data.get("image", "")
	if image_path != "" and ResourceLoader.exists(image_path):
		var image = TextureRect.new()
		image.texture = load(image_path)
		image.custom_minimum_size.y = 200
		image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		vbox.add_child(image)
	
	# Texto do tutorial
	var text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.text = data.get("text", "")
	text_label.fit_content = true
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_label)
	
	# Botão OK
	var ok_btn = Button.new()
	ok_btn.text = "Entendi"
	ok_btn.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.SUCCESS_GREEN,
			UIThemeManager.Colors.ACCENT_GOLD,
			UIThemeManager.Colors.CYBER_CYAN
		))
	ok_btn.pressed.connect(func(): close_current_popup("completed"))
	vbox.add_child(ok_btn)
	
	return popup

func create_reward_popup(data: Dictionary) -> Control:
	"""Cria popup de recompensas"""
	var popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	
	# Popup panel
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	panel.custom_minimum_size = Vector2(500, 350)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-250, -175)
	popup.add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 25
	vbox.offset_right = -25
	vbox.offset_top = 25
	vbox.offset_bottom = -25
	panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = data.get("title", "Recompensas Recebidas!")
	title.add_theme_color_override("font_color", UIThemeManager.Colors.ACCENT_GOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Separador
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# XP e Gold se existirem
	var resources_container = HBoxContainer.new()
	resources_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var xp = data.get("xp", 0)
	if xp > 0:
		var xp_label = Label.new()
		xp_label.text = "XP: +" + str(xp)
		xp_label.add_theme_color_override("font_color", UIThemeManager.Colors.XP_YELLOW)
		xp_label.add_theme_font_size_override("font_size", 16)
		resources_container.add_child(xp_label)
		
		var spacer = Control.new()
		spacer.custom_minimum_size.x = 20
		resources_container.add_child(spacer)
	
	var gold = data.get("gold", 0)
	if gold > 0:
		var gold_label = Label.new()
		gold_label.text = "Ouro: +" + str(gold)
		gold_label.add_theme_color_override("font_color", UIThemeManager.Colors.ACCENT_GOLD)
		gold_label.add_theme_font_size_override("font_size", 16)
		resources_container.add_child(gold_label)
	
	if resources_container.get_child_count() > 0:
		vbox.add_child(resources_container)
	
	# Itens
	var items = data.get("items", [])
	if items.size() > 0:
		var items_label = Label.new()
		items_label.text = "Itens Recebidos:"
		items_label.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
		items_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(items_label)
		
		# Grid de itens
		var items_grid = GridContainer.new()
		items_grid.columns = 4
		
		for item in items:
			var item_container = create_reward_item(item)
			items_grid.add_child(item_container)
		
		vbox.add_child(items_grid)
	
	# Botão OK
	var ok_btn = Button.new()
	ok_btn.text = "Coletar"
	ok_btn.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.ACCENT_GOLD,
			UIThemeManager.Colors.CYBER_CYAN,
			UIThemeManager.Colors.SUCCESS_GREEN
		))
	ok_btn.pressed.connect(func(): close_current_popup("collected"))
	vbox.add_child(ok_btn)
	
	return popup

func create_confirmation_popup(data: Dictionary) -> Control:
	"""Cria popup de confirmação"""
	var popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	
	# Popup panel
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	panel.custom_minimum_size = Vector2(400, 250)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-200, -125)
	popup.add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 25
	vbox.offset_right = -25
	vbox.offset_top = 25
	vbox.offset_bottom = -25
	panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = data.get("title", "Confirmar")
	title.add_theme_color_override("font_color", UIThemeManager.Colors.WARNING_ORANGE)
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Espaçador
	vbox.add_child(Control.new())
	
	# Texto
	var text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.text = data.get("text", "Tem certeza?")
	text_label.fit_content = true
	text_label.custom_minimum_size.y = 100
	vbox.add_child(text_label)
	
	# Botões
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Cancelar
	var cancel_btn = Button.new()
	cancel_btn.text = data.get("cancel_text", "Cancelar")
	cancel_btn.custom_minimum_size.x = 120
	cancel_btn.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.PRIMARY_DARK,
			UIThemeManager.Colors.PRIMARY_NAVY,
			UIThemeManager.Colors.CYBER_CYAN
		))
	cancel_btn.pressed.connect(func(): 
		close_current_popup("cancelled")
		popup_confirmed.emit(data.get("popup_id", ""), false)
	)
	buttons_container.add_child(cancel_btn)
	
	# Espaçador
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 20
	buttons_container.add_child(spacer)
	
	# Confirmar
	var confirm_btn = Button.new()
	confirm_btn.text = data.get("confirm_text", "Confirmar")
	confirm_btn.custom_minimum_size.x = 120
	confirm_btn.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.SUCCESS_GREEN,
			UIThemeManager.Colors.ACCENT_GOLD,
			UIThemeManager.Colors.TECH_ORANGE
		))
	confirm_btn.pressed.connect(func(): 
		close_current_popup("confirmed")
		popup_confirmed.emit(data.get("popup_id", ""), true)
	)
	buttons_container.add_child(confirm_btn)
	
	vbox.add_child(buttons_container)
	
	return popup

func create_reward_item(item: Dictionary) -> Control:
	"""Cria visual de um item de recompensa"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(80, 80)
	
	# Ícone do item
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	if item.has("icon"):
		icon.texture = load(item.icon) if item.icon is String else item.icon
	container.add_child(icon)
	
	# Nome
	var name_label = Label.new()
	name_label.text = item.get("name", "Item")
	name_label.add_theme_color_override("font_color", get_rarity_color(item.get("rarity", "common")))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(name_label)
	
	# Quantidade se > 1
	var quantity = item.get("quantity", 1)
	if quantity > 1:
		var qty_label = Label.new()
		qty_label.text = "x" + str(quantity)
		qty_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(qty_label)
	
	return container

# === HELPER FUNCTIONS ===

func create_message_icon(type: String) -> TextureRect:
	"""Cria ícone para tipo de mensagem"""
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	
	# TODO: Carregar ícones apropriados
	match type:
		"success":
			icon.modulate = UIThemeManager.Colors.SUCCESS_GREEN
		"warning":
			icon.modulate = UIThemeManager.Colors.WARNING_ORANGE
		"error":
			icon.modulate = UIThemeManager.Colors.ERROR_RED
		_: # info
			icon.modulate = UIThemeManager.Colors.INFO_BLUE
	
	return icon

func get_message_color(type: String) -> Color:
	"""Retorna cor para tipo de mensagem"""
	match type:
		"success": return UIThemeManager.Colors.SUCCESS_GREEN
		"warning": return UIThemeManager.Colors.WARNING_ORANGE
		"error": return UIThemeManager.Colors.ERROR_RED
		_: return UIThemeManager.Colors.INFO_BLUE

func get_rarity_color(rarity: String) -> Color:
	"""Retorna cor da raridade"""
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)
		"epic": return Color(0.6, 0.3, 0.9)
		"rare": return Color(0.0, 0.5, 1.0)
		"uncommon": return Color(0.0, 1.0, 0.0)
		_: return UIThemeManager.Colors.TEXT_PRIMARY

func generate_popup_id() -> String:
	"""Gera ID único para popup"""
	return "popup_" + str(Time.get_unix_time_from_system())

# === ANIMATION ===

func animate_popup_in(popup: Control):
	"""Animação de entrada do popup"""
	popup.modulate = Color.TRANSPARENT
	popup.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.parallel().tween_property(popup, "modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(popup, "scale", Vector2.ONE, 0.3)

func animate_popup_out(popup: Control, callback: Callable):
	"""Animação de saída do popup"""
	var tween = create_tween()
	tween.parallel().tween_property(popup, "modulate", Color.TRANSPARENT, 0.2)
	tween.parallel().tween_property(popup, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_callback(callback)

func close_current_popup(result: String):
	"""Fecha popup atual"""
	if not current_popup:
		return
	
	var popup_type = get_popup_type_from_current()
	popup_closed.emit(popup_type, result)
	
	animate_popup_out(current_popup, func():
		current_popup.queue_free()
		current_popup = null
		is_popup_active = false
		process_queue()
	)

func get_popup_type_from_current() -> String:
	"""Determina tipo do popup atual"""
	# Método simples baseado no nome da classe ou metadata
	if current_popup:
		return "unknown"  # TODO: Implementar identificação
	return ""

# === PUBLIC INTERFACE ===

func close_all_popups():
	"""Fecha todos os popups"""
	popup_queue.clear()
	if current_popup:
		close_current_popup("force_closed")

func get_popup_count() -> int:
	"""Retorna quantidade de popups na fila"""
	var count = popup_queue.size()
	if is_popup_active:
		count += 1
	return count

func is_any_popup_active() -> bool:
	"""Verifica se há popup ativo"""
	return is_popup_active