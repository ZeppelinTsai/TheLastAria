class_name WalkableAreaSpawner
extends RefCounted

static func spawn_walkable_area(root: Node, map_data: Dictionary) -> void:
	if not root:
		push_warning("WalkableAreaSpawner needs a root node.")
		return

	var polygon_data = map_data.get("walkable_polygons", [])
	if typeof(polygon_data) != TYPE_ARRAY:
		push_warning("walkable_polygons must be an Array.")
		return

	var walkable_area := _get_or_create_walkable_area(root)
	if _has_non_empty_collision_polygon(walkable_area):
		print("Using existing WalkableArea")
		_assign_player_walkable_area(root, walkable_area)
		return

	var created_count := 0
	for polygon in polygon_data:
		var points := _parse_polygon(polygon)
		if points.size() < 3:
			push_warning("Walkable polygon must contain at least 3 points.")
			continue

		var collision_polygon := CollisionPolygon2D.new()
		collision_polygon.name = "CollisionPolygon2D"
		collision_polygon.polygon = points
		walkable_area.add_child(collision_polygon)
		created_count += 1

	if created_count == 0:
		push_warning("WalkableAreaSpawner did not create any CollisionPolygon2D nodes.")

	_assign_player_walkable_area(root, walkable_area)

static func _get_or_create_walkable_area(root: Node) -> Area2D:
	var existing := root.get_node_or_null("WalkableArea")
	if existing and existing is Area2D:
		return existing

	var walkable_area := Area2D.new()
	walkable_area.name = "WalkableArea"
	root.add_child(walkable_area)
	return walkable_area

static func _has_non_empty_collision_polygon(walkable_area: Area2D) -> bool:
	for child in walkable_area.get_children():
		if child is CollisionPolygon2D and child.polygon.size() > 0:
			return true

	return false

static func _parse_polygon(polygon_data) -> PackedVector2Array:
	var points := PackedVector2Array()
	if typeof(polygon_data) != TYPE_ARRAY:
		push_warning("Walkable polygon must be an Array.")
		return points

	for point_data in polygon_data:
		if typeof(point_data) != TYPE_ARRAY or point_data.size() < 2:
			push_warning("Walkable polygon point must be [x, y].")
			continue

		points.append(Vector2(float(point_data[0]), float(point_data[1])))

	return points

static func _assign_player_walkable_area(root: Node, walkable_area: Area2D) -> void:
	var player := root.get_node_or_null("Player")
	if not player:
		return

	if not _has_property(player, "walkable_area"):
		return

	player.set("walkable_area", walkable_area)

static func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true

	return false
