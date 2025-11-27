extends Node
class_name AdvancedClassSystem

signal class_specialized(player: Node, specialization_id: String)
signal class_evolved(player: Node, evolution_id: String)
signal skill_unlocked(player: Node, skill_id: String, skill_level: int)
signal prestige_achieved(player: Node, prestige_class: String)

# Sistema de dados
var advanced_classes_data: Dictionary = {}
var player_specializations: Dictionary = {}
var dual_class_progress: Dictionary = {}

# Configurações
var specialization_enabled: bool = true
var dual_class_enabled: bool = true
var prestige_enabled: bool = true

# Referências
@onready var data_loader: DataLoader = DataLoader.new()
@onready var event_bus: EventBus = EventBus

func _ready():
	name = "AdvancedClassSystem"
	load_advanced_classes_data()
	connect_events()
	print("[AdvancedClassSystem] Sistema de classes avançadas inicializado")

func load_advanced_classes_data():
	"""Carrega dados das classes avançadas"""
	var data = data_loader.load_json_file("res://data/classes/advanced_classes.json")
	if data:
		advanced_classes_data = data
		print("[AdvancedClassSystem] Dados de classes avançadas carregados")
	else:
		push_error("[AdvancedClassSystem] Falha ao carregar dados de classes avançadas")

func connect_events():
	"""Conecta aos eventos necessários"""
	event_bus.player_level_up.connect(_on_player_level_up)
	event_bus.skill_unlocked.connect(_on_skill_unlocked)

# ============================================================================
# SISTEMA DE ESPECIALIZAÇÃO
# ============================================================================

func can_specialize(player: Node, specialization_id: String) -> bool:
	"""Verifica se o jogador pode se especializar"""
	if not specialization_enabled:
		return false
	
	var player_data = _get_player_data(player)
	if not player_data:
		return false
	
	# Verifica se já tem especialização
	if player_specializations.has(player.get_instance_id()):
		return false
	
	var spec_data = _get_specialization_data(specialization_id)
	if not spec_data:
		return false
	
	# Verifica classe base
	if player_data.class != spec_data.base_class_required:
		return false
	
	# Verifica nível
	if player_data.level < spec_data.level_required:
		return false
	
	# Verifica skills pré-requisitos
	if spec_data.has("prerequisite_skills"):
		for skill in spec_data.prerequisite_skills:
			if not _player_has_skill(player, skill):
				return false
	
	return true

func specialize_player(player: Node, specialization_id: String) -> bool:
	"""Especializa o jogador"""
	if not can_specialize(player, specialization_id):
		print("[AdvancedClassSystem] Jogador não pode se especializar em: ", specialization_id)
		return false
	
	var spec_data = _get_specialization_data(specialization_id)
	var player_id = player.get_instance_id()
	
	# Criar dados da especialização
	player_specializations[player_id] = {
		"specialization_id": specialization_id,
		"unlocked_skills": {},
		"skill_points": 5,  # Pontos iniciais
		"specialization_level": 1
	}
	
	# Aplicar bônus de stats
	_apply_stat_bonuses(player, spec_data.stat_bonuses)
	
	# Desbloquear habilidades especiais
	_unlock_special_abilities(player, spec_data.special_abilities)
	
	# Emitir evento
	class_specialized.emit(player, specialization_id)
	
	print("[AdvancedClassSystem] Jogador especializado em: ", specialization_id)
	return true

func unlock_specialization_skill(player: Node, skill_id: String) -> bool:
	"""Desbloqueia skill da especialização"""
	var player_id = player.get_instance_id()
	
	if not player_specializations.has(player_id):
		return false
	
	var spec_data = player_specializations[player_id]
	var specialization_id = spec_data.specialization_id
	var class_data = _get_specialization_data(specialization_id)
	
	if not class_data or not class_data.has("skill_tree"):
		return false
	
	# Encontrar skill na árvore
	var skill_info = _find_skill_in_tree(class_data.skill_tree, skill_id)
	if not skill_info:
		return false
	
	# Verificar pontos disponíveis
	var cost = skill_info.cost_per_level
	if spec_data.skill_points < cost:
		return false
	
	# Verificar pré-requisitos
	if skill_info.has("prerequisites"):
		for prereq in skill_info.prerequisites:
			if not spec_data.unlocked_skills.has(prereq):
				return false
	
	# Verificar nível atual da skill
	var current_level = spec_data.unlocked_skills.get(skill_id, 0)
	if current_level >= skill_info.max_level:
		return false
	
	# Desbloquear/Melhorar skill
	spec_data.unlocked_skills[skill_id] = current_level + 1
	spec_data.skill_points -= cost
	
	# Aplicar efeitos da skill
	_apply_skill_effects(player, skill_id, current_level + 1)
	
	# Emitir evento
	skill_unlocked.emit(player, skill_id, current_level + 1)
	
	print("[AdvancedClassSystem] Skill desbloqueada: %s (Nível %d)" % [skill_id, current_level + 1])
	return true

