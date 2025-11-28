# Sistema de Montarias - Disorder Chaos
extends Node
class_name Mount

## Classe base para todas as montarias do jogo
## Representa uma montaria com suas propriedades, habilidades e mecânicas

signal mount_summoned(mount)
signal mount_dismissed(mount)
signal stamina_changed(current: float, maximum: float)
signal skill_used(skill_id: String)

enum MountType {
	TERRESTRE,
	AEREA,
	SOMBRIA,
	ELEMENTAL
}

enum MountRarity {
	COMUM,
	INCOMUM,
	RARO,
	EPICO,
	LENDARIO,
	MITICO
}

@export var id: String = ""
@export var mount_name: String = ""
@export var type: MountType = MountType.TERRESTRE
@export var rarity: MountRarity = MountRarity.COMUM
@export var description: String = ""

# Propriedades de movimento
@export var velocidade_base: float = 200.0
@export var stamina_maxima: float = 100.0
@export var stamina_consumo: float = 15.0  # Por segundo durante corrida
@export var stamina_recuperacao: float = 10.0  # Por segundo quando parado
@export var dash_speed_multiplier: float = 2.0
@export var dash_duration: float = 1.0

# Restrições e cooldowns
@export var cooldown_invocacao: float = 5.0
@export var level_required: int = 1
@export var pvp_blocked: bool = false
@export var unlocked: bool = false

# Recursos visuais
@export var icon_path: String = ""
@export var model_path: String = ""

# Skills especiais
@export var skills: Array[String] = []

# Estado runtime
var stamina_atual: float
var last_invocation_time: float = 0.0
var is_mounted: bool = false
var owner_node: Node = null
var mount_node: Node = null
var skill_cooldowns: Dictionary = {}

func _init():
	stamina_atual = stamina_maxima

## Verifica se a montaria pode ser invocada
func can_be_summoned(player: Node) -> bool:
	if not unlocked:
		return false
	
	if player.level < level_required:
		return false
	
	var current_time = Time.get_time_dict_from_system()
	var time_since_last = current_time.get("second", 0) - last_invocation_time
	if time_since_last < cooldown_invocacao:
		return false
	
	# Verificar se está em área PVP restrita
	if pvp_blocked and _is_in_pvp_area(player):
		return false
	
	return true

## Invoca a montaria
func summon(player: Node) -> bool:
	if not can_be_summoned(player):
		return false
	
	if is_mounted:
		return false
	
	owner_node = player
	is_mounted = true
	last_invocation_time = Time.get_time_dict_from_system().get("second", 0)
	
	# Criar node da montaria se necessário
	if model_path != "" and mount_node == null:
		mount_node = load(model_path).instantiate()
		player.get_parent().add_child(mount_node)
		mount_node.global_position = player.global_position
	
	# Aplicar modificadores de velocidade
	if player.has_method("set_movement_speed"):
		player.set_movement_speed(velocidade_base)
	
	# Conectar sinais
	if player.has_signal("movement_started"):
		player.movement_started.connect(_on_movement_started)
	if player.has_signal("movement_stopped"):
		player.movement_stopped.connect(_on_movement_stopped)
	
	mount_summoned.emit(self)
	return true

## Dispensa a montaria
func dismiss() -> bool:
	if not is_mounted:
		return false
	
	is_mounted = false
	
	# Remover modificadores de velocidade
	if owner_node and owner_node.has_method("reset_movement_speed"):
		owner_node.reset_movement_speed()
	
	# Desconectar sinais
	if owner_node:
		if owner_node.has_signal("movement_started") and owner_node.movement_started.is_connected(_on_movement_started):
			owner_node.movement_started.disconnect(_on_movement_started)
		if owner_node.has_signal("movement_stopped") and owner_node.movement_stopped.is_connected(_on_movement_stopped):
			owner_node.movement_stopped.disconnect(_on_movement_stopped)
	
	# Remover node da montaria
	if mount_node:
		mount_node.queue_free()
		mount_node = null
	
	owner_node = null
	mount_dismissed.emit(self)
	return true

## Executa dash temporário
func dash() -> bool:
	if not is_mounted or stamina_atual < 30.0:
		return false
	
	consume_stamina(30.0)
	
	if owner_node and owner_node.has_method("apply_dash"):
		owner_node.apply_dash(dash_speed_multiplier, dash_duration)
	
	return true

## Usa uma skill especial
func use_skill(skill_id: String) -> bool:
	if not is_mounted or skill_id not in skills:
		return false
	
	# Verificar cooldown
	var current_time = Time.get_time_dict_from_system().get("second", 0)
	if skill_id in skill_cooldowns:
		var time_since_use = current_time - skill_cooldowns[skill_id]
		var skill_data = _get_skill_data(skill_id)
		if skill_data and time_since_use < skill_data.get("cooldown", 0):
			return false
	
	# Verificar stamina
	var skill_data = _get_skill_data(skill_id)
	if skill_data:
		var stamina_cost = skill_data.get("stamina_cost", 0)
		if stamina_atual < stamina_cost:
			return false
		
		consume_stamina(stamina_cost)
		skill_cooldowns[skill_id] = current_time
		
		# Aplicar efeito da skill
		_apply_skill_effect(skill_id, skill_data)
		skill_used.emit(skill_id)
		return true
	
	return false

## Consome stamina
func consume_stamina(amount: float):
	stamina_atual = max(0, stamina_atual - amount)
	stamina_changed.emit(stamina_atual, stamina_maxima)

## Recupera stamina
func recover_stamina(amount: float):
	stamina_atual = min(stamina_maxima, stamina_atual + amount)
	stamina_changed.emit(stamina_atual, stamina_maxima)

