extends SceneTree

const Geometry = preload("res://scripts/arena_geometry.gd")
const ARENA := Rect2(32, 88, 896, 416)
const TEST_ARENA := Rect2(0, 0, 1000, 1000)
const BLOCKS := [Rect2(400, 400, 100, 100)]
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func near(actual: Vector2, expected: Vector2, message: String) -> void:
	check(actual.distance_to(expected) < 0.002, "%s: got %s, expected %s" % [message, actual, expected])

func check_sweeps() -> void:
	var hit: Dictionary = Geometry.sweep(Vector2(100, 450), Vector2(900, 450), 10, TEST_ARENA, BLOCKS)
	check(hit.hit and is_equal_approx(hit.fraction, 0.3625), "Fast shot hits first obstacle face without tunneling")
	near(hit.position, Vector2(390, 450), "Left face contact position")
	near(hit.normal, Vector2.LEFT, "Left face reflects toward free space")
	for data in [[Vector2(700, 450), Vector2(100, 450), Vector2(510, 450), Vector2.RIGHT], [Vector2(450, 100), Vector2(450, 900), Vector2(450, 390), Vector2.UP], [Vector2(450, 700), Vector2(450, 100), Vector2(450, 510), Vector2.DOWN]]:
		hit = Geometry.sweep(data[0], data[1], 10, TEST_ARENA, BLOCKS)
		check(hit.hit, "Every obstacle face is swept")
		near(hit.position, data[2], "Face contact")
		near(hit.normal, data[3], "Face outward normal")
	for data in [[Vector2(50, 50), Vector2(-1000, 50), Vector2(10, 50), Vector2.RIGHT], [Vector2(950, 50), Vector2(2000, 50), Vector2(990, 50), Vector2.LEFT], [Vector2(50, 50), Vector2(50, -1000), Vector2(50, 10), Vector2.DOWN], [Vector2(50, 950), Vector2(50, 2000), Vector2(50, 990), Vector2.UP]]:
		hit = Geometry.sweep(data[0], data[1], 10, TEST_ARENA, [])
		check(hit.hit, "Every arena boundary is swept")
		near(hit.position, data[2], "Wall contact")
		near(hit.normal, data[3], "Wall inward normal")
	hit = Geometry.sweep(Vector2(300, 300), Vector2(500, 500), 10, TEST_ARENA, BLOCKS)
	near(hit.position, Vector2(400, 400) - Vector2.ONE * sqrt(50.0), "Rounded corner uses circle contact")
	near(hit.normal, -Vector2.ONE.normalized(), "Corner reflects about radial normal")
	hit = Geometry.sweep(Vector2(385, 391), Vector2(394, 391), 10, TEST_ARENA, BLOCKS)
	check(not hit.hit, "Circle clears square expansion corner without a phantom collision")
	hit = Geometry.sweep(Vector2(50, 50), Vector2(-50, -50), 10, TEST_ARENA, [])
	near(hit.normal, Vector2.ONE.normalized(), "Simultaneous arena corner combines movement normals")
	hit = Geometry.sweep(Vector2(828, 454), Vector2(1028, 554), 5, ARENA.grow(5), [])
	near(hit.position, Vector2(928, 504), "Unequal-direction projectile reaches simultaneous outer corner")
	near(Geometry.reflect(Vector2(2, 1).normalized(), hit), Vector2(-2, -1).normalized(), "Outer corner reflects both independent axes without swapping components")
	hit = Geometry.sweep(Vector2(300, 300), Vector2(500, 500), 10, TEST_ARENA, BLOCKS)
	near(Geometry.reflect(Vector2.ONE.normalized(), hit), -Vector2.ONE.normalized(), "Rounded pillar corner retains radial reflection")
	for data in [[Vector2(390, 450), Vector2(100, 450), BLOCKS], [Vector2(10, 450), Vector2(100, 450), []], [Vector2(450, 390), Vector2(600, 390), BLOCKS]]:
		hit = Geometry.sweep(data[0], data[1], 10, TEST_ARENA, data[2])
		check(not hit.hit, "Contact moving away or tangent does not bounce again")
	hit = Geometry.sweep(Vector2(390, 450), Vector2(400, 450), 10, TEST_ARENA, BLOCKS)
	check(hit.hit and hit.fraction == 0.0, "Contact moving inward collides immediately")
	hit = Geometry.sweep(Vector2(450, 450), Vector2(450, 450), 10, TEST_ARENA, BLOCKS)
	check(hit.hit and hit.fraction == 0.0, "Initial overlap reports immediate correction even without movement")
	near(hit.position, Vector2(390, 450), "Initial overlap deterministic nearest exit")
	hit = Geometry.sweep(Vector2(100, 100), Vector2(100, 100), 10, TEST_ARENA, BLOCKS)
	check(not hit.hit and hit.normal == Vector2.ZERO, "Zero movement in free space has no hit")
	near(hit.position, Vector2(100, 100), "Zero movement preserves position")
	hit = Geometry.sweep(Vector2(400, 450), Vector2(300, 450), 0, TEST_ARENA, BLOCKS)
	check(not hit.hit, "Point ray on rectangle face can move away")

