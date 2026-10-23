extends RefCounted
static func encounter(seed_value: int, index: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + index * 7919
    var roster: Array = []
    var kinds := ["pursuer", "archer", "swarm", "bulwark", "channeler"]
    if index >= 6:
        roster = ["boss"]
    else:
        for i in range(4 + index * 2):
            roster.append(kinds[(i + index) % mini(index + 2, 5)])
        # Guarantee each unlocked role, then vary the remaining composition.
        var unlocked := mini(index + 2, 5)
        for i in range(unlocked, roster.size()):
            roster[i] = kinds[rng.randi_range(0, unlocked - 1)]
        for i in range(roster.size() - 1, 0, -1):
            var pick := rng.randi_range(0, i)
            var saved = roster[i]
            roster[i] = roster[pick]
            roster[pick] = saved
    return {"layout": rng.randi_range(0, 2), "roster": roster, "seed": seed_value + index * 7919}

static func rewards(seed_value: int, index: int, owned: Array) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + index * 104729 + 17
    var pool: Array = []
    for id in ["fire", "pierce", "split", "bounce", "chain", "explode", "cooldown"]:
        if not owned.has(id):
            pool.append(id)
    var result: Array = []
    while not pool.is_empty() and result.size() < 3:
        result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
    return ["restore"] if result.is_empty() else result
