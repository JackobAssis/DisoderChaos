extends Node

class_name DialogueSystem

signal dialogue_started(npc_id: String, dialogue_id: String)
signal dialogue_ended(npc_id: String, dialogue_id: String)
signal dialogue_option_chosen(option_id: String, option_text: String)
signal dialogue_branch_changed(branch_id: String)
signal quest_dialogue_triggered(quest_id: String)

# Dialogue states
enum DialogueState {
	INACTIVE,
	ACTIVE,
	WAITING_FOR_CHOICE,
	PROCESSING,
	COMPLETED
}

# Dialogue data
var all_dialogues: Dictionary = {}
var npc_dialogues: Dictionary = {} # npc_id -> dialogue_ids
var active_dialogue: Dictionary = {}
var dialogue_history: Dictionary = {} # npc_id -> completed_dialogues

# Current dialogue state
var current_state: DialogueState = DialogueState.INACTIVE
var current_npc_id: String = ""
var current_dialogue_id: String = ""
var current_node_id: String = ""
var dialogue_variables: Dictionary = {} # For storing dialogue session variables

# Dialogue conditions
var dialogue_conditions: Dictionary = {
	"quest_completed": [],
	"quest_active": [],
	"has_item": [],
	"level_min": 0,
	"reputation": {}
}

# References
@onready var data_loader: DataLoader = get_node("/root/DataLoader")
@onready var event_bus: EventBus = get_node("/root/EventBus")
@onready var game_state: GameState = get_node("/root/GameState")
@onready var quest_system: QuestSystem = get_node("/root/QuestSystem")
@onready var npc_system: NPCSystem

func _ready():
	await setup_dialogue_system()
	connect_events()
	print("[DialogueSystem] Sistema de Diálogo inicializado")

func setup_dialogue_system():
	"""Initialize dialogue system"""
	# Wait for data to be loaded
	if not data_loader.is_fully_loaded():
		await data_loader.all_data_loaded
	
	# Wait for NPC system
	await get_tree().process_frame
	npc_system = get_node("/root/NPCSystem")
	
	load_all_dialogues()
	build_npc_dialogue_map()

func connect_events():
	"""Connect to game events"""
	event_bus.connect("npc_interacted", _on_npc_interacted)
	event_bus.connect("quest_completed", _on_quest_completed)
	event_bus.connect("quest_started", _on_quest_started)

func load_all_dialogues():
	"""Load all dialogue data"""
	all_dialogues = data_loader.get_all_dialogues()
	print("[DialogueSystem] Carregados %d diálogos" % all_dialogues.size())

func build_npc_dialogue_map():
	"""Build mapping of NPCs to their available dialogues"""
	npc_dialogues.clear()
	
	for dialogue_id in all_dialogues.keys():
		var dialogue_data = all_dialogues[dialogue_id]
		var target_npc = dialogue_data.get("npc_id", "")
		
		if target_npc != "":
			if not npc_dialogues.has(target_npc):
				npc_dialogues[target_npc] = []
			npc_dialogues[target_npc].append(dialogue_id)

func start_dialogue_with_npc(npc_id: String, forced_dialogue_id: String = "") -> bool:
	"""Start dialogue with an NPC"""
	if current_state != DialogueState.INACTIVE:
		print("[DialogueSystem] Diálogo já ativo")
		return false
	
	# Get available dialogues for NPC
	var available_dialogues = get_available_dialogues_for_npc(npc_id)
	if available_dialogues.is_empty():
		print("[DialogueSystem] Nenhum diálogo disponível para NPC: %s" % npc_id)
		return false
	
	# Choose dialogue to start
	var dialogue_id = forced_dialogue_id
	if dialogue_id == "" or dialogue_id not in available_dialogues:
		dialogue_id = choose_best_dialogue(npc_id, available_dialogues)
	
	if dialogue_id == "":
		print("[DialogueSystem] Nenhum diálogo adequado encontrado para NPC: %s" % npc_id)
		return false
	
	return start_dialogue(npc_id, dialogue_id)

func get_available_dialogues_for_npc(npc_id: String) -> Array:
	"""Get all available dialogues for an NPC"""
	var available = []
	var npc_dialogue_list = npc_dialogues.get(npc_id, [])
	
	for dialogue_id in npc_dialogue_list:
		if is_dialogue_available(dialogue_id, npc_id):
			available.append(dialogue_id)
	
	return available

