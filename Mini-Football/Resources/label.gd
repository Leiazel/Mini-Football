extends Label

var goles_local = 0
var goles_visitante = 0
var tiempo_partido = 0.0

@onready var panel_fondo = Panel.new()
@onready var lbl_equipo1 = Label.new()
@onready var lbl_equipo2 = Label.new()
@onready var lbl_tiempo = Label.new()
@onready var lbl_score = Label.new()

func _ready():
	# Ocultar texto original
	text = ""
	
	# Configurar Panel de Fondo (Estilo Transmisión de TV)
	panel_fondo.custom_minimum_size = Vector2(300, 40)
	panel_fondo.position = Vector2(0, 0)
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	estilo.border_width_bottom = 2
	estilo.border_color = Color(1.0, 0.8, 0.0)
	estilo.corner_radius_top_left = 5
	estilo.corner_radius_top_right = 5
	estilo.corner_radius_bottom_left = 5
	estilo.corner_radius_bottom_right = 5
	panel_fondo.add_theme_stylebox_override("panel", estilo)
	add_child(panel_fondo)
	
	# Textos
	lbl_equipo1.text = "AZU"
	lbl_equipo1.position = Vector2(10, 5)
	lbl_equipo1.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	panel_fondo.add_child(lbl_equipo1)
	
	lbl_score.text = "0 - 0"
	lbl_score.position = Vector2(120, 5)
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_fondo.add_child(lbl_score)
	
	lbl_equipo2.text = "ROJ"
	lbl_equipo2.position = Vector2(250, 5)
	lbl_equipo2.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	panel_fondo.add_child(lbl_equipo2)
	
	lbl_tiempo.text = "00:00"
	lbl_tiempo.position = Vector2(120, 25)
	lbl_tiempo.add_theme_font_size_override("font_size", 12)
	lbl_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_fondo.add_child(lbl_tiempo)

func _process(delta):
	tiempo_partido += delta * 2 # Acelerar el tiempo un poco
	var minutos = int(tiempo_partido / 60)
	var segundos = int(tiempo_partido) % 60
	lbl_tiempo.text = "%02d:%02d" % [minutos, segundos]
	
	# Terminar partido
	if minutos >= 90:
		lbl_tiempo.text = "FINAL"
		set_process(false)

func actualizar_marcador():
	lbl_score.text = str(goles_local) + " - " + str(goles_visitante)

func gol_local():
	goles_local += 1
	actualizar_marcador()

func gol_visitante():
	goles_visitante += 1
	actualizar_marcador()
