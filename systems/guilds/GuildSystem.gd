extends Node
class_name GuildSystem

signal guild_created(guild_id: String, guild_name: String, founder: Node)
signal guild_disbanded(guild_id: String, guild_name: String)
signal member_joined(guild_id: String, player: Node, rank: String)
signal member_left(guild_id: String, player: Node, reason: String)
signal member_promoted(guild_id: String, player: Node, new_rank: String)
signal member_demoted(guild_id: String, player: Node, new_rank: String)
signal guild_activity_started(guild_id: String, activity_type: String)
signal guild_activity_completed(guild_id: String, activity_type: String, success: bool)
signal alliance_formed(alliance_id: String, guild_ids: Array)
signal alliance_disbanded(alliance_id: String)

# Dados do sistema
var guild_system_data: Dictionary = {}
var active_guilds: Dictionary = {}
var player_guild_membership: Dictionary = {}
var alliance_data: Dictionary = {}
var guild_activities: Dictionary = {}

# ConfiguraÃ§Ãµes
var guild_system_enabled: bool = true
var alliance_system_enabled: bool = true
var max_guilds_per_player: int = 1

# ReferÃªncias
@onready var data_loader: DataLoader = DataLoader.new()
@onready var event_bus: EventBus = EventBus

func _ready():
	name = "GuildSystem"
	load_guild_system_data()
	connect_events()
	print("[GuildSystem] Sistema de guildas inicializado")

func load_guild_system_data():
# Carrega dados do sistema de guildas
	var data = data_loader.load_json_file("res://data/guilds/guild_system.json")
	if data:
		guild_system_data = data.guild_system
		print("[GuildSystem] Dados do sistema de guildas carregados")
	else:
		push_error("[GuildSystem] Falha ao carregar dados de guildas")

func connect_events():
# Conecta aos eventos necessÃ¡rios
	event_bus.player_level_up.connect(_on_player_level_up)

# ============================================================================
# CRIAÃ‡ÃƒO E GERENCIAMENTO DE GUILDAS
# ============================================================================

func can_create_guild(player: Node, guild_name: String) -> Dictionary:
# Verifica se jogador pode criar guilda
	var result = {"can_create": false, "reason": ""}
	
	if not guild_system_enabled:
		result.reason = "Sistema de guildas desabilitado"
		return result
	
	# Verificar se jÃ¡ estÃ¡ em guilda
	if is_player_in_guild(player):
		result.reason = "Jogador jÃ¡ estÃ¡ em uma guilda"
		return result
	
	var player_data = _get_player_data(player)
	var requirements = guild_system_data.creation_requirements
	
	# Verificar nÃ­vel
	if player_data.level < requirements.min_level:
		result.reason = "NÃ­vel insuficiente (requerido: %d)" % requirements.min_level
		return result
	
	# Verificar gold
	if player_data.currency < requirements.creation_cost:
		result.reason = "Gold insuficiente (requerido: %d)" % requirements.creation_cost
		return result
	
	# Verificar nome
	if not _is_valid_guild_name(guild_name):
		result.reason = "Nome de guilda invÃ¡lido"
		return result
	
	# Verificar se nome jÃ¡ existe
	if _guild_name_exists(guild_name):
		result.reason = "Nome de guilda jÃ¡ existe"
		return result
	
	result.can_create = true
	return result

func create_guild(player: Node, guild_name: String, guild_description: String = "") -> String:
# Cria uma nova guilda
	var validation = can_create_guild(player, guild_name)
	if not validation.can_create:
		print("[GuildSystem] NÃ£o pode criar guilda: ", validation.reason)
		return ""
	
	var guild_id = _generate_guild_id()
	var requirements = guild_system_data.creation_requirements
	
	# Criar dados da guilda
	var guild_data = {
		"id": guild_id,
		"name": guild_name,
		"description": guild_description,
		"founder_id": player.get_instance_id(),
		"created_at": Time.get_time_dict_from_system(),
		"level": 1,
		"experience": 0,
		"members": {},
		"treasury": {
			"gold": 0,
			"resources": {}
		},
		"hall_upgrades": {},
		"activities": [],
		"alliances": [],
		"settings": {
			"recruitment_open": true,
			"min_level_requirement": 1,
			"auto_kick_inactive_days": 30
		}
	}
	
	# Adicionar fundador como guild master
	guild_data.members[str(player.get_instance_id())] = {
		"player_id": player.get_instance_id(),
		"rank": "guild_master",
		"joined_at": Time.get_time_dict_from_system(),
		"contributions": {"total": 0},
		"last_activity": Time.get_time_dict_from_system()
	}
	
	# Salvar guilda
	active_guilds[guild_id] = guild_data
	
	# Registrar membership
	player_guild_membership[player.get_instance_id()] = guild_id
	
	# Cobrar custo
	_charge_player_currency(player, requirements.creation_cost)
	
	# Emitir evento
	guild_created.emit(guild_id, guild_name, player)
	
	print("[GuildSystem] Guilda criada: %s (ID: %s)" % [guild_name, guild_id])
	return guild_id

