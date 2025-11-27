extends Control
class_name PauseMenu

@onready var resume_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/ResumeButton
@onready var inventory_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/InventoryButton
@onready var equipment_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/EquipmentButton
@onready var crafting_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/CraftingButton
@onready var options_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/OptionsButton
@onready var main_menu_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var quit_button: Button = $PausePanel/VBoxContainer/ButtonsContainer/QuitButton
@onready var title_label: Label = $PausePanel/VBoxContainer/Title

func _ready():
	apply_theme()
	resume_button.pressed.connect(_on_resume_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	equipment_button.pressed.connect(_on_equipment_pressed)
	crafting_button.pressed.connect(_on_crafting_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func apply_theme():
	if Engine.has_singleton("UIThemeManager"):
		# If using an autoloaded theme manager as a singleton
		pass
	elif typeof(UIThemeManager) != TYPE_NIL:
		if title_label:
			title_label.add_theme_color_override("font_color", UIThemeManager.Colors.ACCENT_GOLD)
		for b in [resume_button, inventory_button, equipment_button, crafting_button, options_button, main_menu_button, quit_button]:
			if b:
				# Fallback basic styling
				b.add_theme_color_override("font_color", Color(1,1,1))

func _on_resume_pressed():
	get_tree().paused = false
	hide()

func _on_inventory_pressed():
	get_tree().paused = false
	hide()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").request_menu("inventory")

func _on_equipment_pressed():
	get_tree().paused = false
	hide()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").request_menu("equipment")

func _on_crafting_pressed():
	get_tree().paused = false
	hide()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").request_menu("crafting")

func _on_options_pressed():
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").request_menu("options")

func _on_main_menu_pressed():
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").request_popup("confirmation", {
			"title": "Voltar ao Menu Principal",
			"message": "Tem certeza? O progresso não salvo será perdido.",
			"confirm_text": "Sim, voltar",
			"cancel_text": "Cancelar",
			"confirm_action": func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		})

func _on_quit_pressed():
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").request_popup("confirmation", {
			"title": "Sair do Jogo",
			"message": "Tem certeza que deseja sair? O progresso não salvo será perdido.",
			"confirm_text": "Sim, sair",
			"cancel_text": "Cancelar",
			"confirm_action": func(): get_tree().quit()
		})