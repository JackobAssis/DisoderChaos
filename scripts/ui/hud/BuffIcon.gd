extends Control
class_name BuffIcon

@export var buff_id: String = ""
@export var is_buff: bool = true

func setup(buff_id_in: String, is_buff_in: bool):
	buff_id = buff_id_in
	is_buff = is_buff_in
	queue_redraw()

func _draw():
	var color = Color(0.0, 1.0, 0.5, 0.9) if is_buff else Color(1.0, 0.2, 0.2, 0.9)
	draw_rect(Rect2(Vector2.ZERO, Vector2(32,32)), color)
	draw_string(get_theme_default_font(), Vector2(4,18), buff_id.substr(0,2).to_upper(), Color.WHITE)