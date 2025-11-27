# Exemplo de Uso do Sistema de Montarias - Disorder Chaos
extends Node

## Este arquivo demonstra como usar o sistema de montarias
## Serve como referência para desenvolvedores

@onready var mount_manager = MountManager.new()
@onready var player: Entity = preload("res://entities/Player.tscn").instantiate()

func _ready():
	# Adicionar o manager ao jogo
	add_child(mount_manager)
	add_child(player)
	
	# Aguardar sistema estar pronto
	await mount_manager.mount_system_ready
	
	# Configurar componente de montaria no jogador
	_setup_player_mount_component()
	
	# Registrar jogador no sistema
	mount_manager.register_entity(player)
	
	# Exemplos de uso
	_demonstrate_mount_usage()

## Configura componente de montaria no jogador
func _setup_player_mount_component():
	# Criar componente de montaria
	var mount_component = MountComponent.new()
	player.add_component(mount_component)
	
	# Carregar montarias do arquivo
	mount_component.load_mounts_from_file()
	
	# Configurar comportamento
	mount_component.auto_dismiss_on_damage = true
	mount_component.auto_dismiss_on_combat = false

## Demonstra uso básico das montarias
func _demonstrate_mount_usage():
	print("=== Demonstração do Sistema de Montarias ===")
	
	# 1. Desbloquear montaria básica
	mount_manager.unlock_mount(player, "horse_common")
	print("✓ Montaria comum desbloqueada")
	
	# 2. Invocar montaria
	await get_tree().create_timer(1.0).timeout
	if mount_manager.summon_mount(player, "horse_common"):
		print("✓ Montaria invocada com sucesso")
	
	# 3. Verificar se está montado
	await get_tree().create_timer(0.5).timeout
	if mount_manager.is_entity_mounted(player):
		print("✓ Jogador está montado")
	
	# 4. Executar dash
	await get_tree().create_timer(1.0).timeout
	if mount_manager.mount_dash(player):
		print("✓ Dash executado")
	
	# 5. Dispensar montaria
	await get_tree().create_timer(2.0).timeout
	if mount_manager.dismiss_mount(player):
		print("✓ Montaria dispensada")
	
	# 6. Demonstrar alternância
	await get_tree().create_timer(1.0).timeout
	mount_manager.toggle_mount(player, "horse_common")
	print("✓ Montaria alternada")
	
	# 7. Desbloquear montaria avançada
	await get_tree().create_timer(1.0).timeout
	mount_manager.unlock_mount(player, "wolf_shadow")
	print("✓ Lobo das Sombras desbloqueado")
	
	# 8. Trocar para montaria avançada
	await get_tree().create_timer(1.0).timeout
	mount_manager.toggle_mount(player, "wolf_shadow")
	print("✓ Trocado para Lobo das Sombras")
	
	# 9. Usar skill especial
	await get_tree().create_timer(1.0).timeout
	if mount_manager.use_mount_skill(player, "stealth_dash"):
		print("✓ Skill 'Dash Sombrio' usada")
	
	# 10. Mostrar estatísticas
	await get_tree().create_timer(1.0).timeout
	var stats = mount_manager.get_system_statistics()
	print("✓ Estatísticas: ", stats)
	
	print("=== Demonstração Concluída ===")

## Exemplo de integração com sistema de input
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M:
				# Toggle montaria favorita
				mount_manager.toggle_mount(player, "horse_common")
			
			KEY_SHIFT:
				# Dash
				mount_manager.mount_dash(player)
			
			KEY_1:
				# Usar primeira skill da montaria
				var current_mount = mount_manager.get_current_mount(player)
				if current_mount and current_mount.skills.size() > 0:
					mount_manager.use_mount_skill(player, current_mount.skills[0])
			
			KEY_H:
				# Mostrar informações das montarias
				_show_mount_info()

