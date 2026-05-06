extends Node

var goles_local = 0
var goles_visitante = 0

func _ready():
	# Conectar las dos porterías
	var porteria_i = get_tree().get_root().find_child("Porteria_i", true, false)
	var porteria_d = get_tree().get_root().find_child("Porteria_d", true, false)
	
	if porteria_i:
		porteria_i.gol_anotado.connect(_on_gol_visitante)
	if porteria_d:
		porteria_d.gol_anotado.connect(_on_gol_local)

func _on_gol_local():
	goles_local += 1
	actualizar_label()
	resetear_pelota()

func _on_gol_visitante():
	goles_visitante += 1
	actualizar_label()
	resetear_pelota()

func actualizar_label():
	var label = get_tree().get_root().find_child("Label", true, false)
	if label:
		label.text = str(goles_local) + " - " + str(goles_visitante)

func resetear_pelota():
	var pelota = get_tree().get_root().find_child("Pelota", true, false)
	if pelota:
		pelota.linear_velocity = Vector2.ZERO
		pelota.angular_velocity = 0.0
		pelota.global_position = Vector2(660, 320)  # ← centro de tu cancha, ajustá
