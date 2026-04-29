extends CharacterBody2D

var velocidad = 160
var ultima_direccion = "abajo"
var direccion = Vector2.ZERO
var fuerza = 100.0
var override_pateo = false

@onready var timer_pateo = $CooldownPateo
@onready var animador = $AnimationPlayer

# Nueva variable: si es controlado por IA, no lee el teclado
var es_controlado_por_ia = false

func _physics_process(_delta):
	if es_controlado_por_ia:
		return	
	leer_entrada()  # Esto ahora respetará la bandera
	velocity = direccion * velocidad
	move_and_slide()
	patear_pelota()
	actualizar_animaciones()

func leer_entrada():
	# Solo leer teclado si NO es controlado por IA
	if not es_controlado_por_ia:
		direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

func actualizar_animaciones():
	if direccion != Vector2.ZERO:
		if abs(direccion.x) > abs(direccion.y):
			if direccion.x > 0:
				animador.play("caminar_derecha")
				ultima_direccion = "derecha"
			else:
				animador.play("caminar_izquierda")
				ultima_direccion = "izquierda"
		else:
			if direccion.y > 0:
				animador.play("caminar_abajo")
				ultima_direccion = "abajo"
			else:
				animador.play("caminar_arriba")
				ultima_direccion = "arriba"
	else:
		animador.play("quieto_" + ultima_direccion)

func patear_pelota():
	if override_pateo:
		return
	# Mantén tu código original de pateo aquí
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		var objeto = colision.get_collider()
		
		if objeto is RigidBody2D:
			var direccion_golpe = (objeto.global_position - global_position).normalized()
			
			if Input.is_action_just_pressed("patear") and timer_pateo.is_stopped():
				var fuerza_remate = 2220.0
				objeto.apply_central_impulse(direccion_golpe * fuerza_remate)
				timer_pateo.start()
			else:
				var fuerza_empuje = 30.0
				objeto.apply_central_impulse(direccion_golpe * fuerza_empuje)

# Método auxiliar para IA (lo usará Haaland)
func aplicar_golpe_fuerte():
	if timer_pateo.is_stopped():
		for i in get_slide_collision_count():
			var colision = get_slide_collision(i)
			var objeto = colision.get_collider()
			if objeto is RigidBody2D:
				var direccion_golpe = (objeto.global_position - global_position).normalized()
				objeto.apply_central_impulse(direccion_golpe * 2220.0)
				timer_pateo.start()
				break
