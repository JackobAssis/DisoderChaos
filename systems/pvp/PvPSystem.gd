extends Node
class_name PvPSystem

signal match_started(match_id: String, players: Array, mode: String)
signal match_ended(match_id: String, winner: String, results: Dictionary)
signal player_joined_queue(player: Node, mode: String)
signal player_left_queue(player: Node, mode: String)
signal rating_updated(player: Node, old_rating: int, new_rating: int, tier: String)
signal tournament_started(tournament_id: String, participants: Array)
signal tournament_ended(tournament_id: String, champion: Node, results: Array)

# Dados do sistema
var pvp_system_data: Dictionary = {}
var active_matches: Dictionary = {}
var match_queues: Dictionary = {}
var player_ratings: Dictionary = {}
var active_tournaments: Dictionary = {}
var player_stats: Dictionary = {}

# ConfiguraÃ§Ãµes
var pvp_enabled: bool = true
var ranked_enabled: bool = true
var tournaments_enabled: bool = true
var balance_normalization: bool = true

# Matchmaking
var matchmaking_active: bool = true
var queue_timers: Dictionary = {}

# ReferÃªncias
@onready var data_loader: DataLoader = DataLoader.new()
@onready var event_bus: EventBus = EventBus

func _ready():
	name = "PvPSystem"
	load_pvp_system_data()
	initialize_queues()
	connect_events()
	print("[PvPSystem] Sistema PvP inicializado")

func load_pvp_system_data():
# Carrega dados do sistema PvP
	var data = data_loader.load_json_file("res://data/pvp/pvp_system.json")
	if data:
		pvp_system_data = data.pvp_system
		print("[PvPSystem] Dados PvP carregados")
	else:
		push_error("[PvPSystem] Falha ao carregar dados PvP")

func initialize_queues():
# Inicializa filas de matchmaking
	for mode in pvp_system_data.game_modes:
		match_queues[mode] = []
	print("[PvPSystem] Filas de matchmaking inicializadas")

func connect_events():
# Conecta aos eventos necessÃ¡rios
	event_bus.player_level_up.connect(_on_player_level_up)
	event_bus.combat_ended.connect(_on_combat_ended)

# ============================================================================
# SISTEMA DE FILAS E MATCHMAKING
# ============================================================================

func queue_for_pvp(player: Node, mode: String) -> bool:
# Adiciona jogador Ã  fila de PvP
	if not pvp_enabled:
		print("[PvPSystem] PvP estÃ¡ desabilitado")
		return false
	
	if not pvp_system_data.game_modes.has(mode):
		print("[PvPSystem] Modo PvP invÃ¡lido: ", mode)
		return false
	
	# Verificar se jÃ¡ estÃ¡ em fila
	if _is_player_in_any_queue(player):
		print("[PvPSystem] Jogador jÃ¡ estÃ¡ em fila")
		return false
	
	var mode_data = pvp_system_data.game_modes[mode]
	
	# Verificar requisitos do modo
	if not _meets_mode_requirements(player, mode_data):
		print("[PvPSystem] Jogador nÃ£o atende requisitos do modo")
		return false
	
	# Adicionar Ã  fila
	var queue_entry = {
		"player": player,
		"player_id": player.get_instance_id(),
		"rating": _get_player_rating(player, mode),
		"queue_time": Time.get_time_dict_from_system().unix,
		"search_range": pvp_system_data.matchmaking.queue_parameters.initial_search_range
	}
	
	match_queues[mode].push_back(queue_entry)
	
	# Iniciar timer de busca
	_start_queue_timer(player, mode)
	
	# Emitir evento
	player_joined_queue.emit(player, mode)
	
	# Tentar matchmaking imediatamente
	_attempt_matchmaking(mode)
	
	print("[PvPSystem] Jogador %s entrou na fila %s" % [player.name, mode])
	return true

func leave_queue(player: Node) -> bool:
# Remove jogador de todas as filas
	var removed = false
	
	for mode in match_queues:
		var queue = match_queues[mode]
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].player == player:
				queue.remove_at(i)
				removed = true
				player_left_queue.emit(player, mode)
				break
	
	# Remover timer
	if queue_timers.has(player.get_instance_id()):
		queue_timers.erase(player.get_instance_id())
	
	if removed:
		print("[PvPSystem] Jogador %s saiu da fila" % player.name)
	
	return removed