func disband_guild(guild_id: String, requester: Node) -> bool:
# Dissolve uma guilda
	if not active_guilds.has(guild_id):
		return false
	
	var guild = active_guilds[guild_id]
	
	# Verificar se Ã© o guild master
	if not _is_guild_master(requester, guild_id):
		return false
	
	# Remover todos os membros
	for member_id in guild.members:
		var member_id_int = str(member_id).to_int()
		if player_guild_membership.has(member_id_int):
			player_guild_membership.erase(member_id_int)
	
	# Remover de alianÃ§as
	_leave_all_alliances(guild_id)
	
	# Remover guilda
	var guild_name = guild.name
	active_guilds.erase(guild_id)
	
	# Emitir evento
	guild_disbanded.emit(guild_id, guild_name)
	
	print("[GuildSystem] Guilda dissolvida: %s" % guild_name)
	return true

# ============================================================================
# GERENCIAMENTO DE MEMBROS
# ============================================================================

func can_invite_player(guild_id: String, inviter: Node, target_player: Node) -> Dictionary:
# Verifica se pode convidar jogador
	var result = {"can_invite": false, "reason": ""}
	
	if not active_guilds.has(guild_id):
		result.reason = "Guilda nÃ£o encontrada"
		return result
	
	# Verificar permissÃµes do convidador
	if not _has_permission(inviter, guild_id, "invite_members"):
		result.reason = "Sem permissÃ£o para convidar"
		return result
	
	# Verificar se target jÃ¡ estÃ¡ em guilda
	if is_player_in_guild(target_player):
		result.reason = "Jogador jÃ¡ estÃ¡ em uma guilda"
		return result
	
	var guild = active_guilds[guild_id]
	var current_members = guild.members.size()
	var max_members = _get_guild_max_members(guild)
	
	# Verificar limite de membros
	if current_members >= max_members:
		result.reason = "Guilda estÃ¡ cheia"
		return result
	
	result.can_invite = true
	return result

func invite_player_to_guild(guild_id: String, inviter: Node, target_player: Node) -> bool:
# Convida jogador para guilda
	var validation = can_invite_player(guild_id, inviter, target_player)
	if not validation.can_invite:
		print("[GuildSystem] NÃ£o pode convidar: ", validation.reason)
		return false
	
	# Criar convite
	var invite_data = {
		"guild_id": guild_id,
		"guild_name": active_guilds[guild_id].name,
		"inviter_id": inviter.get_instance_id(),
		"target_id": target_player.get_instance_id(),
		"expires_at": Time.get_time_dict_from_system().unix + 300  # 5 minutos
	}
	
	# Enviar convite (implementar sistema de convites)
	_send_guild_invite(invite_data)
	
	print("[GuildSystem] Convite enviado para %s" % target_player.name)
	return true

func accept_guild_invite(player: Node, guild_id: String) -> bool:
# Aceita convite de guilda
	if not active_guilds.has(guild_id):
		return false
	
	if is_player_in_guild(player):
		return false
	
	var guild = active_guilds[guild_id]
	var player_id = player.get_instance_id()
	
	# Adicionar como recruta
	guild.members[str(player_id)] = {
		"player_id": player_id,
		"rank": "recruit",
		"joined_at": Time.get_time_dict_from_system(),
		"contributions": {"total": 0},
		"last_activity": Time.get_time_dict_from_system()
	}
	
	# Registrar membership
	player_guild_membership[player_id] = guild_id
	
	# Emitir evento
	member_joined.emit(guild_id, player, "recruit")
	
	print("[GuildSystem] Jogador %s entrou na guilda %s" % [player.name, guild.name])
	return true

