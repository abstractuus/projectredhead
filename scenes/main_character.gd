# Player.gd
# Enhanced Slingshot Character Controller with FSM and Advanced Features
# meta-description: Godot CharacterBody2D controller using slingshot mechanics,
# momentum, a chargeable AoE attack, state machine, signals, and best practices.

extends CharacterBody2D

#region Signals
signal state_changed(new_state: State)
signal launched(launch_velocity: Vector2)
signal charge_started
signal attack_fired(charge_ratio: float, attack_power: float)
signal health_changed(current_health: int, max_health: int) # Assuming health is managed elsewhere or here
signal cooldown_updated(cooldown_progress: float) # 0.0 to 1.0
#endregion

#region Enums and Constants
enum State { IDLE, AIMING, MOVING, CHARGING, ATTACKING, DISABLED }

const INPUT_ACTION_LAUNCH := "player_launch" # Corresponds to Mouse Left Button in Input Map
const INPUT_ACTION_SPECIAL := "player_special" # Corresponds to Spacebar in Input Map
const INPUT_ACTION_CANCEL := "player_cancel" # Optional: e.g., Mouse Right Button

const GROUP_ENEMY := "enemy"
const GROUP_PLAYER := "player"

const MOMENTUM_RESET_TIME := 0.5 # Time before momentum starts decaying
const MOMENTUM_DECAY_RATE := 0.5 # Multiplier decay per second
const MIN_VELOCITY_THRESHOLD := 5.0 # Velocity below which movement stops

# Physics Layers/Masks (Define these in Project Settings -> Physics Layers)
# const PHYSICS_LAYER_WORLD = 1
# const PHYSICS_LAYER_PLAYER = 2
# const PHYSICS_LAYER_ENEMY = 4
#endregion

#region Exported Parameters

# Movement & Slingshot
@export_group("Movement")
@export var max_launch_strength: float = 1000.0 # Max velocity applied on launch
@export var min_drag_distance: float = 20.0 # Min pixel distance to register drag (Increased for less sensitivity)
@export var drag_sensitivity: float = 5.0 # Drag distance multiplier to launch power
@export var min_launch_power: float = 200.0 # Minimum velocity applied even for short drags
@export var momentum_retention: float = 0.7 # Multiplier applied to *existing* velocity on launch (additive)
@export var fluid_resistance_factor: float = 0.96 # Velocity multiplier per physics frame (higher = less drag)
@export var stop_on_launch: bool = true # Whether to zero out velocity before applying launch force

# Momentum Bonus
@export_group("Momentum Bonus")
@export var enable_momentum_bonus: bool = true
@export var momentum_bonus_per_launch: float = 0.2
@export var max_momentum_bonus: float = 1.5 # Max multiplier from quick launches

# Special Attack
@export_group("Special Attack")
@export var special_attack_radius_base: float = 100.0
@export var special_attack_charge_time: float = 0.5
@export var special_attack_damage_base: int = 2
@export var special_attack_cooldown: float = 2.0 # Reduced cooldown
@export var min_charge_threshold: float = 0.1 # Min charge ratio (0 to 1) to trigger attack

# Visuals & Effects (Flags to enable/disable features)
@export_group("Visuals")
@export var show_aim_line: bool = true
@export var show_trajectory_preview: bool = true
@export var trail_enabled: bool = true
@export var deform_effect: bool = true

# Aiming Visuals Config (if using scenes, these might be adjusted there)
@export_category("Aiming Visual Config")
@export var aim_line_thickness: float = 3.0
@export var aim_line_color: Color = Color(1, 1, 1, 0.8)
@export var trajectory_points: int = 15
@export var trajectory_step: float = 0.02 # Simulated time step for preview points

# Deformation Config
@export_category("Deformation Config")
@export var deform_strength: float = 0.25
@export var deform_lerp_speed: float = 10.0 # Faster lerp for snappier effect
@export var idle_pulse_speed: float = 2.0
@export var idle_pulse_amount: float = 0.02

#endregion

