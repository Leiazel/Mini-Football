extends CharacterBody2D
class_name JugadorBase

@export var es_humano: bool = false:
	set(value):
		es_humano = value
		queue_redraw()
@export var id_jugador: int = 0
@export var equipo: String = "local"
@export var rol: String = "MED"
@export var velocidad_normal: float = 145.0
@export var fuerza_pase: float = 520.0
@export var fuerza_tiro: float = 780.0

@export var pelota: RigidBody2D
@export var porteria_enemiga: Node2D
@export var porteria_propia: Node2D

var velocidad_actual: float = 160.0
var direccion: Vector2 = Vector2.ZERO
var ultima_direccion: String = "abajo"
var puede_rematar: bool = true
var timer_anim_pateo: float = 0.0
var posicion_inicial: Vector2 = Vector2.ZERO
var timer_pelota_quieta: float = 0.0

# Kickoff: mientras está true la IA espera en posición
var en_kickoff: bool = false
var en_saque_arco: bool = false
var equipo_saque: String = ""
var intencion_patear: float = 0.0


@onready var timer_pateo = $CooldownPateo
@onready var animador = $AnimationPlayer
@onready var sprite = $Sprite2D

# Aurora (indicador de jugador controlado)
var aurora_node: Node2D = null

enum EstadoIA { GUARDAR_POSICION, BUSCAR_PELOTA, DESMARCARSE, CORTAR, DECIDIR }
var estado_ia: EstadoIA = EstadoIA.GUARDAR_POSICION
var en_posicion_defensiva: bool = false

const STATS_ROLES = {
	"POR": {"vel": 125.0, "pase": 450.0,  "tiro": 400.0},
	"DEF": {"vel": 140.0, "pase": 500.0,  "tiro": 450.0},
	"MED": {"vel": 155.0, "pase": 550.0,  "tiro": 550.0},
	"DEL": {"vel": 165.0, "pase": 480.0,  "tiro": 700.0}
}

const STATS_JUGADORES = {
	"B.Viking":     {"vel": 175.0,  "pase": 450.0,  "tiro": 850.0},
	"Ibracadabra":  {"vel": 150.0,  "pase": 480.0,  "tiro": 780.0},
	"B.Spice":      {"vel": 150.0,  "pase": 750.0,  "tiro": 650.0},
	"P.Capitano":   {"vel": 150.0,  "pase": 520.0,  "tiro": 450.0},
	"S.Shin":       {"vel": 180.0,  "pase": 500.0,  "tiro": 680.0},
	"J.Gold":       {"vel": 165.0,  "pase": 580.0,  "tiro": 650.0},
	"R.Paul":       {"vel": 155.0,  "pase": 620.0,  "tiro": 580.0},
	"D.Armando":    {"vel": 175.0,  "pase": 720.0,  "tiro": 750.0},
	"I.Bat":        {"vel": 185.0,  "pase": 480.0,  "tiro": 480.0},
	"G.Mill":       {"vel": 155.0,  "pase": 460.0,  "tiro": 820.0}
}

func aplicar_estadisticas(nombre: String, rol_asignado: String):
	if STATS_ROLES.has(rol_asignado):
		velocidad_normal = STATS_ROLES[rol_asignado].vel
		fuerza_pase     = STATS_ROLES[rol_asignado].pase
		fuerza_tiro     = STATS_ROLES[rol_asignado].tiro
	if STATS_JUGADORES.has(nombre):
		velocidad_normal = STATS_JUGADORES[nombre].vel
		fuerza_pase     = STATS_JUGADORES[nombre].pase
		fuerza_tiro     = STATS_JUGADORES[nombre].tiro
	velocidad_actual = velocidad_normal

# ==========================================
func _ready():
	velocidad_actual = velocidad_normal
	posicion_inicial = global_position
	add_to_group(equipo)
	# Eliminado el tinte azul/rojo para que se vea el sprite original
	sprite.modulate = Color(1, 1, 1)

	# El indicador (aurora) se dibuja automáticamente en _draw() si es_humano es true


# ==========================================
var _tiempo_aurora: float = 0.0

func _process(delta: float):
	_tiempo_aurora += delta
	queue_redraw()

