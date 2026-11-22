extends Node
## Textos en español e inglés. Uso: I18n.t("clave")

const T := {
	"explore": ["EXPLORAR", "EXPLORE"],
	"multiplayer": ["MULTIJUGADOR", "MULTIPLAYER"],
	"settings": ["AJUSTES", "SETTINGS"],
	"credits": ["CRÉDITOS", "CREDITS"],
	"back": ["VOLVER", "BACK"],
	"soon": ["PRÓXIMAMENTE · v0.3", "COMING SOON · v0.3"],
	"quality": ["Calidad gráfica", "Graphics quality"],
	"q_low": ["Bajo", "Low"], "q_medium": ["Medio", "Medium"], "q_high": ["Alto", "High"], "q_ultra": ["Ultra", "Ultra"],
	"fps_limit": ["Límite de FPS", "FPS limit"],
	"render_scale": ["Resolución 3D", "3D resolution"],
	"language": ["Idioma", "Language"],
	"show_fps": ["Mostrar FPS", "Show FPS"],
	"sensitivity": ["Sensibilidad de cámara", "Camera sensitivity"],
	"music": ["Música", "Music"],
	"apply_restart": ["Algunos cambios se aplican al volver a entrar al mundo.", "Some changes apply when re-entering the world."],
	"loading": ["CARGANDO MUNDO", "LOADING WORLD"],
	"ready": ["SISTEMA LISTO", "SYSTEM READY"],
	"offline": ["Sin conexión · Todo el mundo vive en tu dispositivo", "Offline · The whole world lives on your device"],
	"map": ["MAPA", "MAP"],
	"set_route": ["Marcar ruta", "Set route"],
	"clear_route": ["Quitar ruta", "Clear route"],
	"center": ["Centrar", "Center"],
	"close": ["Cerrar", "Close"],
	"places": ["LUGARES", "PLACES"],
	"tap_to_mark": ["Toca el mapa para marcar un destino", "Tap the map to set a destination"],
	"arrived": ["Has llegado a tu destino", "You have arrived"],
	"destination": ["Destino", "Destination"],
	"custom_point": ["Punto marcado", "Marked point"],
	"resume": ["CONTINUAR", "RESUME"],
	"to_title": ["MENÚ PRINCIPAL", "MAIN MENU"],
	"paused": ["PAUSA", "PAUSED"],
	"jump": ["Saltar", "Jump"], "run": ["Correr", "Run"], "attack": ["Atacar", "Attack"], "camera": ["Cámara", "Camera"],
	"welcome": ["Bienvenido a la Isla de Aurelia", "Welcome to the Isle of Aurelia"],
	"hint_pc": ["WASD mover · Shift correr · Espacio saltar · Clic atacar · V cámara · M mapa", "WASD move · Shift run · Space jump · Click attack · V camera · M map"],
	"hint_touch": ["Joystick para moverte · Desliza a la derecha para mirar · Abre el MAPA y marca una ruta", "Joystick to move · Swipe right side to look · Open the MAP and set a route"],
	# lugares
	"city": ["Ciudad Aurelia", "Aurelia City"],
	"port": ["Puerto Marea", "Tide Harbor"],
	"forest": ["Bosque Lumen", "Lumen Forest"],
	"mountain": ["Pico Escarcha", "Frost Peak"],
	"lake": ["Lago Espejo", "Mirror Lake"],
	"ruins": ["Ruinas de Vael", "Ruins of Vael"],
	"village": ["Aldea Brisa", "Breeze Village"],
	"wild": ["Tierras salvajes", "Wildlands"],
	"sea": ["Mar abierto", "Open sea"],
	"credits_text": [
		"EXPRESSING FANTASY · REMASTERED\n\nCreado por\nJhoniber De la Cruz\nJustin Manuel Nolasco «Mano»\n\nMotor: Godot Engine 4.7 (MIT)\nFuentes: Poppins, Inter (OFL) · DejaVu\nMúsica y gráficos: originales, generados para este juego\n\nGracias por jugar.",
		"EXPRESSING FANTASY · REMASTERED\n\nCreated by\nJhoniber De la Cruz\nJustin Manuel Nolasco «Mano»\n\nEngine: Godot Engine 4.7 (MIT)\nFonts: Poppins, Inter (OFL) · DejaVu\nMusic and graphics: original, made for this game\n\nThanks for playing."],
}

func t(key: String) -> String:
	if not T.has(key):
		return key
	var i := 0 if Settings.lang == "es" else 1
	return T[key][i]
