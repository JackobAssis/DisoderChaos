class_name UIThemeManagerResource
extends Resource

## Gerenciador de temas para UI dark fantasy/tecnolÃ³gica
## Centraliza todas as cores, fontes e estilos do jogo

# === CORES DA PALETA ===
class Colors:
	# Cores primÃ¡rias - Dark Fantasy
	const PRIMARY_DARK = Color(0.102, 0.102, 0.180)  # #1a1a2e
	const PRIMARY_NAVY = Color(0.086, 0.129, 0.243)  # #16213e
	const PRIMARY_BLUE = Color(0.059, 0.204, 0.376)  # #0f3460
	
	# Cores secundÃ¡rias - TecnolÃ³gico
	const CYBER_CYAN = Color(0.0, 0.831, 1.0)        # #00d4ff
	const TECH_ORANGE = Color(1.0, 0.420, 0.208)     # #ff6b35
	
	# Cores de destaque
	const ACCENT_GOLD = Color(1.0, 0.843, 0.0)       # #ffd700
	const ACCENT_PURPLE = Color(0.627, 0.125, 0.941) # #a020f0
	
	# Cores de texto
	const TEXT_PRIMARY = Color(1.0, 1.0, 1.0)        # #ffffff
	const TEXT_SECONDARY = Color(0.878, 0.878, 0.878) # #e0e0e0
	const TEXT_DISABLED = Color(0.627, 0.627, 0.627) # #a0a0a0
	
	# Cores de fundo
	const BG_MAIN = Color(0.039, 0.039, 0.039)       # #0a0a0a
	const BG_PANEL = Color(0.102, 0.102, 0.180, 0.9) # #1a1a2e com alpha
	const BG_POPUP = Color(0.0, 0.0, 0.0, 0.8)       # Background de popups
	
	# Cores de status
	const HP_RED = Color(1.0, 0.278, 0.341)          # #ff4757
	const MANA_BLUE = Color(0.216, 0.259, 0.980)     # #3742fa
	const STAMINA_GREEN = Color(0.125, 0.698, 0.667) # #20b2aa
	const XP_YELLOW = Color(1.0, 0.647, 0.008)       # #ffa502
	
	# Estados de UI
	const SUCCESS_GREEN = Color(0.125, 0.698, 0.667) # #20b2aa
	const WARNING_ORANGE = Color(1.0, 0.647, 0.008)  # #ffa502
	const ERROR_RED = Color(1.0, 0.278, 0.341)       # #ff4757
	const INFO_BLUE = Color(0.0, 0.831, 1.0)         # #00d4ff

# === ESTILOS DE UI ===
class Styles:
	# Bordas e contornos
	const BORDER_WIDTH = 2
	const BORDER_RADIUS = 8
	const BUTTON_BORDER_RADIUS = 12
	const PANEL_BORDER_RADIUS = 16
	
	# Sombras e efeitos
	const SHADOW_OFFSET = Vector2(4, 4)
	const SHADOW_BLUR = 8
	const GLOW_SIZE = 6
	
	# AnimaÃ§Ãµes
	const FADE_DURATION = 0.3
	const SLIDE_DURATION = 0.4
	const HOVER_DURATION = 0.2
	const SCALE_HOVER = 1.05

# === FONTES ===
class Fonts:
	const MAIN_SIZE = 16
	const TITLE_SIZE = 24
	const SUBTITLE_SIZE = 20
	const SMALL_SIZE = 12
	const LARGE_SIZE = 32

static func get_color(color_name: String) -> Color:
# Retorna cor por nome para facilitar uso em scripts
	match color_name:
		"primary_dark": return Colors.PRIMARY_DARK
		"primary_navy": return Colors.PRIMARY_NAVY
		"cyber_cyan": return Colors.CYBER_CYAN
		"tech_orange": return Colors.TECH_ORANGE
		"accent_gold": return Colors.ACCENT_GOLD
		"text_primary": return Colors.TEXT_PRIMARY
		"text_secondary": return Colors.TEXT_SECONDARY
		"bg_main": return Colors.BG_MAIN
		"bg_panel": return Colors.BG_PANEL
		"hp_red": return Colors.HP_RED
		"mana_blue": return Colors.MANA_BLUE
		"stamina_green": return Colors.STAMINA_GREEN
		"xp_yellow": return Colors.XP_YELLOW
		"success": return Colors.SUCCESS_GREEN
		"warning": return Colors.WARNING_ORANGE
		"error": return Colors.ERROR_RED
		"info": return Colors.INFO_BLUE
		_: return Colors.TEXT_PRIMARY

static func create_button_style(
	normal_color: Color,
	hover_color: Color,
	pressed_color: Color,
	border_color: Color = Colors.CYBER_CYAN
) -> StyleBoxFlat:
# Cria estilo padrÃ£o para botÃµes
	var style = StyleBoxFlat.new()
	style.bg_color = normal_color
	style.border_width_left = Styles.BORDER_WIDTH
	style.border_width_right = Styles.BORDER_WIDTH
	style.border_width_top = Styles.BORDER_WIDTH
	style.border_width_bottom = Styles.BORDER_WIDTH
	style.border_color = border_color
	style.corner_radius_top_left = Styles.BUTTON_BORDER_RADIUS
	style.corner_radius_top_right = Styles.BUTTON_BORDER_RADIUS
	style.corner_radius_bottom_left = Styles.BUTTON_BORDER_RADIUS
	style.corner_radius_bottom_right = Styles.BUTTON_BORDER_RADIUS
	
	return style

static func create_panel_style(
	bg_color: Color = Colors.BG_PANEL,
	border_color: Color = Colors.CYBER_CYAN
) -> StyleBoxFlat:
# Cria estilo padrÃ£o para painÃ©is
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = Styles.BORDER_WIDTH
	style.border_width_right = Styles.BORDER_WIDTH
	style.border_width_top = Styles.BORDER_WIDTH
	style.border_width_bottom = Styles.BORDER_WIDTH
	style.border_color = border_color
	style.corner_radius_top_left = Styles.PANEL_BORDER_RADIUS
	style.corner_radius_top_right = Styles.PANEL_BORDER_RADIUS
	style.corner_radius_bottom_left = Styles.PANEL_BORDER_RADIUS
	style.corner_radius_bottom_right = Styles.PANEL_BORDER_RADIUS
	
	return style

static func create_progress_bar_style(
	fill_color: Color,
	background_color: Color = Colors.PRIMARY_DARK
) -> StyleBoxFlat:
# Cria estilo para barras de progresso (HP, Mana, etc.)
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = fill_color.darkened(0.3)
	style.corner_radius_top_left = Styles.BORDER_RADIUS
	style.corner_radius_top_right = Styles.BORDER_RADIUS
	style.corner_radius_bottom_left = Styles.BORDER_RADIUS
	style.corner_radius_bottom_right = Styles.BORDER_RADIUS
	
	return style

static func apply_glow_effect(node: Control, color: Color = Colors.CYBER_CYAN):
# Aplica efeito de brilho em um node
	# ImplementaÃ§Ã£o de efeito glow via shader ou modulate
	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate", color * 1.2, 1.0)
	tween.tween_property(node, "modulate", color, 1.0)

static func animate_scale_hover(node: Control):
# AnimaÃ§Ã£o de escala no hover
	var tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * Styles.SCALE_HOVER, Styles.HOVER_DURATION)

static func animate_scale_normal(node: Control):
# Volta escala normal
	var tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, Styles.HOVER_DURATION)