func check_corner_departures() -> void:
	for radius in [1.0, 5.0, 8.0, 14.0, 28.0]:
		for step in range(1, 90):
			var angle := deg_to_rad(float(step))
			var normal := Vector2(-cos(angle), -sin(angle))
			var corner := Vector2(400, 400)
			var hit: Dictionary = Geometry.sweep(corner + normal * (radius + 100), corner + normal * (radius - 0.5), radius, TEST_ARENA, BLOCKS)
			check(hit.hit, "Corner approach hits rounded surface")
			var away: Dictionary = Geometry.sweep(hit.position, hit.position + normal * 30, radius, TEST_ARENA, BLOCKS)
			check(not away.hit, "Rounded contact can depart without a numerical double bounce")

func check_movement() -> void:
	near(Geometry.move_circle(Vector2(100, 450), Vector2(800, 0), 10, TEST_ARENA, BLOCKS), Vector2(390, 450), "Fast body cannot tunnel")
	near(Geometry.move_circle(Vector2(300, 420), Vector2(200, 40), 10, TEST_ARENA, BLOCKS), Vector2(390, 460), "Body slides along obstacle face")
	near(Geometry.move_circle(Vector2(950, 800), Vector2(200, 100), 10, TEST_ARENA, []), Vector2(990, 900), "Body slides along arena edge")
	near(Geometry.safe_position(Vector2(-10, 1200), 10, TEST_ARENA, []), Vector2(10, 990), "Spawn projection respects circle bounds")
	near(Geometry.safe_position(Vector2(395, 395), 10, TEST_ARENA, BLOCKS), Vector2(400, 400) - Vector2.ONE * sqrt(50.0), "Spawn projection uses rounded corner")
	near(Geometry.safe_position(Vector2(450, 450), 10, TEST_ARENA, BLOCKS), Vector2(390, 450), "Interior projection tie is stable")

func check_layouts() -> void:
	check(Geometry.obstacles(0).is_empty(), "Default route remains open")
	for expedition in ["forge", "archive"]:
		for layout in range(3):
			var blocks: Array = Geometry.obstacles(layout, expedition, "reflector")
			check(blocks.size() >= 1 and blocks.size() <= 2, "Authored layout has bounded terrain count")
			check(blocks == Geometry.obstacles(layout, expedition, "reflector"), "Layout generation is deterministic")
			for block: Rect2 in blocks:
				check(ARENA.encloses(block), "Reflectors fit inside arena")
			near(Geometry.safe_position(ARENA.get_center(), 28, ARENA, blocks), ARENA.get_center(), "Player and boss center stays clear")
			# Test the entire spawn ellipse, including future wave counts/rotations.
			for step in range(360):
				var angle := TAU * step / 360.0
				var spawn := ARENA.get_center() + Vector2(cos(angle) * 340, sin(angle) * 155)
				near(Geometry.safe_position(spawn, 28, ARENA, blocks), spawn, "Standard spawn edge stays clear")
			blocks.clear()
			check(Geometry.obstacles(layout, expedition, "reflector").size() == 2, "Layouts do not share mutable arrays")