func leave_guild(player: Node, guild_id: String = "") -> bool:
# Sai da guilda
	var player_id = player.get_instance_id()
	
	if guild_id == "":
		guild_id = player_guild_membership.get(player_id, "")
	
	if guild_id == "":
		return false
	
	if not active_guilds.has(guild_id):
		return false
	
	var guild = active_guilds[guild_id]
	
	# Verificar se Ã© guild master
	if _is_guild_master(player, guild_id):
		# Guild master nÃ£o pode sair, deve transferir lideranÃ§a ou dissolver
		return false
	
	# Remover da guilda
	guild.members.erase(str(player_id))
	player_guild_membership.erase(player_id)
	
	# Emitir evento
	member_left.emit(guild_id, player, "voluntary")
	
	print("[GuildSystem] Jogador %s saiu da guilda %s" % [player.name, guild.name])
	return true

func kick_member(guild_id: String, kicker: Node, target_player_id: int) -> bool:
# Expulsa membro da guilda
	if not active_guilds.has(guild_id):
		return false
	
	# Verificar permissÃµes
	if not _has_permission(kicker, guild_id, "kick_members"):
		return false
	
	var guild = active_guilds[guild_id]
	var target_member_data = guild.members.get(str(target_player_id))
	
	if not target_member_data:
		return false
	
	# NÃ£o pode expulsar guild master ou rank superior
	var kicker_rank_level = _get_rank_level(kicker, guild_id)
	var target_rank_level = _get_rank_level_by_rank(target_member_data.rank)
	
	if target_rank_level >= kicker_rank_level:
		return false
	
	# Remover membro
	guild.members.erase(str(target_player_id))
	player_guild_membership.erase(target_player_id)
	
	# Emitir evento (placeholder para target_player)
	var placeholder_player = Node.new()
	placeholder_player.name = "Player_" + str(target_player_id)
	member_left.emit(guild_id, placeholder_player, "kicked")
	
	print("[GuildSystem] Membro %d expulso da guilda %s" % [target_player_id, guild.name])
	return true

# ============================================================================
# SISTEMA DE RANKS
# ============================================================================

func promote_member(guild_id: String, promoter: Node, target_player_id: int, new_rank: String) -> bool:
# Promove membro
	if not active_guilds.has(guild_id):
		return false
	
	# Verificar permissÃµes
	var promoter_rank_level = _get_rank_level(promoter, guild_id)
	var new_rank_level = _get_rank_level_by_rank(new_rank)
	
	if promoter_rank_level <= new_rank_level:
		return false
	
	var guild = active_guilds[guild_id]
	var target_member = guild.members.get(str(target_player_id))
	
	if not target_member:
		return false
	
	# Verificar limites de rank
	if not _can_promote_to_rank(guild_id, new_rank):
		return false
	
	# Promover
	target_member.rank = new_rank
	
	# Emitir evento
	var placeholder_player = Node.new()
	placeholder_player.name = "Player_" + str(target_player_id)
	member_promoted.emit(guild_id, placeholder_player, new_rank)
	
	print("[GuildSystem] Membro %d promovido para %s" % [target_player_id, new_rank])
	return true

func demote_member(guild_id: String, demoter: Node, target_player_id: int, new_rank: String) -> bool:
# Rebaixa membro
	if not active_guilds.has(guild_id):
		return false
	
	# Verificar permissÃµes (similar ao promote)
	var demoter_rank_level = _get_rank_level(demoter, guild_id)
	var guild = active_guilds[guild_id]
	var target_member = guild.members.get(str(target_player_id))
	
	if not target_member:
		return false
	
	var current_rank_level = _get_rank_level_by_rank(target_member.rank)
	
	if demoter_rank_level <= current_rank_level:
		return false
	
	# Rebaixar
	target_member.rank = new_rank
	
	# Emitir evento
	var placeholder_player = Node.new()
	placeholder_player.name = "Player_" + str(target_player_id)
	member_demoted.emit(guild_id, placeholder_player, new_rank)
	
	print("[GuildSystem] Membro %d rebaixado para %s" % [target_player_id, new_rank])
	return true