# ============================================================================
# SISTEMA DE EVOLUÇÃO/PRESTIGE
# ============================================================================

func can_evolve_class(player: Node, evolution_id: String) -> bool:
	"""Verifica se pode evoluir para classe prestigiosa"""
	if not prestige_enabled:
		return false
	
	var player_id = player.get_instance_id()
	if not player_specializations.has(player_id):
		return false
	
	var player_data = _get_player_data(player)
	var spec_data = player_specializations[player_id]
	var evolution_data = _get_evolution_data(evolution_id)
	
	if not evolution_data:
		return false
	
	# Verifica se evolui da especialização atual
	if evolution_data.evolves_from != spec_data.specialization_id:
		return false
	
	# Verifica nível
	if player_data.level < evolution_data.level_required:
		return false
	
	return true

func evolve_class(player: Node, evolution_id: String) -> bool:
	"""Evolui a classe para versão prestigiosa"""
	if not can_evolve_class(player, evolution_id):
		return false
	
	var player_id = player.get_instance_id()
	var evolution_data = _get_evolution_data(evolution_id)
	
	# Atualizar dados do jogador
	player_specializations[player_id]["evolution_id"] = evolution_id
	player_specializations[player_id]["prestige_level"] = 1
	
	# Desbloquear habilidades únicas
	_unlock_special_abilities(player, evolution_data.unique_abilities)
	
	# Emitir evento
	class_evolved.emit(player, evolution_id)
	prestige_achieved.emit(player, evolution_data.name)
	
	print("[AdvancedClassSystem] Classe evoluída para: ", evolution_data.name)
	return true

# ============================================================================
# SISTEMA DE DUAL CLASS
# ============================================================================

func can_dual_class(player: Node, second_class: String) -> bool:
	"""Verifica se pode ter dual class"""
	if not dual_class_enabled:
		return false
	
	var player_data = _get_player_data(player)
	if player_data.level < 30:
		return false
	
	# Verificar se já tem dual class
	var player_id = player.get_instance_id()
	if dual_class_progress.has(player_id):
		return false
	
	return true

func start_dual_class_training(player: Node, second_class: String) -> bool:
	"""Inicia treinamento de dual class"""
	if not can_dual_class(player, second_class):
		return false
	
	var player_id = player.get_instance_id()
	dual_class_progress[player_id] = {
		"second_class": second_class,
		"progress": 0,
		"max_progress": 1000,
		"training_active": true
	}
	
	print("[AdvancedClassSystem] Treinamento dual class iniciado: ", second_class)
	return true

func advance_dual_class_training(player: Node, progress_amount: int):
	"""Avança progresso de dual class"""
	var player_id = player.get_instance_id()
	
	if not dual_class_progress.has(player_id):
		return
	
	var training = dual_class_progress[player_id]
	if not training.training_active:
		return
	
	training.progress += progress_amount
	
	# Verificar se completou
	if training.progress >= training.max_progress:
		_complete_dual_class_training(player)

func _complete_dual_class_training(player: Node):
	"""Completa treinamento de dual class"""
	var player_id = player.get_instance_id()
	var training = dual_class_progress[player_id]
	
	training.training_active = false
	training.completed = true
	
	# Verificar sinergias
	var player_data = _get_player_data(player)
	var synergy_id = _get_class_synergy(player_data.class, training.second_class)
	
	if synergy_id:
		var synergy_data = advanced_classes_data.class_synergies[synergy_id]
		_apply_synergy_bonuses(player, synergy_data.bonuses)
		print("[AdvancedClassSystem] Sinergia de classe ativada: ", synergy_data.name)

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

func _get_player_data(player: Node) -> Dictionary:
	"""Obtém dados do jogador"""
	if player.has_method("get_player_data"):
		return player.get_player_data()
	
	# Fallback para GameState
	return GameState.get_player_data()