func _attempt_matchmaking(mode: String):
# Tenta fazer matchmaking para um modo
	if not matchmaking_active:
		return
	
	var queue = match_queues[mode]
	var mode_data = pvp_system_data.game_modes[mode]
	
	if queue.size() < mode_data.min_players:
		return
	
	# Ordenar por tempo de fila e rating
	queue.sort_custom(_compare_queue_entries)
	
	# Encontrar matches possÃ­veis
	var potential_matches = _find_potential_matches(queue, mode_data)
	
	# Criar matches
	for match_data in potential_matches:
		_create_match(match_data, mode)

func _find_potential_matches(queue: Array, mode_data: Dictionary) -> Array:
# Encontra matches potenciais na fila
	var potential_matches = []
	var used_players = []
	
	var players_needed = mode_data.max_players
	
	for i in range(queue.size() - players_needed + 1):
		if used_players.has(i):
			continue
		
		var anchor_player = queue[i]
		var match_players = [anchor_player]
		used_players.push_back(i)
		
		# Encontrar players compatÃ­veis
		for j in range(i + 1, queue.size()):
			if used_players.has(j):
				continue
			
			var candidate = queue[j]
			
			# Verificar compatibilidade de rating
			var rating_diff = abs(anchor_player.rating - candidate.rating)
			if rating_diff <= anchor_player.search_range:
				match_players.push_back(candidate)
				used_players.push_back(j)
				
				if match_players.size() >= players_needed:
					break
		
		# Se encontrou players suficientes
		if match_players.size() >= mode_data.min_players:
			potential_matches.push_back(match_players)
	
	return potential_matches

func _create_match(players: Array, mode: String) -> String:
# Cria uma nova partida
	var match_id = _generate_match_id()
	var mode_data = pvp_system_data.game_modes[mode]
	
	# Remover players da fila
	for player_entry in players:
		_remove_from_queue(player_entry.player, mode)
	
	# Dividir em teams se necessÃ¡rio
	var teams = _divide_into_teams(players, mode)
	
	# Criar dados da partida
	var match_data = {
		"id": match_id,
		"mode": mode,
		"players": players,
		"teams": teams,
		"start_time": Time.get_time_dict_from_system(),
		"status": "starting",
		"map": _select_map(mode_data),
		"duration": mode_data.duration_minutes * 60,
		"score": {},
		"stats": {}
	}
	
	# Aplicar normalizaÃ§Ã£o de stats se necessÃ¡rio
	if _should_normalize_stats(mode):
		_apply_stat_normalization(players, mode)
	
	# Salvar match
	active_matches[match_id] = match_data
	
	# Emitir evento
	var player_nodes = []
	for player_entry in players:
		player_nodes.push_back(player_entry.player)
	
	match_started.emit(match_id, player_nodes, mode)
	
	print("[PvPSystem] Match criado: %s (%s)" % [match_id, mode])
	return match_id

# ============================================================================
# SISTEMA DE RATING E RANKING
# ============================================================================

func _get_player_rating(player: Node, mode: String) -> int:
# ObtÃ©m rating do jogador para um modo
	var player_id = player.get_instance_id()
	
	if not player_ratings.has(player_id):
		player_ratings[player_id] = {}
	
	var player_rating_data = player_ratings[player_id]
	
	if not player_rating_data.has(mode):
		player_rating_data[mode] = {
			"rating": 1000,  # Rating inicial
			"tier": "bronze",
			"division": 5,
			"games_played": 0,
			"wins": 0,
			"losses": 0,
			"win_streak": 0,
			"loss_streak": 0
		}
	
	return player_rating_data[mode].rating

func update_player_rating(player: Node, mode: String, won: bool, performance: Dictionary):
# Atualiza rating do jogador baseado no resultado
	if not ranked_enabled:
		return
	
	var player_id = player.get_instance_id()
	var rating_data = player_ratings[player_id][mode]
	var old_rating = rating_data.rating
	
	# Calcular mudanÃ§a de rating
	var rating_change = _calculate_rating_change(rating_data, won, performance)
	
	# Aplicar mudanÃ§a
	rating_data.rating = max(0, rating_data.rating + rating_change)
	rating_data.games_played += 1
	
	if won:
		rating_data.wins += 1
		rating_data.win_streak += 1
		rating_data.loss_streak = 0
	else:
		rating_data.losses += 1
		rating_data.loss_streak += 1
		rating_data.win_streak = 0
	
	# Atualizar tier e divisÃ£o
	var old_tier = rating_data.tier
	_update_tier_and_division(rating_data)
	
	# Emitir evento se tier mudou
	if old_tier != rating_data.tier:
		rating_updated.emit(player, old_rating, rating_data.rating, rating_data.tier)
	
	print("[PvPSystem] Rating atualizado - %s: %d â†’ %d (%s)" % [
		player.name, old_rating, rating_data.rating, rating_data.tier
	])