func _draw():
	# Círculo de equipo (sutil bajo los pies)
	var color_equipo = Color(0.3, 0.6, 1.0, 0.25) if equipo == "local" else Color(1.0, 0.3, 0.3, 0.25)
	draw_circle(Vector2(0, 24), 16.0, color_equipo)
	draw_arc(Vector2(0, 24), 16.0, 0, TAU, 32, Color(color_equipo.r, color_equipo.g, color_equipo.b, 0.5), 1.5)

	if es_humano:
		var r = 28.0
		var opacidad = 0.4 + 0.15 * sin(_tiempo_aurora * 4.0)
		var color_humano = Color(0.2, 0.8, 1.0, opacidad) if id_jugador == 1 else Color(1.0, 0.3, 0.2, opacidad)
		# Indicador premium para el humano
		draw_arc(Vector2(0, 24), r, 0.0, TAU, 32, color_humano, 3.0)
		draw_arc(Vector2(0, 24), r + 4, 0.0, TAU, 32, Color(color_humano.r, color_humano.g, color_humano.b, opacidad * 0.4), 1.0)


# ==========================================
func _physics_process(delta: float):
	timer_anim_pateo -= delta

	if en_kickoff or en_saque_arco:
		logica_ia_kickoff(delta)
		if en_saque_arco:
			aplicar_restriccion_mitad_cancha()
		return
		
	if es_humano:
		logica_humano(delta)
		# Buffer de pateo
		var patear_pressed = false
		if id_jugador == 1:
			patear_pressed = Input.is_action_just_pressed("p1_patear")
		elif id_jugador == 2:
			patear_pressed = Input.is_action_just_pressed("p2_patear")
		
		if patear_pressed:
			intencion_patear = 0.2
		if intencion_patear > 0:
			intencion_patear -= delta
	else:
		logica_ia(delta)

	
	velocity = direccion * velocidad_actual
	move_and_slide()
	verificar_colision_pelota()
	if timer_anim_pateo <= 0.0:
		actualizar_animaciones()

func logica_ia_kickoff(delta: float):
	timer_anim_pateo -= delta
	var dir = (posicion_inicial - global_position)
	if dir.length() > 5:
		direccion = dir.normalized()
		velocidad_actual = velocidad_normal
	else:
		direccion = Vector2.ZERO
		velocidad_actual = 0.0
	velocity = direccion * velocidad_actual
	move_and_slide()
	if timer_anim_pateo <= 0.0:
		actualizar_animaciones()

# ==========================================
func logica_humano(_delta: float):
	direccion = Vector2.ZERO
	if id_jugador == 1:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A): direccion.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D): direccion.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W): direccion.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S): direccion.y += 1
	elif id_jugador == 2:
		if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_LEFT): direccion.x -= 1
		if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_RIGHT): direccion.x += 1
		if Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_UP): direccion.y -= 1
		if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_DOWN): direccion.y += 1
	
	if direccion.length() > 0:
		direccion = direccion.normalized()
	# Boost de velocidad para el humano para que se sienta ágil
	velocidad_actual = velocidad_normal * 1.2

