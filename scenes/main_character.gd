extends CharacterBody2D

# Slingshot and momentum parameters
@export var max_launch_strength: float = 1000.0 # Maximum launch velocity
@export var min_drag_distance: float = 2.0     # Smaller minimum distance to register a drag
@export var drag_sensitivity: float = 4.0      # Multiplier for drag distance to launch power
@export var min_launch_power: float = 200.0    # Minimum launch power for any valid drag
@export var momentum_retention: float = 0.7    # How much momentum is retained between launches
@export var fluid_resistance: float = 0.96     # Slower deceleration (higher value)
@export var max_momentum_bonus: float = 1.5    # Maximum momentum multiplier
@export var wall_bounce: float = 0.6           # Wall bounce factor

# Visual parameters
@export var trail_enabled: bool = true         # Enable movement trail
@export var deform_effect: bool = true         # Enable deformation effect
@export var deform_strength: float = 0.25      # How much the cell deforms
@export var show_aim_line: bool = true         # Show aiming line when dragging
@export var aim_line_thickness: float = 3.0    # Thickness of aim line for better visibility

# Private variables
var drag_start: Vector2 = Vector2.ZERO
var dragging: bool = false
var momentum_multiplier: float = 1.0         # Accumulates with successive launches
var momentum_cooldown: float = 0.0           # Tracks time since last launch
var aim_line: Line2D
var trajectory_preview: Line2D
var power_bar: ColorRect
var power_bar_bg: ColorRect
var can_move: bool = true
var initial_scale: Vector2
var trail: Line2D

func _ready():
	# Store original scale for deformation
	initial_scale = scale
	
	# Add to player group
	add_to_group("player")
	
	# Create aim line
	setup_aim_line()
	
	# Create power bar
	setup_power_bar()
	
	# Create trail
	if trail_enabled:
		setup_trail()

func setup_aim_line():
	# Create line for aiming
	aim_line = Line2D.new()
	aim_line.width = aim_line_thickness
	aim_line.default_color = Color(1, 1, 1, 0.8)  # More visible
	aim_line.z_index = 10  # Make sure it's visible above everything
	aim_line.add_point(Vector2.ZERO)
	aim_line.add_point(Vector2.ZERO)
	add_child(aim_line)
	aim_line.visible = false
	
	# Create trajectory preview
	trajectory_preview = Line2D.new()
	trajectory_preview.width = 1.5
	trajectory_preview.default_color = Color(0.5, 0.8, 1.0, 0.4)  # Light blue, more visible
	trajectory_preview.z_index = 5
	add_child(trajectory_preview)
	trajectory_preview.visible = false

func setup_power_bar():
	# Create a container node
	var bar_container = Node2D.new()
	bar_container.name = "PowerBarContainer"
	add_child(bar_container)
	
	# Background bar (gray)
	power_bar_bg = ColorRect.new()
	power_bar_bg.size = Vector2(32, 4)  # Width and height
	power_bar_bg.position = Vector2(-16, -25)  # Centered, positioned above sprite
	power_bar_bg.color = Color(0.2, 0.2, 0.2, 0.5)  # Dark gray, semi-transparent
	bar_container.add_child(power_bar_bg)
	
	# Foreground power bar (changes color)
	power_bar = ColorRect.new()
	power_bar.size = Vector2(0, 4)  # Start with zero width
	power_bar.position = Vector2(-16, -25)  # Same position as background
	power_bar.color = Color(0, 1, 0, 0.8)  # Start with green
	bar_container.add_child(power_bar)
	
	# Hide initially
	bar_container.visible = false

func setup_trail():
	trail = Line2D.new()
	trail.width = 4.0
	trail.default_color = Color(1, 1, 1, 0.15)
	trail.z_index = -1
	
	# Create gradient for trail
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0.0))
	gradient.add_point(1.0, Color(1, 1, 1, 0.15))
	trail.gradient = gradient
	
	# Add trail to parent deferred
	get_parent().call_deferred("add_child", trail)

func _process(delta):
	# Update momentum cooldown
	if momentum_cooldown > 0:
		momentum_cooldown -= delta
	else:
		# Gradually decay momentum multiplier when not launching
		momentum_multiplier = max(1.0, momentum_multiplier - delta * 0.5)
	
	# Update visual effects
	update_visual_effects(delta)
	
	# Update aim line while dragging
	if dragging and show_aim_line:
		update_aim_line()

func _physics_process(delta):
	if !can_move:
		# Still apply fluid physics when movement is disabled
		apply_fluid_physics(delta)
		return
	
	# Apply fluid physics
	apply_fluid_physics(delta)

func _input(event):
	if !can_move:
		return
	
	# Handle mouse input for dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				drag_start = get_global_mouse_position()
				dragging = true
				if show_aim_line:
					aim_line.visible = true
					trajectory_preview.visible = true
					get_node("PowerBarContainer").visible = true
			else:
				# End dragging and launch
				dragging = false
				aim_line.visible = false
				trajectory_preview.visible = false
				get_node("PowerBarContainer").visible = false
				
				# Calculate launch vector
				var drag_end = get_global_mouse_position()
				var drag_distance = drag_start.distance_to(drag_end)
				
				# Only launch if dragged far enough
				if drag_distance > min_drag_distance:
					launch(drag_start, drag_end)
	
	# Update drag position
	if event is InputEventMouseMotion and dragging:
		pass  # The line updates are handled in _process

