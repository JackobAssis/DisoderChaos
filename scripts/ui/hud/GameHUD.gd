class_name GameHUD
extends Control

## HUD Principal do jogo Disorder Chaos
## ContÃ©m barras de status, minimap, buffs, relÃ³gio e informaÃ§Ãµes essenciais

@onready var health_bar: ProgressBar = $VBox/TopPanel/LeftSection/HealthBar
@onready var mana_bar: ProgressBar = $VBox/TopPanel/LeftSection/ManaBar
@onready var stamina_bar: ProgressBar = $VBox/TopPanel/LeftSection/StaminaBar
@onready var xp_bar: ProgressBar = $VBox/BottomPanel/XPBar

@onready var health_label: Label = $VBox/TopPanel/LeftSection/HealthBar/HealthLabel
@onready var mana_label: Label = $VBox/TopPanel/LeftSection/ManaBar/ManaLabel
@onready var stamina_label: Label = $VBox/TopPanel/LeftSection/StaminaBar/StaminaLabel
@onready var level_label: Label = $VBox/BottomPanel/LevelLabel

@onready var minimap: Control = $VBox/TopPanel/RightSection/MinimapContainer/Minimap
@onready var game_clock: Label = $VBox/TopPanel/CenterSection/GameClock
@onready var buffs_container: HBoxContainer = $VBox/TopPanel/CenterSection/BuffsContainer
@onready var debuffs_container: HBoxContainer = $VBox/TopPanel/CenterSection/DebuffsContainer

@onready var hotbar: HBoxContainer = $VBox/BottomPanel/HotbarContainer/Hotbar
@onready var chat_box: RichTextLabel = $VBox/BottomPanel/ChatContainer/ChatBox
@onready var chat_input: LineEdit = $VBox/BottomPanel/ChatContainer/ChatInput

# Sistema de relÃ³gio do jogo
var game_time: float = 0.0
var time_scale: float = 60.0  # 1 segundo real = 1 minuto do jogo
var day_duration: float = 1440.0  # 24 horas em minutos

# Cache de referÃªncias para performance
var player_stats: PlayerStats
var current_buffs: Array[Buff] = []
var current_debuffs: Array[Debuff] = []

signal hotbar_slot_used(slot_index: int)
signal chat_message_sent(message: String)
signal minimap_clicked(position: Vector2)

func _ready():
	setup_ui_theme()
	setup_connections()
	update_time_display()
	setup_hotbar()
	
	# Conecta com sistemas do jogo
	if EventBus:
		EventBus.player_stats_changed.connect(_on_player_stats_changed)
		EventBus.buff_added.connect(_on_buff_added)
		EventBus.buff_removed.connect(_on_buff_removed)
		EventBus.debuff_added.connect(_on_debuff_added)
		EventBus.debuff_removed.connect(_on_debuff_removed)

func _process(delta):
	update_game_time(delta)

func setup_ui_theme():
# Aplica tema dark fantasy em todos os elementos
	# Barras de status
	health_bar.add_theme_stylebox_override("fill", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.HP_RED))
	health_bar.add_theme_stylebox_override("background", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.PRIMARY_DARK))
	
	mana_bar.add_theme_stylebox_override("fill", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.MANA_BLUE))
	mana_bar.add_theme_stylebox_override("background", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.PRIMARY_DARK))
	
	stamina_bar.add_theme_stylebox_override("fill", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.STAMINA_GREEN))
	stamina_bar.add_theme_stylebox_override("background", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.PRIMARY_DARK))
	
	xp_bar.add_theme_stylebox_override("fill", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.XP_YELLOW))
	xp_bar.add_theme_stylebox_override("background", 
		UIThemeManager.create_progress_bar_style(UIThemeManager.Colors.PRIMARY_DARK))
	
	# Labels
	health_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	mana_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	stamina_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	level_label.add_theme_color_override("font_color", UIThemeManager.Colors.ACCENT_GOLD)
	game_clock.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)
	
	# Chat
	chat_box.add_theme_stylebox_override("normal", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.BG_PANEL))
	chat_input.add_theme_stylebox_override("normal", 
		UIThemeManager.create_panel_style(UIThemeManager.Colors.PRIMARY_DARK))

func setup_connections():
# Configura todas as conexÃµes de sinais
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	
	# Hotbar inputs
	for i in range(10):
		var slot = hotbar.get_child(i) as Button
		if slot:
			slot.pressed.connect(func(): hotbar_slot_used.emit(i))

