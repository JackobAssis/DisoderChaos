class_name OptionsMenu
extends Control

## Menu de configuraÃ§Ãµes com abas para VÃ­deo, Ãudio e Controles

@onready var tab_container: TabContainer = $Background/TabContainer

# Aba VÃ­deo
@onready var resolution_option: OptionButton = $Background/TabContainer/Video/VBox/Resolution/OptionButton
@onready var fullscreen_check: CheckBox = $Background/TabContainer/Video/VBox/Fullscreen/CheckBox
@onready var vsync_check: CheckBox = $Background/TabContainer/Video/VBox/VSync/CheckBox
@onready var quality_slider: HSlider = $Background/TabContainer/Video/VBox/Quality/HSlider
@onready var brightness_slider: HSlider = $Background/TabContainer/Video/VBox/Brightness/HSlider

# Aba Ãudio
@onready var master_slider: HSlider = $Background/TabContainer/Audio/VBox/Master/HSlider
@onready var music_slider: HSlider = $Background/TabContainer/Audio/VBox/Music/HSlider
@onready var sfx_slider: HSlider = $Background/TabContainer/Audio/VBox/SFX/HSlider
@onready var voice_slider: HSlider = $Background/TabContainer/Audio/VBox/Voice/HSlider
@onready var mute_check: CheckBox = $Background/TabContainer/Audio/VBox/Mute/CheckBox

# Aba Controles
@onready var key_bindings_container: VBoxContainer = $Background/TabContainer/Controls/ScrollContainer/VBox
@onready var mouse_sensitivity_slider: HSlider = $Background/TabContainer/Controls/VBox/Sensitivity/HSlider
@onready var invert_y_check: CheckBox = $Background/TabContainer/Controls/VBox/InvertY/CheckBox

# BotÃµes principais
@onready var apply_btn: Button = $Background/ButtonsContainer/ApplyButton
@onready var cancel_btn: Button = $Background/ButtonsContainer/CancelButton
@onready var defaults_btn: Button = $Background/ButtonsContainer/DefaultsButton

# Dados das configuraÃ§Ãµes
var settings_data: Dictionary = {}
var key_mappings: Dictionary = {}
var resolution_options: Array[Vector2] = [
	Vector2(1920, 1080),
	Vector2(1680, 1050),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1024, 768)
]

signal settings_applied(settings: Dictionary)
signal settings_cancelled

func _ready():
	setup_ui_theme()
	setup_connections()
	setup_resolution_options()
	setup_key_bindings()
	load_current_settings()

func setup_ui_theme():
# Aplica tema dark fantasy
	# Background
	var bg = $Background as ColorRect
	if bg:
		bg.color = UIThemeManager.Colors.BG_POPUP
	
	# TabContainer
	tab_container.add_theme_stylebox_override("panel", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	
	# BotÃµes
	var buttons = [apply_btn, cancel_btn, defaults_btn]
	for btn in buttons:
		if btn:
			btn.add_theme_stylebox_override("normal", 
				UIThemeManager.create_button_style(
					UIThemeManager.Colors.PRIMARY_DARK,
					UIThemeManager.Colors.PRIMARY_NAVY,
					UIThemeManager.Colors.CYBER_CYAN
				))
			btn.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	
	# Sliders
	var sliders = [quality_slider, brightness_slider, master_slider, music_slider, 
				   sfx_slider, voice_slider, mouse_sensitivity_slider]
	for slider in sliders:
		if slider:
			# Slider fill (parte preenchida)
			slider.add_theme_stylebox_override("slider", 
				UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.CYBER_CYAN))
			# Grabber (botÃ£o deslizante)
			slider.add_theme_stylebox_override("grabber_area", 
				UIThemeManager.create_button_style(
					UIThemeManager.Colors.ACCENT_GOLD,
					UIThemeManager.Colors.TECH_ORANGE,
					UIThemeManager.Colors.CYBER_CYAN
				))