func update_aim_line():
	var current_pos = get_global_mouse_position()
	
	# Calculate launch direction (from cell to drag start)
	var launch_dir = drag_start - current_pos
	
	# Update aim line positions
	aim_line.points[0] = to_local(current_pos)
	aim_line.points[1] = to_local(drag_start)
	
	# Update power bar
	var power_ratio = min(1.0, launch_dir.length() / (max_launch_strength / drag_sensitivity))
	power_bar.size.x = 32 * power_ratio  # Scale width based on power
	
	# Change color based on power (green to yellow to red)
	var color_r = min(1.0, power_ratio * 2)
	var color_g = min(1.0, 2.0 - power_ratio * 2)
	var color_b = 0.2
	power_bar.color = Color(color_r, color_g, color_b, 0.8)
	
	# Update trajectory preview
	update_trajectory_preview(launch_dir)

func update_trajectory_preview(launch_dir: Vector2):
	trajectory_preview.clear_points()
	
	# Skip if direction is too small
	if launch_dir.length() < min_drag_distance:
		return
	
	# Calculate launch strength with momentum
	var strength = calculate_launch_strength(launch_dir.length())
	var direction = launch_dir.normalized() * strength * momentum_multiplier
	
	# Simulate trajectory
	var pos = Vector2.ZERO
	var vel = direction
	
	# Add points showing potential trajectory
	for i in range(10):
		trajectory_preview.add_point(pos)
		vel *= fluid_resistance  # Apply fluid resistance in simulation
		pos += vel * 0.016  # Approximate delta for 60fps
		
		# Stop preview if velocity becomes too small
		if vel.length() < 10:
			break

func calculate_launch_strength(drag_length: float) -> float:
	# Apply sensitivity multiplier to make small drags more effective
	var strength = drag_length * drag_sensitivity
	
	# Ensure a minimum launch power for better responsiveness
	if strength > min_drag_distance * drag_sensitivity:
		strength = max(min_launch_power, strength)
	
	# Cap at maximum
	return min(strength, max_launch_strength)

func launch(from_pos: Vector2, to_pos: Vector2):
	# Calculate launch vector (from drag end to drag start)
	var launch_dir = from_pos - to_pos
	
	# Only launch if vector is long enough
	if launch_dir.length() < min_drag_distance:
		return
	
	# Calculate strength with sensitivity multiplier
	var strength = calculate_launch_strength(launch_dir.length())
	launch_dir = launch_dir.normalized()
	
	# Apply momentum multiplier and add to velocity
	velocity += launch_dir * strength * momentum_multiplier
	
	# Increase momentum for successive quick launches
	if momentum_cooldown > 0:
		momentum_multiplier = min(momentum_multiplier + 0.2, max_momentum_bonus)
	
	# Reset momentum cooldown
	momentum_cooldown = 0.5

func apply_fluid_physics(delta):
	# Apply fluid resistance
	velocity *= fluid_resistance
	
	# Stop if practically not moving
	if velocity.length() < 5:
		velocity = Vector2.ZERO
	
	# Move the cell
	var collision = move_and_collide(velocity * delta)
	
	# Handle collisions
	if collision:
		# Bounce with reduced velocity
		velocity = velocity.bounce(collision.get_normal()) * wall_bounce

func update_visual_effects(delta):
	# Update trail
	if trail_enabled and is_instance_valid(trail):
		if velocity.length() > 20:
			if trail.points.size() > 15:
				trail.remove_point(0)
			trail.add_point(global_position)
	
	# Apply deformation effect based on movement
	if deform_effect:
		if velocity.length() > 20:
			var direction = velocity.normalized()
			
			# Calculate squish in direction of movement
			var squish_x = initial_scale.x * (1.0 - deform_strength * abs(direction.x) + deform_strength * abs(direction.y))
			var squish_y = initial_scale.y * (1.0 - deform_strength * abs(direction.y) + deform_strength * abs(direction.x))
			
			# Apply deformation with smooth lerp
			scale = scale.lerp(Vector2(squish_x, squish_y), 0.2)
		else:
			# Return to normal shape when still
			if velocity.length() < 10:
				var pulse = sin(Time.get_ticks_msec() * 0.001) * 0.02
				scale = scale.lerp(initial_scale * (1.0 + pulse), 0.1)

# Public functions for gameplay integration

func disable_movement():
	# Called when player is hit or during cutscenes
	can_move = false
	dragging = false
	aim_line.visible = false
	trajectory_preview.visible = false
	get_node("PowerBarContainer").visible = false

func enable_movement():
	# Called to re-enable player control
	can_move = true

func clear_trail():
	# Called when teleporting or respawning
	if trail_enabled and is_instance_valid(trail):
		trail.clear_points()

func apply_speed_boost(multiplier: float, duration: float):
	# Implement for power-ups
	var original_momentum_bonus = max_momentum_bonus
	max_momentum_bonus *= multiplier
	
	# Reset after duration
	await get_tree().create_timer(duration).timeout
	max_momentum_bonus = original_momentum_bonus

func _unhandled_input(event):
	# Test damage with T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if has_node("PlayerStats"):
			get_node("PlayerStats").take_damage(1)
			print("Test damage applied")
