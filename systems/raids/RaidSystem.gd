extends Node
class_name RaidSystem

signal raid_instance_created(instance_id: String, raid_id: String, participants: Array)
signal raid_started(instance_id: String, raid_data: Dictionary)
signal raid_completed(instance_id: String, success: bool, completion_time: float)
signal boss_encounter_started(instance_id: String, boss_name: String)
signal boss_defeated(instance_id: String, boss_name: String, loot_distributed: Array)
signal player_joined_raid(instance_id: String, player: Node, role: String)
signal player_left_raid(instance_id: String, player: Node, reason: String)
signal raid_wipe(instance_id: String, cause: String)

# Dados do sistema
var raid_system_data: Dictionary = {}
var active_raid_instances: Dictionary = {}
var raid_groups: Dictionary = {}
var player_raid_progress: Dictionary = {}
var raid_lockouts: Dictionary = {}

# Configurações
var raid_system_enabled: bool = true
var cross_server_raids: bool = false
var max_concurrent_raids: int = 50

# Timers e scheduling
var instance_cleanup_timer: Timer
var lockout_reset_timer: Timer

# Referências
@onready var data_loader: DataLoader = DataLoader.new()
@onready var event_bus: EventBus = EventBus

func _ready():
	name = "RaidSystem"
	load_raid_system_data()
	setup_timers()
	connect_events()
	print("[RaidSystem] Sistema de raids inicializado")

func load_raid_system_data():
	"""Carrega dados do sistema de raids"""
	var data = data_loader.load_json_file("res://data/raids/raid_system.json")
	if data:
		raid_system_data = data.raid_system
		print("[RaidSystem] Dados de raids carregados")
	else:
		push_error("[RaidSystem] Falha ao carregar dados de raids")

func setup_timers():
	"""Configura timers do sistema"""
	instance_cleanup_timer = Timer.new()
	instance_cleanup_timer.wait_time = 300.0  # 5 minutos
	instance_cleanup_timer.timeout.connect(_cleanup_expired_instances)
	instance_cleanup_timer.autostart = true
	add_child(instance_cleanup_timer)
	
	lockout_reset_timer = Timer.new()
	lockout_reset_timer.wait_time = 3600.0  # 1 hora (verificação)
	lockout_reset_timer.timeout.connect(_check_lockout_resets)
	lockout_reset_timer.autostart = true
	add_child(lockout_reset_timer)

func connect_events():
	"""Conecta aos eventos necessários"""
	event_bus.player_level_up.connect(_on_player_level_up)
	event_bus.combat_ended.connect(_on_combat_ended)

# ============================================================================
# CRIAÇÃO E GERENCIAMENTO DE INSTÂNCIAS
# ============================================================================

func create_raid_instance(raid_id: String, leader: Node, difficulty: String = "normal") -> String:
	"""Cria uma nova instância de raid"""
	if not raid_system_enabled:
		print("[RaidSystem] Sistema de raids desabilitado")
		return ""
	
	if not raid_system_data.raid_instances.has(raid_id):
		print("[RaidSystem] Raid inexistente: ", raid_id)
		return ""
	
	# Verificar se pode criar mais instâncias
	if active_raid_instances.size() >= max_concurrent_raids:
		print("[RaidSystem] Limite de instâncias atingido")
		return ""
	
	# Verificar lockout do líder
	if _is_player_locked_out(leader, raid_id, difficulty):
		print("[RaidSystem] Líder em lockout para este raid")
		return ""
	
	var raid_data = raid_system_data.raid_instances[raid_id]
	var instance_id = _generate_instance_id()
	
	# Criar dados da instância
	var instance_data = {
		"id": instance_id,
		"raid_id": raid_id,
		"raid_data": raid_data.duplicate(true),
		"difficulty": difficulty,
		"leader": leader,
		"participants": [leader],
		"status": "forming",
		"created_at": Time.get_time_dict_from_system(),
		"started_at": null,
		"current_room": 1,
		"boss_kills": [],
		"total_deaths": 0,
		"loot_distributed": [],
		"instance_settings": {
			"loot_method": "personal_loot",
			"difficulty_locked": false,
			"auto_invite": true
		}
	}
	
	# Aplicar modificadores de dificuldade
	_apply_difficulty_scaling(instance_data)
	
	# Salvar instância
	active_raid_instances[instance_id] = instance_data
	
	# Criar grupo de raid
	raid_groups[instance_id] = {
		"leader": leader,
		"members": [leader],
		"roles": {str(leader.get_instance_id()): "leader"},
		"ready_status": {},
		"loot_master": leader
	}
	
	# Emitir evento
	raid_instance_created.emit(instance_id, raid_id, [leader])
	
	print("[RaidSystem] Instância criada: %s (%s - %s)" % [instance_id, raid_id, difficulty])
	return instance_id

