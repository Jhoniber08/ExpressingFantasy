class_name RoadNet
extends RefCounted
## Red de caminos para calcular rutas (estilo GPS de GTA) con A*.

var astar := AStar3D.new()
var _next := 0
var polylines: Array = []   # Array de PackedVector3Array (para dibujar en el mapa)

func _find_near(p: Vector3, max_d: float) -> int:
	if astar.get_point_count() == 0:
		return -1
	var id := astar.get_closest_point(p)
	if id >= 0 and astar.get_point_position(id).distance_to(p) <= max_d:
		return id
	return -1

func _add(p: Vector3, merge_d := 5.0) -> int:
	var near := _find_near(p, merge_d)
	if near >= 0:
		return near
	return _new_point(p)

func _new_point(p: Vector3) -> int:
	var id := _next
	_next += 1
	astar.add_point(id, p)
	return id

## Agrega un camino. Los extremos se unen con nodos cercanos existentes.
func add_polyline(pts: PackedVector3Array, step := 10.0) -> void:
	if pts.size() < 2:
		return
	polylines.append(pts)
	var prev := -1
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		var is_end := i == 0 or i == pts.size() - 1
		if not is_end and acc < step:
			continue
		acc = 0.0
		var id := _add(pts[i], 6.0 if is_end else 2.0)
		if prev >= 0 and prev != id and not astar.are_points_connected(prev, id):
			astar.connect_points(prev, id)
		prev = id

## Une nodos cercanos (cruces) para que toda la red quede conectada
func finalize(link_d := 9.0) -> void:
	var ids := astar.get_point_ids()
	for i in ids.size():
		var a := ids[i]
		var pa := astar.get_point_position(a)
		for j in range(i + 1, ids.size()):
			var b := ids[j]
			var pb := astar.get_point_position(b)
			if absf(pa.x - pb.x) > link_d or absf(pa.z - pb.z) > link_d:
				continue
			if Vector2(pa.x, pa.z).distance_to(Vector2(pb.x, pb.z)) <= link_d and not astar.are_points_connected(a, b):
				astar.connect_points(a, b)

## Ruta desde el jugador hasta el destino, siguiendo los caminos cuando conviene.
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var direct := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	if astar.get_point_count() == 0 or direct < 90.0:
		out.append(from)
		out.append(to)
		return out
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	var path := astar.get_point_path(a, b)
	if path.is_empty():
		out.append(from)
		out.append(to)
		return out
	out.append(from)
	# saltar el primer nodo si ya vamos en esa dirección
	for i in path.size():
		out.append(path[i])
	out.append(to)
	return out
