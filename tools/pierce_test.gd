extends SceneTree
# Does pierce actually pass THROUGH to the enemy behind?
#
# tools/dps_test.sh cannot answer this: it puts exactly one enemy on the field
# by design, so it proves "one shot lands once on one target" and nothing about
# what happens to the body behind. This fires one projectile down a line of
# five stationary enemies and counts where the damage landed.
#
# Waits frames before asserting because the projectile moves in _physics_process
# and a raycast needs the bodies' colliders registered with the physics server.

# load(), not preload(), and not until a frame has passed. A SceneTree script's
# _initialize() runs BEFORE the autoloads are attached, and enemy.gd references
# AudioManager at compile time -- so preloading here compiles the scene against
# a missing identifier and it instantiates with NO SCRIPT: a bare
# CharacterBody2D that silently ignores every property you set on it and records
# zero hits. That is a fixture reporting a clean failure, not a real one.
const COUNT := 5
const SPACING := 40.0
const FIRST_X := 120.0
const HEALTH := 1.0e9

var _frames := 0
var _world: Node2D = null
var _enemies: Array = []
var _fired := false

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_build()
		return false
	# Let the bodies register with the physics server before casting at them.
	if _frames == 5:
		_fire(3)
		_fired = true
		return false
	if not _fired or _frames < 45:
		return false
	_report()
	return true

func _build() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	for i in range(COUNT):
		var e = enemy_scene.instantiate()
		if e.get_script() == null:
			print("[PIERCE] FAIL: enemy instantiated with no script")
			quit(1)
			return
		e.global_position = Vector2(FIRST_X + SPACING * float(i), 0.0)
		# No setup(): difficulty scaling would move the health we are reading.
		# Physics off so nothing walks out of the line mid-flight.
		e.max_health = HEALTH
		e.health = HEALTH
		e.speed = 0.0
		_world.add_child(e)
		e.set_physics_process(false)
		_enemies.append(e)

func _fire(pierce: int) -> void:
	var p = load("res://scenes/projectile.tscn").instantiate()
	p.global_position = Vector2(0.0, 0.0)
	if p.has_method("setup"):
		p.setup(null, Vector2.RIGHT, 600.0, 10.0, 1000.0, 0.0, pierce, 1.0, 0.0, "normal")
	_world.add_child(p)

func _report() -> void:
	var hits: Array = []
	var damaged := 0
	var max_on_one := 0
	for e in _enemies:
		var n := 0
		if is_instance_valid(e):
			n = int(round((HEALTH - float(e.health)) / 10.0))
		hits.append(n)
		if n > 0:
			damaged += 1
		max_on_one = max(max_on_one, n)
	print("[PIERCE] hits per enemy along the line = ", hits)
	# pierce_count = 3 should mean four DIFFERENT bodies, once each.
	var ok_distinct := damaged == 4
	var ok_once := max_on_one <= 1
	print("[PIERCE] distinct enemies damaged=%d (want 4)  max hits on any one=%d (want 1)" % [damaged, max_on_one])
	print("[PIERCE] ", "PASS" if (ok_distinct and ok_once) else "FAIL")
	quit(0 if (ok_distinct and ok_once) else 1)
