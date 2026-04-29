extends Label

var goles_local = 0
var goles_visitante = 0

func gol_local():
	goles_local += 1
	text = str(goles_local) + " - " + str(goles_visitante)

func gol_visitante():
	goles_visitante += 1
	text = str(goles_local) + " - " + str(goles_visitante)