func join_raid_instance(instance_id: String, player: Node, role: String = "dps") -> bool:
	"""Jogador entra em instância de raid"""
	if not active_raid_instances.has(instance_id):
		print("[RaidSystem] Instância não encontrada: ", instance_id)
		return false
	
	var instance = active_raid_instances[instance_id]
	var raid_data = instance.raid_data
	
	# Verificar se instância aceita novos membros
	if instance.status != "forming":
		print("[RaidSystem] Instância não aceita novos membros")
		return false
	
	# Verificar limite de participantes
	if instance.participants.size() >= raid_data.type_data.max_players:
		print("[RaidSystem] Instância lotada")
		return false
	
	# Verificar se jogador já está em raid
	if _is_player_in_raid(player):
		print("[RaidSystem] Jogador já está em raid")
		return false
	
	# Verificar requisitos do raid
	if not _meets_raid_requirements(player, instance):
		print("[RaidSystem] Jogador não atende requisitos")
		return false
	
	# Verificar lockout
	if _is_player_locked_out(player, instance.raid_id, instance.difficulty):
		print("[RaidSystem] Jogador em lockout")
		return false
	
	# Adicionar jogador
	instance.participants.push_back(player)
	var group = raid_groups[instance_id]
	group.members.push_back(player)
	group.roles[str(player.get_instance_id())] = role
	group.ready_status[str(player.get_instance_id())] = false
	
	# Emitir evento
	player_joined_raid.emit(instance_id, player, role)
	
	print("[RaidSystem] Jogador %s entrou na instância %s como %s" % [player.name, instance_id, role])
	return true

func leave_raid_instance(player: Node, reason: String = "voluntary") -> bool:
	"""Jogador sai da instância de raid"""
	var instance_id = _get_player_instance(player)
	if instance_id == "":
		return false
	
	var instance = active_raid_instances[instance_id]
	var group = raid_groups[instance_id]
	
	# Remover jogador
	instance.participants.erase(player)
	group.members.erase(player)
	var player_id_str = str(player.get_instance_id())
	group.roles.erase(player_id_str)
	group.ready_status.erase(player_id_str)
	
	# Verificar se era o líder
	if instance.leader == player:
		if group.members.size() > 0:
			# Transferir liderança
			instance.leader = group.members[0]
			group.leader = group.members[0]
			group.loot_master = group.members[0]
		else:
			# Dissolver raid se não há mais membros
			_dissolve_raid_instance(instance_id)
			return true
	
	# Emitir evento
	player_left_raid.emit(instance_id, player, reason)
	
	print("[RaidSystem] Jogador %s saiu da instância %s (%s)" % [player.name, instance_id, reason])
	return true

func start_raid_instance(instance_id: String) -> bool:
	"""Inicia uma instância de raid"""
	if not active_raid_instances.has(instance_id):
		return false
	
	var instance = active_raid_instances[instance_id]
	var raid_data = instance.raid_data
	
	# Verificar se pode iniciar
	if instance.status != "forming":
		print("[RaidSystem] Instância não pode ser iniciada")
		return false
	
	# Verificar número mínimo de jogadores
	var type_data = _get_raid_type_data(raid_data.type)
	if instance.participants.size() < type_data.min_players:
		print("[RaidSystem] Participantes insuficientes")
		return false
	
	# Verificar se todos estão prontos
	var group = raid_groups[instance_id]
	for player_id in group.ready_status:
		if not group.ready_status[player_id]:
			print("[RaidSystem] Nem todos os jogadores estão prontos")
			return false
	
	# Verificar composição do grupo se necessário
	if not _validate_group_composition(instance_id):
		print("[RaidSystem] Composição de grupo inválida")
		return false
	
	# Iniciar raid
	instance.status = "in_progress"
	instance.started_at = Time.get_time_dict_from_system()
	
	# Teleportar jogadores para o raid
	_teleport_players_to_raid(instance_id)
	
	# Aplicar lockouts
	_apply_raid_lockouts(instance_id)
	
	# Emitir evento
	raid_started.emit(instance_id, instance)
	
	print("[RaidSystem] Raid iniciado: %s" % instance_id)
	return true