func is_dialogue_available(dialogue_id: String, npc_id: String) -> bool:
	"""Check if dialogue is available"""
	var dialogue_data = all_dialogues.get(dialogue_id, {})
	if dialogue_data.is_empty():
		return false
	
	# Check if already completed (for one-time dialogues)
	var is_repeatable = dialogue_data.get("repeatable", true)
	if not is_repeatable:
		var history = dialogue_history.get(npc_id, [])
		if dialogue_id in history:
			return false
	
	# Check availability conditions
	var conditions = dialogue_data.get("conditions", {})
	return check_dialogue_conditions(conditions)

func check_dialogue_conditions(conditions: Dictionary) -> bool:
	"""Check if dialogue conditions are met"""
	# Quest requirements
	if conditions.has("quest_completed"):
		for quest_id in conditions.quest_completed:
			if not quest_system.is_quest_completed(quest_id):
				return false
	
	if conditions.has("quest_active"):
		for quest_id in conditions.quest_active:
			if not quest_system.is_quest_active(quest_id):
				return false
	
	if conditions.has("quest_not_active"):
		for quest_id in conditions.quest_not_active:
			if quest_system.is_quest_active(quest_id):
				return false
	
	# Item requirements
	if conditions.has("has_item"):
		for item_requirement in conditions.has_item:
			var item_id = item_requirement.get("item_id", "")
			var count = item_requirement.get("count", 1)
			if not game_state.has_item(item_id, count):
				return false
	
	# Level requirements
	if conditions.has("level_min"):
		if game_state.player_stats.current_level < conditions.level_min:
			return false
	
	if conditions.has("level_max"):
		if game_state.player_stats.current_level > conditions.level_max:
			return false
	
	# Reputation requirements
	if conditions.has("reputation"):
		for faction in conditions.reputation:
			var required_rep = conditions.reputation[faction]
			var current_rep = game_state.get_reputation(faction)
			if current_rep < required_rep:
				return false
	
	# Time-based conditions
	if conditions.has("time_of_day"):
		var required_time = conditions.time_of_day
		var current_time = game_state.get_time_of_day()
		if current_time != required_time:
			return false
	
	# Flag conditions
	if conditions.has("flags"):
		for flag_name in conditions.flags:
			var flag_value = conditions.flags[flag_name]
			var current_value = game_state.get_flag(flag_name, false)
			if current_value != flag_value:
				return false
	
	return true

func choose_best_dialogue(npc_id: String, available_dialogues: Array) -> String:
	"""Choose the best dialogue to start based on priority"""
	var best_dialogue = ""
	var highest_priority = -1
	
	for dialogue_id in available_dialogues:
		var dialogue_data = all_dialogues[dialogue_id]
		var priority = dialogue_data.get("priority", 0)
		
		# Quest dialogues have higher priority
		if dialogue_data.has("triggers_quest") or dialogue_data.has("completes_quest"):
			priority += 100
		
		if priority > highest_priority:
			highest_priority = priority
			best_dialogue = dialogue_id
	
	return best_dialogue

func start_dialogue(npc_id: String, dialogue_id: String) -> bool:
	"""Start specific dialogue"""
	var dialogue_data = all_dialogues.get(dialogue_id, {})
	if dialogue_data.is_empty():
		print("[DialogueSystem] Diálogo não encontrado: %s" % dialogue_id)
		return false
	
	# Initialize dialogue state
	current_state = DialogueState.ACTIVE
	current_npc_id = npc_id
	current_dialogue_id = dialogue_id
	dialogue_variables.clear()
	
	# Setup active dialogue data
	active_dialogue = {
		"npc_id": npc_id,
		"dialogue_id": dialogue_id,
		"data": dialogue_data,
		"start_time": Time.get_time_dict_from_system(),
		"nodes_visited": []
	}
	
	# Start from root node
	var start_node = dialogue_data.get("start_node", "start")
	current_node_id = start_node
	
	# Process initial node
	process_dialogue_node(start_node)
	
	# Emit signal
	dialogue_started.emit(npc_id, dialogue_id)
	event_bus.emit_signal("dialogue_ui_show", get_current_node_data())
	
	print("[DialogueSystem] Diálogo iniciado: %s com %s" % [dialogue_id, npc_id])
	return true

