extends RefCounted

# All callers (movement, shots, previews and telegraphs) use these same world
# rectangles. The standard arena is Rect2(32, 88, 896, 416).
const EPSILON := 0.00001
# Vector2 uses float precision: an exact swept contact can round a few ten-
# thousandths inside a corner. Treat that as contact, not a fresh overlap.
const CONTACT_SLOP := 0.0001

static func obstacles(layout: int, expedition: String = "forge", route: String = "open") -> Array:
	if route != "reflector" and expedition != "archive":
		return []
	match posmod(layout, 3):
		0:
			return [Rect2(300, 238, 44, 116), Rect2(616, 238, 44, 116)]
		1:
			return [Rect2(380, 192, 200, 32), Rect2(380, 368, 200, 32)]
		_:
			return [Rect2(324, 224, 48, 144), Rect2(588, 224, 48, 144)]

static func _inside(point: Vector2, radius: float, block: Rect2) -> bool:
	var nearest := point.clamp(block.position, block.end)
	var strictly_inside := point.x > block.position.x and point.x < block.end.x and point.y > block.position.y and point.y < block.end.y
	var interior_radius := maxf(radius - CONTACT_SLOP, 0.0)
	return strictly_inside or point.distance_squared_to(nearest) < interior_radius * interior_radius

static func safe_position(point: Vector2, radius: float, arena: Rect2, blocks: Array) -> Vector2:
	radius = maxf(radius, 0.0)
	var low := arena.position + Vector2.ONE * radius
	var high := arena.end - Vector2.ONE * radius
	# Degenerate arenas collapse to their center rather than returning NaNs.
	low = low.min(arena.get_center())
	high = high.max(arena.get_center())
	var result := point.clamp(low, high)
	for iteration in range(16):
		var changed := false
		for block: Rect2 in blocks:
			if not _inside(result, radius, block):
				continue
			var nearest := result.clamp(block.position, block.end)
			var offset := result - nearest
			if offset.length_squared() > EPSILON * EPSILON:
				result = nearest + offset.normalized() * (radius + EPSILON)
			else:
				# Stable left/right/top/bottom tie order makes center projection replayable.
				var candidates := [Vector2(block.position.x - radius - EPSILON, result.y), Vector2(block.end.x + radius + EPSILON, result.y), Vector2(result.x, block.position.y - radius - EPSILON), Vector2(result.x, block.end.y + radius + EPSILON)]
				var best: Vector2 = candidates[0]
				for candidate: Vector2 in candidates:
					if result.distance_squared_to(candidate) < result.distance_squared_to(best):
						best = candidate
				result = best
			result = result.clamp(low, high)
			changed = true
		if not changed:
			break
	return result

static func _candidate(best: Dictionary, fraction: float, normal: Vector2, movement: Vector2) -> void:
	if fraction < -EPSILON or fraction > 1.0 + EPSILON or movement.dot(normal) >= -EPSILON:
		return
	fraction = clampf(fraction, 0.0, 1.0)
	if not best.hit or fraction < best.fraction - EPSILON:
		best.hit = true
		best.fraction = fraction
		best.normal = normal
	elif absf(fraction - best.fraction) <= EPSILON:
		best.normal = (best.normal + normal).normalized()

static func sweep(start: Vector2, end: Vector2, radius: float, arena: Rect2, blocks: Array) -> Dictionary:
	radius = maxf(radius, 0.0)
	var movement := end - start
	var projected := safe_position(start, radius, arena, blocks)
	if projected.distance_squared_to(start) > EPSILON * EPSILON:
		return {"hit": true, "fraction": 0.0, "normal": (projected - start).normalized(), "position": projected}
	var best := {"hit": false, "fraction": 1.0, "normal": Vector2.ZERO, "position": end}
	if movement.length_squared() <= EPSILON * EPSILON:
		return best
	var low := arena.position + Vector2.ONE * radius
	var high := arena.end - Vector2.ONE * radius
	for axis in range(2):
		if absf(movement[axis]) <= EPSILON:
			continue
		var normal := Vector2.ZERO
		normal[axis] = -1.0 if movement[axis] > 0.0 else 1.0
		var boundary: float = high[axis] if movement[axis] > 0.0 else low[axis]
		_candidate(best, (boundary - start[axis]) / movement[axis], normal, movement)
	for block: Rect2 in blocks:
		# Face tests retain the original rectangle's span. Corners below supply
		# the circular arcs of the Minkowski sum, avoiding square-corner snags.
		for axis in range(2):
			if absf(movement[axis]) <= EPSILON:
				continue
			var other := 1 - axis
			var normal := Vector2.ZERO
			normal[axis] = -1.0 if movement[axis] > 0.0 else 1.0
			var face: float = block.position[axis] - radius if movement[axis] > 0.0 else block.end[axis] + radius
			var fraction: float = (face - start[axis]) / movement[axis]
			var across: float = start[other] + movement[other] * fraction
			if across >= block.position[other] - EPSILON and across <= block.end[other] + EPSILON:
				_candidate(best, fraction, normal, movement)
		if radius <= EPSILON:
			continue
		for side_x in [-1, 1]:
			for side_y in [-1, 1]:
				var corner := Vector2(block.position.x if side_x < 0 else block.end.x, block.position.y if side_y < 0 else block.end.y)
				var relative := start - corner
				# Keep quadratic arithmetic in GDScript float precision.
				# Vector2 dot/length_squared round to engine vector precision
				# and lose small corner radii on long incoming segments.
				var a: float = movement.x * movement.x + movement.y * movement.y
				var b: float = 2.0 * (relative.x * movement.x + relative.y * movement.y)
				var c: float = relative.x * relative.x + relative.y * relative.y - radius * radius
				var discriminant := b * b - 4.0 * a * c
				if discriminant < 0.0:
					continue
				var fraction := (-b - sqrt(discriminant)) / (2.0 * a)
				var offset := start + movement * fraction - corner
				if offset.x * side_x >= -EPSILON and offset.y * side_y >= -EPSILON:
					_candidate(best, fraction, offset.normalized(), movement)
	best.position = start + movement * best.fraction
	return best