func is_clear(point: Vector2, radius: float, arena: Rect2, blocks: Array) -> bool:
	if point.x < arena.position.x + radius - 0.002 or point.x > arena.end.x - radius + 0.002 or point.y < arena.position.y + radius - 0.002 or point.y > arena.end.y - radius + 0.002:
		return false
	for block: Rect2 in blocks:
		if point.distance_to(point.clamp(block.position, block.end)) < radius - 0.002:
			return false
	return true

func check_seeded_paths() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729
	for trial in range(500):
		var radius := rng.randf_range(5, 28)
		var start := Geometry.safe_position(Vector2(rng.randf_range(0, 1000), rng.randf_range(0, 1000)), radius, TEST_ARENA, BLOCKS)
		var end := Vector2(rng.randf_range(-1000, 2000), rng.randf_range(-1000, 2000))
		var hit: Dictionary = Geometry.sweep(start, end, radius, TEST_ARENA, BLOCKS)
		check(hit == Geometry.sweep(start, end, radius, TEST_ARENA, BLOCKS), "Seeded sweep is deterministic")
		for step in range(33):
			var sample := start.lerp(end, hit.fraction * step / 32.0)
			check(is_clear(sample, radius, TEST_ARENA, BLOCKS), "Entire precontact path stays outside solids and bounds")
		if hit.hit:
			check(hit.normal.dot(end - start) < 0.0 and is_equal_approx(hit.normal.length(), 1.0), "Impact normal is unit length and opposes motion")
			var point: Vector2 = hit.position
			var surface_distance := minf(minf(point.x - radius, 1000 - radius - point.x), minf(point.y - radius, 1000 - radius - point.y))
			for block: Rect2 in BLOCKS:
				surface_distance = minf(surface_distance, point.distance_to(point.clamp(block.position, block.end)) - radius)
			check(absf(surface_distance) < 0.002, "Reported impact touches a real surface")
		var moved := Geometry.move_circle(start, end - start, radius, TEST_ARENA, BLOCKS)
		check(is_clear(moved, radius, TEST_ARENA, BLOCKS), "Swept sliding ends in free space")