# ============================================================================
# ATIVIDADES DE GUILDA
# ============================================================================

func start_guild_raid(guild_id: String, organizer: Node, boss_type: String) -> bool:
# Inicia raid de guilda
	if not active_guilds.has(guild_id):
		return false
	
	# Verificar permissÃµes
	if not _has_permission(organizer, guild_id, "start_guild_activities"):
		return false
	
	var activities_data = guild_system_data.guild_activities.guild_raids
	var boss_data = null
	
	# Encontrar dados do boss
	for boss in activities_data.boss_types:
		if boss.name == boss_type:
			boss_data = boss
			break
	
	if not boss_data:
		return false
	
	var guild = active_guilds[guild_id]
	
	# Verificar nÃ­vel da guilda
	if guild.level < boss_data.required_guild_level:
		return false
	
	# Verificar cooldown
	if _guild_activity_on_cooldown(guild_id, "guild_raid"):
		return false
	
	# Criar atividade
	var activity_id = _generate_activity_id()
	var activity_data = {
		"id": activity_id,
		"type": "guild_raid",
		"boss_type": boss_type,
		"organizer_id": organizer.get_instance_id(),
		"participants": [],
		"status": "recruiting",
		"start_time": null,
		"end_time": null,
		"cooldown_expires": Time.get_time_dict_from_system().unix + (activities_data.cooldown_hours * 3600)
	}
	
	guild_activities[activity_id] = activity_data
	guild.activities.push_back(activity_id)
	
	# Emitir evento
	guild_activity_started.emit(guild_id, "guild_raid")
	
	print("[GuildSystem] Raid iniciado: %s" % boss_type)
	return true

func join_guild_activity(player: Node, activity_id: String) -> bool:
# Participa de atividade de guilda
	if not guild_activities.has(activity_id):
		return false
	
	var activity = guild_activities[activity_id]
	var player_guild = get_player_guild(player)
	
	if not player_guild:
		return false
	
	# Verificar se atividade Ã© da guilda do jogador
	var guild = active_guilds[player_guild]
	if not guild.activities.has(activity_id):
		return false
	
	# Verificar status da atividade
	if activity.status != "recruiting":
		return false
	
	# Verificar se jÃ¡ estÃ¡ participando
	if activity.participants.has(player.get_instance_id()):
		return false
	
	# Adicionar participante
	activity.participants.push_back(player.get_instance_id())
	
	print("[GuildSystem] Jogador %s entrou na atividade %s" % [player.name, activity_id])
	return true

# ============================================================================
# SISTEMA DE ALIANÃ‡AS
# ============================================================================

func can_form_alliance(guild_ids: Array, alliance_name: String) -> Dictionary:
# Verifica se pode formar alianÃ§a
	var result = {"can_form": false, "reason": ""}
	
	if not alliance_system_enabled:
		result.reason = "Sistema de alianÃ§as desabilitado"
		return result
	
	var requirements = guild_system_data.alliance_system.creation_requirements
	
	# Verificar nÃºmero mÃ­nimo de guildas
	if guild_ids.size() < requirements.min_guilds:
		result.reason = "MÃ­nimo de %d guildas necessÃ¡rias" % requirements.min_guilds
		return result
	
	# Verificar nÃºmero mÃ¡ximo de guildas
	if guild_ids.size() > requirements.max_guilds:
		result.reason = "MÃ¡ximo de %d guildas permitidas" % requirements.max_guilds
		return result
	
	# Verificar se todas as guildas existem e atendem requisitos
	for guild_id in guild_ids:
		if not active_guilds.has(guild_id):
			result.reason = "Guilda %s nÃ£o encontrada" % guild_id
			return result
		
		var guild = active_guilds[guild_id]
		if guild.level < requirements.min_guild_level:
			result.reason = "Guilda %s nÃ­vel insuficiente" % guild.name
			return result
		
		# Verificar se jÃ¡ estÃ¡ em outra alianÃ§a
		if guild.alliances.size() > 0:
			result.reason = "Guilda %s jÃ¡ estÃ¡ em alianÃ§a" % guild.name
			return result
	
	result.can_form = true
	return result