func _calculate_rating_change(rating_data: Dictionary, won: bool, performance: Dictionary) -> int:
# Calcula mudanÃ§a de rating
	var calculation = pvp_system_data.ranking_system.rating_calculation
	var base_change = calculation.base_rating_gain if won else -calculation.base_rating_loss
	
	# Multiplicador de performance
	var performance_level = performance.get("level", "average")
	var performance_multiplier = calculation.performance_multiplier.get(performance_level, 1.0)
	
	# BÃ´nus de streak
	var streak_bonus = 0
	if won and rating_data.win_streak >= 3:
		if rating_data.win_streak >= 10:
			streak_bonus = calculation.streak_bonus.win_streak_10
		elif rating_data.win_streak >= 5:
			streak_bonus = calculation.streak_bonus.win_streak_5
		else:
			streak_bonus = calculation.streak_bonus.win_streak_3
	elif not won and rating_data.loss_streak >= 3:
		streak_bonus = calculation.streak_bonus.loss_streak_protection
	
	# BÃ´nus de matchmaking
	var fairness_bonus = performance.get("fairness_bonus", 0)
	
	# Calcular mudanÃ§a final
	var total_change = int((base_change * performance_multiplier) + streak_bonus + fairness_bonus)
	
	return total_change

func _update_tier_and_division(rating_data: Dictionary):
# Atualiza tier e divisÃ£o baseado no rating
	var rating = rating_data.rating
	var tiers = pvp_system_data.ranking_system.rating_tiers
	
	for tier_name in tiers:
		var tier_data = tiers[tier_name]
		if rating >= tier_data.min_rating and rating <= tier_data.max_rating:
			rating_data.tier = tier_name
			
			# Calcular divisÃ£o
			if tier_data.has("divisions") and tier_data.divisions > 1:
				var tier_range = tier_data.max_rating - tier_data.min_rating
				var division_size = tier_range / tier_data.divisions
				var division = int((rating - tier_data.min_rating) / division_size) + 1
				rating_data.division = min(division, tier_data.divisions)
			else:
				rating_data.division = 1
			
			break

# ============================================================================
# BALANCEAMENTO E NORMALIZAÃ‡ÃƒO
# ============================================================================

func _should_normalize_stats(mode: String) -> bool:
# Verifica se deve normalizar stats para o modo
	var balance = pvp_system_data.balance_mechanics
	return balance.stat_normalization.enabled_modes.has(mode)

func _apply_stat_normalization(players: Array, mode: String):
# Aplica normalizaÃ§Ã£o de stats
	if not balance_normalization:
		return
	
	var normalized_stats = pvp_system_data.balance_mechanics.stat_normalization.normalized_stats
	
	for player_entry in players:
		var player = player_entry.player
		_normalize_player_stats(player, normalized_stats)

func _normalize_player_stats(player: Node, normalized_stats: Dictionary):
# Normaliza stats de um jogador
	if not player.has_method("apply_pvp_normalization"):
		return
	
	# Aplicar normalizaÃ§Ã£o via mÃ©todo do jogador
	player.apply_pvp_normalization(normalized_stats)
	
	# Aplicar modificadores de classe
	var player_data = _get_player_data(player)
	var class_balance = pvp_system_data.balance_mechanics.class_balance
	
	if class_balance.has(player_data.class):
		var modifiers = class_balance[player_data.class]
		player.apply_pvp_class_modifiers(modifiers)

func apply_pvp_ability_modifications(player: Node):
# Aplica modificaÃ§Ãµes especÃ­ficas de PvP para habilidades
	var global_changes = pvp_system_data.balance_mechanics.ability_modifications.global_pvp_changes
	var specific_nerfs = pvp_system_data.balance_mechanics.ability_modifications.specific_ability_nerfs
	
	if player.has_method("apply_pvp_ability_modifications"):
		player.apply_pvp_ability_modifications(global_changes, specific_nerfs)

# ============================================================================
# SISTEMA DE TORNEIOS
# ============================================================================

