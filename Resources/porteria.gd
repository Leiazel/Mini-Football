extends Area2D

enum Equipo { LOCAL, VISITANTE }
@export var equipo: Equipo = Equipo.LOCAL
@export var zona_tiro: Marker2D  # Arrastra un Marker2D aquí

signal gol_anotado  # ← esta línea tiene que estar

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.name == "Pelota":
		gol_anotado.emit()	
		# Reiniciar pelota
		reset_pelota(body)

func reset_pelota(pelota: RigidBody2D):
	pelota.linear_velocity = Vector2.ZERO
	pelota.angular_velocity = 0
	# Esperar un momento y colocar en centro
	await get_tree().create_timer(0.2).timeout
	pelota.global_position = Vector2(710, 336)  # Centro de pantalla (ajusta)