#region Onready Node References
# Assuming these nodes exist as children or are assigned in the editor
@onready var sprite: Sprite2D = $Sprite2D # Or AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var aim_line_node: Line2D = $AimLine # Setup in editor: width, color, material etc.
@onready var trajectory_preview_node: Line2D = $TrajectoryPreview # Setup in editor
@onready var power_bar_container: Node2D = $PowerBarContainer # Container for power bar visuals
@onready var power_bar: ColorRect = $PowerBarContainer/PowerBarFG # Actual bar
@export var power_bar_max_width: float = 32.0 # Configurable width
@onready var charge_indicator: Node2D = $ChargeIndicator # e.g., Sprite2D or Node2D with shader
@onready var attack_area_detector: Area2D = $AttackAreaDetector # Area2D with CollisionShape2D matching max radius
@onready var attack_area_visual: Node2D = $AttackAreaVisual # Effect shown on attack (Particles/Shader)
@onready var trail_emitter: Node = $TrailEmitter # GPUParticles2D recommended
@onready var cooldown_progress_ui: ProgressBar = $UIContainer/CooldownProgress # Assumes CanvasLayer setup

#endregion

#region Private State Variables
# State Machine
var current_state: State = State.IDLE : set = set_state

# Movement / Dragging
var _drag_start_position: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _current_momentum_multiplier: float = 1.0
var _time_since_last_launch: float = 0.0

# Special Attack
var _is_charging_special: bool = false
var _current_charge_amount: float = 0.0 # 0.0 to charge_time
var _current_cooldown: float = 0.0 # Remaining cooldown time
var _can_use_special: bool = true

# Visuals
var _initial_scale: Vector2
var _target_scale: Vector2 # For deformation lerping
#endregion

#region Godot Lifecycle Methods
func _ready() -> void:
	add_to_group(GROUP_PLAYER)
	set_process(true) # Enable _process for visual updates / cooldowns
	set_physics_process(true) # Enable _physics_process for movement

	_initial_scale = sprite.scale
	_target_scale = _initial_scale

	# Configure Area2D for attack detection
	if attack_area_detector:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = special_attack_radius_base
		attack_area_detector.get_node("CollisionShape2D").shape = shape # Assumes child named CollisionShape2D
		attack_area_detector.collision_layer = 0 # Doesn't need to be detected
		attack_area_detector.collision_mask = 0 # Detects nothing itself (we use get_overlapping_bodies)
		attack_area_detector.monitoring = false # Only check manually when attacking
	else:
		push_warning("AttackAreaDetector node not found. Special attack enemy detection disabled.")

	# Hide visuals initially
	if aim_line_node: aim_line_node.visible = false
	if trajectory_preview_node: trajectory_preview_node.visible = false
	if power_bar_container: power_bar_container.visible = false
	if charge_indicator: charge_indicator.visible = false
	if attack_area_visual: attack_area_visual.visible = false
	if cooldown_progress_ui: cooldown_progress_ui.visible = false

	set_state(State.IDLE)
	print("Player Initialized. State: ", State.keys()[current_state])


func _unhandled_input(event: InputEvent) -> void:
	# Input handling is delegated based on state
	match current_state:
		State.IDLE, State.MOVING:
			if event.is_action_pressed(INPUT_ACTION_LAUNCH):
				start_aiming(get_global_mouse_position())
			elif event.is_action_pressed(INPUT_ACTION_SPECIAL) and _can_use_special:
				set_state(State.CHARGING)
		State.AIMING:
			if event.is_action_released(INPUT_ACTION_LAUNCH):
				attempt_launch(get_global_mouse_position())
			elif event.is_action_pressed(INPUT_ACTION_CANCEL): # Optional cancel
				cancel_aiming()
		State.CHARGING:
			if event.is_action_released(INPUT_ACTION_SPECIAL):
				attempt_special_attack()
			elif event.is_action_pressed(INPUT_ACTION_CANCEL): # Optional cancel
				cancel_charging()
		State.DISABLED:
			pass # No input processing when disabled


func _process(delta: float) -> void:
	# Update timers and visual elements not tied to physics
	update_cooldowns(delta)
	update_momentum_decay(delta)

	match current_state:
		State.AIMING:
			update_aiming_visuals(get_global_mouse_position())
		State.CHARGING:
			update_charging_state(delta)
		State.MOVING:
			# Update non-physics visuals while moving
			update_deformation()
			update_trail(true)
		State.IDLE:
			# Update non-physics visuals while idle
			update_deformation()
			update_trail(false)
		State.DISABLED:
			# Could have specific visual state for disabled
			update_trail(false)


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			# Allow minor physics corrections/settling if needed
			apply_resistance()
			move_and_slide()
		State.MOVING:
			apply_resistance()
			var collision := move_and_slide()
			if collision:
				handle_collision(collision)
			# Check if stopped moving
			if velocity.length() < MIN_VELOCITY_THRESHOLD:
				velocity = Vector2.ZERO
				set_state(State.IDLE)
		State.DISABLED:
			# Apply resistance even when disabled to slow down
			apply_resistance()
			move_and_slide() # Allow sliding/bouncing while disabled
		_:
			# States like AIMING, CHARGING, ATTACKING usually don't move
			# but could apply resistance if they have residual velocity
			if velocity.length() > 0:
				apply_resistance()
				move_and_slide()