# ============================================================================
# SISTEMA DE BOSS E MECÂNICAS
# ============================================================================

func trigger_boss_encounter(instance_id: String, boss_name: String) -> bool:
	"""Inicia encounter com boss"""
	if not active_raid_instances.has(instance_id):
		return false
	
	var instance = active_raid_instances[instance_id]
	
	# Encontrar dados do boss
	var boss_data = null
	for boss in instance.raid_data.bosses:
		if boss.name == boss_name:
			boss_data = boss
			break
	
	if not boss_data:
		print("[RaidSystem] Boss não encontrado: ", boss_name)
		return false
	
	# Verificar se boss já foi derrotado
	if instance.boss_kills.has(boss_name):
		print("[RaidSystem] Boss já foi derrotado")
		return false
	
	# Aplicar scaling de dificuldade ao boss
	var scaled_boss = _scale_boss_for_difficulty(boss_data, instance.difficulty)
	
	# Aplicar scaling por número de jogadores se necessário
	var type_data = _get_raid_type_data(instance.raid_data.type)
	if type_data.has("difficulty_scaling") and type_data.difficulty_scaling == "dynamic":
		scaled_boss = _scale_boss_for_player_count(scaled_boss, instance.participants.size())
	
	# Iniciar encounter
	instance.current_boss = {
		"name": boss_name,
		"data": scaled_boss,
		"start_time": Time.get_time_dict_from_system(),
		"attempts": instance.get("boss_attempts", {}).get(boss_name, 0) + 1,
		"phase": 1,
		"mechanics_active": []
	}
	
	# Emitir evento
	boss_encounter_started.emit(instance_id, boss_name)
	
	print("[RaidSystem] Boss encounter iniciado: %s (%s)" % [boss_name, instance_id])
	return true

func defeat_boss(instance_id: String, boss_name: String) -> bool:
	"""Marca boss como derrotado e distribui loot"""
	if not active_raid_instances.has(instance_id):
		return false
	
	var instance = active_raid_instances[instance_id]
	
	# Verificar se boss estava ativo
	if not instance.has("current_boss") or instance.current_boss.name != boss_name:
		return false
	
	# Marcar como derrotado
	instance.boss_kills.push_back(boss_name)
	
	# Calcular tempo do encounter
	var encounter_time = Time.get_time_dict_from_system().unix - instance.current_boss.start_time.unix
	
	# Gerar e distribuir loot
	var loot = _generate_boss_loot(instance, boss_name)
	var distributed_loot = _distribute_loot(instance_id, loot)
	
	# Conceder achievements se aplicável
	_check_boss_achievements(instance_id, boss_name, encounter_time)
	
	# Atualizar progresso
	_update_raid_progress(instance_id, boss_name)
	
	# Limpar boss atual
	instance.erase("current_boss")
	
	# Emitir evento
	boss_defeated.emit(instance_id, boss_name, distributed_loot)
	
	print("[RaidSystem] Boss derrotado: %s (%s)" % [boss_name, instance_id])
	return true

func wipe_raid(instance_id: String, cause: String = "combat") -> bool:
	"""Processa wipe do raid"""
	if not active_raid_instances.has(instance_id):
		return false
	
	var instance = active_raid_instances[instance_id]
	
	# Incrementar contador de deaths
	instance.total_deaths += instance.participants.size()
	
	# Resetar boss encounter se estava ativo
	if instance.has("current_boss"):
		var boss_name = instance.current_boss.name
		
		# Incrementar tentativas
		if not instance.has("boss_attempts"):
			instance.boss_attempts = {}
		instance.boss_attempts[boss_name] = instance.boss_attempts.get(boss_name, 0) + 1
		
		# Limpar boss atual
		instance.erase("current_boss")
	
	# Respawn players se permitido
	var type_data = _get_raid_type_data(instance.raid_data.type)
	if type_data.respawn_allowed:
		_respawn_raid_players(instance_id)
	else:
		# Se não permite respawn, raid falhou
		_fail_raid_instance(instance_id, "wipe_no_respawn")
		return true
	
	# Emitir evento
	raid_wipe.emit(instance_id, cause)
	
	print("[RaidSystem] Raid wipe: %s (%s)" % [instance_id, cause])
	return true