func form_alliance(guild_ids: Array, alliance_name: String, founder_guild_id: String) -> String:
# Forma uma alianÃ§a
	var validation = can_form_alliance(guild_ids, alliance_name)
	if not validation.can_form:
		print("[GuildSystem] NÃ£o pode formar alianÃ§a: ", validation.reason)
		return ""
	
	var alliance_id = _generate_alliance_id()
	var alliance_data = {
		"id": alliance_id,
		"name": alliance_name,
		"founder_guild_id": founder_guild_id,
		"member_guilds": guild_ids.duplicate(),
		"created_at": Time.get_time_dict_from_system(),
		"activities": [],
		"territories": []
	}
	
	# Adicionar alianÃ§a
	alliance_data[alliance_id] = alliance_data
	
	# Atualizar guildas
	for guild_id in guild_ids:
		var guild = active_guilds[guild_id]
		guild.alliances.push_back(alliance_id)
	
	# Emitir evento
	alliance_formed.emit(alliance_id, guild_ids)
	
	print("[GuildSystem] AlianÃ§a formada: %s" % alliance_name)
	return alliance_id

# ============================================================================
# FUNÃ‡Ã•ES AUXILIARES
# ============================================================================

func _get_player_data(player: Node) -> Dictionary:
# ObtÃ©m dados do jogador
	if player.has_method("get_player_data"):
		return player.get_player_data()
	return GameState.get_player_data()

func _is_valid_guild_name(name: String) -> bool:
# Verifica se nome de guilda Ã© vÃ¡lido
	var requirements = guild_system_data.creation_requirements
	var len = name.length()
	
	return len >= requirements.min_guild_name_length and len <= requirements.max_guild_name_length

func _guild_name_exists(name: String) -> bool:
# Verifica se nome jÃ¡ existe
	for guild_id in active_guilds:
		var guild = active_guilds[guild_id]
		if guild.name.to_lower() == name.to_lower():
			return true
	return false

func _generate_guild_id() -> String:
# Gera ID Ãºnico para guilda
	return "guild_" + str(Time.get_time_dict_from_system().unix) + "_" + str(randi())

func _generate_activity_id() -> String:
# Gera ID Ãºnico para atividade
	return "activity_" + str(Time.get_time_dict_from_system().unix) + "_" + str(randi())

func _generate_alliance_id() -> String:
# Gera ID Ãºnico para alianÃ§a
	return "alliance_" + str(Time.get_time_dict_from_system().unix) + "_" + str(randi())

func _charge_player_currency(player: Node, amount: int):
# Cobra currency do jogador
	if player.has_method("remove_currency"):
		player.remove_currency(amount)
	else:
		# Fallback para GameState
		GameState.update_currency(-amount)

func _is_guild_master(player: Node, guild_id: String) -> bool:
# Verifica se Ã© guild master
	if not active_guilds.has(guild_id):
		return false
	
	var guild = active_guilds[guild_id]
	var player_id = str(player.get_instance_id())
	var member_data = guild.members.get(player_id)
	
	return member_data and member_data.rank == "guild_master"

func _has_permission(player: Node, guild_id: String, permission: String) -> bool:
# Verifica se jogador tem permissÃ£o
	if not active_guilds.has(guild_id):
		return false
	
	var guild = active_guilds[guild_id]
	var player_id = str(player.get_instance_id())
	var member_data = guild.members.get(player_id)
	
	if not member_data:
		return false
	
	var rank_data = guild_system_data.guild_ranks.get(member_data.rank)
	if not rank_data:
		return false
	
	return rank_data.permissions.has(permission) or rank_data.permissions.has("all")

func _get_rank_level(player: Node, guild_id: String) -> int:
# ObtÃ©m nÃ­vel do rank do jogador
	if not active_guilds.has(guild_id):
		return 0
	
	var guild = active_guilds[guild_id]
	var player_id = str(player.get_instance_id())
	var member_data = guild.members.get(player_id)
	
	if not member_data:
		return 0
	
	return _get_rank_level_by_rank(member_data.rank)