func create_tournament(tournament_type: String, organizer: Node = null) -> String:
# Cria um novo torneio
	if not tournaments_enabled:
		return ""
	
	var tournament_data = pvp_system_data.tournament_system.tournament_types.get(tournament_type)
	if not tournament_data:
		return ""
	
	var tournament_id = _generate_tournament_id()
	var tournament = {
		"id": tournament_id,
		"type": tournament_type,
		"organizer": organizer,
		"participants": [],
		"status": "registration",
		"created_at": Time.get_time_dict_from_system(),
		"start_time": null,
		"matches": [],
		"bracket": {},
		"prizes": _calculate_tournament_prizes(tournament_type)
	}
	
	active_tournaments[tournament_id] = tournament
	
	print("[PvPSystem] Torneio criado: %s (%s)" % [tournament_id, tournament_type])
	return tournament_id

func register_for_tournament(tournament_id: String, player: Node) -> bool:
# Registra jogador em torneio
	if not active_tournaments.has(tournament_id):
		return false
	
	var tournament = active_tournaments[tournament_id]
	
	if tournament.status != "registration":
		return false
	
	# Verificar qualificaÃ§Ãµes
	if not _meets_tournament_requirements(player, tournament):
		return false
	
	# Verificar se jÃ¡ estÃ¡ registrado
	for participant in tournament.participants:
		if participant.get_instance_id() == player.get_instance_id():
			return false
	
	# Registrar
	tournament.participants.push_back(player)
	
	print("[PvPSystem] Jogador %s registrado no torneio %s" % [player.name, tournament_id])
	return true

func start_tournament(tournament_id: String) -> bool:
# Inicia um torneio
	if not active_tournaments.has(tournament_id):
		return false
	
	var tournament = active_tournaments[tournament_id]
	var tournament_type_data = pvp_system_data.tournament_system.tournament_types[tournament.type]
	
	if tournament.participants.size() < 2:
		return false
	
	# Gerar bracket
	tournament.bracket = _generate_tournament_bracket(tournament.participants, tournament.type)
	tournament.status = "in_progress"
	tournament.start_time = Time.get_time_dict_from_system()
	
	# Emitir evento
	tournament_started.emit(tournament_id, tournament.participants)
	
	# Iniciar primeiras partidas
	_start_tournament_round(tournament_id, 1)
	
	print("[PvPSystem] Torneio iniciado: %s" % tournament_id)
	return true

# ============================================================================
# FUNÃ‡Ã•ES AUXILIARES
# ============================================================================

func _get_player_data(player: Node) -> Dictionary:
# ObtÃ©m dados do jogador
	if player.has_method("get_player_data"):
		return player.get_player_data()
	return GameState.get_player_data()

func _is_player_in_any_queue(player: Node) -> bool:
# Verifica se jogador estÃ¡ em alguma fila
	var player_id = player.get_instance_id()
	
	for mode in match_queues:
		var queue = match_queues[mode]
		for entry in queue:
			if entry.player_id == player_id:
				return true
	
	return false

func _meets_mode_requirements(player: Node, mode_data: Dictionary) -> bool:
# Verifica se jogador atende requisitos do modo
	var player_data = _get_player_data(player)
	
	if mode_data.has("requirements"):
		var requirements = mode_data.requirements
		
		if requirements.has("min_level"):
			if player_data.level < requirements.min_level:
				return false
		
		if requirements.has("ranked_games_required"):
			var player_id = player.get_instance_id()
			if player_ratings.has(player_id):
				var rating_data = player_ratings[player_id]
				var total_games = 0
				for mode in rating_data:
					total_games += rating_data[mode].get("games_played", 0)
				
				if total_games < requirements.ranked_games_required:
					return false
	
	return true

func _meets_tournament_requirements(player: Node, tournament: Dictionary) -> bool:
# Verifica requisitos de torneio
	var tournament_type = tournament.type
	var tournament_data = pvp_system_data.tournament_system.tournament_types[tournament_type]
	
	# Implementar verificaÃ§Ãµes especÃ­ficas de torneio
	return true

func _compare_queue_entries(a: Dictionary, b: Dictionary) -> bool:
# Compara entradas da fila para ordenaÃ§Ã£o
	# Priorizar por tempo de fila primeiro
	if a.queue_time != b.queue_time:
		return a.queue_time < b.queue_time
	
	# Depois por rating
	return a.rating > b.rating

func _remove_from_queue(player: Node, mode: String):
# Remove jogador especÃ­fico da fila
	var queue = match_queues[mode]
	var player_id = player.get_instance_id()
	
	for i in range(queue.size() - 1, -1, -1):
		if queue[i].player_id == player_id:
			queue.remove_at(i)
			break

func _divide_into_teams(players: Array, mode: String) -> Array:
# Divide jogadores em teams
	var teams = [[], []]
	
	# Dividir por rating balanceado
	players.sort_custom(func(a, b): return a.rating > b.rating)
	
	for i in range(players.size()):
		var team_index = i % 2
		teams[team_index].push_back(players[i])
	
	return teams