# ============================================================================
# SISTEMA DE LOOT
# ============================================================================

func _generate_boss_loot(instance: Dictionary, boss_name: String) -> Array:
	"""Gera loot para um boss derrotado"""
	var loot = []
	var difficulty = instance.difficulty
	var loot_table = raid_system_data.loot_system.drop_tables[difficulty]
	
	# Encontrar boss data
	var boss_data = null
	for boss in instance.raid_data.bosses:
		if boss.name == boss_name:
			boss_data = boss
			break
	
	if not boss_data:
		return loot
	
	# Gerar currency reward
	var base_currency = 100
	var currency_reward = int(base_currency * loot_table.currency_multiplier)
	loot.push_back({
		"type": "currency",
		"amount": currency_reward,
		"currency_type": "gold"
	})
	
	# Gerar special drops se existirem
	if boss_data.has("special_drops"):
		for drop_item in boss_data.special_drops:
			if randf() < 0.3:  # 30% chance para special drops
				loot.push_back({
					"type": "item",
					"item_id": drop_item,
					"quality": "epic"
				})
	
	# Gerar loot baseado na qualidade
	var num_drops = randi_range(2, 5)
	for i in range(num_drops):
		var quality = _roll_loot_quality(loot_table.quality_distribution)
		if quality != "":
			loot.push_back({
				"type": "equipment",
				"quality": quality,
				"level": instance.raid_data.recommended_level,
				"stat_bonus": difficulty
			})
	
	return loot

func _distribute_loot(instance_id: String, loot: Array) -> Array:
	"""Distribui loot entre os participantes"""
	var instance = active_raid_instances[instance_id]
	var group = raid_groups[instance_id]
	var distributed = []
	
	var loot_method = instance.instance_settings.loot_method
	
	match loot_method:
		"personal_loot":
			distributed = _distribute_personal_loot(instance, loot)
		"group_loot":
			distributed = _distribute_group_loot(instance, group, loot)
		"master_looter":
			distributed = _distribute_master_loot(instance, group, loot)
	
	# Registrar loot distribuído
	instance.loot_distributed.append_array(distributed)
	
	return distributed

func _distribute_personal_loot(instance: Dictionary, loot: Array) -> Array:
	"""Distribui loot pessoal"""
	var distributed = []
	
	for participant in instance.participants:
		for loot_item in loot:
			# Cada jogador tem chance individual de receber cada item
			if randf() < 0.2:  # 20% chance base
				var personal_loot = loot_item.duplicate()
				personal_loot.recipient = participant
				distributed.push_back(personal_loot)
				
				# Entregar item ao jogador
				_give_item_to_player(participant, personal_loot)
	
	return distributed

func _distribute_group_loot(instance: Dictionary, group: Dictionary, loot: Array) -> Array:
	"""Distribui loot de grupo usando need/greed/pass"""
	var distributed = []
	
	# Implementar sistema need/greed/pass
	# Por agora, distribuição simples round-robin
	var player_index = 0
	
	for loot_item in loot:
		if instance.participants.size() > 0:
			var recipient = instance.participants[player_index % instance.participants.size()]
			loot_item.recipient = recipient
			distributed.push_back(loot_item)
			
			_give_item_to_player(recipient, loot_item)
			player_index += 1
	
	return distributed

func _distribute_master_loot(instance: Dictionary, group: Dictionary, loot: Array) -> Array:
	"""Distribui loot via master looter"""
	var distributed = []
	var master_looter = group.loot_master
	
	# Master looter decide distribuição
	# Por agora, dar tudo para o master looter
	for loot_item in loot:
		loot_item.recipient = master_looter
		loot_item.needs_distribution = true  # Marcado para distribuição manual
		distributed.push_back(loot_item)
	
	return distributed

func _give_item_to_player(player: Node, loot_item: Dictionary):
	"""Entrega item para jogador"""
	if player.has_method("receive_raid_loot"):
		player.receive_raid_loot(loot_item)
	else:
		# Fallback - adicionar ao inventário
		print("[RaidSystem] Loot entregue para %s: %s" % [player.name, loot_item])

# ============================================================================
# SISTEMA DE PROGRESSO E LOCKOUTS
# ============================================================================

