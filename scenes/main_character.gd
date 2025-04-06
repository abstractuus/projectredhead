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

# Special attack parameters - UPDATED VALUES
@export var special_attack_radius: float = 100.0     # Radius of the attack
@export var special_attack_charge_time: float = 0.5   # REDUCED from 1.5 to 0.5 seconds
@export var special_attack_damage: int = 2           # Damage dealt by the special attack
@export var special_attack_cooldown: float = 5     # REDUCED from 3.0 to 2.0 seconds
@export var min_charge_threshold: float = 0.1        # REDUCED from 0.2 to 0.1 (10%)

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

# Private variables for special attack
var special_attack_charging: bool = false
var current_charge: float = 0.0
var cooldown_timer: float = 0.0
var can_special_attack: bool = true
var attack_ready: bool = false

# Special attack visual elements
var charge_indicator: Node2D
var attack_area_effect: Node2D
var cooldown_progress: ProgressBar

func _ready():
	print("DEBUG: Player character initializing")
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
	
	# Setup special attack visuals
	setup_special_attack_visuals()
	print("DEBUG: Player character initialized successfully")

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

func setup_special_attack_visuals():
	print("DEBUG: Setting up special attack visuals")
	# Create a node for the charge indicator
	charge_indicator = Node2D.new()
	charge_indicator.name = "ChargeIndicator"
	add_child(charge_indicator)
	
	# Create a circular charge indicator
	var charge_circle = DrawingUtils.create_circle(special_attack_radius, Color(0.1, 0.5, 1.0, 0.3))
	charge_indicator.add_child(charge_circle)
	charge_indicator.visible = false
	
	# Create attack area effect node (will be shown when attack is released)
	attack_area_effect = Node2D.new()
	attack_area_effect.name = "AttackAreaEffect"
	add_child(attack_area_effect)
	
	# Add visual effect for the attack
	var attack_circle = DrawingUtils.create_circle(special_attack_radius, Color(0.3, 0.8, 1.0, 0.6))
	attack_area_effect.add_child(attack_circle)
	attack_area_effect.visible = false
	
	# Set up cooldown UI
	setup_cooldown_ui()
	print("DEBUG: Special attack visuals setup complete")

func setup_cooldown_ui():
	print("DEBUG: Setting up cooldown UI")
	# Create a ProgressBar for the cooldown
	var ui_container = CanvasLayer.new()
	ui_container.name = "UIContainer"
	add_child(ui_container)
	
	cooldown_progress = ProgressBar.new()
	cooldown_progress.name = "CooldownProgress"
	cooldown_progress.set_position(Vector2(20, 20))
	cooldown_progress.set_size(Vector2(100, 20))
	cooldown_progress.max_value = 100
	cooldown_progress.value = 100
	cooldown_progress.visible = false
	
	ui_container.add_child(cooldown_progress)
	print("DEBUG: Cooldown UI setup complete")

func create_progress_texture(color: Color) -> ImageTexture:
	# Use a simple solid square texture instead of a circle
	var size = 32
	var img = Image.new()
	
	# Create with explicit size and format
	img.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Simply fill the entire image with the color
	img.fill(color)
	
	# Create texture from image
	var texture = ImageTexture.create_from_image(img)
	return texture
	
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
		
	# Handle special attack cooldown
	if !can_special_attack:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			print("DEBUG: Special attack cooldown complete")
			can_special_attack = true
			cooldown_progress.visible = false
		else:
			# Update cooldown UI
			var cooldown_percent = (1 - (cooldown_timer / special_attack_cooldown)) * 100
			cooldown_progress.value = cooldown_percent
	
	# Handle charging logic
	if special_attack_charging:
		current_charge += delta
		# Update charge indicator size
		var charge_ratio = min(1.0, current_charge / special_attack_charge_time)
		charge_indicator.scale = Vector2(charge_ratio, charge_ratio)
		
		# If fully charged, indicate ready
		if current_charge >= special_attack_charge_time and !attack_ready:
			attack_ready = true
			print("DEBUG: Special attack fully charged!")
			# Visual feedback for full charge
			charge_indicator.modulate = Color(1.0, 0.5, 0.0, 0.6)

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
		
	# Special attack input
	if event is InputEventKey and can_move:
		if event.keycode == KEY_SPACE:
			if event.pressed and can_special_attack:
				# Start charging
				print("DEBUG: Space pressed - starting special attack charge")
				start_charging()
			elif !event.pressed and special_attack_charging:
				# Release attack
				print("DEBUG: Space released - releasing special attack")
				release_special_attack()

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

# Special attack functions
func start_charging():
	print("DEBUG: Starting special attack charge")
	special_attack_charging = true
	current_charge = 0.0
	attack_ready = false
	charge_indicator.visible = true
	charge_indicator.scale = Vector2(0.1, 0.1)
	charge_indicator.modulate = Color(0.1, 0.5, 1.0, 0.3)