func setup_connections():
# Conecta todos os controles
	# BotÃµes principais
	apply_btn.pressed.connect(_on_apply_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	defaults_btn.pressed.connect(_on_defaults_pressed)
	
	# VÃ­deo
	resolution_option.item_selected.connect(_on_resolution_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	quality_slider.value_changed.connect(_on_quality_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	
	# Ãudio
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	voice_slider.value_changed.connect(_on_voice_volume_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	
	# Controles
	mouse_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	invert_y_check.toggled.connect(_on_invert_y_toggled)

func setup_resolution_options():
# Popula opÃ§Ãµes de resoluÃ§Ã£o
	resolution_option.clear()
	for res in resolution_options:
		resolution_option.add_item("%dx%d" % [res.x, res.y])

func setup_key_bindings():
# Cria interface para configuraÃ§Ã£o de teclas
	var action_names = {
		"move_up": "Mover para Cima",
		"move_down": "Mover para Baixo", 
		"move_left": "Mover para Esquerda",
		"move_right": "Mover para Direita",
		"jump": "Pular",
		"dash": "Dash",
		"attack": "Atacar",
		"block": "Bloquear",
		"use_item": "Usar Item",
		"inventory": "InventÃ¡rio",
		"character": "Personagem",
		"pause": "Pausar",
		"interact": "Interagir"
	}
	
	for action in action_names:
		create_key_binding_row(action, action_names[action])

func create_key_binding_row(action: String, display_name: String):
# Cria linha para configuraÃ§Ã£o de tecla
	var row = HBoxContainer.new()
	
	# Label do nome da aÃ§Ã£o
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size.x = 200
	label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	row.add_child(label)
	
	# BotÃ£o para mostrar tecla atual
	var key_button = Button.new()
	key_button.custom_minimum_size = Vector2(150, 30)
	update_key_button_text(key_button, action)
	key_button.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.PRIMARY_DARK,
			UIThemeManager.Colors.PRIMARY_NAVY,
			UIThemeManager.Colors.CYBER_CYAN
		))
	key_button.pressed.connect(func(): start_key_rebinding(action, key_button))
	row.add_child(key_button)
	
	# BotÃ£o reset
	var reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(80, 30)
	reset_button.add_theme_stylebox_override("normal", 
		UIThemeManager.create_button_style(
			UIThemeManager.Colors.WARNING_ORANGE,
			UIThemeManager.Colors.ERROR_RED,
			UIThemeManager.Colors.ACCENT_GOLD
		))
	reset_button.pressed.connect(func(): reset_key_binding(action, key_button))
	row.add_child(reset_button)
	
	key_bindings_container.add_child(row)
	key_mappings[action] = key_button

func update_key_button_text(button: Button, action: String):
# Atualiza texto do botÃ£o com a tecla atual
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			button.text = OS.get_keycode_string(event.physical_keycode)
		elif event is InputEventMouseButton:
			button.text = "Mouse " + str(event.button_index)
	else:
		button.text = "NÃ£o definido"

func start_key_rebinding(action: String, button: Button):
# Inicia processo de redefinir tecla
	button.text = "Pressione uma tecla..."
	button.disabled = true
	
	# Espera input
	var input_event = await get_viewport().gui_input
	
	if input_event is InputEventKey and input_event.pressed:
		# Remove eventos antigos
		for event in InputMap.action_get_events(action):
			InputMap.action_erase_event(action, event)
		
		# Adiciona novo evento
		InputMap.action_add_event(action, input_event)
		update_key_button_text(button, action)
	
	button.disabled = false

func reset_key_binding(action: String, button: Button):
# Reseta tecla para padrÃ£o
	# Aqui vocÃª definiria as teclas padrÃ£o
	# Por simplicidade, apenas limpa
	InputMap.action_erase_events(action)
	update_key_button_text(button, action)

func load_current_settings():
# Carrega configuraÃ§Ãµes atuais
	# VÃ­deo
	var window = get_window()
	if window:
		var current_res = window.size
		for i in range(resolution_options.size()):
			if resolution_options[i] == current_res:
				resolution_option.selected = i
				break
		
		fullscreen_check.button_pressed = window.mode == Window.MODE_FULLSCREEN
	
	# Ãudio (valores padrÃ£o)
	master_slider.value = 100
	music_slider.value = 80
	sfx_slider.value = 90
	voice_slider.value = 85
	
	# Controles
	mouse_sensitivity_slider.value = 50
	
	# Outros
	quality_slider.value = 75
	brightness_slider.value = 50

# === VIDEO HANDLERS ===
func _on_resolution_changed(index: int):
# Muda resoluÃ§Ã£o
	var new_res = resolution_options[index]
	get_window().size = new_res

func _on_fullscreen_toggled(pressed: bool):
# Alterna fullscreen
	if pressed:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED

func _on_vsync_toggled(pressed: bool):
# Alterna V-Sync
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_quality_changed(value: float):
# Muda qualidade grÃ¡fica
	# Implementar mudanÃ§a de qualidade baseada no valor
	print("Quality changed to: ", value)

func _on_brightness_changed(value: float):
# Muda brilho
	# Implementar mudanÃ§a de brilho
	print("Brightness changed to: ", value)

# === AUDIO HANDLERS ===
func _on_master_volume_changed(value: float):
# Muda volume master
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))

