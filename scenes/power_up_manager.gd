# power_up_manager.gd - Updated with better debugging
extends Node2D

# Power-up scene reference - assign this in the Inspector
@export var power_up_scene: PackedScene
@export var spawn_points: Array[Node2D] = []
@export var auto_spawn: bool = true
@export var min_spawn_time: float = 15.0
@export var max_spawn_time: float = 30.0

var rng = RandomNumberGenerator.new()
var timer: Timer

func _ready():
	print("DEBUG: PowerUpManager initializing")
	
	# Verify power_up_scene is set
	if power_up_scene == null:
		push_error("PowerUpManager: power_up_scene is not assigned!")
		print("ERROR: power_up_scene is not assigned to PowerUpManager!")
		return
	
	if auto_spawn:
		# Set up timer for automatic spawning
		timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.timeout.connect(Callable(self, "_on_spawn_timer_timeout"))
		
		# Start initial timer
		set_random_timer()
		print("DEBUG: Auto-spawn enabled with timer: ", timer.wait_time)
	
	# Optional: spawn one power-up immediately for testing
	if Engine.is_editor_hint() == false:  # Don't spawn during editing
		spawn_at_random_location()
		print("DEBUG: Initial test power-up spawned")

func _on_spawn_timer_timeout():
	print("DEBUG: Spawn timer triggered")
	spawn_random_power_up()
	set_random_timer()

func set_random_timer():
	var wait_time = rng.randf_range(min_spawn_time, max_spawn_time)
	timer.wait_time = wait_time
	timer.start()
	print("DEBUG: Next spawn in ", wait_time, " seconds")

func spawn_random_power_up():
	# Choose a random type
	var power_up_types = ["SPEED", "ATTACK", "SHIELD"]
	var type_index = rng.randi_range(0, power_up_types.size() - 1)
	
	# Choose a random spawn point
	var spawn_location
	if spawn_points.size() > 0:
		var spawn_index = rng.randi_range(0, spawn_points.size() - 1)
		spawn_location = spawn_points[spawn_index].global_position
		print("DEBUG: Using spawn point: ", spawn_index)
	else:
		# If no spawn points defined, use a random location in the visible area
		var viewport_rect = get_viewport_rect().size
		var x = rng.randf_range(50, viewport_rect.x - 50)
		var y = rng.randf_range(50, viewport_rect.y - 50)
		spawn_location = Vector2(x, y)
		print("DEBUG: Using random location: ", spawn_location)
	
	# Create and spawn the power-up
	spawn_power_up(type_index, spawn_location)

func spawn_power_up(type_index: int, location: Vector2):
	if power_up_scene:
		var power_up = power_up_scene.instantiate()
		power_up.power_up_type = type_index
		power_up.position = location
		add_child(power_up)
		print("DEBUG: Spawned power-up of type ", type_index, " at location ", location)
	else:
		print("ERROR: Power-up scene not assigned in PowerUpManager")

# Call this from gameplay script to manually spawn a power-up
func manual_spawn_power_up(type_index: int, location: Vector2):
	spawn_power_up(type_index, location)
	print("DEBUG: Manually spawned power-up of type ", type_index)

# Call this to spawn a power-up at a random location
func spawn_at_random_location(type_index: int = -1):
	# If type_index is -1, choose random type
	if type_index == -1:
		type_index = rng.randi_range(0, 2)  # 0=Speed, 1=Attack, 2=Shield
	
	# Choose a random location
	var viewport_rect = get_viewport_rect().size
	var x = rng.randf_range(50, viewport_rect.x - 50)
	var y = rng.randf_range(50, viewport_rect.y - 50)
	var location = Vector2(x, y)
	
	spawn_power_up(type_index, location)
	print("DEBUG: Spawned random power-up at ", location)