# ==========================================
func logica_ia(delta: float):
	if not pelota or not porteria_enemiga or not porteria_propia:
		direccion = Vector2.ZERO
		return

	var pos_pelota    = pelota.global_position
	var dist_pelota   = global_position.distance_to(pos_pelota)
	var pos_arco_en   = porteria_enemiga.global_position
	var pos_arco_pr   = porteria_propia.global_position
	var equipo_rival  = "visitante" if equipo == "local" else "local"
	
	# ---- SEPARACIÓN (Evitar amontonamiento) ----
	var fuerza_separacion = Vector2.ZERO
	for p in get_tree().get_nodes_in_group(equipo):
		if p != self:
			var d = global_position.distance_to(p.global_position)
			if d < 55.0:
				fuerza_separacion += (global_position - p.global_position).normalized() * (55.0 - d) * 1.5
	
	if fuerza_separacion.length() > 0:
		direccion = (direccion + fuerza_separacion.normalized() * 0.25).normalized()

	# ---- ANTI-ATASCO ----
	if pelota.linear_velocity.length() < 30.0 and dist_pelota < 40.0:
		timer_pelota_quieta += delta
	else:
		timer_pelota_quieta = 0.0

	if timer_pelota_quieta > 0.9 and puede_rematar:
		# Solo actúa el jugador más cercano de todos
		var soy_mas_cercano = true
		for p in get_tree().get_nodes_in_group(equipo):
			if p != self and p.global_position.distance_to(pos_pelota) < dist_pelota - 4.0:
				soy_mas_cercano = false
				break
		if soy_mas_cercano:
			for p in get_tree().get_nodes_in_group(equipo_rival):
				if p.global_position.distance_to(pos_pelota) < dist_pelota - 4.0:
					soy_mas_cercano = false
					break
		if soy_mas_cercano:
			var dir_despeje = _calcular_direccion_despeje(pos_arco_en, pos_arco_pr)
			pelota.apply_central_impulse(dir_despeje * fuerza_pase * 1.6)
			timer_pelota_quieta = 0.0
			iniciar_cooldown_pateo()
			return

	var pos_base = calcular_posicion_base(pos_pelota, pos_arco_pr, pos_arco_en)

	var compañero_tiene_pelota = false
	for p in get_tree().get_nodes_in_group(equipo):
		if p != self and p.global_position.distance_to(pos_pelota) < 55:
			compañero_tiene_pelota = true
			break

	# ---- ESTADOS POR ROL ----
	match rol:
		"POR":
			estado_ia = EstadoIA.BUSCAR_PELOTA if (dist_pelota < 130 and not compañero_tiene_pelota) else EstadoIA.GUARDAR_POSICION

		"DEF":
			var pos_arco = porteria_propia.global_position
			var dist_arco_pelota = pos_arco.distance_to(pos_pelota)
			var radio_salida = 450.0
			
			if estado_ia == EstadoIA.GUARDAR_POSICION:
				if dist_arco_pelota < radio_salida:
					estado_ia = EstadoIA.CORTAR
					en_posicion_defensiva = false
				elif global_position.distance_to(pos_base) < 20.0:
					en_posicion_defensiva = true
			elif estado_ia == EstadoIA.CORTAR:
				if dist_pelota < 80.0:
					estado_ia = EstadoIA.DECIDIR
				elif dist_arco_pelota > radio_salida * 1.5:
					estado_ia = EstadoIA.GUARDAR_POSICION
			elif estado_ia == EstadoIA.DECIDIR:
				if dist_pelota > 150.0:
					estado_ia = EstadoIA.GUARDAR_POSICION

		"MED":
			if compañero_tiene_pelota:
				estado_ia = EstadoIA.DESMARCARSE
			elif dist_pelota < 470:
				estado_ia = EstadoIA.BUSCAR_PELOTA
			else:
				estado_ia = EstadoIA.GUARDAR_POSICION

		"DEL":
			if compañero_tiene_pelota:
				estado_ia = EstadoIA.DESMARCARSE
			elif dist_pelota < 620:
				estado_ia = EstadoIA.BUSCAR_PELOTA
			else:
				estado_ia = EstadoIA.DESMARCARSE

	# ---- EJECUTAR ESTADO ----
	var destino = pos_base
	velocidad_actual = velocidad_normal

	match estado_ia:
		EstadoIA.GUARDAR_POSICION:
			destino = pos_base
			velocidad_actual = 0.0 if en_posicion_defensiva else velocidad_normal * 0.8

		EstadoIA.BUSCAR_PELOTA, EstadoIA.CORTAR, EstadoIA.DECIDIR:
			destino = pos_pelota
			velocidad_actual = velocidad_normal * 1.2

		EstadoIA.DESMARCARSE:
			var dir_ataque = (pos_arco_en - global_position).normalized()
			match rol:
				"MED":
					var largo = abs(pos_arco_en.x - pos_arco_pr.x)
					var x_lim = pos_arco_pr.x + dir_ataque.x * largo * 0.65
					var x_obj = pos_pelota.x + dir_ataque.x * 180
					x_obj = min(x_obj, x_lim) if dir_ataque.x > 0 else max(x_obj, x_lim)
					destino = Vector2(x_obj, posicion_inicial.y)
					velocidad_actual = velocidad_normal * 0.85
				"DEL":
					destino = pos_arco_en - dir_ataque * 200
					velocidad_actual = velocidad_normal * 1.0
				_:
					destino = pos_base
					velocidad_actual = velocidad_normal * 0.8

	if estado_ia != EstadoIA.BUSCAR_PELOTA and destino.distance_to(global_position) < 25:
		velocidad_actual = 0.0

	var dir_obj = (destino - global_position).normalized()
	if velocidad_actual > 0:
		direccion = direccion.lerp(dir_obj, 0.18)
	else:
		direccion = Vector2.ZERO