func _get_specialization_data(specialization_id: String) -> Dictionary:
	"""Obtém dados de uma especialização"""
	for class_type in advanced_classes_data.prestige_classes:
		var specializations = advanced_classes_data.prestige_classes[class_type]
		if specializations.has(specialization_id):
			return specializations[specialization_id]
	return {}

func _get_evolution_data(evolution_id: String) -> Dictionary:
	"""Obtém dados de evolução"""
	if not advanced_classes_data.has("prestige_evolution"):
		return {}
	
	var tier2_classes = advanced_classes_data.prestige_evolution.tier_2_classes
	if tier2_classes.has(evolution_id):
		return tier2_classes[evolution_id]
	
	return {}

func _player_has_skill(player: Node, skill_id: String) -> bool:
	"""Verifica se jogador tem skill"""
	# Esta função deve verificar no sistema de skills do jogador
	# Por agora, retorna true como placeholder
	return true

func _find_skill_in_tree(skill_tree: Dictionary, skill_id: String) -> Dictionary:
	"""Encontra skill na árvore de skills"""
	for tier in skill_tree:
		var tier_data = skill_tree[tier]
		if tier_data.has(skill_id):
			return tier_data[skill_id]
	return {}

func _apply_stat_bonuses(player: Node, stat_bonuses: Dictionary):
	"""Aplica bônus de stats"""
	if player.has_method("add_permanent_stat_bonus"):
		for stat in stat_bonuses:
			player.add_permanent_stat_bonus(stat, stat_bonuses[stat])

func _unlock_special_abilities(player: Node, abilities: Array):
	"""Desbloqueia habilidades especiais"""
	for ability in abilities:
		if player.has_method("add_ability"):
			player.add_ability(ability)

func _apply_skill_effects(player: Node, skill_id: String, level: int):
	"""Aplica efeitos de skill"""
	# Esta função deve aplicar os efeitos específicos da skill
	# Implementar baseado no sistema de skills existente
	pass

func _get_class_synergy(class1: String, class2: String) -> String:
	"""Obtém ID de sinergia entre duas classes"""
	var combined = class1 + "_" + class2
	var reversed = class2 + "_" + class1
	
	if advanced_classes_data.class_synergies.has(combined):
		return combined
	elif advanced_classes_data.class_synergies.has(reversed):
		return reversed
	
	return ""

func _apply_synergy_bonuses(player: Node, bonuses: Dictionary):
	"""Aplica bônus de sinergia"""
	if player.has_method("add_synergy_bonuses"):
		player.add_synergy_bonuses(bonuses)

# ============================================================================
# EVENTOS
# ============================================================================

func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
	"""Quando jogador sobe de nível"""
	# Adicionar skill points para especialização
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_id = player.get_instance_id()
		if player_specializations.has(player_id):
			player_specializations[player_id].skill_points += 2

func _on_skill_unlocked(skill_id: String):
	"""Quando skill é desbloqueada"""
	# Verificar se pode desbloquear especializações
	pass

# ============================================================================
# API PÚBLICA
# ============================================================================

func get_player_specialization(player: Node) -> Dictionary:
	"""Obtém especialização atual do jogador"""
	var player_id = player.get_instance_id()
	return player_specializations.get(player_id, {})

func get_available_specializations(player: Node) -> Array:
	"""Obtém especializações disponíveis"""
	var available = []
	var player_data = _get_player_data(player)
	
	for class_type in advanced_classes_data.prestige_classes:
		var specializations = advanced_classes_data.prestige_classes[class_type]
		for spec_id in specializations:
			if can_specialize(player, spec_id):
				available.push_back({
					"id": spec_id,
					"data": specializations[spec_id]
				})
	
	return available

func get_available_evolutions(player: Node) -> Array:
	"""Obtém evoluções disponíveis"""
	var available = []
	
	if not advanced_classes_data.has("prestige_evolution"):
		return available
	
	var tier2_classes = advanced_classes_data.prestige_evolution.tier_2_classes
	for evolution_id in tier2_classes:
		if can_evolve_class(player, evolution_id):
			available.push_back({
				"id": evolution_id,
				"data": tier2_classes[evolution_id]
			})
	
	return available

func get_dual_class_progress(player: Node) -> Dictionary:
	"""Obtém progresso de dual class"""
	var player_id = player.get_instance_id()
	return dual_class_progress.get(player_id, {})