func _on_music_volume_changed(value: float):
# Muda volume da mÃºsica
	var bus_index = AudioServer.get_bus_index("Music")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))

func _on_sfx_volume_changed(value: float):
# Muda volume dos efeitos
	var bus_index = AudioServer.get_bus_index("SFX")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))

func _on_voice_volume_changed(value: float):
# Muda volume das vozes
	var bus_index = AudioServer.get_bus_index("Voice")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))

func _on_mute_toggled(pressed: bool):
# Muta/desmuta Ã¡udio
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), pressed)

# === CONTROLS HANDLERS ===
func _on_sensitivity_changed(value: float):
# Muda sensibilidade do mouse
	# Implementar mudanÃ§a de sensibilidade
	print("Mouse sensitivity changed to: ", value)

func _on_invert_y_toggled(pressed: bool):
# Inverte eixo Y
	# Implementar inversÃ£o do Y
	print("Invert Y: ", pressed)

# === BUTTON HANDLERS ===
func _on_apply_pressed():
# Aplica configuraÃ§Ãµes
	save_settings()
	settings_applied.emit(settings_data)
	hide()

func _on_cancel_pressed():
# Cancela mudanÃ§as
	load_current_settings()  # Restaura valores anteriores
	settings_cancelled.emit()
	hide()

func _on_defaults_pressed():
# Volta para configuraÃ§Ãµes padrÃ£o
	reset_to_defaults()

func save_settings():
# Salva configuraÃ§Ãµes no arquivo
	settings_data = {
		"video": {
			"resolution": resolution_options[resolution_option.selected],
			"fullscreen": fullscreen_check.button_pressed,
			"vsync": vsync_check.button_pressed,
			"quality": quality_slider.value,
			"brightness": brightness_slider.value
		},
		"audio": {
			"master_volume": master_slider.value,
			"music_volume": music_slider.value,
			"sfx_volume": sfx_slider.value,
			"voice_volume": voice_slider.value,
			"muted": mute_check.button_pressed
		},
		"controls": {
			"mouse_sensitivity": mouse_sensitivity_slider.value,
			"invert_y": invert_y_check.button_pressed
		}
	}
	
	# Salvar em arquivo JSON
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data))
		file.close()

func reset_to_defaults():
# Reseta todas as configuraÃ§Ãµes para padrÃ£o
	# VÃ­deo
	resolution_option.selected = 0
	fullscreen_check.button_pressed = false
	vsync_check.button_pressed = true
	quality_slider.value = 75
	brightness_slider.value = 50
	
	# Ãudio
	master_slider.value = 100
	music_slider.value = 80
	sfx_slider.value = 90
	voice_slider.value = 85
	mute_check.button_pressed = false
	
	# Controles
	mouse_sensitivity_slider.value = 50
	invert_y_check.button_pressed = false
	
	# Aplica as mudanÃ§as
	_on_apply_pressed()

func show_menu():
# Mostra menu com animaÃ§Ã£o
	visible = true
	modulate = Color.TRANSPARENT
	scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3)

func hide():
# Esconde menu com animaÃ§Ã£o
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_callback(func(): visible = false)