## Atualiza a montaria por frame
func update_mount(delta: float):
	if not is_mounted:
		return
	
	# Recuperar stamina quando parado
	if owner_node and owner_node.has_method("is_moving"):
		if not owner_node.is_moving():
			recover_stamina(stamina_recuperacao * delta)
	
	# Atualizar posição do modelo
	if mount_node and owner_node:
		mount_node.global_position = owner_node.global_position

## Callbacks de movimento
func _on_movement_started():
	if not is_mounted:
		return
	
	# Começar a consumir stamina durante corrida
	var tween = create_tween()
	tween.set_loops()
	tween.tween_callback(_consume_running_stamina).set_delay(1.0)

func _on_movement_stopped():
	# Parar consumo de stamina
	pass

func _consume_running_stamina():
	if is_mounted and owner_node and owner_node.has_method("is_moving"):
		if owner_node.is_moving():
			consume_stamina(stamina_consumo)

## Verifica se está em área PVP restrita
func _is_in_pvp_area(player: Node) -> bool:
	# Esta função precisa ser implementada baseada no sistema de áreas do jogo
	# Por enquanto, retorna false
	if player.has_method("get_current_area"):
		var area_name = player.get_current_area()
		var restricted_areas = [
			"arena_1v1",
			"arena_3v3", 
			"battleground_central",
			"tournament_grounds"
		]
		return area_name in restricted_areas
	
	return false

## Obtém dados de uma skill
func _get_skill_data(skill_id: String) -> Dictionary:
	# Carregar dados das skills do JSON
	var file = FileAccess.open("res://data/mounts/mountList.json", FileAccess.READ)
	if file:
		var json_data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if json_data and "mount_skills" in json_data:
			return json_data["mount_skills"].get(skill_id, {})
	
	return {}

## Aplica efeito de uma skill
func _apply_skill_effect(skill_id: String, skill_data: Dictionary):
	if not owner_node:
		return
	
	var effect = skill_data.get("effect", "")
	var duration = skill_data.get("duration", 0.0)
	
	match effect:
		"invisibility":
			if owner_node.has_method("set_invisible"):
				owner_node.set_invisible(true)
				get_tree().create_timer(duration).timeout.connect(
					func(): owner_node.set_invisible(false)
				)
		
		"flight":
			if owner_node.has_method("enable_flight"):
				owner_node.enable_flight(true)
				get_tree().create_timer(duration).timeout.connect(
					func(): owner_node.enable_flight(false)
				)
		
		"fire_trail":
			if owner_node.has_method("enable_fire_trail"):
				owner_node.enable_fire_trail(duration)
		
		"lightning_dash":
			if owner_node.has_method("lightning_dash"):
				owner_node.lightning_dash()
		
		"speed_boost":
			if owner_node.has_method("apply_speed_boost"):
				var boost_amount = 1.5
				owner_node.apply_speed_boost(boost_amount, duration)
		
		"stun_aoe":
			if owner_node.has_method("stun_nearby_enemies"):
				owner_node.stun_nearby_enemies(200.0, duration)  # 200 pixels de raio
		
		"fear_aura":
			if owner_node.has_method("apply_fear_aura"):
				owner_node.apply_fear_aura(300.0, duration)  # 300 pixels de raio

## Serialização para save/load
func get_save_data() -> Dictionary:
	return {
		"id": id,
		"stamina_atual": stamina_atual,
		"unlocked": unlocked,
		"is_mounted": is_mounted,
		"skill_cooldowns": skill_cooldowns
	}

func load_save_data(data: Dictionary):
	stamina_atual = data.get("stamina_atual", stamina_maxima)
	unlocked = data.get("unlocked", false)
	is_mounted = data.get("is_mounted", false)
	skill_cooldowns = data.get("skill_cooldowns", {})

## Cria uma montaria a partir de dados JSON
static func from_json_data(data: Dictionary) -> Mount:
	var mount = Mount.new()
	
	mount.id = data.get("id", "")
	mount.name = data.get("name", "")
	mount.description = data.get("description", "")
	mount.velocidade_base = data.get("velocidadeBase", 200.0)
	mount.stamina_maxima = data.get("stamina", 100.0)
	mount.stamina_consumo = data.get("staminaConsumo", 15.0)
	mount.stamina_recuperacao = data.get("staminaRecuperacao", 10.0)
	mount.cooldown_invocacao = data.get("cooldown", 5.0)
	mount.level_required = data.get("levelRequired", 1)
	mount.pvp_blocked = data.get("pvpBlocked", false)
	mount.unlocked = data.get("unlocked", false)
	mount.icon_path = data.get("iconPath", "")
	mount.model_path = data.get("modelPath", "")
	mount.skills = data.get("skills", [])
	
	# Converter tipo
	var type_str = data.get("type", "terrestre")
	match type_str:
		"terrestre":
			mount.type = MountType.TERRESTRE
		"aérea":
			mount.type = MountType.AEREA
		"sombria":
			mount.type = MountType.SOMBRIA
		"elemental":
			mount.type = MountType.ELEMENTAL
	
	# Converter raridade
	var rarity_str = data.get("rarity", "comum")
	match rarity_str:
		"comum":
			mount.rarity = MountRarity.COMUM
		"incomum":
			mount.rarity = MountRarity.INCOMUM
		"raro":
			mount.rarity = MountRarity.RARO
		"épico":
			mount.rarity = MountRarity.EPICO
		"lendário":
			mount.rarity = MountRarity.LENDARIO
		"mítico":
			mount.rarity = MountRarity.MITICO
	
	mount.stamina_atual = mount.stamina_maxima
	return mount