func _apply_raid_lockouts(instance_id: String):
	"""Aplica lockouts aos participantes"""
	var instance = active_raid_instances[instance_id]
	var reset_type = _get_reset_schedule(instance.raid_id, instance.difficulty)
	
	for participant in instance.participants:
		var player_id = participant.get_instance_id()
		
		if not raid_lockouts.has(player_id):
			raid_lockouts[player_id] = {}
		
		var lockout_key = instance.raid_id + "_" + instance.difficulty
		raid_lockouts[player_id][lockout_key] = {
			"locked_until": _calculate_reset_time(reset_type),
			"instance_id": instance_id,
			"progress": []
		}

func _is_player_locked_out(player: Node, raid_id: String, difficulty: String) -> bool:
	"""Verifica se jogador está em lockout"""
	var player_id = player.get_instance_id()
	var lockout_key = raid_id + "_" + difficulty
	
	if not raid_lockouts.has(player_id):
		return false
	
	var player_lockouts = raid_lockouts[player_id]
	if not player_lockouts.has(lockout_key):
		return false
	
	var lockout = player_lockouts[lockout_key]
	var current_time = Time.get_time_dict_from_system().unix
	
	return current_time < lockout.locked_until

func _update_raid_progress(instance_id: String, boss_name: String):
	"""Atualiza progresso do raid para todos os participantes"""
	var instance = active_raid_instances[instance_id]
	
	for participant in instance.participants:
		var player_id = participant.get_instance_id()
		
		if not player_raid_progress.has(player_id):
			player_raid_progress[player_id] = {}
		
		var progress_key = instance.raid_id + "_" + instance.difficulty
		if not player_raid_progress[player_id].has(progress_key):
			player_raid_progress[player_id][progress_key] = {
				"bosses_killed": [],
				"completion_count": 0,
				"best_time": 0,
				"achievements": []
			}
		
		var progress = player_raid_progress[player_id][progress_key]
		if not progress.bosses_killed.has(boss_name):
			progress.bosses_killed.push_back(boss_name)

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

func _get_player_data(player: Node) -> Dictionary:
	"""Obtém dados do jogador"""
	if player.has_method("get_player_data"):
		return player.get_player_data()
	return GameState.get_player_data()

func _generate_instance_id() -> String:
	"""Gera ID único para instância"""
	return "raid_" + str(Time.get_time_dict_from_system().unix) + "_" + str(randi())

func _get_raid_type_data(type: String) -> Dictionary:
	"""Obtém dados do tipo de raid"""
	return raid_system_data.raid_types.get(type, {})

func _apply_difficulty_scaling(instance_data: Dictionary):
	"""Aplica scaling de dificuldade"""
	var difficulty = instance_data.difficulty
	var scaling = raid_system_data.difficulty_levels.get(difficulty, {})
	
	if scaling.is_empty():
		return
	
	# Aplicar multiplicadores aos bosses
	for boss in instance_data.raid_data.bosses:
		if boss.has("health_base"):
			boss.health_scaled = int(boss.health_base * scaling.health_multiplier)
		if boss.has("damage_base"):
			boss.damage_scaled = int(boss.damage_base * scaling.damage_multiplier)

func _meets_raid_requirements(player: Node, instance: Dictionary) -> bool:
	"""Verifica se jogador atende requisitos"""
	var player_data = _get_player_data(player)
	var raid_data = instance.raid_data
	var difficulty_data = raid_system_data.difficulty_levels[instance.difficulty]
	
	# Verificar nível
	if player_data.level < difficulty_data.level_requirement:
		return false
	
	# Verificar item level se aplicável
	if difficulty_data.has("required_item_level"):
		var player_item_level = _get_player_item_level(player)
		if player_item_level < difficulty_data.required_item_level:
			return false
	
	return true

func _get_player_item_level(player: Node) -> int:
	"""Obtém item level médio do jogador"""
	# Implementar cálculo de item level
	return 50  # Placeholder

func _validate_group_composition(instance_id: String) -> bool:
	"""Valida composição do grupo"""
	var instance = active_raid_instances[instance_id]
	var group = raid_groups[instance_id]
	var type_data = _get_raid_type_data(instance.raid_data.type)
	
	# Se não requer composição específica, aceitar
	if not type_data.has("role_requirements"):
		return true
	
	# Contar roles
	var role_counts = {"tank": 0, "healer": 0, "dps": 0, "support": 0}
	
	for player_id in group.roles:
		var role = group.roles[player_id]
		if role_counts.has(role):
			role_counts[role] += 1
	
	# Verificar requisitos mínimos
	var requirements = raid_system_data.group_mechanics.role_requirements
	
	for role in requirements:
		var role_req = requirements[role]
		if role_counts[role] < role_req.min_required:
			return false
	
	return true