func process_dialogue_node(node_id: String):
	"""Process a dialogue node"""
	var dialogue_data = active_dialogue.data
	var nodes = dialogue_data.get("nodes", {})
	
	if not nodes.has(node_id):
		print("[DialogueSystem] Nó de diálogo não encontrado: %s" % node_id)
		end_dialogue()
		return
	
	var node_data = nodes[node_id]
	current_node_id = node_id
	
	# Track visited nodes
	if node_id not in active_dialogue.nodes_visited:
		active_dialogue.nodes_visited.append(node_id)
	
	# Process node actions
	process_node_actions(node_data)
	
	# Update state based on node type
	var node_type = node_data.get("type", "text")
	match node_type:
		"text":
			process_text_node(node_data)
		"choice":
			process_choice_node(node_data)
		"action":
			process_action_node(node_data)
		"conditional":
			process_conditional_node(node_data)
		"end":
			end_dialogue()

func process_text_node(node_data: Dictionary):
	"""Process text dialogue node"""
	current_state = DialogueState.ACTIVE
	
	# Check for auto-advance
	var auto_advance = node_data.get("auto_advance", false)
	if auto_advance:
		var next_node = get_next_node(node_data)
		if next_node != "":
			# Auto-advance after a delay
			get_tree().create_timer(2.0).timeout.connect(
				func(): process_dialogue_node(next_node)
			)
		else:
			end_dialogue()

func process_choice_node(node_data: Dictionary):
	"""Process choice dialogue node"""
	current_state = DialogueState.WAITING_FOR_CHOICE
	
	# Filter available choices based on conditions
	var choices = node_data.get("choices", [])
	var available_choices = []
	
	for choice in choices:
		if check_choice_conditions(choice):
			available_choices.append(choice)
	
	if available_choices.is_empty():
		# No valid choices, end dialogue
		end_dialogue()
		return
	
	# Send choices to UI
	event_bus.emit_signal("dialogue_choices_available", available_choices)

func process_action_node(node_data: Dictionary):
	"""Process action dialogue node"""
	current_state = DialogueState.PROCESSING
	
	# Execute node actions immediately
	var next_node = get_next_node(node_data)
	if next_node != "":
		process_dialogue_node(next_node)
	else:
		end_dialogue()

func process_conditional_node(node_data: Dictionary):
	"""Process conditional dialogue node"""
	current_state = DialogueState.PROCESSING
	
	var conditions = node_data.get("conditions", {})
	var true_node = node_data.get("true_node", "")
	var false_node = node_data.get("false_node", "")
	
	var next_node = ""
	if check_dialogue_conditions(conditions):
		next_node = true_node
	else:
		next_node = false_node
	
	if next_node != "":
		process_dialogue_node(next_node)
	else:
		end_dialogue()

func process_node_actions(node_data: Dictionary):
	"""Process actions defined in dialogue node"""
	var actions = node_data.get("actions", [])
	
	for action in actions:
		execute_dialogue_action(action)

func execute_dialogue_action(action: Dictionary):
	"""Execute a dialogue action"""
	var action_type = action.get("type", "")
	
	match action_type:
		"start_quest":
			var quest_id = action.get("quest_id", "")
			if quest_id != "":
				quest_system.start_quest(quest_id, current_npc_id)
				quest_dialogue_triggered.emit(quest_id)
		
		"complete_quest":
			var quest_id = action.get("quest_id", "")
			if quest_id != "":
				quest_system.complete_quest(quest_id)
		
		"give_item":
			var item_id = action.get("item_id", "")
			var quantity = action.get("quantity", 1)
			if item_id != "":
				game_state.add_item_to_inventory(item_id, quantity)
		
		"take_item":
			var item_id = action.get("item_id", "")
			var quantity = action.get("quantity", 1)
			if item_id != "":
				game_state.remove_item_from_inventory(item_id, quantity)
		
		"modify_currency":
			var amount = action.get("amount", 0)
			game_state.modify_currency(amount)
		
		"modify_reputation":
			var faction = action.get("faction", "")
			var amount = action.get("amount", 0)
			if faction != "":
				game_state.modify_reputation(faction, amount)
		
		"set_flag":
			var flag_name = action.get("flag", "")
			var flag_value = action.get("value", true)
			if flag_name != "":
				game_state.set_flag(flag_name, flag_value)
		
		"set_variable":
			var var_name = action.get("variable", "")
			var var_value = action.get("value", null)
			if var_name != "":
				dialogue_variables[var_name] = var_value
		
		"play_sound":
			var sound_path = action.get("sound", "")
			if sound_path != "":
				event_bus.emit_signal("play_dialogue_sound", sound_path)
		
		"change_npc_state":
			var new_state = action.get("state", "")
			if new_state != "" and npc_system:
				npc_system.change_npc_state(current_npc_id, new_state)