## Exemplo de exibição de informações
func _show_mount_info():
	print("\n=== Informações das Montarias ===")
	
	var mounts = mount_manager.get_entity_mounts(player)
	for mount in mounts:
		print("Montaria: ", mount.name)
		print("  ID: ", mount.id)
		print("  Tipo: ", mount.type)
		print("  Velocidade: ", mount.velocidade_base)
		print("  Stamina: ", mount.stamina_atual, "/", mount.stamina_maxima)
		print("  Desbloqueada: ", mount.unlocked)
		print("  Skills: ", mount.skills)
		print()
	
	var current = mount_manager.get_current_mount(player)
	if current:
		print("Montaria Atual: ", current.name)
		print("Montado: ", mount_manager.is_entity_mounted(player))
	else:
		print("Nenhuma montaria ativa")
	
	print("================================\n")

## Exemplo de configuração avançada
func _configure_advanced_settings():
	# Modificar configurações globais
	mount_manager.set_global_speed_modifier(1.5)  # +50% velocidade
	mount_manager.set_global_stamina_modifier(0.8)  # -20% stamina
	mount_manager.set_pvp_restrictions_enabled(false)  # Permitir em PvP
	
	print("Configurações avançadas aplicadas")

## Exemplo de tratamento de eventos
func _connect_mount_events():
	# Conectar aos eventos do EventBus
	EventBus.mount_summoned.connect(_on_mount_summoned)
	EventBus.mount_dismissed.connect(_on_mount_dismissed)
	EventBus.mount_stamina_changed.connect(_on_mount_stamina_changed)
	EventBus.mount_skill_used.connect(_on_mount_skill_used)

func _on_mount_summoned(entity: Entity, mount: Mount):
	if entity == player:
		print("[Event] Montaria invocada: ", mount.name)
		# Aqui você pode adicionar efeitos visuais, sons, etc.

func _on_mount_dismissed(entity: Entity, mount: Mount):
	if entity == player:
		print("[Event] Montaria dispensada: ", mount.name)
		# Aqui você pode adicionar efeitos de dispensar

func _on_mount_stamina_changed(entity: Entity, current: float, maximum: float):
	if entity == player:
		var percent = (current / maximum) * 100
		if percent < 25:
			print("[Event] Aviso: Stamina baixa! (", int(percent), "%)")

func _on_mount_skill_used(entity: Entity, skill_id: String):
	if entity == player:
		print("[Event] Skill usada: ", skill_id)
		# Aqui você pode adicionar efeitos especiais da skill

## Exemplo de integração com UI
func _setup_mount_ui():
	# Criar UI de montaria
	var mount_ui = preload("res://ui/mounts/MountUI.tscn").instantiate()
	add_child(mount_ui)
	
	# Configurar para o jogador
	mount_ui.set_entity(player)
	
	# Posicionar UI
	mount_ui.set_ui_position(Vector2(20, 20))
	mount_ui.set_ui_scale(1.0)
	
	# Conectar sinais da UI
	mount_ui.mount_selected.connect(_on_mount_selected)
	mount_ui.mount_skill_activated.connect(_on_mount_skill_activated)

func _on_mount_selected(mount_id: String):
	print("Montaria selecionada na UI: ", mount_id)
	mount_manager.toggle_mount(player, mount_id)

func _on_mount_skill_activated(skill_id: String):
	print("Skill ativada na UI: ", skill_id)
	mount_manager.use_mount_skill(player, skill_id)

## Exemplo de save/load
func _save_mount_data():
	var mount_component = player.get_component("MountComponent")
	if mount_component:
		var save_data = mount_component.get_save_data()
		# Salvar dados em arquivo de save
		print("Dados de montaria salvos: ", save_data)

func _load_mount_data(save_data: Dictionary):
	var mount_component = player.get_component("MountComponent")
	if mount_component:
		mount_component.load_save_data(save_data)
		print("Dados de montaria carregados")

## Exemplo de debugging
func _debug_mount_system():
	print("\n=== Debug do Sistema de Montarias ===")
	
	# Estatísticas do sistema
	mount_manager.debug_mount_statistics()
	
	# Lista de entidades
	mount_manager.debug_list_all_entities()
	
	# Informações do sistema de input
	if mount_manager.mount_input_system:
		mount_manager.mount_input_system.debug_list_mount_actions()
	
	print("====================================\n")