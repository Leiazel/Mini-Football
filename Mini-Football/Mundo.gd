extends Node2D

@export var jugador_escena: PackedScene = preload("res://Players/jugador_base.tscn")

@onready var pelota    = $Pelota
@onready var porteria_i = $Porteria_i
@onready var porteria_d = $Porteria_d
@onready var camera    = $Camera2D
@onready var fondo     = $TextureRect

var roles = ["POR", "DEF", "MED", "DEL"]

const CAM_MIN_X = 500.0
const CAM_MAX_X = 1600.0
const CAM_MIN_Y = 150.0
const CAM_MAX_Y = 750.0

var kickoff_activo: bool = false
var equipo_kickoff: String = "local"
var timer_kickoff_ia: float = 0.0

var saque_arco_activo: bool = false
var equipo_saque_arco: String = ""
var timer_ia_saque: float = 0.0

var CENTRO_PELOTA: Vector2 = Vector2(1050, 525)  # Centro del campo por defecto

var modo_juego: String = "6v6"
var es_multijugador: bool = false

# Limites dinámicos del campo
var limite_min_x: float = 110.0
var limite_max_x: float = 2010.0
var limite_min_y: float = 25.0
var limite_max_y: float = 1025.0


func _ready():
	_configurar_inputs()
	_configurar_fisica_pelota()

	var datos_web = obtener_datos_web()
	if datos_web:
		print("Datos recibidos de la web: ", datos_web)
		if datos_web.has("modoJuego"):
			modo_juego = datos_web.modoJuego
		if datos_web.has("multijugador"):
			es_multijugador = datos_web.multijugador
		
		instanciar_equipo(datos_web.local, "local")
		instanciar_equipo(datos_web.visitante, "visitante")
	else:
		print("Modo local, equipo por defecto.")
		var def_local = [
			{"nombre": "J.Pick",     "rol": "POR"},
			{"nombre": "S.Guard",    "rol": "DEF"},
			{"nombre": "R.Paul",     "rol": "MED"},
			{"nombre": "B.Viking",   "rol": "DEL"}
		]
		var def_visit = [
			{"nombre": "B.Drago",    "rol": "POR"},
			{"nombre": "P.Capitano", "rol": "DEF"},
			{"nombre": "J.Gold",     "rol": "MED"},
			{"nombre": "Ibracadabra", "rol": "DEL"}
		]
		instanciar_equipo(def_local, "local")
		instanciar_equipo(def_visit, "visitante")

	_ajustar_cancha_segun_modo()

	# Iniciar el kickoff después de que todos los jugadores existan
	call_deferred("iniciar_kickoff", "local")

func _configurar_inputs():
	var acciones = {
		"p1_left": [KEY_A],
		"p1_right": [KEY_D],
		"p1_up": [KEY_W],
		"p1_down": [KEY_S],
		"p1_patear": [KEY_SPACE],
		"p1_cambiar": [KEY_Q],
		"p2_left": [KEY_LEFT],
		"p2_right": [KEY_RIGHT],
		"p2_up": [KEY_UP],
		"p2_down": [KEY_DOWN],
		"p2_patear": [KEY_SHIFT],
		"p2_cambiar": [KEY_ENTER]
	}
	for accion in acciones:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
		# Limpiamos si hay previos
		InputMap.action_erase_events(accion)
		for tecla in acciones[accion]:
			var evento = InputEventKey.new()
			# Para teclas físicas comunes (letras, espacio), usamos physical_keycode. Para especiales (flechas), keycode.
			if tecla < 4000000:
				evento.physical_keycode = tecla
			else:
				evento.keycode = tecla
			InputMap.action_add_event(accion, evento)