func check_choice_conditions(choice: Dictionary) -> bool:
	"""Check if choice is available"""
	var conditions = choice.get("conditions", {})
	return check_dialogue_conditions(conditions)

func choose_dialogue_option(option_index: int):
	"""Player chooses a dialogue option"""
	if current_state != DialogueState.WAITING_FOR_CHOICE:
		return
	
	var dialogue_data = active_dialogue.data
	var nodes = dialogue_data.get("nodes", {})
	var current_node = nodes.get(current_node_id, {})
	var choices = current_node.get("choices", [])
	
	if option_index < 0 or option_index >= choices.size():
		print("[DialogueSystem] Índice de opção inválido: %d" % option_index)
		return
	
	var chosen_option = choices[option_index]
	var option_text = chosen_option.get("text", "")
	var option_id = chosen_option.get("id", str(option_index))
	
	# Execute choice actions
	var choice_actions = chosen_option.get("actions", [])
	for action in choice_actions:
		execute_dialogue_action(action)
	
	# Emit choice signal
	dialogue_option_chosen.emit(option_id, option_text)
	
	# Move to next node
	var next_node = chosen_option.get("next_node", "")
	if next_node != "":
		process_dialogue_node(next_node)
	else:
		end_dialogue()

func get_next_node(node_data: Dictionary) -> String:
	"""Get the next node to process"""
	return node_data.get("next_node", "")

func end_dialogue():
	"""End current dialogue"""
	if current_state == DialogueState.INACTIVE:
		return
	
	# Mark dialogue as completed
	if not dialogue_history.has(current_npc_id):
		dialogue_history[current_npc_id] = []
	
	var dialogue_data = active_dialogue.data
	var is_repeatable = dialogue_data.get("repeatable", true)
	
	if not is_repeatable and current_dialogue_id not in dialogue_history[current_npc_id]:
		dialogue_history[current_npc_id].append(current_dialogue_id)
	
	# Emit end signal
	dialogue_ended.emit(current_npc_id, current_dialogue_id)
	event_bus.emit_signal("dialogue_ui_hide")
	event_bus.emit_signal("dialogue_completed", current_npc_id, current_dialogue_id)
	
	# Reset state
	current_state = DialogueState.INACTIVE
	current_npc_id = ""
	current_dialogue_id = ""
	current_node_id = ""
	active_dialogue.clear()
	dialogue_variables.clear()
	
	print("[DialogueSystem] Diálogo finalizado")

func get_current_node_data() -> Dictionary:
	"""Get current dialogue node data for UI"""
	if current_state == DialogueState.INACTIVE:
		return {}
	
	var dialogue_data = active_dialogue.data
	var nodes = dialogue_data.get("nodes", {})
	var current_node = nodes.get(current_node_id, {})
	
	# Process text with variables
	var text = current_node.get("text", "")
	text = process_text_variables(text)
	
	# Get speaker info
	var speaker = current_node.get("speaker", current_npc_id)
	var speaker_data = get_speaker_data(speaker)
	
	return {
		"text": text,
		"speaker": speaker,
		"speaker_name": speaker_data.get("name", speaker),
		"speaker_portrait": speaker_data.get("portrait", ""),
		"node_id": current_node_id,
		"dialogue_id": current_dialogue_id,
		"npc_id": current_npc_id,
		"type": current_node.get("type", "text"),
		"choices": get_processed_choices(current_node),
		"auto_advance": current_node.get("auto_advance", false)
	}

func get_speaker_data(speaker_id: String) -> Dictionary:
	"""Get speaker data (NPC or player)"""
	if speaker_id == "player":
		return {
			"name": game_state.player_name,
			"portrait": game_state.player_portrait
		}
	elif npc_system:
		return npc_system.get_npc_data(speaker_id)
	else:
		return {"name": speaker_id}

func get_processed_choices(node_data: Dictionary) -> Array:
	"""Get processed choices for current node"""
	if node_data.get("type", "") != "choice":
		return []
	
	var choices = node_data.get("choices", [])
	var processed_choices = []
	
	for i in range(choices.size()):
		var choice = choices[i]
		if check_choice_conditions(choice):
			var text = process_text_variables(choice.get("text", ""))
			processed_choices.append({
				"index": i,
				"text": text,
				"id": choice.get("id", str(i))
			})
	
	return processed_choices