func setup_hotbar():
# Configura a hotbar com 10 slots
	for i in range(10):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(50, 50)
		slot.add_theme_stylebox_override("normal", 
			UIThemeManager.create_button_style(
				UIThemeManager.Colors.PRIMARY_DARK,
				UIThemeManager.Colors.PRIMARY_NAVY,
				UIThemeManager.Colors.CYBER_CYAN
			))
		
		# Adiciona nÃºmero do slot
		var label = Label.new()
		label.text = str((i + 1) % 10)  # 1-9, 0
		label.position = Vector2(2, 2)
		label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_SECONDARY)
		slot.add_child(label)
		
		hotbar.add_child(slot)

func update_game_time(delta: float):
# Atualiza relÃ³gio interno do jogo
	game_time += delta * time_scale
	if game_time >= day_duration:
		game_time = 0.0
	
	update_time_display()

func update_time_display():
# Atualiza display do relÃ³gio
	var hours = int(game_time / 60.0)
	var minutes = int(game_time) % 60
	var time_period = "AM" if hours < 12 else "PM"
	var display_hour = hours if hours <= 12 else hours - 12
	if display_hour == 0:
		display_hour = 12
	
	game_clock.text = "%02d:%02d %s" % [display_hour, minutes, time_period]
	
	# Muda cor baseado no perÃ­odo
	if hours >= 6 and hours < 18:  # Dia
		game_clock.add_theme_color_override("font_color", UIThemeManager.Colors.XP_YELLOW)
	else:  # Noite
		game_clock.add_theme_color_override("font_color", UIThemeManager.Colors.CYBER_CYAN)

func _on_player_stats_changed(stats: PlayerStats):
# Atualiza barras quando stats do player mudam
	player_stats = stats
	update_status_bars()

func update_status_bars():
# Atualiza todas as barras de status
	if not player_stats:
		return
	
	# Health
	health_bar.max_value = player_stats.max_health
	health_bar.value = player_stats.current_health
	health_label.text = "%d/%d" % [player_stats.current_health, player_stats.max_health]
	
	# Mana
	mana_bar.max_value = player_stats.max_mana
	mana_bar.value = player_stats.current_mana
	mana_label.text = "%d/%d" % [player_stats.current_mana, player_stats.max_mana]
	
	# Stamina
	stamina_bar.max_value = player_stats.max_stamina
	stamina_bar.value = player_stats.current_stamina
	stamina_label.text = "%d/%d" % [player_stats.current_stamina, player_stats.max_stamina]
	
	# XP e Level
	xp_bar.max_value = player_stats.xp_to_next_level
	xp_bar.value = player_stats.current_xp
	level_label.text = "NÃ­vel %d" % player_stats.level
	
	# AnimaÃ§Ãµes de mudanÃ§a
	animate_bar_change(health_bar)
	animate_bar_change(mana_bar)
	animate_bar_change(stamina_bar)

func animate_bar_change(bar: ProgressBar):
# Anima mudanÃ§as nas barras de status
	var tween = create_tween()
	tween.tween_property(bar, "modulate", Color.WHITE * 1.5, 0.1)
	tween.tween_property(bar, "modulate", Color.WHITE, 0.1)

func _on_buff_added(buff: Buff):
# Adiciona Ã­cone de buff
	current_buffs.append(buff)
	update_buffs_display()

func _on_buff_removed(buff: Buff):
# Remove Ã­cone de buff
	current_buffs.erase(buff)
	update_buffs_display()

func _on_debuff_added(debuff: Debuff):
# Adiciona Ã­cone de debuff
	current_debuffs.append(debuff)
	update_debuffs_display()

func _on_debuff_removed(debuff: Debuff):
# Remove Ã­cone de debuff
	current_debuffs.erase(debuff)
	update_debuffs_display()

func update_buffs_display():
# Atualiza display de buffs
	# Limpa buffs antigos
	for child in buffs_container.get_children():
		child.queue_free()
	
	# Adiciona novos buffs
	for buff in current_buffs:
		var buff_icon = create_buff_icon(buff, true)
		buffs_container.add_child(buff_icon)

func update_debuffs_display():
# Atualiza display de debuffs
	# Limpa debuffs antigos
	for child in debuffs_container.get_children():
		child.queue_free()
	
	# Adiciona novos debuffs
	for debuff in current_debuffs:
		var debuff_icon = create_buff_icon(debuff, false)
		debuffs_container.add_child(debuff_icon)