func _ajustar_cancha_segun_modo():
	if modo_juego == "1v1":
		# Campo muy reducido para 1v1
		limite_min_x = 550.0
		limite_max_x = 1550.0
		limite_min_y = 200.0
		limite_max_y = 850.0
		if camera: camera.zoom = Vector2(1.3, 1.3)
	elif modo_juego == "3v3":
		# Campo intermedio para 3v3
		limite_min_x = 450.0
		limite_max_x = 1650.0
		limite_min_y = 125.0
		limite_max_y = 925.0
		if camera: camera.zoom = Vector2(1.1, 1.1)
	else:
		# Campo completo 6v6
		limite_min_x = 110.0
		limite_max_x = 2010.0
		limite_min_y = 25.0
		limite_max_y = 1025.0
		if camera: camera.zoom = Vector2(0.85, 0.85)
	
	# Mover porterías al borde del campo
	if porteria_i: porteria_i.global_position.x = limite_min_x + 20
	if porteria_d: porteria_d.global_position.x = limite_max_x - 20
	
	# Ajustar imagen de fondo para que coincida con el campo
	if fondo:
		fondo.offset_left   = limite_min_x - 100
		fondo.offset_right  = limite_max_x + 100
		fondo.offset_top    = limite_min_y - 75
		fondo.offset_bottom = limite_max_y + 75
	
	# Centrar cámara en el campo
	if camera:
		camera.global_position = Vector2((limite_min_x + limite_max_x) / 2.0, (limite_min_y + limite_max_y) / 2.0)
	
	# Actualizar centro de pelota para kickoffs
	CENTRO_PELOTA = Vector2((limite_min_x + limite_max_x) / 2.0, (limite_min_y + limite_max_y) / 2.0)


# ==========================================
# KICKOFF
# ==========================================
func iniciar_kickoff(equipo_que_saca: String = "local"):
	kickoff_activo = true
	equipo_kickoff = equipo_que_saca
	timer_kickoff_ia = 0.0

	# Congelar pelota en el centro
	pelota.global_position = CENTRO_PELOTA
	pelota.linear_velocity  = Vector2.ZERO
	pelota.angular_velocity = 0.0
	pelota.freeze = true
	if has_node("AvisoSaque"):
		var text = "SAQUE DE CENTRO: " + equipo_que_saca.to_upper()
		if equipo_que_saca == "local":
			text += "\nPresiona ESPACIO para patear"
		elif es_multijugador:
			text += "\nPresiona SHIFT para patear"
		$AvisoSaque.text = text
		$AvisoSaque.visible = true

	# Ordenar a todos los jugadores que vayan a su posición inicial
	for p in get_tree().get_nodes_in_group("local"):
		p.activar_kickoff()
	for p in get_tree().get_nodes_in_group("visitante"):
		p.activar_kickoff()

func _process(delta: float):
	# --- CAMBIO DE JUGADOR (Q) ---
	if Input.is_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_Q):
		# Usamos un cooldown interno o solo just_pressed
		pass # Lo manejamos mejor en _unhandled_input para evitar ráfagas
		
	# --- KICKOFF COUNTDOWN ---

	if kickoff_activo:
		if equipo_kickoff == "local":
			if Input.is_action_just_pressed("p1_patear"):
				_finalizar_kickoff()
		else:
			if es_multijugador:
				if Input.is_action_just_pressed("p2_patear"):
					_finalizar_kickoff()
			else:
				timer_kickoff_ia += delta
				if timer_kickoff_ia >= 1.5:
					_finalizar_kickoff()
	elif saque_arco_activo:
		if equipo_saque_arco == "local":
			if Input.is_action_just_pressed("p1_patear"):
				_finalizar_saque_arco()
		else:
			if es_multijugador:
				if Input.is_action_just_pressed("p2_patear"):
					_finalizar_saque_arco()
			else:
				timer_ia_saque += delta
				if timer_ia_saque >= 1.5:
					_finalizar_saque_arco()

	# --- CÁMARA ---
	if camera and pelota:
		var target_x = clamp(pelota.global_position.x, CAM_MIN_X, CAM_MAX_X)
		var target_y = clamp(pelota.global_position.y, CAM_MIN_Y, CAM_MAX_Y)
		camera.global_position.x = lerp(camera.global_position.x, target_x, delta * 4.0)
		camera.global_position.y = lerp(camera.global_position.y, target_y, delta * 3.0)

func _finalizar_kickoff():
	kickoff_activo = false
	pelota.freeze  = false
	if has_node("AvisoSaque"):
		$AvisoSaque.visible = false

	# Buscar compañero local (IA) para pasarle
	var teammate_group = equipo_kickoff
	var teammates = get_tree().get_nodes_in_group(teammate_group)
	var target = null
	var min_dist = INF
	for p in teammates:
		if p.es_humano: continue
		var d = p.global_position.distance_to(pelota.global_position)
		if d < min_dist:
			min_dist = d
			target = p
	
	var dir = Vector2(1, 0) if teammate_group == "local" else Vector2(-1, 0)
	if target:
		dir = (target.global_position - pelota.global_position).normalized()
	
	pelota.apply_central_impulse(dir * 500.0)

	# Liberar a todos los jugadores
	for p in get_tree().get_nodes_in_group("local"):
		p.desactivar_kickoff()
	for p in get_tree().get_nodes_in_group("visitante"):
		p.desactivar_kickoff()