#endregion

#region State Management (FSM)
func set_state(new_state: State) -> void:
	if new_state == current_state:
		return

	# Exit logic for the previous state
	match current_state:
		State.AIMING:
			_exit_aiming_state()
		State.CHARGING:
			_exit_charging_state()
		State.ATTACKING:
			_exit_attacking_state()

	# Enter logic for the new state
	match new_state:
		State.IDLE:
			_enter_idle_state()
		State.AIMING:
			_enter_aiming_state()
		State.MOVING:
			_enter_moving_state()
		State.CHARGING:
			_enter_charging_state()
		State.ATTACKING:
			_enter_attacking_state()
		State.DISABLED:
			_enter_disabled_state()

	current_state = new_state
	emit_signal("state_changed", current_state)
	# print("State changed to: ", State.keys()[current_state]) # Debug logging


# State Enter/Exit Logic
func _enter_idle_state() -> void: pass # Usually involves resetting visuals/timers if needed
func _exit_idle_state() -> void: pass

func _enter_aiming_state() -> void:
	_is_dragging = true
	if aim_line_node and show_aim_line: aim_line_node.visible = true
	if trajectory_preview_node and show_trajectory_preview: trajectory_preview_node.visible = true
	if power_bar_container: power_bar_container.visible = true
func _exit_aiming_state() -> void:
	_is_dragging = false
	if aim_line_node: aim_line_node.visible = false
	if trajectory_preview_node: trajectory_preview_node.visible = false
	if power_bar_container: power_bar_container.visible = false
	if aim_line_node: aim_line_node.clear_points(); aim_line_node.add_point(Vector2.ZERO); aim_line_node.add_point(Vector2.ZERO) # Reset points
	if trajectory_preview_node: trajectory_preview_node.clear_points()

func _enter_moving_state() -> void:
	# Trail emission likely starts here
	if trail_emitter and trail_enabled:
		trail_emitter.emitting = true
func _exit_moving_state() -> void:
	if trail_emitter and trail_enabled:
		trail_emitter.emitting = false # Or let particles naturally fade

func _enter_charging_state() -> void:
	_is_charging_special = true
	_current_charge_amount = 0.0
	if charge_indicator:
		charge_indicator.visible = true
		charge_indicator.scale = Vector2.ZERO # Start small
		# Reset modulation if needed
		charge_indicator.modulate = Color.WHITE
	emit_signal("charge_started")
func _exit_charging_state() -> void:
	_is_charging_special = false
	if charge_indicator:
		charge_indicator.visible = false

func _enter_attacking_state() -> void:
	# Trigger attack visuals immediately
	var charge_ratio := clampi(_current_charge_amount / special_attack_charge_time, 0.0, 1.0)
	var attack_power := special_attack_damage_base * charge_ratio
	show_attack_visuals(charge_ratio)
	perform_attack_damage(charge_ratio)
	apply_attack_cooldown()
	emit_signal("attack_fired", charge_ratio, attack_power)
	# Transition out of attacking state quickly (e.g., after animation or instantly)
	# Using a short timer or tween callback before changing state is common
	set_state(State.IDLE) # Or State.MOVING if there was residual velocity
func _exit_attacking_state() -> void: pass # Visuals hide via tweens/timers

func _enter_disabled_state() -> void:
	# Cancel any ongoing actions
	if current_state == State.AIMING: _exit_aiming_state()
	if current_state == State.CHARGING: _exit_charging_state()
	# Could change sprite appearance, stop emitters etc.
	if trail_emitter: trail_emitter.emitting = false
func _exit_disabled_state() -> void: pass # Restore visuals/input


# Public methods to control state
func enable_movement_control() -> void:
	if current_state == State.DISABLED:
		set_state(State.IDLE)
func disable_movement_control() -> void:
	if current_state != State.DISABLED:
		set_state(State.DISABLED)

#endregion

#region Movement & Physics
func apply_resistance() -> void:
	# Apply fluid resistance if moving
	if velocity.length_squared() > 0: # Use length_squared for efficiency
		velocity *= fluid_resistance_factor

