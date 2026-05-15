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

