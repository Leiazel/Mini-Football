extends Node

func _ready():
	# Esperar un frame para que los nodos estén listos
	await get_tree().process_frame
	var porteria_i = get_tree().get_root().find_child("Porteria_i", true, false)
	var porteria_d = get_tree().get_root().find_child("Porteria_d", true, false)
	
	if porteria_i:
		porteria_i.gol_anotado.connect(_on_gol_visitante)
	if porteria_d:
		porteria_d.gol_anotado.connect(_on_gol_local)

func _on_gol_local():
	var label = get_tree().get_root().find_child("Label", true, false)
	if label and label.has_method("gol_local"):
		label.gol_local()
	
	# Si anota el local, saca el visitante
	var mundo = get_tree().current_scene
	if mundo and mundo.has_method("iniciar_kickoff"):
		mundo.call_deferred("iniciar_kickoff", "visitante")

func _on_gol_visitante():
	var label = get_tree().get_root().find_child("Label", true, false)
	if label and label.has_method("gol_visitante"):
		label.gol_visitante()
	
	# Si anota el visitante, saca el local
	var mundo = get_tree().current_scene
	if mundo and mundo.has_method("iniciar_kickoff"):
		mundo.call_deferred("iniciar_kickoff", "local")

