extends Area2D

enum Equipo { LOCAL, VISITANTE }
@export var equipo: Equipo = Equipo.LOCAL
@export var zona_tiro: Marker2D  # Arrastra un Marker2D aquí

signal gol_marcado(equipo)

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Cambiar color según equipo (visual)
	if equipo == Equipo.LOCAL:
		modulate = Color(1, 0.5, 0.5)  # Rojizo
	else:
		modulate = Color(0.5, 0.5, 1)  # Azulado

func _on_body_entered(body: Node2D):
	if body.name == "Pelota" or (body is RigidBody2D and body.get_class() == "RigidBody2D"):
		print("⚽ ¡GOL! Gol del equipo ", "LOCAL" if equipo == Equipo.LOCAL else "VISITANTE")
		gol_marcado.emit(equipo)
		
		# Reiniciar pelota
		reset_pelota(body)

func reset_pelota(pelota: RigidBody2D):
	pelota.linear_velocity = Vector2.ZERO
	pelota.angular_velocity = 0
	# Esperar un momento y colocar en centro
	await get_tree().create_timer(1.5).timeout
	pelota.global_position = Vector2(710, 336)  # Centro de pantalla (ajusta)