func check_radial_footprints() -> void:
	var blocks := Geometry.obstacles(1, "forge", "reflector")
	var origin := Vector2(480, 180)
	var boundary := Geometry.radial_boundary(origin, 72, ARENA, blocks)
	check(boundary == Geometry.radial_boundary(origin, 72, ARENA, blocks), "Radial cover boundary is deterministic")
	check(boundary.size() > 33 and boundary[0] == boundary[-1], "Cover footprint closes and adds obstacle-corner rays")
	check(not Geometry2D.is_point_in_polygon(Vector2(480, 237), boundary), "Original repro: shielded target is outside visible blast footprint")
	check(Geometry2D.is_point_in_polygon(Vector2(530, 150), boundary), "Uncovered target remains inside visible blast footprint")
	for point: Vector2 in boundary:
		check(point.distance_to(origin) <= 72.001, "Clipped radial vertex never extends beyond its damage radius")
		var hit := Geometry.sweep(origin, point, 0, ARENA, blocks)
		check(not hit.hit or hit.position.distance_to(point) < 0.002, "Clipped radial vertex is visible up to its exact cover endpoint")
	# Corners lie within range here: their angular shadows need exact transition rays.
	origin = Vector2(350, 180)
	boundary = Geometry.radial_boundary(origin, 180, ARENA, blocks)
	check(not Geometry2D.triangulate_polygon(boundary.slice(0, boundary.size() - 1)).is_empty(), "Corner-clipped radial fill triangulates")
	for x in range(200, 530, 5):
		for y in range(100, 350, 5):
			var point := Vector2(x, y)
			var distance := point.distance_to(origin)
			if distance > 178:
				continue # Polygonal circle approximation is intentionally inscribed.
			var contact := Geometry.sweep(origin, point, 0, ARENA, blocks)
			if contact.hit and contact.position.distance_to(point) < 0.01:
				continue # Exact wall endpoints are the silhouette, not shielded interior.
			var on_shadow_edge := false
			for block: Rect2 in blocks:
				for corner: Vector2 in [block.position, Vector2(block.end.x, block.position.y), block.end, Vector2(block.position.x, block.end.y)]:
					if contact.hit and contact.position.distance_to(corner) < 0.002:
						on_shadow_edge = true
			if on_shadow_edge:
				continue # Closed polygons include their silhouette's tangent boundary.
			check(Geometry2D.is_point_in_polygon(point, boundary) == not contact.hit, "Corner footprint agrees with damage LOS at %s (hit %s, point %s)" % [point, contact.hit, contact.position])
	var circle := Geometry.radial_boundary(Vector2(480, 300), 72, ARENA, [])
	check(circle.size() == 33 and circle[0] == circle[-1], "No-cover boundary preserves the original 32-segment closed circle")
	for i in 33:
		near(circle[i], Vector2(480, 300) + Vector2(cos(TAU * i / 32.0), sin(TAU * i / 32.0)) * 72, "No-cover circle point unchanged")
	check(Geometry.radial_boundary(Vector2(480, 200), 72, ARENA, blocks).is_empty(), "Origin inside cover has no falsely visible radial area")

func check_lane_footprints() -> void:
	var blocks := [Rect2(300, 238, 44, 116)]
	var origin := Vector2(250, 230)
	var target := Vector2(928, 230)
	var shielded := Vector2(365, 245)
	var boundary := Geometry.lane_boundary(origin, target, 16, ARENA, blocks)
	check(boundary == Geometry.lane_boundary(origin, target, 16, ARENA, blocks), "Lane footprint is deterministic")
	check(boundary[0] == boundary[-1] and not Geometry2D.triangulate_polygon(boundary.slice(0, boundary.size() - 1)).is_empty(), "Clipped lane closes and triangulates")
	check(not Geometry2D.is_point_in_polygon(shielded, boundary), "Grazing lane excludes protected floor inside the original capsule")
	check(Geometry2D.is_point_in_polygon(Vector2(365, 225), boundary), "Grazing lane retains uncovered floor beyond the pillar")
	check(Geometry2D.is_point_in_polygon(shielded, Geometry.lane_boundary(origin, target, 16, ARENA, [])), "Open-floor lane preserves its full capsule")
	for x in range(260, 920, 5):
		for y in range(216, 245, 2):
			var point := Vector2(x, y)
			var contact := Geometry.sweep(origin, point, 0, ARENA, blocks)
			# Exact obstacle/silhouette contacts form the polygon's visible boundary.
			if contact.hit and (point.distance_to(contact.position) < 0.002 or contact.position.distance_to(blocks[0].position) < 0.002):
				continue
			check(Geometry2D.is_point_in_polygon(point, boundary) == not contact.hit, "Lane warning agrees with cover LOS at %s" % point)
	check(Geometry.lane_boundary(Vector2(320, 280), target, 16, ARENA, blocks).is_empty(), "Lane origin inside cover has no visible footprint")

func _initialize() -> void:
	check_sweeps()
	check_corner_departures()
	check_movement()
	check_layouts()
	check_seeded_paths()
	check_radial_footprints()
	check_lane_footprints()
	print("Arena geometry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
