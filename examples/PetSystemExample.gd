# Exemplo de Uso do Sistema de Pets - Disorder Chaos
extends Node

## Este arquivo demonstra como usar o sistema de pets/companions
## Serve como referência para desenvolvedores

@onready var pet_manager = PetManager.new()
@onready var player: Entity = preload("res://entities/Player.tscn").instantiate()

func _ready():
	# Adicionar o manager ao jogo
	add_child(pet_manager)
	add_child(player)
	
	# Aguardar sistema estar pronto
	await pet_manager.pet_system_ready
	
	# Configurar componente de pet no jogador
	_setup_player_pet_component()
	
	# Registrar jogador no sistema
	pet_manager.register_entity(player)
	
	# Exemplos de uso
	_demonstrate_pet_usage()

## Configura componente de pet no jogador
func _setup_player_pet_component():
	# Criar componente de pet
	var pet_component = PetComponent.new()
	player.add_component(pet_component)
	
	# Carregar pets do arquivo
	pet_component.load_pets_from_file()
	
	# Configurar comportamento
	pet_component.auto_summon_on_start = false
	pet_component.share_xp_with_pet = true
	pet_component.pet_xp_share_rate = 0.3

## Demonstra uso básico dos pets
func _demonstrate_pet_usage():
	print("=== Demonstração do Sistema de Pets ===")
	
	# 1. Desbloquear pet básico
	pet_manager.unlock_pet(player, "wolf_companion")
	print("✓ Pet Lobo Companheiro desbloqueado")
	
	# 2. Invocar pet
	await get_tree().create_timer(1.0).timeout
	if pet_manager.summon_pet(player, "wolf_companion"):
		print("✓ Pet invocado com sucesso")
	
	# 3. Verificar se tem pet ativo
	await get_tree().create_timer(0.5).timeout
	if pet_manager.entity_has_active_pet(player):
		print("✓ Jogador tem pet ativo")
	
	# 4. Dar XP ao pet
	await get_tree().create_timer(1.0).timeout
	pet_manager.give_pet_xp(player, 150)
	print("✓ Pet ganhou 150 XP")
	
	# 5. Usar habilidade do pet
	await get_tree().create_timer(1.0).timeout
	if pet_manager.use_pet_ability(player, "bite_attack"):
		print("✓ Pet usou habilidade 'Mordida'")
	
	# 6. Dispensar pet
	await get_tree().create_timer(2.0).timeout
	if pet_manager.dismiss_pet(player):
		print("✓ Pet dispensado")
	
	# 7. Desbloquear pet de suporte
	await get_tree().create_timer(1.0).timeout
	pet_manager.unlock_pet(player, "healing_fairy")
	print("✓ Fada Curadora desbloqueada")
	
	# 8. Trocar para pet de suporte
	await get_tree().create_timer(1.0).timeout
	pet_manager.toggle_pet(player, "healing_fairy")
	print("✓ Trocado para Fada Curadora")
	
	# 9. Usar habilidade de cura
	await get_tree().create_timer(1.0).timeout
	if pet_manager.use_pet_ability(player, "healing_burst"):
		print("✓ Pet usou 'Explosão Curativa'")
	
	# 10. Mostrar estatísticas
	await get_tree().create_timer(1.0).timeout
	var stats = pet_manager.get_system_statistics()
	print("✓ Estatísticas: ", stats)
	
	print("=== Demonstração Concluída ===")

## Exemplo de integração com sistema de input
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:
				# Toggle pet favorito
				pet_manager.toggle_pet(player, "wolf_companion")
			
			KEY_F1:
				# Usar primeira habilidade do pet
				var active_pet = pet_manager.get_active_pet(player)
				if active_pet and active_pet.abilities.size() > 0:
					var first_ability = active_pet.abilities.values()[0]
					pet_manager.use_pet_ability(player, first_ability)
			
			KEY_F2:
				# Usar segunda habilidade do pet
				var active_pet = pet_manager.get_active_pet(player)
				if active_pet and active_pet.abilities.size() > 1:
					var second_ability = active_pet.abilities.values()[1]
					pet_manager.use_pet_ability(player, second_ability)
			
			KEY_B:
				# Mostrar informações dos pets
				_show_pet_info()

## Exemplo de exibição de informações
func _show_pet_info():
	print("\n=== Informações dos Pets ===")
	
	var pets = pet_manager.get_entity_pets(player)
	for pet in pets:
		print("Pet: ", pet.name)
		print("  ID: ", pet.id)
		print("  Tipo: ", pet.type)
		print("  Nível: ", pet.level)
		print("  XP: ", pet.current_xp, "/", pet._get_xp_for_level(pet.level + 1))
		print("  Desbloqueado: ", pet.unlocked)
		print("  Stats: ", pet.current_stats)
		print("  Habilidades: ", pet.abilities)
		print()
	
	var active_pet = pet_manager.get_active_pet(player)
	if active_pet:
		print("Pet Ativo: ", active_pet.name)
		print("Ativo: ", pet_manager.entity_has_active_pet(player))
	else:
		print("Nenhum pet ativo")
	
	print("==============================\n")

## Exemplo de configuração avançada
func _configure_advanced_settings():
	# Modificar configurações globais
	pet_manager.set_global_xp_modifier(1.5)  # +50% XP
	pet_manager.set_max_active_pets(1)  # Apenas 1 pet ativo
	pet_manager.set_pet_revival_enabled(true)  # Pets podem ser revividos
	pet_manager.set_auto_dismiss_in_pvp(true)  # Auto dispensar em PvP
	
	print("Configurações avançadas aplicadas")

