class_name MapIcons
extends RefCounted
## Íconos dibujados a mano para el mapa y el minimapa: cada lugar se reconoce a simple vista.

const ROUTE_COLOR := Color(1.0, 0.25, 0.85)

static func badge(ci: CanvasItem, kind: String, p: Vector2, r: float, col: Color, alpha := 1.0) -> void:
	ci.draw_circle(p, r + 2.0, Color(0, 0, 0, 0.45 * alpha))
	ci.draw_circle(p, r, Color(0.03, 0.05, 0.11, 0.92 * alpha))
	ci.draw_arc(p, r, 0.0, TAU, 28, Color(col, alpha), maxf(1.5, r * 0.14), true)
	glyph(ci, kind, p, r * 0.62, Color(col.lightened(0.25), alpha))

static func glyph(ci: CanvasItem, kind: String, p: Vector2, s: float, c: Color) -> void:
	match kind:
		"city":
			# silueta de rascacielos
			ci.draw_rect(Rect2(p + Vector2(-0.95, -0.2) * s, Vector2(0.5, 0.95) * s), c)
			ci.draw_rect(Rect2(p + Vector2(-0.35, -0.95) * s, Vector2(0.55, 1.7) * s), c)
			ci.draw_rect(Rect2(p + Vector2(0.3, -0.5) * s, Vector2(0.6, 1.25) * s), c)
			ci.draw_line(p + Vector2(-0.07, -0.95) * s, p + Vector2(-0.07, -1.25) * s, c, maxf(1.0, s * 0.12))
		"port":
			# ancla
			var wdt := maxf(1.5, s * 0.2)
			ci.draw_line(p + Vector2(0, -0.85) * s, p + Vector2(0, 0.8) * s, c, wdt)
			ci.draw_line(p + Vector2(-0.45, -0.45) * s, p + Vector2(0.45, -0.45) * s, c, wdt)
			ci.draw_arc(p + Vector2(0, 0.1) * s, 0.75 * s, 0.25, PI - 0.25, 12, c, wdt)
			ci.draw_circle(p + Vector2(0, -0.95) * s, 0.2 * s, c)
		"forest":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -1.0) * s, p + Vector2(0.75, 0.35) * s, p + Vector2(-0.75, 0.35) * s]), c)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -0.45) * s, p + Vector2(0.9, 0.7) * s, p + Vector2(-0.9, 0.7) * s]), c)
			ci.draw_rect(Rect2(p + Vector2(-0.14, 0.65) * s, Vector2(0.28, 0.4) * s), c)
		"mountain":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-1.0, 0.75) * s, p + Vector2(-0.15, -0.85) * s, p + Vector2(1.0, 0.75) * s]), c)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.38, -0.4) * s, p + Vector2(-0.15, -0.85) * s, p + Vector2(0.12, -0.4) * s]), Color(1, 1, 1, c.a))
		"lake":
			var wd := maxf(1.5, s * 0.18)
			for k in 3:
				var pts := PackedVector2Array()
				var yy := (-0.5 + k * 0.5) * s
				for i in 9:
					var x := (-0.9 + i * 0.225) * s
					pts.append(p + Vector2(x, yy + sin(i * 1.4) * 0.14 * s))
				ci.draw_polyline(pts, c, wd, true)
		"ruins":
			ci.draw_rect(Rect2(p + Vector2(-0.85, -0.55) * s, Vector2(1.7, 0.3) * s), c)
			ci.draw_rect(Rect2(p + Vector2(-0.7, -0.25) * s, Vector2(0.32, 1.1) * s), c)
			ci.draw_rect(Rect2(p + Vector2(0.38, -0.25) * s, Vector2(0.32, 1.1) * s), c)
			ci.draw_rect(Rect2(p + Vector2(-0.95, 0.78) * s, Vector2(1.9, 0.2) * s), c)
		"village":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -0.95) * s, p + Vector2(0.95, -0.1) * s, p + Vector2(-0.95, -0.1) * s]), c)
			ci.draw_rect(Rect2(p + Vector2(-0.7, -0.15) * s, Vector2(1.4, 0.95) * s), c)
			ci.draw_rect(Rect2(p + Vector2(-0.18, 0.25) * s, Vector2(0.36, 0.55) * s), Color(0.03, 0.05, 0.11, c.a))
		_:
			ci.draw_circle(p, s * 0.5, c)

static func pin(ci: CanvasItem, p: Vector2, s: float) -> void:
	var c := ROUTE_COLOR
	ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-0.55, -1.2) * s, p + Vector2(0.55, -1.2) * s]), Color(0, 0, 0, 0.5))
	ci.draw_circle(p + Vector2(0, -1.45) * s, 0.72 * s, c)
	ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-0.5, -1.15) * s, p + Vector2(0.5, -1.15) * s]), c)
	ci.draw_circle(p + Vector2(0, -1.45) * s, 0.3 * s, Color.WHITE)

static func arrow(ci: CanvasItem, p: Vector2, dir_angle: float, s: float, c := Color.WHITE) -> void:
	var f := Vector2(sin(dir_angle), -cos(dir_angle))
	var r := Vector2(-f.y, f.x)
	var pts := PackedVector2Array([p + f * s, p - f * s * 0.7 + r * s * 0.75, p - f * s * 0.3, p - f * s * 0.7 - r * s * 0.75])
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
	var pts2 := PackedVector2Array()
	for q in pts:
		pts2.append(p + (q - p) * 0.82)
	ci.draw_colored_polygon(pts2, c)