func iniciar_saque_arco(equipo: String):
	saque_arco_activo = true
	equipo_saque_arco = equipo
	pelota.freeze = true
	timer_ia_saque = 0.0
	
	var pos_saque = Vector2.ZERO
	if equipo == "local":
		pos_saque = Vector2(limite_min_x + 140, 500)
	else:
		pos_saque = Vector2(limite_max_x - 140, 500)
	
	pelota.global_position = pos_saque
	pelota.linear_velocity = Vector2.ZERO
	
	if has_node("AvisoSaque"):
		if equipo == "local":
			$AvisoSaque.text = "SAQUE DE ARCO: " + equipo.to_upper() + "\nPresiona ESPACIO"
		elif es_multijugador:
			$AvisoSaque.text = "SAQUE DE ARCO: " + equipo.to_upper() + "\nPresiona SHIFT"
		else:
			$AvisoSaque.text = "SAQUE DE ARCO: " + equipo.to_upper()
		$AvisoSaque.visible = true
	
	for p in get_tree().get_nodes_in_group("local"):
		p.activar_saque_arco(equipo)
	for p in get_tree().get_nodes_in_group("visitante"):
		p.activar_saque_arco(equipo)

func _finalizar_saque_arco():
	saque_arco_activo = false
	pelota.freeze = false
	if has_node("AvisoSaque"):
		$AvisoSaque.visible = false
	
	# El portero o jugador más cercano patea
	var p_pateador = null
	var min_dist = INF
	for p in get_tree().get_nodes_in_group(equipo_saque_arco):
		var d = p.global_position.distance_to(pelota.global_position)
		if d < min_dist:
			min_dist = d
			p_pateador = p
	
	if p_pateador:
		var target = null
		var min_dist_t = INF
		for p in get_tree().get_nodes_in_group(equipo_saque_arco):
			if p != p_pateador:
				var d = p.global_position.distance_to(pelota.global_position)
				if d < min_dist_t:
					min_dist_t = d
					target = p
		
		var dir = Vector2(1, 0) if equipo_saque_arco == "local" else Vector2(-1, 0)
		if target:
			dir = (target.global_position - pelota.global_position).normalized()
		
		pelota.apply_central_impulse(dir * 600.0)

	for p in get_tree().get_nodes_in_group("local"):
		p.desactivar_saque_arco()
	for p in get_tree().get_nodes_in_group("visitante"):
		p.desactivar_saque_arco()
		
func _unhandled_input(event):
	if event.is_action_pressed("p1_cambiar"):
		_cambiar_jugador_activo("local", 1)
	elif event.is_action_pressed("p2_cambiar") and es_multijugador:
		_cambiar_jugador_activo("visitante", 2)

func _cambiar_jugador_activo(equipo_id: String, jugador_id: int):
	var players = get_tree().get_nodes_in_group(equipo_id)
	var mas_cercano = null
	var min_dist = INF
	
	for p in players:
		var dist = p.global_position.distance_to(pelota.global_position)
		if dist < min_dist:
			min_dist = dist
			mas_cercano = p
			
	if mas_cercano:
		for p in players:
			if p == mas_cercano:
				p.es_humano = true
				p.id_jugador = jugador_id
			else:
				p.es_humano = false


# ==========================================
# FÍSICA DE PELOTA — ESTILO HAXBALL
# ==========================================
func _configurar_fisica_pelota():
	if not pelota: return
	var mat = PhysicsMaterial.new()
	mat.bounce   = 0.35
	mat.friction = 0.1
	pelota.physics_material_override = mat
	pelota.mass         = 1.1 # Le bajamos la masa para que no sea tan pesada
	pelota.linear_damp  = 3.8 # Le bajamos el damp para que fluya mejor

	pelota.angular_damp = 2.0