## Exemplo de tratamento de eventos
func _connect_pet_events():
	# Conectar aos eventos do EventBus
	EventBus.pet_summoned.connect(_on_pet_summoned)
	EventBus.pet_dismissed.connect(_on_pet_dismissed)
	EventBus.pet_level_up.connect(_on_pet_level_up)
	EventBus.pet_xp_gained.connect(_on_pet_xp_gained)

func _on_pet_summoned(entity: Entity, pet: Pet):
	if entity == player:
		print("[Event] Pet invocado: ", pet.name)
		# Aqui você pode adicionar efeitos visuais, sons, etc.

func _on_pet_dismissed(entity: Entity, pet: Pet):
	if entity == player:
		print("[Event] Pet dispensado: ", pet.name)
		# Aqui você pode adicionar efeitos de dispensar

func _on_pet_level_up(entity: Entity, pet: Pet, new_level: int):
	if entity == player:
		print("[Event] Pet subiu de nível! ", pet.name, " → Nível ", new_level)
		# Efeitos de level up podem ser adicionados aqui

func _on_pet_xp_gained(entity: Entity, pet: Pet, xp_amount: int):
	if entity == player:
		print("[Event] Pet ganhou XP: +", xp_amount, " (", pet.name, ")")

## Exemplo de integração com UI
func _setup_pet_ui():
	# Criar UI de pet
	var pet_ui = preload("res://ui/pets/PetUI.tscn").instantiate()
	add_child(pet_ui)
	
	# Configurar para o jogador
	pet_ui.set_entity(player)
	
	# Posicionar UI
	pet_ui.set_ui_position(Vector2(20, 20))
	pet_ui.set_ui_scale(1.0)
	
	# Conectar sinais da UI
	pet_ui.pet_selected.connect(_on_pet_selected)
	pet_ui.pet_ability_activated.connect(_on_pet_ability_activated)

func _on_pet_selected(pet_id: String):
	print("Pet selecionado na UI: ", pet_id)
	pet_manager.toggle_pet(player, pet_id)

func _on_pet_ability_activated(ability_id: String):
	print("Habilidade ativada na UI: ", ability_id)
	pet_manager.use_pet_ability(player, ability_id)

## Exemplo de save/load
func _save_pet_data():
	var pet_component = player.get_component("PetComponent")
	if pet_component:
		var save_data = pet_component.get_save_data()
		# Salvar dados em arquivo de save
		print("Dados de pet salvos: ", save_data)

func _load_pet_data(save_data: Dictionary):
	var pet_component = player.get_component("PetComponent")
	if pet_component:
		pet_component.load_save_data(save_data)
		print("Dados de pet carregados")

## Exemplo de sistema de recompensas
func _demonstrate_pet_rewards():
	print("\n=== Sistema de Recompensas para Pets ===")
	
	# Recompensar todos os pets ativos com XP
	pet_manager.reward_all_active_pets("xp", 200)
	print("✓ Todos os pets ativos ganharam 200 XP")
	
	# Evento especial de XP
	pet_manager.trigger_pet_event("xp_boost_hour", {"boost": 500})
	print("✓ Evento de boost de XP ativado")
	
	# Reset de cooldowns
	pet_manager.trigger_pet_event("pet_ability_reset", {})
	print("✓ Cooldowns de pets resetados")
	
	# Boost temporário de stats
	pet_manager.trigger_pet_event("pet_stat_boost", {"duration": 300})
	print("✓ Boost temporário de stats aplicado")
	
	print("=====================================\n")

## Exemplo de comportamentos por tipo
func _demonstrate_pet_types():
	print("\n=== Demonstração de Tipos de Pet ===")
	
	# Pet de Ataque
	pet_manager.unlock_pet(player, "phoenix_chick")
	pet_manager.summon_pet(player, "phoenix_chick")
	await get_tree().create_timer(1.0).timeout
	pet_manager.use_pet_ability(player, "flame_breath")
	print("✓ Pet de ataque demonstrado")
	
	# Pet de Suporte
	await get_tree().create_timer(1.0).timeout
	pet_manager.toggle_pet(player, "healing_fairy")
	pet_manager.use_pet_ability(player, "auto_heal")
	print("✓ Pet de suporte demonstrado")
	
	# Pet Coletor
	await get_tree().create_timer(1.0).timeout
	pet_manager.unlock_pet(player, "treasure_goblin")
	pet_manager.toggle_pet(player, "treasure_goblin")
	pet_manager.use_pet_ability(player, "treasure_sense")
	print("✓ Pet coletor demonstrado")
	
	# Pet Passivo
	await get_tree().create_timer(1.0).timeout
	pet_manager.unlock_pet(player, "shadow_spirit")
	pet_manager.toggle_pet(player, "shadow_spirit")
	print("✓ Pet passivo demonstrado")
	
	print("===================================\n")

## Exemplo de debugging
func _debug_pet_system():
	print("\n=== Debug do Sistema de Pets ===")
	
	# Estatísticas do sistema
	pet_manager.debug_pet_statistics()
	
	# Lista de entidades
	pet_manager.debug_list_all_entities()
	
	# Informações do componente
	var pet_component = player.get_component("PetComponent")
	if pet_component:
		pet_component.debug_print_pet_info()
	
	print("===============================\n")