func _is_player_in_raid(player: Node) -> bool:
	"""Verifica se jogador está em algum raid"""
	var player_id = player.get_instance_id()
	
	for instance_id in active_raid_instances:
		var instance = active_raid_instances[instance_id]
		for participant in instance.participants:
			if participant.get_instance_id() == player_id:
				return true
	
	return false

func _get_player_instance(player: Node) -> String:
	"""Obtém instância atual do jogador"""
	var player_id = player.get_instance_id()
	
	for instance_id in active_raid_instances:
		var instance = active_raid_instances[instance_id]
		for participant in instance.participants:
			if participant.get_instance_id() == player_id:
				return instance_id
	
	return ""

func _teleport_players_to_raid(instance_id: String):
	"""Teleporta jogadores para o raid"""
	var instance = active_raid_instances[instance_id]
	
	# Implementar teleporte para raid
	print("[RaidSystem] Teleportando jogadores para raid %s" % instance_id)

func _respawn_raid_players(instance_id: String):
	"""Respawna jogadores do raid"""
	var instance = active_raid_instances[instance_id]
	
	for participant in instance.participants:
		if participant.has_method("respawn_in_raid"):
			participant.respawn_in_raid()

func _fail_raid_instance(instance_id: String, reason: String):
	"""Falha instância de raid"""
	var instance = active_raid_instances[instance_id]
	instance.status = "failed"
	
	# Teleportar jogadores de volta
	_teleport_players_out_of_raid(instance_id)
	
	print("[RaidSystem] Raid falhou: %s (%s)" % [instance_id, reason])

func _teleport_players_out_of_raid(instance_id: String):
	"""Teleporta jogadores para fora do raid"""
	# Implementar teleporte de saída
	print("[RaidSystem] Teleportando jogadores para fora do raid %s" % instance_id)

func _dissolve_raid_instance(instance_id: String):
	"""Dissolve instância de raid"""
	if active_raid_instances.has(instance_id):
		active_raid_instances.erase(instance_id)
	
	if raid_groups.has(instance_id):
		raid_groups.erase(instance_id)
	
	print("[RaidSystem] Instância dissolvida: %s" % instance_id)

func _scale_boss_for_difficulty(boss_data: Dictionary, difficulty: String) -> Dictionary:
	"""Escala boss para dificuldade"""
	var scaled = boss_data.duplicate()
	var scaling = raid_system_data.difficulty_levels[difficulty]
	
	if scaled.has("health_base"):
		scaled.health = int(scaled.health_base * scaling.health_multiplier)
	
	return scaled

func _scale_boss_for_player_count(boss_data: Dictionary, player_count: int) -> Dictionary:
	"""Escala boss para número de jogadores"""
	var scaled = boss_data.duplicate()
	
	# Scaling simples: +10% health e damage por jogador adicional acima do mínimo
	var scaling_factor = 1.0 + (player_count - 1) * 0.1
	
	if scaled.has("health"):
		scaled.health = int(scaled.health * scaling_factor)
	
	return scaled

func _roll_loot_quality(quality_distribution: Dictionary) -> String:
	"""Rola qualidade do loot"""
	var roll = randi() % 100
	var cumulative = 0
	
	for quality in quality_distribution:
		cumulative += quality_distribution[quality]
		if roll < cumulative:
			return quality
	
	return "common"

func _get_reset_schedule(raid_id: String, difficulty: String) -> String:
	"""Obtém schedule de reset para raid"""
	# Implementar lógica de reset baseada no raid e dificuldade
	return "weekly_reset"

func _calculate_reset_time(reset_type: String) -> int:
	"""Calcula próximo tempo de reset"""
	var current_time = Time.get_time_dict_from_system().unix
	
	match reset_type:
		"daily_reset":
			return current_time + 86400  # 24 horas
		"weekly_reset":
			return current_time + 604800  # 7 dias
		"monthly_reset":
			return current_time + 2592000  # 30 dias
		_:
			return current_time + 604800

func _check_boss_achievements(instance_id: String, boss_name: String, encounter_time: float):
	"""Verifica achievements de boss"""
	# Implementar sistema de achievements
	pass

