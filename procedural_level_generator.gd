extends Node3D

@export_group("Cuadricula")
@export_range(5, 100, 1) var width: int = 12
@export_range(5, 100, 1) var height: int = 8
@export_range(1.0, 10.0, 0.5) var cell_size: float = 2.0

@export_group("Generacion")
@export_range(0.0, 0.45, 0.01) var wall_probability: float = 0.22
@export_range(0, 100, 1) var reward_count: int = 5
@export var seed_value: int = 12345

@export_group("Escenas")
@export var floor_scene: PackedScene
@export var wall_scene: PackedScene
@export var start_scene: PackedScene
@export var goal_scene: PackedScene
@export var reward_scene: PackedScene

@onready var generated_root: Node3D = $Generated
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var map: Array = []

func _ready() -> void:
	generate_level()

func generate_level() -> void:
	if not _validate_configuration():
		return
	_clear_generated()
	rng.seed = seed_value
	var start := Vector2i(1, 1)
	var goal := Vector2i(width - 2, height - 2)
	map.clear()

	for x in range(width):
		var column: Array[int] = []
		for y in range(height):
			var border := (x == 0 or y == 0 or x == width - 1 or y == height - 1)
			var cell := Vector2i(x, y)
			var protected_cell := (cell == start or cell == goal)
			var is_wall := (border or (not protected_cell and rng.randf() < wall_probability))
			column.append(1 if is_wall else 0)
		map.append(column)

	_carve_guaranteed_path(start, goal)
	_build_geometry()
	_spawn_scene(start_scene, _cell_to_world(start, 0.5), "Start")
	_spawn_scene(goal_scene, _cell_to_world(goal, 0.5), "Goal")
	
	var spawned_rewards: int = _spawn_rewards(start, goal)
	print("Semilla: %d | Recompensas: %d | Misión: Llega a la meta y recolecta %d recompensas." % [seed_value, spawned_rewards, spawned_rewards])

func _carve_guaranteed_path(start: Vector2i, goal: Vector2i) -> void:
	for x in range(start.x, goal.x + 1):
		map[x][start.y] = 0
	for y in range(start.y, goal.y + 1):
		map[goal.x][y] = 0

func _build_geometry() -> void:
	for x in range(width):
		for y in range(height):
			var cell := Vector2i(x, y)
			_spawn_scene(floor_scene, _cell_to_world(cell, 0.0), "Floor_%d_%d" % [x, y])
			if map[x][y] == 1:
				_spawn_scene(wall_scene, _cell_to_world(cell, 0.5), "Wall_%d_%d" % [x, y])

func _spawn_rewards(start: Vector2i, goal: Vector2i) -> int:
	var candidates: Array[Vector2i] = []
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			var cell := Vector2i(x, y)
			if map[x][y] == 0 and cell != start and cell != goal:
				candidates.append(cell)
	
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temp
		
	var amount: int = min(reward_count, candidates.size())
	for i in range(amount):
		_spawn_scene(reward_scene, _cell_to_world(candidates[i], 0.5), "Reward_%d" % i)
	return amount

func _cell_to_world(cell: Vector2i, y_position: float) -> Vector3:
	return Vector3(cell.x * cell_size, y_position, cell.y * cell_size)

func _spawn_scene(scene_resource: PackedScene, position_value: Vector3, node_name: String) -> void:
	var instance := scene_resource.instantiate() as Node3D
	if instance == null:
		push_error("La escena %s debe tener un Node3D como raíz." % node_name)
		return
	generated_root.add_child(instance)
	instance.position = position_value
	instance.name = node_name

func _clear_generated() -> void:
	for child in generated_root.get_children():
		child.queue_free()

func _validate_configuration() -> bool:
	if width < 5 or height < 5:
		push_error("El mapa debe tener al menos 5x5 celdas.")
		return false
	if floor_scene == null or wall_scene == null or start_scene == null or goal_scene == null:
		push_error("Faltan escenas obligatorias en el Inspector.")
		return false
	if reward_count > 0 and reward_scene == null:
		push_error("Reward Scene es obligatoria cuando reward_count > 0.")
		return false
	return true
