extends "res://Players/jugador_base.gd"

@export var pelota: RigidBody2D
@export var porteria_propia: Node2D
@export var jugador_humano: CharacterBody2D
@export var velocidad_normal = 155
@export var radio_salida = 500.0

var timer_anim_pateo := 0.0
var en_posicion := false  # evita el bucle de GUARDAR_POSICION

enum Estado { GUARDAR_POSICION, CORTAR, DECIDIR }
var estado = Estado.GUARDAR_POSICION

func _ready():
	es_controlado_por_ia = true
	override_pateo = true

func _physics_process(_delta):
	if not pelota or not porteria_propia or not jugador_humano:
		return

	timer_anim_pateo -= _delta

	# 1. DATOS BÁSICOS
	var pos_pelota        = pelota.global_position
	var pos_arco          = porteria_propia.global_position
	var dist_pelota       = global_position.distance_to(pos_pelota)
	var dist_arco_pelota  = pos_arco.distance_to(pos_pelota)
	var dist_humano_pelota = jugador_humano.global_position.distance_to(pos_pelota)
	var dir_despeje       = (pos_pelota - pos_arco).normalized()
	var humano_tiene_pelota = dist_humano_pelota < dist_pelota - 20.0
	var pos_cobertura     = pos_arco + (pos_pelota - pos_arco).normalized() * 250.0
	var dist_a_cobertura  = global_position.distance_to(pos_cobertura)

	# 2. TRANSICIONES
	match estado:
		Estado.GUARDAR_POSICION:
			# Fix bucle: si ya llegó, no sigue intentando
			if dist_a_cobertura < 20.0:
				en_posicion = true
			else:
				en_posicion = false
			if dist_arco_pelota < radio_salida or (humano_tiene_pelota and dist_arco_pelota < radio_salida * 1.5):
				en_posicion = false
				estado = Estado.CORTAR
		Estado.CORTAR:
			# Entra en DECIDIR apenas está cerca (por distancia, no solo colisión)
			if dist_pelota < 80.0:
				estado = Estado.DECIDIR
			elif dist_arco_pelota > radio_salida * 1.8 and not humano_tiene_pelota:
				estado = Estado.GUARDAR_POSICION
		Estado.DECIDIR:
			if dist_pelota > 150.0:
				estado = Estado.GUARDAR_POSICION

	# 3. DESTINO Y VELOCIDAD
	var destino: Vector2
	var velocidad_actual = velocidad_normal

	match estado:
		Estado.GUARDAR_POSICION:
			destino = pos_cobertura
			# Si ya está en posición, velocidad cero para no temblar
			velocidad_actual = 0.0 if en_posicion else velocidad_normal * 0.8
		Estado.CORTAR:
			destino = pos_pelota
		Estado.DECIDIR:
			destino = pos_pelota

	# 4. MOVIMIENTO
	var dir_objetivo = (destino - global_position).normalized()
	direccion = direccion.lerp(dir_objetivo, 0.14)
	velocity = direccion * velocidad_actual

	move_and_slide()

	# 5. ACCIÓN — detectar por colisión Y por distancia
	var tocando_pelota = false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == pelota:
			tocando_pelota = true
			break
			
	# Fallback por cercanía
	if dist_pelota < 35.0 and estado == Estado.DECIDIR:
		tocando_pelota = true

	# ACTUALIZACIÓN DE ESTADO EQUIPO: Si está en zona de decisión e interactuando, el compañero TIENE la pelota
	if estado == Estado.DECIDIR and tocando_pelota:
		EstadoEquipo.compañero_tiene_pelota = true
	else:
		# Si se alejó o cambió de estado, ya no la tiene
		if estado != Estado.DECIDIR:
			EstadoEquipo.compañero_tiene_pelota = false

	if tocando_pelota and timer_pateo.is_stopped() and estado == Estado.DECIDIR:
		var puede_pasar = (
			EstadoEquipo.delantero_listo_para_recibir and
			EstadoEquipo.pos_delantero != Vector2.ZERO
		)

		if puede_pasar:
			var dir_pase = (EstadoEquipo.pos_delantero - pos_pelota).normalized()
			var dist_a_delantero = pos_pelota.distance_to(EstadoEquipo.pos_delantero)
			var fuerza_pase = clamp(dist_a_delantero * 3.5, 600.0, 1400.0)
			pelota.apply_central_impulse(dir_pase * fuerza_pase)
			print("¡Pase realizado al delantero!") # Debug para tu consola
		else:
			var fuerza_despeje = 1400.0 if dist_arco_pelota < 150.0 else 800.0
			pelota.apply_central_impulse(dir_despeje * fuerza_despeje)
			print("Despeje efectuado")

		timer_pateo.start()
		timer_anim_pateo = 0.35
		velocity = velocity * 0.2
		direccion = direccion * 0.2
		
		# IMPORTANTE: Apagamos la posesión porque ya pateamos, y cambiamos estado
		EstadoEquipo.compañero_tiene_pelota = false
		estado = Estado.GUARDAR_POSICION

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