# ============================================================================
# TIMERS E CLEANUP
# ============================================================================

func _cleanup_expired_instances():
	"""Remove instâncias expiradas"""
	var current_time = Time.get_time_dict_from_system().unix
	var instances_to_remove = []
	
	for instance_id in active_raid_instances:
		var instance = active_raid_instances[instance_id]
		var creation_time = instance.created_at.unix
		
		# Remover instâncias antigas (4 horas)
		if current_time - creation_time > 14400:
			instances_to_remove.push_back(instance_id)
	
	for instance_id in instances_to_remove:
		_dissolve_raid_instance(instance_id)

func _check_lockout_resets():
	"""Verifica e limpa lockouts expirados"""
	var current_time = Time.get_time_dict_from_system().unix
	
	for player_id in raid_lockouts:
		var player_lockouts = raid_lockouts[player_id]
		var lockouts_to_remove = []
		
		for lockout_key in player_lockouts:
			var lockout = player_lockouts[lockout_key]
			if current_time >= lockout.locked_until:
				lockouts_to_remove.push_back(lockout_key)
		
		for lockout_key in lockouts_to_remove:
			player_lockouts.erase(lockout_key)

# ============================================================================
# EVENTOS
# ============================================================================

func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
	"""Quando jogador sobe de nível"""
	# Verificar se desbloqueou novos raids
	pass

func _on_combat_ended(winner: String):
	"""Quando combate termina"""
	# Verificar se foi boss de raid
	pass

# ============================================================================
# API PÚBLICA
# ============================================================================

func get_available_raids(player: Node) -> Array:
	"""Obtém raids disponíveis para o jogador"""
	var available = []
	var player_data = _get_player_data(player)
	
	for raid_id in raid_system_data.raid_instances:
		var raid_data = raid_system_data.raid_instances[raid_id]
		
		# Verificar se atende requisitos básicos
		if player_data.level >= raid_data.recommended_level:
			available.push_back({
				"id": raid_id,
				"data": raid_data
			})
	
	return available

func get_player_raid_progress(player: Node) -> Dictionary:
	"""Obtém progresso de raid do jogador"""
	var player_id = player.get_instance_id()
	return player_raid_progress.get(player_id, {})

func get_player_lockouts(player: Node) -> Dictionary:
	"""Obtém lockouts do jogador"""
	var player_id = player.get_instance_id()
	return raid_lockouts.get(player_id, {})

func set_player_ready(player: Node, ready: bool) -> bool:
	"""Define status de ready do jogador"""
	var instance_id = _get_player_instance(player)
	if instance_id == "":
		return false
	
	var group = raid_groups[instance_id]
	var player_id_str = str(player.get_instance_id())
	
	if group.ready_status.has(player_id_str):
		group.ready_status[player_id_str] = ready
		return true
	
	return false

func change_player_role(instance_id: String, player: Node, new_role: String) -> bool:
	"""Muda role do jogador na instância"""
	if not raid_groups.has(instance_id):
		return false
	
	var group = raid_groups[instance_id]
	var player_id_str = str(player.get_instance_id())
	
	if group.roles.has(player_id_str):
		group.roles[player_id_str] = new_role
		return true
	
	return false

func get_instance_info(instance_id: String) -> Dictionary:
	"""Obtém informações da instância"""
	return active_raid_instances.get(instance_id, {})

func complete_raid_instance(instance_id: String, success: bool) -> bool:
	"""Completa instância de raid"""
	if not active_raid_instances.has(instance_id):
		return false
	
	var instance = active_raid_instances[instance_id]
	instance.status = "completed" if success else "failed"
	
	var completion_time = 0.0
	if instance.started_at:
		completion_time = Time.get_time_dict_from_system().unix - instance.started_at.unix
	
	# Processar recompensas finais
	if success:
		_process_completion_rewards(instance_id)
	
	# Emitir evento
	raid_completed.emit(instance_id, success, completion_time)
	
	# Cleanup após delay
	await get_tree().create_timer(30.0).timeout
	_dissolve_raid_instance(instance_id)
	
	return true

func _process_completion_rewards(instance_id: String):
	"""Processa recompensas de completar raid"""
	var instance = active_raid_instances[instance_id]
	
	# Conceder currency bonus
	# Conceder achievement progress
	# Etc.
	print("[RaidSystem] Processando recompensas de conclusão para %s" % instance_id)