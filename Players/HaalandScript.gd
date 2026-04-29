extends "res://Players/jugador_base.gd"

@export var objetivo: CharacterBody2D
@export var pelota: RigidBody2D
@export var porteria_enemiga: Node2D
@export var velocidad_normal = 160
@export var distancia_control = 60.0
@export var angulo_aceptable = 45.0

enum Estado { BUSCAR, PREPARAR, REMATAR }
var estado = Estado.BUSCAR
var puede_rematar = true
var timer_anim_pateo := 0.0

func _ready():
	es_controlado_por_ia = true
	override_pateo = true

func _physics_process(_delta):
	if not pelota or not porteria_enemiga:
		return

	timer_anim_pateo -= _delta

	# 1. DATOS BÁSICOS
	var pos_pelota = pelota.global_position
	var pos_arco = porteria_enemiga.global_position
	var dist_pelota = global_position.distance_to(pos_pelota)
	var dir_tiro = (pos_arco - pos_pelota).normalized()
	var punto_detras = pos_pelota - (dir_tiro * 70.0)
	var hacia_pelota_norm = (pos_pelota - global_position).normalized()
	var estoy_estorbando = hacia_pelota_norm.dot(dir_tiro) < -0.2

	# 2. TRANSICIONES DE ESTADO
	match estado:
		Estado.BUSCAR:
			if dist_pelota < 400.0 and not estoy_estorbando:
				estado = Estado.PREPARAR
		Estado.PREPARAR:
			if estoy_estorbando:
				estado = Estado.BUSCAR
			elif global_position.distance_to(punto_detras) < 25.0:
				estado = Estado.REMATAR
		Estado.REMATAR:
			if dist_pelota > 120.0:
				estado = Estado.BUSCAR

	# 3. DESTINO SEGÚN ESTADO
	var destino: Vector2
	if dist_pelota > 400.0:
		destino = pos_pelota
	elif estoy_estorbando:
		var lado = Vector2(-dir_tiro.y, dir_tiro.x)
		if (global_position - pos_pelota).dot(lado) < 0:
			lado = -lado
		destino = pos_pelota + (lado * 120.0)
	else:
		match estado:
			Estado.BUSCAR:
				destino = pos_pelota
			Estado.PREPARAR:
				destino = punto_detras
			Estado.REMATAR:
				destino = pos_pelota

	# 4. MOVIMIENTO
	var velocidad_actual = velocidad_normal
	if estado == Estado.PREPARAR:
		velocidad_actual = velocidad_normal * 0.7  # más lento al posicionarse
	elif estado == Estado.REMATAR:
		velocidad_actual = velocidad_normal * 1.2  # más rápido al atacar

	var dir_objetivo = (destino - global_position).normalized()
	direccion = direccion.lerp(dir_objetivo, 0.12)
	velocity = direccion * velocidad_actual

	# 5. PATEO
	var cerca_del_arco = pos_pelota.distance_to(pos_arco) < 500.0

	move_and_slide()

	# Detectar contacto físico real (sirve para conducción Y remate)
	var tocando_pelota = false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == pelota:
			tocando_pelota = true
			break

	if tocando_pelota and timer_pateo.is_stopped():
		if cerca_del_arco and puede_rematar:
			# REMATE
			pelota.apply_central_impulse(dir_tiro * 2200.0)
			timer_pateo.start()
			timer_anim_pateo = 0.4
			puede_rematar = false
			velocity = velocity * 0.1
			direccion = direccion * 0.1
			get_tree().create_timer(1.5).connect("timeout", func(): puede_rematar = true)
		elif not cerca_del_arco and not estoy_estorbando:
			# CONDUCCIÓN
			pelota.apply_central_impulse(dir_tiro * 320.0)
			timer_pateo.start()
		elif estoy_estorbando:
			velocity *= 0.8

	# 6. ANIMACIONES
	if timer_anim_pateo <= 0.0:
		actualizar_animaciones()

func actualizar_animaciones():
	if velocity.length() > 10:
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