func handle_collision(collision: KinematicCollision2D) -> void:
	# Basic bounce using Physics Material (preferred)
	# Ensure the CharacterBody2D has a PhysicsMaterial set in the inspector
	# with appropriate Bounce value. `move_and_slide` handles this automatically.

	# Manual bounce (if not using PhysicsMaterial or need custom logic):
	# var bounce_factor = wall_bounce # Use exported var if needed
	# velocity = velocity.bounce(collision.get_normal()) * bounce_factor
	# push_warning("Collision detected, velocity after bounce: " + str(velocity))

	# Could add effects on collision (particles, sound)
	pass

func update_momentum_decay(delta: float) -> void:
	if enable_momentum_bonus:
		_time_since_last_launch += delta
		if _time_since_last_launch > MOMENTUM_RESET_TIME:
			# Gradually decay momentum multiplier back to 1.0
			_current_momentum_multiplier = max(1.0, _current_momentum_multiplier - MOMENTUM_DECAY_RATE * delta)

func start_aiming(mouse_pos: Vector2) -> void:
	if current_state == State.IDLE or current_state == State.MOVING:
		_drag_start_position = mouse_pos
		set_state(State.AIMING)

func cancel_aiming() -> void:
	if current_state == State.AIMING:
		set_state(State.IDLE if velocity.length() < MIN_VELOCITY_THRESHOLD else State.MOVING)

func attempt_launch(mouse_pos: Vector2) -> void:
	if current_state != State.AIMING: return

	var drag_vector := _drag_start_position - mouse_pos
	var drag_length := drag_vector.length()

	if drag_length >= min_drag_distance:
		var launch_strength := calculate_launch_strength(drag_length)
		var launch_direction := drag_vector.normalized()

		# Calculate final launch velocity including momentum bonus
		var launch_velocity := launch_direction * launch_strength * _current_momentum_multiplier

		# Apply momentum retention from previous velocity (optional)
		var retained_velocity := velocity * momentum_retention if !stop_on_launch else Vector2.ZERO

		# Apply the launch
		velocity = retained_velocity + launch_velocity

		# Update momentum bonus
		if enable_momentum_bonus:
			if _time_since_last_launch <= MOMENTUM_RESET_TIME:
				_current_momentum_multiplier = min(max_momentum_bonus, _current_momentum_multiplier + momentum_bonus_per_launch)
			# else: bonus doesn't increase, but multiplier doesn't reset yet

		_time_since_last_launch = 0.0 # Reset time tracker

		emit_signal("launched", launch_velocity)
		# Play launch sound via AudioManager or direct node
		# AudioManager.play_sfx("player_launch")

		set_state(State.MOVING)
	else:
		# Drag too short, cancel aiming
		cancel_aiming()


func calculate_launch_strength(drag_length: float) -> float:
	var base_strength := drag_length * drag_sensitivity
	# Ensure minimum power if drag distance threshold is met
	return max(min_launch_power, base_strength)


#endregion

#region Special Attack Logic
func update_cooldowns(delta: float) -> void:
	if !_can_use_special:
		_current_cooldown -= delta
		if _current_cooldown <= 0:
			_can_use_special = true
			_current_cooldown = 0.0
			if cooldown_progress_ui:
				cooldown_progress_ui.visible = false
			emit_signal("cooldown_updated", 1.0)
		else:
			# Update UI
			var progress_ratio := 1.0 - (_current_cooldown / special_attack_cooldown)
			if cooldown_progress_ui:
				cooldown_progress_ui.value = progress_ratio * cooldown_progress_ui.max_value
			emit_signal("cooldown_updated", progress_ratio)

func update_charging_state(delta: float) -> void:
	_current_charge_amount += delta
	var charge_ratio := clampi(_current_charge_amount / special_attack_charge_time, 0.0, 1.0)

	# Update charge indicator visual (e.g., scale, shader parameter)
	if charge_indicator:
		charge_indicator.scale = Vector2(charge_ratio, charge_ratio)
		# Example: modulate color when fully charged
		if charge_ratio >= 1.0:
			charge_indicator.modulate = Color.ORANGE # Indicate fully charged
		else:
			charge_indicator.modulate = Color.WHITE # Normal charging color

func cancel_charging() -> void:
	if current_state == State.CHARGING:
		set_state(State.IDLE if velocity.length() < MIN_VELOCITY_THRESHOLD else State.MOVING)


