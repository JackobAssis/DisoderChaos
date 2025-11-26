extends Control

class_name DialogueSystem

signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal dialogue_choice_selected(choice_index: int)
signal skill_check_result(success: bool, skill: String, roll: int)

# UI Components
@onready var dialogue_panel: Panel
@onready var portrait_container: Control
@onready var npc_portrait: TextureRect
@onready var speaker_name: Label
@onready var dialogue_text: RichTextLabel
@onready var choices_container: VBoxContainer
@onready var continue_button: Button

# Current dialogue state
var current_npc_id: String = ""
var current_tree: Dictionary = {}
var current_node: String = ""
var dialogue_history: Array = []
var active_dialogue: bool = false

# References
@onready var npc_system: NPCSystem = get_node("/root/NPCSystem")
@onready var quest_system: QuestSystem = get_node("/root/QuestSystem")
@onready var game_state: GameState = get_node("/root/GameState")
@onready var event_bus: EventBus = get_node("/root/EventBus")

# Dialogue processing
var text_speed: float = 50.0  # Characters per second
var is_typing: bool = false
var full_text: String = ""
var current_text_index: int = 0

func _ready():
	create_ui_components()
	setup_connections()
	hide_dialogue_ui()
	
	print("[DialogueSystem] Sistema de Diálogos inicializado")

func create_ui_components():
	# Main dialogue panel
	dialogue_panel = Panel.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.anchor_left = 0.1
	dialogue_panel.anchor_right = 0.9
	dialogue_panel.anchor_top = 0.7
	dialogue_panel.anchor_bottom = 0.95
	add_child(dialogue_panel)
	
	# Portrait container
	portrait_container = Control.new()
	portrait_container.name = "PortraitContainer"
	portrait_container.anchor_left = 0.02
	portrait_container.anchor_top = 0.1
	portrait_container.anchor_right = 0.25
	portrait_container.anchor_bottom = 0.9
	dialogue_panel.add_child(portrait_container)
	
	# NPC Portrait
	npc_portrait = TextureRect.new()
	npc_portrait.name = "NPCPortrait"
	npc_portrait.anchor_right = 1.0
	npc_portrait.anchor_bottom = 1.0
	npc_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_container.add_child(npc_portrait)
	
	# Speaker name
	speaker_name = Label.new()
	speaker_name.name = "SpeakerName"
	speaker_name.anchor_left = 0.28
	speaker_name.anchor_right = 0.98
	speaker_name.anchor_top = 0.05
	speaker_name.anchor_bottom = 0.2
	speaker_name.add_theme_font_size_override("font_size", 18)
	speaker_name.add_theme_color_override("font_color", Color.YELLOW)
	dialogue_panel.add_child(speaker_name)
	
	# Dialogue text
	dialogue_text = RichTextLabel.new()
	dialogue_text.name = "DialogueText"
	dialogue_text.anchor_left = 0.28
	dialogue_text.anchor_right = 0.98
	dialogue_text.anchor_top = 0.2
	dialogue_text.anchor_bottom = 0.65
	dialogue_text.bbcode_enabled = true
	dialogue_text.scroll_active = false
	dialogue_panel.add_child(dialogue_text)
	
	# Choices container
	choices_container = VBoxContainer.new()
	choices_container.name = "ChoicesContainer"
	choices_container.anchor_left = 0.28
	choices_container.anchor_right = 0.98
	choices_container.anchor_top = 0.68
	choices_container.anchor_bottom = 0.95
	dialogue_panel.add_child(choices_container)
	
	# Continue button
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue..."
	continue_button.anchor_left = 0.8
	continue_button.anchor_right = 0.98
	continue_button.anchor_top = 0.68
	continue_button.anchor_bottom = 0.8
	continue_button.visible = false
	dialogue_panel.add_child(continue_button)

func setup_connections():
	continue_button.pressed.connect(_on_continue_pressed)

func start_dialogue(npc_id: String, dialogue_tree: Dictionary) -> void:
	if active_dialogue:
		end_dialogue()
	
	current_npc_id = npc_id
	current_tree = dialogue_tree
	current_node = dialogue_tree.get("root", "greeting")
	dialogue_history.clear()
	active_dialogue = true
	
	# Load NPC data for portrait and name
	load_npc_presentation_data(npc_id)
	
	# Show dialogue UI
	show_dialogue_ui()
	
	# Process first node
	process_dialogue_node(current_node)
	
	dialogue_started.emit(npc_id)
	print("[DialogueSystem] Diálogo iniciado com ", npc_id)