func _select_map(mode_data: Dictionary) -> String:
# Seleciona mapa para a partida
	if mode_data.has("maps") and mode_data.maps.size() > 0:
		return mode_data.maps[randi() % mode_data.maps.size()]
	return "default_map"

func _generate_match_id() -> String:
# Gera ID Ãºnico para partida
	return "match_" + str(Time.get_time_dict_from_system().unix) + "_" + str(randi())

func _generate_tournament_id() -> String:
# Gera ID Ãºnico para torneio
	return "tournament_" + str(Time.get_time_dict_from_system().unix) + "_" + str(randi())

func _generate_tournament_bracket(participants: Array, tournament_type: String) -> Dictionary:
# Gera bracket do torneio
	# ImplementaÃ§Ã£o de bracket baseada no tipo de torneio
	return {}

func _start_tournament_round(tournament_id: String, round_number: int):
# Inicia round do torneio
	# Implementar lÃ³gica de rounds de torneio
	pass

func _calculate_tournament_prizes(tournament_type: String) -> Dictionary:
# Calcula prÃªmios do torneio
	return {}

func _start_queue_timer(player: Node, mode: String):
# Inicia timer de expansÃ£o de busca
	var player_id = player.get_instance_id()
	queue_timers[player_id] = {
		"mode": mode,
		"start_time": Time.get_time_dict_from_system().unix
	}

# ============================================================================
# EVENTOS
# ============================================================================

func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
# Quando jogador sobe de nÃ­vel
	# Verificar se desbloqueou novos modos PvP
	pass

func _on_combat_ended(winner: String):
# Quando combate termina
	# Processar resultado se for match PvP
	pass

# ============================================================================
# API PÃšBLICA
# ============================================================================

func get_player_pvp_stats(player: Node) -> Dictionary:
# ObtÃ©m estatÃ­sticas PvP do jogador
	var player_id = player.get_instance_id()
	return player_ratings.get(player_id, {})

func get_active_match(player: Node) -> Dictionary:
# ObtÃ©m partida ativa do jogador
	var player_id = player.get_instance_id()
	
	for match_id in active_matches:
		var match_data = active_matches[match_id]
		for player_entry in match_data.players:
			if player_entry.player_id == player_id:
				return match_data
	
	return {}

func get_leaderboard(mode: String, limit: int = 50) -> Array:
# ObtÃ©m leaderboard de um modo
	var leaderboard = []
	
	for player_id in player_ratings:
		var player_data = player_ratings[player_id]
		if player_data.has(mode):
			leaderboard.push_back({
				"player_id": player_id,
				"rating": player_data[mode].rating,
				"tier": player_data[mode].tier,
				"wins": player_data[mode].wins,
				"losses": player_data[mode].losses
			})
	
	# Ordenar por rating
	leaderboard.sort_custom(func(a, b): return a.rating > b.rating)
	
	# Limitar resultados
	if leaderboard.size() > limit:
		leaderboard = leaderboard.slice(0, limit)
	
	return leaderboard

func end_match(match_id: String, winner_team: int, stats: Dictionary) -> bool:
# Finaliza uma partida
	if not active_matches.has(match_id):
		return false
	
	var match_data = active_matches[match_id]
	match_data.status = "ended"
	match_data.end_time = Time.get_time_dict_from_system()
	match_data.winner = winner_team
	match_data.final_stats = stats
	
	# Processar resultados para cada jogador
	_process_match_results(match_data)
	
	# Emitir evento
	match_ended.emit(match_id, str(winner_team), stats)
	
	# Remover match ativo
	active_matches.erase(match_id)
	
	print("[PvPSystem] Match finalizado: %s" % match_id)
	return true

func _process_match_results(match_data: Dictionary):
# Processa resultados da partida
	var mode = match_data.mode
	
	for i in range(match_data.players.size()):
		var player_entry = match_data.players[i]
		var player = player_entry.player
		
		# Determinar se ganhou
		var player_team = _get_player_team(player, match_data.teams)
		var won = (player_team == match_data.get("winner", -1))
		
		# Calcular performance
		var performance = _calculate_player_performance(player, match_data.final_stats)
		
		# Atualizar rating se for modo ranqueado
		if _is_ranked_mode(mode):
			update_player_rating(player, mode, won, performance)
		
		# Conceder recompensas
		_award_match_rewards(player, won, performance, mode)