func _get_rank_level_by_rank(rank: String) -> int:
# ObtÃ©m nÃ­vel do rank
	var rank_data = guild_system_data.guild_ranks.get(rank)
	return rank_data.level if rank_data else 0

func _can_promote_to_rank(guild_id: String, rank: String) -> bool:
# Verifica se pode promover para rank
	var guild = active_guilds[guild_id]
	var rank_data = guild_system_data.guild_ranks.get(rank)
	
	if not rank_data:
		return false
	
	# Contar membros com este rank
	var count = 0
	for member_id in guild.members:
		var member = guild.members[member_id]
		if member.rank == rank:
			count += 1
	
	return count < rank_data.max_count

func _get_guild_max_members(guild_data: Dictionary) -> int:
# ObtÃ©m limite mÃ¡ximo de membros da guilda
	var hall_upgrades = guild_data.get("hall_upgrades", {})
	var main_hall_level = hall_upgrades.get("main_hall_level", 1)
	
	var upgrades_data = guild_system_data.guild_hall.upgrades.main_hall
	var level_key = "level_%d" % main_hall_level
	
	if upgrades_data.has(level_key):
		return upgrades_data[level_key].max_members
	
	return 25  # Default

func _send_guild_invite(invite_data: Dictionary):
# Envia convite de guilda (placeholder)
	# Implementar sistema de convites aqui
	pass

func _guild_activity_on_cooldown(guild_id: String, activity_type: String) -> bool:
# Verifica se atividade estÃ¡ em cooldown
	var guild = active_guilds[guild_id]
	var current_time = Time.get_time_dict_from_system().unix
	
	for activity_id in guild.activities:
		var activity = guild_activities.get(activity_id)
		if activity and activity.type == activity_type:
			if activity.get("cooldown_expires", 0) > current_time:
				return true
	
	return false

func _leave_all_alliances(guild_id: String):
# Remove guilda de todas as alianÃ§as
	var guild = active_guilds[guild_id]
	
	for alliance_id in guild.alliances:
		if alliance_data.has(alliance_id):
			var alliance = alliance_data[alliance_id]
			alliance.member_guilds.erase(guild_id)
			
			# Se alianÃ§a ficou com menos de 2 guildas, dissolver
			if alliance.member_guilds.size() < 2:
				alliance_data.erase(alliance_id)
				alliance_disbanded.emit(alliance_id)

# ============================================================================
# EVENTOS
# ============================================================================

func _on_player_level_up(level: int, hp_gain: int, mp_gain: int):
# Quando jogador sobe de nÃ­vel
	# Contribuir XP para guilda
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var guild_id = get_player_guild(player)
		if guild_id:
			award_guild_experience(guild_id, 100)

# ============================================================================
# API PÃšBLICA
# ============================================================================

func is_player_in_guild(player: Node) -> bool:
# Verifica se jogador estÃ¡ em guilda
	return player_guild_membership.has(player.get_instance_id())

func get_player_guild(player: Node) -> String:
# ObtÃ©m guilda do jogador
	return player_guild_membership.get(player.get_instance_id(), "")

func get_guild_data(guild_id: String) -> Dictionary:
# ObtÃ©m dados da guilda
	return active_guilds.get(guild_id, {})

func get_guild_members(guild_id: String) -> Dictionary:
# ObtÃ©m membros da guilda
	var guild = active_guilds.get(guild_id, {})
	return guild.get("members", {})

func award_guild_experience(guild_id: String, amount: int):
# Concede XP para guilda
	if not active_guilds.has(guild_id):
		return
	
	var guild = active_guilds[guild_id]
	guild.experience += amount
	
	# Verificar se subiu de nÃ­vel
	_check_guild_level_up(guild_id)

func _check_guild_level_up(guild_id: String):
# Verifica se guilda subiu de nÃ­vel
	var guild = active_guilds[guild_id]
	var progression = guild_system_data.guild_progression
	
	var next_level = guild.level + 1
	var required_xp_key = "level_%d" % next_level
	
	if progression.level_requirements.has(required_xp_key):
		var required_xp = progression.level_requirements[required_xp_key]
		if guild.experience >= required_xp:
			guild.level = next_level
			print("[GuildSystem] Guilda %s subiu para nÃ­vel %d!" % [guild.name, next_level])