func release_special_attack():
	# Only proceed if we were charging
	if !special_attack_charging:
		print("DEBUG: Not charging, can't release")
		return

	print("DEBUG: Releasing special attack")
	special_attack_charging = false
	charge_indicator.visible = false

	# Calculate attack strength based on charge time
	var charge_ratio = min(1.0, current_charge / special_attack_charge_time)
	var attack_power = special_attack_damage * charge_ratio

	print("DEBUG: Charge ratio: ", charge_ratio, ", Attack power: ", attack_power)

	# Minimum attack power threshold - USE NEW PARAMETER
	if charge_ratio < min_charge_threshold:  # Reduced to 10%
		print("DEBUG: Special attack charge too low, canceling")
		return  # Cancel the attack if charge is too low

	# Visual effect for the attack
	show_attack_effect(charge_ratio)

	# Detect and damage enemies in range
	var attack_radius = special_attack_radius * charge_ratio
	print("DEBUG: Attack radius: ", attack_radius)
	var enemies_in_range = get_enemies_in_range(attack_radius)
	print("DEBUG: Found ", enemies_in_range.size(), " enemies in range")

	for enemy in enemies_in_range:
		if enemy.has_method("take_damage"):
			print("DEBUG: Applying damage to enemy: ", enemy.name)
			enemy.take_damage(round(attack_power))
		else:
			print("DEBUG: Enemy doesn't have take_damage method: ", enemy.name)

	# Apply cooldown
	can_special_attack = false
	cooldown_timer = special_attack_cooldown
	cooldown_progress.visible = true
	cooldown_progress.value = 0
	# Only proceed if we were charging
	if !special_attack_charging:
		print("DEBUG: Not charging, can't release")
		return
	
	print("DEBUG: Releasing special attack")
	special_attack_charging = false
	charge_indicator.visible = false
	
	# Calculate attack strength based on charge time
	charge_ratio = min(1.0, current_charge / special_attack_charge_time)
	attack_power = special_attack_damage * charge_ratio
	
	print("DEBUG: Charge ratio: ", charge_ratio, ", Attack power: ", attack_power)
	
	# Minimum attack power threshold
	if charge_ratio < 0.2:  # If charge is less than 20%
		print("DEBUG: Special attack charge too low, canceling")
		return  # Cancel the attack if charge is too low
	
	# Visual effect for the attack
	show_attack_effect(charge_ratio)
	
	# Detect and damage enemies in range
	attack_radius = special_attack_radius * charge_ratio
	print("DEBUG: Attack radius: ", attack_radius)
	enemies_in_range = get_enemies_in_range(attack_radius)
	print("DEBUG: Found ", enemies_in_range.size(), " enemies in range")
	
	for enemy in enemies_in_range:
		if enemy.has_method("take_damage"):
			print("DEBUG: Applying damage to enemy: ", enemy.name)
			enemy.take_damage(round(attack_power))
		else:
			print("DEBUG: Enemy doesn't have take_damage method: ", enemy.name)
	
	# Apply cooldown
	can_special_attack = false
	cooldown_timer = special_attack_cooldown
	cooldown_progress.visible = true
	cooldown_progress.value = 0
	
	# Play attack sound
	# If you have the AudioFramework set up
	# AudioManager.play_sfx("player_attack_" + str(1 + randi() % 3))

func show_attack_effect(charge_ratio):
	print("DEBUG: Showing attack effect with charge ratio: ", charge_ratio)
	# Set size based on charge ratio
	attack_area_effect.scale = Vector2(charge_ratio, charge_ratio)
	attack_area_effect.visible = true
	
	# Create a tween for the attack effect
	var tween = create_tween()
	tween.tween_property(attack_area_effect, "scale", Vector2(charge_ratio * 1.2, charge_ratio * 1.2), 0.2)
	tween.tween_property(attack_area_effect, "scale", Vector2(charge_ratio, charge_ratio), 0.1)
	tween.tween_property(attack_area_effect, "modulate:a", 0.0, 0.3)
	
	# Connect to the tween's finished signal to hide the effect
	tween.finished.connect(func():
		attack_area_effect.visible = false
		attack_area_effect.modulate.a = 1.0
		print("DEBUG: Attack effect animation complete")
	)

func get_enemies_in_range(range_radius):
	var enemies = []
	
	# Get all nodes in the "enemy" group and check if they're within range
	var potential_enemies = get_tree().get_nodes_in_group("enemy")
	print("DEBUG: Found ", potential_enemies.size(), " potential enemies in 'enemy' group")
	
	for enemy in potential_enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= range_radius:
			print("DEBUG: Enemy ", enemy.name, " is within range (distance: ", distance, ")")
			enemies.append(enemy)
		else:
			print("DEBUG: Enemy ", enemy.name, " is out of range (distance: ", distance, ")")
	
	print("DEBUG: Total enemies within attack radius: ", enemies.size())
	return enemies

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
	print("DEBUG: Applying speed boost with multiplier ", multiplier, " for ", duration, " seconds")
	var original_momentum_bonus = max_momentum_bonus
	max_momentum_bonus *= multiplier
	
	# Reset after duration
	await get_tree().create_timer(duration).timeout
	max_momentum_bonus = original_momentum_bonus
	print("DEBUG: Speed boost expired")

func _unhandled_input(event):
	# Test damage with T key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if has_node("PlayerStats"):
			get_node("PlayerStats").take_damage(1)
			print("Test damage applied")

# Utility class for drawing shapes
class DrawingUtils:
	static func create_circle(radius, color):
		# Create a custom Circle2D class instance
		var circle = Circle2D.new()
		circle.radius = radius
		circle.color = color
		return circle

# Custom class for drawing circles
class Circle2D extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.WHITE

	func _draw():
		draw_circle(Vector2.ZERO, radius, color)