func process_text_variables(text: String) -> String:
	"""Process variables in dialogue text"""
	var processed_text = text
	
	# Replace player name
	processed_text = processed_text.replace("{player_name}", game_state.player_name)
	
	# Replace dialogue variables
	for var_name in dialogue_variables.keys():
		var var_value = str(dialogue_variables[var_name])
		processed_text = processed_text.replace("{" + var_name + "}", var_value)
	
	# Replace game state variables
	processed_text = processed_text.replace("{player_level}", str(game_state.player_stats.current_level))
	processed_text = processed_text.replace("{player_gold}", str(game_state.currency))
	
	return processed_text

# Event handlers
func _on_npc_interacted(npc_id: String):
	"""Handle NPC interaction"""
	start_dialogue_with_npc(npc_id)

func _on_quest_completed(quest_id: String):
	"""Update dialogue availability when quests complete"""
	# Dialogues may become available after quest completion
	pass

func _on_quest_started(quest_id: String):
	"""Update dialogue availability when quests start"""
	# Dialogues may become available after quest starts
	pass

# Utility functions
func is_dialogue_active() -> bool:
	"""Check if dialogue is currently active"""
	return current_state != DialogueState.INACTIVE

func get_dialogue_history_for_npc(npc_id: String) -> Array:
	"""Get dialogue history with specific NPC"""
	return dialogue_history.get(npc_id, [])

func has_had_dialogue(npc_id: String, dialogue_id: String) -> bool:
	"""Check if player has had specific dialogue with NPC"""
	var history = dialogue_history.get(npc_id, [])
	return dialogue_id in history

func get_all_available_dialogues() -> Dictionary:
	"""Get all available dialogues organized by NPC"""
	var available = {}
	
	for npc_id in npc_dialogues.keys():
		var npc_available = get_available_dialogues_for_npc(npc_id)
		if not npc_available.is_empty():
			available[npc_id] = npc_available
	
	return available

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"dialogue_history": dialogue_history,
		"current_dialogue": serialize_current_dialogue()
	}

func serialize_current_dialogue() -> Dictionary:
	"""Serialize current dialogue state"""
	if current_state == DialogueState.INACTIVE:
		return {}
	
	return {
		"npc_id": current_npc_id,
		"dialogue_id": current_dialogue_id,
		"node_id": current_node_id,
		"state": current_state,
		"variables": dialogue_variables,
		"nodes_visited": active_dialogue.get("nodes_visited", [])
	}

func load_save_data(data: Dictionary):
	"""Load dialogue save data"""
	dialogue_history = data.get("dialogue_history", {})
	
	# Restore current dialogue if any
	var current_dialogue_data = data.get("current_dialogue", {})
	if not current_dialogue_data.is_empty():
		restore_dialogue_state(current_dialogue_data)
	
	print("[DialogueSystem] Dados de diálogo carregados")

func restore_dialogue_state(data: Dictionary):
	"""Restore dialogue state from save"""
	var npc_id = data.get("npc_id", "")
	var dialogue_id = data.get("dialogue_id", "")
	
	if npc_id != "" and dialogue_id != "":
		# Restart the dialogue
		if start_dialogue(npc_id, dialogue_id):
			current_node_id = data.get("node_id", "start")
			current_state = data.get("state", DialogueState.ACTIVE)
			dialogue_variables = data.get("variables", {})
			active_dialogue.nodes_visited = data.get("nodes_visited", [])

# Debug functions
func debug_start_dialogue(npc_id: String, dialogue_id: String):
	"""Debug: Start specific dialogue"""
	start_dialogue(npc_id, dialogue_id)

func debug_set_dialogue_variable(var_name: String, value):
	"""Debug: Set dialogue variable"""
	dialogue_variables[var_name] = value

func debug_clear_dialogue_history(npc_id: String = ""):
	"""Debug: Clear dialogue history"""
	if npc_id == "":
		dialogue_history.clear()
	else:
		dialogue_history.erase(npc_id)

func debug_list_available_dialogues(npc_id: String = "") -> Array:
	"""Debug: List available dialogues"""
	if npc_id == "":
		return get_all_available_dialogues().keys()
	else:
		return get_available_dialogues_for_npc(npc_id)
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