static func move_circle(start: Vector2, displacement: Vector2, radius: float, arena: Rect2, blocks: Array) -> Vector2:
	var position := safe_position(start, radius, arena, blocks)
	var remaining := displacement
	for iteration in range(6):
		var contact := sweep(position, position + remaining, radius, arena, blocks)
		position = contact.position
		if not contact.hit:
			break
		remaining *= 1.0 - contact.fraction
		var inward: float = remaining.dot(contact.normal)
		if inward < 0.0:
			remaining -= contact.normal * inward
		if remaining.length_squared() <= EPSILON * EPSILON:
			break
	return safe_position(position, radius, arena, blocks)

# Visible radial footprint uses the same radius-zero rays as damage line of sight.
# Uniform rays approximate the circular edge; corner and either-side rays preserve
# the sharp shadow boundaries that uniform sampling alone would cut across.
# Empty terrain retains the original full-circle/arc points, even at arena edges.
static func radial_boundary(origin: Vector2, radius: float, arena: Rect2, blocks: Array, segments: int = 32, start_angle: float = 0.0, arc: float = TAU) -> PackedVector2Array:
	var boundary := PackedVector2Array()
	if radius <= 0.0 or arc <= 0.0:
		return boundary
	segments = clampi(segments, 3, 128)
	arc = minf(arc, TAU)
	var closed := is_equal_approx(arc, TAU)
	var angles: Array[float] = []
	for i in range(segments + 1):
		angles.append(arc * i / segments)
	if not blocks.is_empty():
		if sweep(origin, origin, 0.0, arena, blocks).hit:
			return boundary
		for block: Rect2 in blocks + [arena]:
			var transition_points: Array[Vector2] = [block.position, Vector2(block.end.x, block.position.y), block.end, Vector2(block.position.x, block.end.y)]
			# A face can enter the circle between corners that lie outside its radius.
			# Include those intersections to avoid chopping off visible circular arcs.
			for axis in 2:
				var other := 1 - axis
				for face: float in [block.position[axis], block.end[axis]]:
					var offset := face - origin[axis]
					if absf(offset) > radius:
						continue
					var side := sqrt(maxf(radius * radius - offset * offset, 0.0))
					for sign_value: float in [-1.0, 1.0]:
						var point := origin
						point[axis] = face
						point[other] += sign_value * side
						if point[other] >= block.position[other] and point[other] <= block.end[other]:
							transition_points.append(point)
			for corner: Vector2 in transition_points:
				var angle := fposmod((corner - origin).angle() - start_angle, TAU)
				for offset in [-0.00001, 0.0, 0.00001]:
					var ray_angle: float = angle + offset
					if ray_angle >= 0.0 and ray_angle <= arc:
						angles.append(ray_angle)
	angles.sort()
	for angle: float in angles:
		var endpoint := origin + Vector2.from_angle(start_angle + angle) * radius
		if not blocks.is_empty():
			endpoint = sweep(origin, endpoint, 0.0, arena, blocks).position
		if boundary.is_empty() or boundary[-1].distance_squared_to(endpoint) > 0.0000000001:
			boundary.append(endpoint)
	if closed and boundary.size() > 1:
		if boundary[-1].distance_squared_to(boundary[0]) < 0.00000001:
			boundary[-1] = boundary[0]
		else:
			boundary.append(boundary[0])
	return boundary