func attempt_special_attack() -> void:
	if current_state != State.CHARGING: return

	var charge_ratio := clampi(_current_charge_amount / special_attack_charge_time, 0.0, 1.0)

	if charge_ratio >= min_charge_threshold:
		# Transition to attacking state (which handles visuals, damage, cooldown)
		set_state(State.ATTACKING)
	else:
		# Charge too low, fizzle / cancel
		# print("Attack fizzled - charge too low")
		# Play fizzle sound/effect
		set_state(State.IDLE if velocity.length() < MIN_VELOCITY_THRESHOLD else State.MOVING)

func perform_attack_damage(charge_ratio: float) -> void:
	if not attack_area_detector: return

	var attack_radius := special_attack_radius_base * charge_ratio
	var attack_power := roundi(special_attack_damage_base * charge_ratio)

	# Temporarily enable monitoring to get overlaps
	# Note: Consider using PhysicsServer2D queries for more control if needed
	attack_area_detector.monitoring = true
	# Force update overlaps (might not be needed depending on setup)
	# await get_tree().physics_frame

	var bodies := attack_area_detector.get_overlapping_bodies()
	attack_area_detector.monitoring = false # Disable after checking

	# print(f"Attack triggered: Radius={attack_radius:.1f}, Power={attack_power}, Overlaps={bodies.size()}")

	for body in bodies:
		if body.is_in_group(GROUP_ENEMY) and body.has_method("take_damage"):
			# print(f"Damaging enemy: {body.name}")
			body.call("take_damage", attack_power) # Use call for safety

func apply_attack_cooldown() -> void:
	_can_use_special = false
	_current_cooldown = special_attack_cooldown
	if cooldown_progress_ui:
		cooldown_progress_ui.visible = true
		cooldown_progress_ui.value = 0
	emit_signal("cooldown_updated", 0.0)

#endregion

#region Visual Updates
func update_aiming_visuals(mouse_pos: Vector2) -> void:
	var drag_vector = _drag_start_position - mouse_pos
	var drag_length = drag_vector.length()

	if drag_length < min_drag_distance:
		# Optionally hide preview or show minimum range indicator
		if aim_line_node: aim_line_node.visible = false # Hide if below min distance
		if trajectory_preview_node: trajectory_preview_node.visible = false
		if power_bar_container: power_bar_container.visible = false # Hide power bar too
		return
	else:
		# Ensure visible if drag is valid
		if aim_line_node and show_aim_line: aim_line_node.visible = true
		if trajectory_preview_node and show_trajectory_preview: trajectory_preview_node.visible = true
		if power_bar_container: power_bar_container.visible = true


	# 1. Update Aim Line
	if aim_line_node and show_aim_line:
		# Position points relative to the player node
		aim_line_node.set_point_position(0, to_local(mouse_pos))
		aim_line_node.set_point_position(1, to_local(_drag_start_position))
		# Could also color based on power

	# 2. Update Power Bar
	if power_bar_container:
		var launch_strength = calculate_launch_strength(drag_length)
		# Normalize power against max possible strength for the bar fill ratio
		var power_ratio = clampi(launch_strength / max_launch_strength, 0.0, 1.0)
		power_bar.size.x = power_bar_max_width * power_ratio
		# Color interpolation (Green -> Yellow -> Red)
		power_bar.color = Color.GREEN.lerp(Color.RED, power_ratio)

	# 3. Update Trajectory Preview
	if trajectory_preview_node and show_trajectory_preview:
		update_trajectory_preview_points(drag_vector)


func update_trajectory_preview_points(drag_vector: Vector2) -> void:
	if not trajectory_preview_node: return
	trajectory_preview_node.clear_points()

	var drag_length := drag_vector.length()
	if drag_length < min_drag_distance: return # Don't preview if too short

	# Calculate initial velocity for simulation
	var strength := calculate_launch_strength(drag_length)
	var launch_dir := drag_vector.normalized()
	var sim_velocity := launch_dir * strength * _current_momentum_multiplier # Use current momentum

	var current_pos := Vector2.ZERO # Start relative to player
	var time_step := trajectory_step # Use exported step

	# Add initial point at player center
	trajectory_preview_node.add_point(current_pos)

	# Simulate steps (replace with PhysicsServer2D.body_test_motion for collision checks if needed)
	for i in range(trajectory_points):
		# Apply simulated resistance
		sim_velocity *= pow(fluid_resistance_factor, time_step / get_physics_process_delta_time()) # More accurate resistance over time_step
		# Update position
		current_pos += sim_velocity * time_step
		trajectory_preview_node.add_point(current_pos)

		# Stop if velocity is negligible
		if sim_velocity.length_squared() < MIN_VELOCITY_THRESHOLD * MIN_VELOCITY_THRESHOLD:
			break