func load_npc_presentation_data(npc_id: String) -> void:
	if not npc_system:
		return
	
	var npc_data = npc_system.get_npc_data(npc_id)
	
	# Set speaker name
	speaker_name.text = npc_data.get("name", "NPC")
	
	# Load portrait
	var portrait_path = npc_data.get("portrait_path", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait_texture = load(portrait_path)
		if portrait_texture:
			npc_portrait.texture = portrait_texture
	else:
		npc_portrait.texture = create_placeholder_portrait()

func create_placeholder_portrait() -> ImageTexture:
	var image = Image.create(128, 128, false, Image.FORMAT_RGB8)
	image.fill(Color.GRAY)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func process_dialogue_node(node_id: String) -> void:
	if not current_tree.has("nodes") or not current_tree.nodes.has(node_id):
		print("[DialogueSystem] ERRO: Nó de diálogo não encontrado: ", node_id)
		end_dialogue()
		return
	
	var node_data = current_tree.nodes[node_id]
	var node_type = node_data.get("type", "text")
	
	# Add to history
	dialogue_history.append(node_id)
	
	match node_type:
		"text":
			process_text_node(node_data)
		"conditional":
			process_conditional_node(node_data)
		"quest_check":
			process_quest_check_node(node_data)
		"training":
			process_training_node(node_data)
		"shop":
			process_shop_node(node_data)
		"faction_action":
			process_faction_action_node(node_data)
		"transport":
			process_transport_node(node_data)
		_:
			print("[DialogueSystem] Tipo de nó desconhecido: ", node_type)
			end_dialogue()

func process_text_node(node_data: Dictionary) -> void:
	var text = node_data.get("text", "...")
	
	# Process text with variables
	text = process_text_variables(text)
	
	# Start typing effect
	start_typing_text(text)
	
	# Set up choices or continue
	if node_data.has("options"):
		setup_dialogue_choices(node_data.options)
	elif node_data.get("end", false):
		# Dialogue ends after this node
		continue_button.visible = true
		continue_button.text = "Farewell"
		continue_button.pressed.connect(end_dialogue, CONNECT_ONE_SHOT)
	else:
		# Auto-continue node
		continue_button.visible = true
		continue_button.text = "Continue..."

func process_conditional_node(node_data: Dictionary) -> void:
	var conditions = node_data.get("conditions", [])
	
	for condition in conditions:
		if evaluate_condition(condition):
			var next_node = condition.get("next", "")
			if next_node != "":
				process_dialogue_node(next_node)
				return
	
	# No conditions met, try default
	for condition in conditions:
		if condition.get("type") == "default":
			var next_node = condition.get("next", "")
			if next_node != "":
				process_dialogue_node(next_node)
				return
	
	# No valid path found
	print("[DialogueSystem] Nenhuma condição atendida no nó condicional")
	end_dialogue()

func process_quest_check_node(node_data: Dictionary) -> void:
	if not quest_system:
		process_text_node({"text": "Quest system not available.", "options": [{"text": "OK", "next": "greeting"}]})
		return
	
	var available_quests = node_data.get("available_quests", [])
	var text = node_data.get("text", "Available quests:")
	var no_quests_text = node_data.get("no_quests_text", "No quests available.")
	
	# Check which quests are available for this NPC
	var valid_quests = []
	for quest_id in available_quests:
		if quest_system.can_start_quest(quest_id):
			valid_quests.append(quest_id)
	
	if valid_quests.size() > 0:
		# Show available quests
		dialogue_text.text = text
		
		# Create quest options
		var quest_options = []
		for quest_id in valid_quests:
			var quest_data = quest_system.get_quest_data(quest_id)
			quest_options.append({
				"text": quest_data.get("title", quest_id),
				"action": "start_quest",
				"quest_id": quest_id
			})
		
		# Add back option
		quest_options.append({"text": "Back", "next": "greeting"})
		setup_dialogue_choices(quest_options)
	else:
		# No quests available
		process_text_node({"text": no_quests_text, "options": [{"text": "I see", "next": "greeting"}]})

func process_training_node(node_data: Dictionary) -> void:
	var requirements = node_data.get("requirements", {})
	var skills = node_data.get("skills", [])
	var cost = node_data.get("cost", {})
	var text = node_data.get("text", "Training available.")
	
	# Check if player meets requirements
	if not check_training_requirements(requirements):
		var req_text = "You don't meet the training requirements."
		process_text_node({"text": req_text, "options": [{"text": "I'll come back later", "next": "greeting"}]})
		return
	
	# Show training options
	dialogue_text.text = text + "\n\nCost: " + format_cost(cost)
	
	var training_options = []
	for skill in skills:
		training_options.append({
			"text": "Learn " + skill.capitalize(),
			"action": "learn_skill",
			"skill": skill,
			"cost": cost
		})
	
	training_options.append({"text": "Not now", "next": "greeting"})
	setup_dialogue_choices(training_options)

func process_shop_node(node_data: Dictionary) -> void:
	var merchant_type = node_data.get("merchant_type", "general")
	var text = node_data.get("text", "What would you like to buy?")
	
	# This would open the shop interface
	dialogue_text.text = text + "\n\n[Shop interface would open here]"
	
	continue_button.visible = true
	continue_button.text = "Close Shop"

func process_faction_action_node(node_data: Dictionary) -> void:
	var action = node_data.get("action", "")
	var faction = node_data.get("faction", "")
	var amount = node_data.get("amount", 0)
	var text = node_data.get("text", "Faction standing changed.")
	var reward = node_data.get("reward", {})
	
	match action:
		"improve_reputation":
			if quest_system and faction != "":
				quest_system.modify_faction_reputation(faction, amount)
		
		"decrease_reputation":
			if quest_system and faction != "":
				quest_system.modify_faction_reputation(faction, -amount)
	
	# Give rewards
	if reward.has("gold"):
		game_state.modify_currency(reward.gold)
	
	if reward.has("items"):
		for item_id in reward.items:
			# Add item to inventory
			pass
	
	# Show result text
	process_text_node({"text": text, "options": node_data.get("options", [{"text": "Thank you", "next": "greeting"}])})

func process_transport_node(node_data: Dictionary) -> void:
	var destinations = node_data.get("destinations", [])
	var text = node_data.get("text", "Where would you like to go?")
	
	dialogue_text.text = text
	
	var transport_options = []
	for destination in destinations:
		transport_options.append({
			"text": destination.capitalize(),
			"action": "transport",
			"destination": destination
		})
	
	transport_options.append({"text": "Nowhere, thanks", "next": "greeting"})
	setup_dialogue_choices(transport_options)

func setup_dialogue_choices(options: Array) -> void:
	# Clear existing choices
	for child in choices_container.get_children():
		child.queue_free()
	
	continue_button.visible = false
	
	# Create choice buttons
	for i in range(options.size()):
		var option = options[i]
		var choice_button = Button.new()
		choice_button.text = option.get("text", "Choice " + str(i))
		choice_button.pressed.connect(_on_choice_selected.bind(i, option))
		choices_container.add_child(choice_button)

func start_typing_text(text: String) -> void:
	full_text = text
	current_text_index = 0
	is_typing = true
	dialogue_text.text = ""
	
	var timer = Timer.new()
	timer.wait_time = 1.0 / text_speed
	timer.timeout.connect(_on_typing_timer)
	add_child(timer)
	timer.start()

func _on_typing_timer() -> void:
	if current_text_index < full_text.length():
		current_text_index += 1
		dialogue_text.text = full_text.substr(0, current_text_index)
	else:
		is_typing = false
		# Remove the timer
		for child in get_children():
			if child is Timer:
				child.queue_free()

func evaluate_condition(condition: Dictionary) -> bool:
	var condition_type = condition.get("type", "")
	
	match condition_type:
		"faction_reputation":
			var faction = condition.get("faction", "")
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			
			if quest_system:
				var current_rep = quest_system.get_faction_reputation(faction)
				match operator:
					">=":
						return current_rep >= value
					">":
						return current_rep > value
					"<=":
						return current_rep <= value
					"<":
						return current_rep < value
					"==":
						return current_rep == value
		
		"level_check":
			var minimum_level = condition.get("minimum_level", 1)
			return game_state.get_player_level() >= minimum_level
		
		"skill_check":
			var skill = condition.get("skill", "")
			var difficulty = condition.get("difficulty", 10)
			return perform_skill_check(skill, difficulty)
		
		"time_check":
			var time_range = condition.get("time_range", [0, 24])
			var current_time = npc_system.current_time if npc_system else 12
			return current_time >= time_range[0] and current_time <= time_range[1]
		
		"reputation_check":
			var total_reputation = condition.get("total_reputation", 0)
			if quest_system:
				var total = quest_system.get_total_reputation()
				return total >= total_reputation
		
		"default":
			return true
	
	return false

func perform_skill_check(skill: String, difficulty: int) -> bool:
	var player_skill = game_state.get_player_skill(skill)
	var roll = randi() % 20 + 1  # d20 roll
	var total = player_skill + roll
	var success = total >= difficulty
	
	skill_check_result.emit(success, skill, roll)
	
	return success

func check_training_requirements(requirements: Dictionary) -> bool:
	for req_type in requirements.keys():
		var req_value = requirements[req_type]
		
		match req_type:
			"level":
				if game_state.get_player_level() < req_value:
					return false
			
			"intelligence":
				if game_state.get_player_attribute("intelligence") < req_value:
					return false
			
			"faction_reputation":
				if quest_system:
					for faction in req_value.keys():
						var required_rep = req_value[faction]
						var current_rep = quest_system.get_faction_reputation(faction)
						if current_rep < required_rep:
							return false
	
	return true

func format_cost(cost: Dictionary) -> String:
	var cost_text = ""
	
	if cost.has("gold"):
		cost_text += str(cost.gold) + " gold"
	
	if cost.has("materials"):
		if cost_text != "":
			cost_text += ", "
		cost_text += "materials: " + ", ".join(cost.materials)
	
	if cost.has("time_days"):
		if cost_text != "":
			cost_text += ", "
		cost_text += str(cost.time_days) + " days"
	
	return cost_text if cost_text != "" else "Free"

func process_text_variables(text: String) -> String:
	# Replace variables in text like {player_name}, {faction_reputation}, etc.
	var processed_text = text
	
	# Player name
	processed_text = processed_text.replace("{player_name}", game_state.get_player_name())
	
	# Faction reputations
	if quest_system:
		for faction in ["eternal_flame", "void_seekers", "iron_pact", "free_wanderers", "shadow_court"]:
			var rep = quest_system.get_faction_reputation(faction)
			processed_text = processed_text.replace("{" + faction + "_rep}", str(rep))
	
	return processed_text

func show_dialogue_ui() -> void:
	visible = true
	# Pause game or set dialogue mode
	get_tree().paused = false  # Adjust based on your pause system

func hide_dialogue_ui() -> void:
	visible = false
	# Unpause game
	get_tree().paused = false

func end_dialogue() -> void:
	if not active_dialogue:
		return
	
	hide_dialogue_ui()
	active_dialogue = false
	
	dialogue_ended.emit(current_npc_id)
	
	# Clean up
	current_npc_id = ""
	current_tree = {}
	current_node = ""
	dialogue_history.clear()
	
	print("[DialogueSystem] Diálogo encerrado")

func _on_continue_pressed() -> void:
	if is_typing:
		# Skip typing animation
		dialogue_text.text = full_text
		is_typing = false
		return
	
	# Continue to next node or end dialogue
	end_dialogue()

func _on_choice_selected(choice_index: int, option: Dictionary) -> void:
	dialogue_choice_selected.emit(choice_index)
	
	# Process choice action
	if option.has("action"):
		var action = option.action
		match action:
			"start_quest":
				if quest_system and option.has("quest_id"):
					quest_system.start_quest(option.quest_id)
					process_text_node({"text": "Quest started!", "options": [{"text": "Thank you", "next": "greeting"}]})
			
			"learn_skill":
				if option.has("skill"):
					# Process skill learning
					process_text_node({"text": "Skill learned: " + option.skill, "options": [{"text": "Thank you", "next": "greeting"}]})
			
			"transport":
				if option.has("destination"):
					# Process transport
					process_text_node({"text": "Transporting to " + option.destination, "end": true})
			
			_:
				print("[DialogueSystem] Ação desconhecida: ", action)
	
	# Navigate to next node
	if option.has("next"):
		var next_node = option.next
		process_dialogue_node(next_node)
	else:
		end_dialogue()

# Debug functions
func debug_print_dialogue_state() -> void:
	print("[DialogueSystem] Estado atual:")
	print("  NPC: ", current_npc_id)
	print("  Nó: ", current_node)
	print("  Ativo: ", active_dialogue)
	print("  Histórico: ", dialogue_history)

# Input handling
func _input(event: InputEvent) -> void:
	if not active_dialogue:
		return
	
	if event.is_action_pressed("ui_accept"):
		if continue_button.visible:
			_on_continue_pressed()
	
	if event.is_action_pressed("ui_cancel"):
		end_dialogue()

# Save/Load functionality
func get_save_data() -> Dictionary:
	return {
		"current_npc_id": current_npc_id,
		"dialogue_history": dialogue_history,
		"active_dialogue": active_dialogue
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("active_dialogue") and data.active_dialogue:
		# Don't restore active dialogues - they should restart fresh
		end_dialogue()