# ==========================================
func calcular_posicion_base(pos_pelota: Vector2, pos_arco_propio: Vector2, pos_arco_enemigo: Vector2) -> Vector2:
	var dir_cancha = (pos_arco_enemigo - pos_arco_propio).normalized()
	var base = pos_arco_propio
	match rol:
		"POR": base = pos_arco_propio + dir_cancha * 60
		"DEF": 
			var dir_hacia_pelota = (pos_pelota - pos_arco_propio).normalized()
			base = pos_arco_propio + dir_hacia_pelota * 400.0
		"MED": base = pos_arco_propio + dir_cancha * 650
		"DEL": base = pos_arco_propio + dir_cancha * 1000
	base.y = lerp(posicion_inicial.y, pos_pelota.y, 0.35)
	return base

# ==========================================
# Calcula la dirección de despeje inteligente:
# - Si el jugador "mira" hacia su propio arco (de espaldas al rival),
#   desvía hacia los costados en lugar de atrás.
# ==========================================
func _calcular_direccion_despeje(pos_arco_en: Vector2, pos_arco_pr: Vector2) -> Vector2:
	var dir_hacia_arco_en = (pos_arco_en - global_position).normalized()
	# Verificar si estamos mirando hacia el arco propio (ángulo obtuso con dir de ataque)
	var dir_cancha = (pos_arco_en - pos_arco_pr).normalized()
	var dot = dir_hacia_arco_en.dot(dir_cancha)

	if dot > 0.25:
		# Podemos despejar hacia adelante con cierto sesgo lateral
		var sesgo_y = clamp((global_position.y - 450.0) / 450.0, -0.3, 0.3)
		return Vector2(dir_hacia_arco_en.x, dir_hacia_arco_en.y + sesgo_y).normalized()
	else:
		# Estamos de espaldas: despejar hacia el costado libre
		# Elegir el lado con menos rivales
		var equipo_rival = "visitante" if equipo == "local" else "local"
		var rivals_arriba = 0
		var rivals_abajo  = 0
		for rival in get_tree().get_nodes_in_group(equipo_rival):
			if rival.global_position.distance_to(global_position) < 250:
				if rival.global_position.y < global_position.y:
					rivals_arriba += 1
				else:
					rivals_abajo += 1
		# Despejar hacia el lado con menos rivales
		var dir_y = -1.0 if rivals_arriba <= rivals_abajo else 1.0
		# Añadir componente X hacia adelante
		return Vector2(dir_cancha.x * 0.5, dir_y * 0.85).normalized()

# ==========================================
func verificar_colision_pelota():
	if not pelota: return
	
	var tocando_pelota = false
	var direccion_golpe = Vector2.ZERO
	
	for i in get_slide_collision_count():
		var colision = get_slide_collision(i)
		if colision.get_collider() == pelota:
			tocando_pelota = true
			direccion_golpe = (pelota.global_position - global_position).normalized()
			break
	
	# Fallback por cercanía para IA
	if not es_humano and global_position.distance_to(pelota.global_position) < 24.0:
		tocando_pelota = true
		direccion_golpe = (pelota.global_position - global_position).normalized()

	if tocando_pelota and timer_pateo.is_stopped() and puede_rematar:
		evaluar_pateo_o_pase(pelota, direccion_golpe)

func verificar_linea_pase(compañero: Node2D) -> bool:
	var equipo_rival = "visitante" if equipo == "local" else "local"
	var dir_pase  = (compañero.global_position - global_position).normalized()
	var dist_pase = global_position.distance_to(compañero.global_position)
	for rival in get_tree().get_nodes_in_group(equipo_rival):
		var dir_rival  = (rival.global_position - global_position).normalized()
		var dist_rival = global_position.distance_to(rival.global_position)
		if dir_pase.dot(dir_rival) > 0.82 and dist_rival < dist_pase:
			return false
	return true