func update_deformation() -> void:
	if not deform_effect or not sprite: return

	if current_state == State.MOVING and velocity.length_squared() > MIN_VELOCITY_THRESHOLD * MIN_VELOCITY_THRESHOLD:
		var move_dir = velocity.normalized()
		# Dynamic squash and stretch based on direction vs sprite up axis (assuming sprite faces right)
		var stretch_factor = clampi(velocity.length() / (max_launch_strength * 0.5), 0.0, 1.0) # Scale effect with speed
		var dot_prod = move_dir.dot(Vector2.RIGHT) # How much aligned with sprite's default right direction
		var cross_prod_sign = sign(move_dir.cross(Vector2.RIGHT)) # Perpendicular direction

		# Simplified squash/stretch - scale along velocity axis, squash perpendicular
		var stretch_scale = 1.0 + deform_strength * stretch_factor
		var squash_scale = 1.0 - deform_strength * stretch_factor

		# Apply scale based on direction (more advanced would use rotation + scale)
		# This simplified version scales X/Y based on horizontal/vertical movement components
		var target_x = lerp(_initial_scale.x, _initial_scale.x * stretch_scale if abs(dot_prod) > 0.5 else _initial_scale.x * squash_scale, stretch_factor)
		var target_y = lerp(_initial_scale.y, _initial_scale.y * stretch_scale if abs(dot_prod) <= 0.5 else _initial_scale.y * squash_scale, stretch_factor)

		_target_scale = Vector2(target_x, target_y)
	else:
		# Idle pulse or return to normal
		var time = Time.get_ticks_msec() * 0.001 * idle_pulse_speed
		var pulse = sin(time) * idle_pulse_amount
		_target_scale = _initial_scale * (1.0 + pulse)

	# Smoothly interpolate towards the target scale
	sprite.scale = sprite.scale.lerp(_target_scale, get_process_delta_time() * deform_lerp_speed)


func update_trail(is_moving: bool) -> void:
	if not trail_enabled or not trail_emitter: return

	if is_instance_valid(trail_emitter): # Check if node is valid
		# Assuming GPUParticles2D
		if trail_emitter is GPUParticles2D:
			trail_emitter.emitting = is_moving and velocity.length_squared() > MIN_VELOCITY_THRESHOLD * MIN_VELOCITY_THRESHOLD
		# Add logic for other trail types if necessary
	else:
		push_warning("Trail emitter node is not valid or not found.")


func show_attack_visuals(charge_ratio: float) -> void:
	if not attack_area_visual: return

	attack_area_visual.scale = Vector2.ONE * charge_ratio # Scale visual by charge
	attack_area_visual.modulate = Color.WHITE # Reset modulate
	attack_area_visual.visible = true

	# Use a tween for a quick pulse/fade effect
	var tween := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# Scale up slightly then fade out quickly
	tween.tween_property(attack_area_visual, "scale", attack_area_visual.scale * 1.3, 0.1)
	tween.parallel().tween_property(attack_area_visual, "modulate:a", 0.0, 0.3).from(1.0)

	# Hide node when tween completes
	tween.finished.connect(func():
		if is_instance_valid(attack_area_visual): # Check if node still exists
			attack_area_visual.visible = false
			attack_area_visual.modulate.a = 1.0 # Reset alpha
			attack_area_visual.scale = Vector2.ONE # Reset scale
		)


#endregion

#region Public API & Utility
func clear_persistent_effects() -> void:
	# Call when respawning or teleporting
	if trail_emitter and trail_emitter.has_method("restart"):
		trail_emitter.restart() # Reset particles
	# Could also clear Line2D trails if using that approach
	velocity = Vector2.ZERO
	_current_momentum_multiplier = 1.0
	_time_since_last_launch = 0.0

# Example: Apply temporary boost (e.g., from power-up)
func apply_temporary_boost(strength_multiplier: float = 1.5, duration: float = 3.0) -> void:
	var original_max_bonus = max_momentum_bonus
	var original_launch_strength = max_launch_strength
	max_momentum_bonus *= strength_multiplier
	max_launch_strength *= strength_multiplier
	print(f"Boost Applied! Strength: x{strength_multiplier:.1f}, Duration: {duration}s")

	# Use a timer to revert the boost
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		max_momentum_bonus = original_max_bonus
		max_launch_strength = original_launch_strength
		print("Boost Expired.")
		, CONNECT_ONE_SHOT # Ensure connection is removed after firing
	)

#endregion