func _physics_process(_delta):
	if not pelota or pelota.freeze: return
	
	var pos = pelota.global_position
	var vel = pelota.linear_velocity
	
	# Límites del campo
	var choco = false
	if pos.x < limite_min_x:
		if modo_juego == "1v1":
			# En 1v1 la pelota rebota siempre, no hay saque de arco
			pos.x = limite_min_x
			vel.x = abs(vel.x) * 0.8
			choco = true
		elif pos.y < 400 or pos.y > 600:
			iniciar_saque_arco("local")
			return
	elif pos.x > limite_max_x:
		if modo_juego == "1v1":
			pos.x = limite_max_x
			vel.x = -abs(vel.x) * 0.8
			choco = true
		elif pos.y < 400 or pos.y > 600:
			iniciar_saque_arco("visitante")
			return
		
	if pos.y < limite_min_y:
		pos.y = limite_min_y
		vel.y = abs(vel.y) * 0.8
		vel.x += (randf() - 0.5) * 350.0
		choco = true
	elif pos.y > limite_max_y:
		pos.y = limite_max_y
		vel.y = -abs(vel.y) * 0.8
		vel.x += (randf() - 0.5) * 350.0
		choco = true
		
	if choco:
		pelota.global_position = pos
		pelota.linear_velocity = vel

# ==========================================
func obtener_datos_web():
	if OS.has_feature("web"):
		var json_string = JavaScriptBridge.eval("window.localStorage.getItem('miniFootballMatchData');")
		if json_string and json_string != "null":
			var json = JSON.new()
			if json.parse(json_string) == OK:
				return json.get_data()
	return null

func instanciar_equipo(datos_jugadores: Array, equipo: String):
	var ya_hay_humano = false
	var count_rol  = {"POR": 0, "DEF": 0, "MED": 0, "DEL": 0}
	var current_rol = {"POR": 0, "DEF": 0, "MED": 0, "DEL": 0}

	for j in datos_jugadores:
		var r = j.rol if typeof(j) == TYPE_DICTIONARY else roles[datos_jugadores.find(j) % 4]
		if count_rol.has(r):
			count_rol[r] += 1

	for i in range(min(datos_jugadores.size(), 6)):
		var data           = datos_jugadores[i]
		var nombre_jugador = data.nombre if typeof(data) == TYPE_DICTIONARY else data
		var rol_jugador    = data.rol    if typeof(data) == TYPE_DICTIONARY else roles[i % 4]

		var inst = jugador_escena.instantiate()

		var x_pos = 150
		match rol_jugador:
			"POR": x_pos = 150
			"DEF": x_pos = 420
			"MED": x_pos = 690
			"DEL": x_pos = 1010  # Acercado al centro para saque

		# Ajuste dinámico de posiciones iniciales según el modo de juego
		if modo_juego == "3v3":
			match rol_jugador:
				"DEF": x_pos = 600
				"DEL": x_pos = 950
		elif modo_juego == "1v1":
			x_pos = 950

		if equipo == "visitante":
			if rol_jugador == "DEL":
				x_pos = limite_max_x - (limite_max_x / 2 - 150) # Alejado del centro
			else:
				x_pos = limite_max_x - x_pos


		var total_en_linea = max(1, count_rol[rol_jugador])
		var idx_en_linea   = current_rol[rol_jugador]
		var espacio_y      = 900.0 / float(total_en_linea)
		var y_pos          = 75.0 + (espacio_y / 2.0) + (idx_en_linea * espacio_y)
		current_rol[rol_jugador] += 1

		inst.global_position = Vector2(x_pos, y_pos)
		inst.equipo = equipo
		inst.rol    = rol_jugador

		var ruta_sprite = "res://SpriteSheets/" + nombre_jugador + ".png"
		if ResourceLoader.exists(ruta_sprite):
			inst.get_node("Sprite2D").texture  = load(ruta_sprite)
			inst.get_node("Sprite2D").modulate = Color(1, 1, 1)

		inst.aplicar_estadisticas(nombre_jugador, rol_jugador)
		inst.pelota = pelota

		if equipo == "local":
			inst.porteria_propia  = porteria_i
			inst.porteria_enemiga = porteria_d
			if not ya_hay_humano and (rol_jugador == "DEL" or rol_jugador == "MED" or modo_juego == "1v1"):
				inst.es_humano = true
				inst.id_jugador = 1
				ya_hay_humano  = true
		else:
			inst.porteria_propia  = porteria_d
			inst.porteria_enemiga = porteria_i
			inst.es_humano = false
			if es_multijugador and not ya_hay_humano and (rol_jugador == "DEL" or rol_jugador == "MED" or modo_juego == "1v1"):
				inst.es_humano = true
				inst.id_jugador = 2
				ya_hay_humano  = true

		add_child(inst)
		print("Spawneado ", nombre_jugador, " (", rol_jugador, ") - ", equipo)