func evaluar_pateo_o_pase(pelota_rb: RigidBody2D, direccion_golpe: Vector2):
	var pos_pelota = pelota_rb.global_position
	if not porteria_enemiga: return
	var pos_arco = porteria_enemiga.global_position
	var dir_al_arco = (pos_arco - global_position).normalized()
	var dist_al_arco = global_position.distance_to(pos_arco)
	var pos_arco_pr  = porteria_propia.global_position
	
	if es_humano:
		var patear_held = false
		if id_jugador == 1:
			patear_held = Input.is_action_pressed("p1_patear")
		elif id_jugador == 2:
			patear_held = Input.is_action_pressed("p2_patear")
			
		if intencion_patear > 0 or patear_held:
			pelota_rb.apply_central_impulse(direccion_golpe * 2220.0)
			iniciar_cooldown_pateo()
			intencion_patear = 0.0
		else:
			# Conducción más controlada y ágil
			var dir_conduccion = (direccion_golpe + direccion * 0.4).normalized()
			pelota_rb.apply_central_impulse(dir_conduccion * 50.0)
		return

	# IA Logic
	var dist_pared = min(abs(pos_pelota.x - 110), abs(pos_pelota.x - 2010), abs(pos_pelota.y - 25), abs(pos_pelota.y - 1025))
	var mult_f = 0.5 if dist_pared < 50.0 else 1.0

	match rol:
		"DEF", "POR":
			var puede_pasar = EstadoEquipo.delantero_listo_para_recibir and EstadoEquipo.pos_delantero != Vector2.ZERO
			if puede_pasar:
				var dir_a_haaland = (EstadoEquipo.pos_delantero - global_position).normalized()
				if direccion_golpe.dot(dir_a_haaland) > 0.2:
					var dist_a_delantero = global_position.distance_to(EstadoEquipo.pos_delantero)
					var fuerza_pase_ia = clamp(dist_a_delantero * 6.5, 2200.0, 3200.0)
					pelota_rb.apply_central_impulse(dir_a_haaland * fuerza_pase_ia * mult_f)
				else:
					var dir_despeje = (pos_pelota - pos_arco_pr).normalized()
					var dir_lateral = dir_despeje.rotated(deg_to_rad(45) * (1 if randf() > 0.5 else -1))
					pelota_rb.apply_central_impulse(dir_lateral * 1800.0 * mult_f)
			else:
				var dir_despeje = (pelota_rb.global_position - pos_arco_pr).normalized()
				var fuerza_despeje = 2220.0 if global_position.distance_to(pos_arco_pr) < 500.0 else 1000.0
				pelota_rb.apply_central_impulse(dir_despeje * fuerza_despeje * mult_f)
			iniciar_cooldown_pateo()

		"DEL":
			if dist_al_arco < 900.0:
				pelota_rb.apply_central_impulse(dir_al_arco * 2220.0 * mult_f)
				iniciar_cooldown_pateo()
			else:
				pelota_rb.apply_central_impulse(direccion_golpe * 45.0 * mult_f)

		"MED":
			# Pasar al DEL si es posible, sino conducir o tirar
			var mejor_del = null
			for c in get_tree().get_nodes_in_group(equipo):
				if c != self and c.rol == "DEL" and verificar_linea_pase(c):
					mejor_del = c
					break
			if mejor_del:
				pelota_rb.apply_central_impulse((mejor_del.global_position - global_position).normalized() * 1800.0 * mult_f)
				iniciar_cooldown_pateo()
			elif dist_al_arco < 600.0:
				pelota_rb.apply_central_impulse(dir_al_arco * 2100.0 * mult_f)
				iniciar_cooldown_pateo()
			else:
				pelota_rb.apply_central_impulse(direccion_golpe * 40.0 * mult_f)

# ==========================================
func iniciar_cooldown_pateo():
	timer_pateo.start()
	timer_anim_pateo = 0.4
	puede_rematar = false
	get_tree().create_timer(0.6).timeout.connect(permitir_remate)

func permitir_remate():
	puede_rematar = true

func activar_kickoff():
	en_kickoff = true
	global_position = posicion_inicial
	velocidad_actual = 0.0
	direccion = Vector2.ZERO

func desactivar_kickoff():
	en_kickoff = false

func activar_saque_arco(equipo_que_saca: String):
	en_saque_arco = true
	equipo_saque = equipo_que_saca
	global_position = posicion_inicial
	velocidad_actual = 0.0
	direccion = Vector2.ZERO

func desactivar_saque_arco():
	en_saque_arco = false

func aplicar_restriccion_mitad_cancha():
	if equipo != equipo_saque:
		var mitad_x = 1050.0
		if equipo == "local":
			# Local ataca derecha, no puede pasar a la derecha de mitad
			global_position.x = min(global_position.x, mitad_x - 120.0)
		else:
			# Visitante ataca izquierda, no puede pasar a la izquierda de mitad
			global_position.x = max(global_position.x, mitad_x + 120.0)

# ==========================================
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