func create_buff_icon(effect, is_buff: bool) -> Control:
# Cria Ã­cone para buff/debuff
	var container = Control.new()
	container.custom_minimum_size = Vector2(32, 32)
	
	# Fundo do Ã­cone
	var background = ColorRect.new()
	background.color = UIThemeManager.Colors.SUCCESS_GREEN if is_buff else UIThemeManager.Colors.ERROR_RED
	background.size = Vector2(32, 32)
	container.add_child(background)
	
	# Ãcone (usar TextureRect quando tiver assets)
	var icon = Label.new()
	icon.text = effect.icon_text if effect.has_method("get_icon_text") else "?"
	icon.position = Vector2(8, 8)
	icon.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
	container.add_child(icon)
	
	# Tooltip
	container.tooltip_text = effect.description if effect.has_method("get_description") else "Efeito"
	
	# Timer visual (se aplicÃ¡vel)
	if effect.has_method("get_remaining_time"):
		var timer_label = Label.new()
		timer_label.text = str(int(effect.get_remaining_time()))
		timer_label.position = Vector2(20, 20)
		timer_label.scale = Vector2(0.7, 0.7)
		timer_label.add_theme_color_override("font_color", UIThemeManager.Colors.TEXT_PRIMARY)
		container.add_child(timer_label)
	
	return container

func _on_chat_text_submitted(text: String):
# Processa mensagem do chat
	if text.strip_edges() != "":
		add_chat_message("VocÃª", text)
		chat_message_sent.emit(text)
		chat_input.text = ""

func add_chat_message(sender: String, message: String):
# Adiciona mensagem ao chat
	var time_str = game_clock.text
	var formatted_message = "[color=#00d4ff][%s][/color] [color=#ffd700]%s:[/color] %s\n" % [time_str, sender, message]
	chat_box.append_text(formatted_message)

func show_damage_number(damage: int, position: Vector2, is_critical: bool = false):
# Mostra nÃºmero de dano flutuante
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.position = position
	damage_label.z_index = 100
	
	if is_critical:
		damage_label.add_theme_color_override("font_color", UIThemeManager.Colors.ACCENT_GOLD)
		damage_label.add_theme_font_size_override("font_size", 24)
	else:
		damage_label.add_theme_color_override("font_color", UIThemeManager.Colors.ERROR_RED)
		damage_label.add_theme_font_size_override("font_size", 16)
	
	add_child(damage_label)
	
	# AnimaÃ§Ã£o
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "position", position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(damage_label, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(damage_label.queue_free)

func show_healing_number(healing: int, position: Vector2):
# Mostra nÃºmero de cura flutuante
	var heal_label = Label.new()
	heal_label.text = "+" + str(healing)
	heal_label.position = position
	heal_label.z_index = 100
	heal_label.add_theme_color_override("font_color", UIThemeManager.Colors.SUCCESS_GREEN)
	heal_label.add_theme_font_size_override("font_size", 16)
	
	add_child(heal_label)
	
	# AnimaÃ§Ã£o
	var tween = create_tween()
	tween.parallel().tween_property(heal_label, "position", position + Vector2(0, -30), 0.8)
	tween.parallel().tween_property(heal_label, "modulate", Color.TRANSPARENT, 0.8)
	tween.tween_callback(heal_label.queue_free)

func toggle_minimap_size():
# Alterna entre minimap normal e expandido
	var current_size = minimap.size
	var target_size = Vector2(200, 200) if current_size.x < 150 else Vector2(120, 120)
	
	var tween = create_tween()
	tween.tween_property(minimap, "size", target_size, 0.3)

func set_hotbar_item(slot_index: int, item_data: Dictionary):
# Define item em slot da hotbar
	if slot_index >= 0 and slot_index < hotbar.get_child_count():
		var slot = hotbar.get_child(slot_index) as Button
		if slot and item_data.has("icon"):
			slot.icon = load(item_data.icon) if item_data.icon is String else item_data.icon
			slot.tooltip_text = item_data.get("name", "Item")

# === INPUT HANDLING ===
func _input(event):
# Gerencia inputs do HUD
	if event.is_action_pressed("toggle_chat"):
		chat_input.grab_focus()
	elif event.is_action_pressed("toggle_minimap"):
		toggle_minimap_size()
	
	# Hotbar shortcuts (1-9, 0)
	for i in range(10):
		var action_name = "hotbar_" + str((i + 1) % 10)
		if event.is_action_pressed(action_name):
			hotbar_slot_used.emit(i)

func hide_hud():
# Esconde HUD (Ãºtil para screenshots ou cutscenes)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, UIThemeManager.Styles.FADE_DURATION)

func show_hud():
# Mostra HUD novamente
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, UIThemeManager.Styles.FADE_DURATION)
