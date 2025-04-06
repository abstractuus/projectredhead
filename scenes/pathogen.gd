extends CharacterBody2D

enum State {CUTE, SPIKEY, ATTACHED, FLEEING}  # Added FLEEING state

signal state_changed(new_state)

# Configuration parameters to update in the pathogen.gd file
@export var move_speed: float = 150.0
@export var flee_speed: float = 250.0  # Increased for more obvious fleeing
@export var detection_radius: float = 140.0  # Slightly reduced from 180 for better gameplay balance
@export var flee_distance: float = 50.0
@export var aggression_chance: float = 0.4  # DOUBLED from 0.2 for more frequent state changes
@export var state_change_cooldown: float = 2.0  # Reduced from 3.0 to make state changes more frequent
@export var health: int = 2  # Keeping at 2 for balance
@export var damage_interval: float = 0.5  # How often it damages the player when attached
@export var disinterest_time: float = 3.0  # Time to remain disinterested after being removed
@export var fleeing_duration: float = 2.0  # Duration for fleeing behavior
@export var wander_speed: float = 75.0  # Separate speed for wandering behavior

# State variables
var current_state: int = State.CUTE
var player: CharacterBody2D = null
var damage_timer: float = 0.0
var clicks_to_remove: int = 3  # Increased from 1 to 2 for better gameplay feel
var current_clicks: int = 0
var disinterest_timer: float = 0.0
var initial_scale: Vector2
var fear_timer: float = 0.0
var player_near_timer: float = 0.0
var wander_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var fleeing_timer: float = 0.0  # NEW: Track fleeing duration
var state_change_timer: float = 0.0  # NEW: Track time since last state change

var aggression_cooldown_timer: float = 0.0
var aggression_cooldown_time: float = 3.0  # Time after disinterest before becoming aggressive again

# Visual feedback variables
var pulse_effect: float = 0.0  # NEW: For breathing/pulsing effect
var pulse_speed: float = 5.0   # NEW: Speed of pulsing
var pulse_strength: float = 0.1  # NEW: Magnitude of pulse
var click_label: Label = null   # NEW: Label for showing click progress

# Node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var hit_area: Area2D = $HitArea

var deform_effect: bool = true  # Enable deformation effects for visual feedback

func _ready():
	# Store initial scale
	initial_scale = scale
	print("DEBUG: Initial scale set to: ", initial_scale)
	print("DEBUG: Pathogen initialized with health: ", health)
	print("DEBUG: Clicks required to remove: ", clicks_to_remove)
	
	# Set up the initial state
	set_state(State.CUTE)
	
	# Connect signals
	detection_area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))
	hit_area.connect("body_entered", Callable(self, "_on_hit_area_body_entered"))
	
	var detection_shape = detection_area.get_node("CollisionShape2D3")
	if detection_shape:
		var shape_radius = detection_shape.shape.radius
		var target_scale = detection_radius / (shape_radius * initial_scale.x)
		detection_shape.scale = Vector2(target_scale, target_scale)
		print("DEBUG: Adjusted detection area to radius: ", detection_radius)
	
	# IMPORTANT: Add to enemy group but ensure NOT enemy_attack when starting in CUTE state
	if is_in_group("enemy_attack"):
		remove_from_group("enemy_attack")

	if not is_in_group("enemy"):
		add_to_group("enemy")

	print("DEBUG: Initial group membership: enemy=", is_in_group("enemy"), ", enemy_attack=", is_in_group("enemy_attack"))

	# Set up the hit_area group - remove from attack group initially
	hit_area.add_to_group("enemy_hitbox")
	if hit_area.is_in_group("enemy_attack"):
		hit_area.remove_from_group("enemy_attack")
	
	# Set up initial wander direction
	randomize_wander()
	
	# Connect click input
	set_process_input(true)
	
	# Setup click counter
	setup_click_counter()

func setup_click_counter():
	# Create a label for displaying click progress
	click_label = Label.new()
	click_label.name = "ClickCounter"
	click_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position the label above the pathogen - smaller positioning offset
	click_label.position = Vector2(-25, -20)  # Reduced offset for smaller appearance
	click_label.size = Vector2(50, 15)  # Smaller size overall
	
	# Set font color and shadow for better visibility
	click_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	click_label.add_theme_constant_override("shadow_offset_x", 1)
	click_label.add_theme_constant_override("shadow_offset_y", 1)
	click_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	
	# Make the font smaller
	var font_size = 10  # Smaller font size
	var font = FontFile.new()
	var theme = Theme.new()
	theme.set_default_font_size(font_size)
	click_label.theme = theme
	
	# Hide initially
	click_label.visible = false
	
	# Add to the scene
	add_child(click_label)
	
	print("DEBUG: Click counter label created with smaller font size")
	
func randomize_wander():
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_timer = randf_range(1.0, 3.0)
	#print("DEBUG: New wander direction: ", wander_direction)

func _process(delta):
	# Update state change timer
	state_change_timer = max(0, state_change_timer - delta)
	
	# Update pulse effect
	pulse_effect = sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * pulse_strength
	
	# Handle state-specific behavior
	match current_state:
		State.CUTE:
			process_cute_state(delta)
		State.SPIKEY:
			process_spikey_state(delta)
		State.ATTACHED:
			process_attached_state(delta)
		State.FLEEING:
			process_fleeing_state(delta)  # Process fleeing state
			# Ensure we always maintain initial scale in FLEEING state
			scale = initial_scale
	
	# Handle timers
	update_timers(delta)
	
	# Check for aggression
	check_aggression(delta)
	
	# Update wander timer
	wander_timer -= delta
	if wander_timer <= 0:
		randomize_wander()

func update_timers(delta):
	# Disinterest timer
	if disinterest_timer > 0:
		disinterest_timer -= delta
		if disinterest_timer <= 0:
			print("DEBUG: Disinterest period ended, starting aggression cooldown")
			aggression_cooldown_timer = aggression_cooldown_time
	
	# Aggression cooldown timer
	if aggression_cooldown_timer > 0:
		aggression_cooldown_timer -= delta
		# Visual indicator that it's becoming aggressive again
		if aggression_cooldown_timer <= 1.0:
			if int(aggression_cooldown_timer * 5) % 2 == 0:
				sprite.modulate = Color(1.2, 1.0, 1.0)
			else:
				sprite.modulate = Color(1.0, 1.0, 1.0)
	
	# Fleeing timer
	if fleeing_timer > 0:
		fleeing_timer -= delta
		if fleeing_timer <= 0 and current_state == State.FLEEING:
			print("DEBUG: Fleeing behavior finished, returning to CUTE state")
			set_state(State.CUTE)
	
	# Fear timer
	if fear_timer > 0:
		fear_timer -= delta

# Update to check_aggression function - increase aggression chance
func check_aggression(delta):
	# Only check for aggression if NOT disinterested, NOT fleeing, cooldown has expired, and state change timer expired
	if player and current_state == State.CUTE and disinterest_timer <= 0 and aggression_cooldown_timer <= 0 and state_change_timer <= 0:
		player_near_timer += delta
		
		# SIGNIFICANT INCREASE to aggression chance - was too subtle before
		var current_aggression_chance = aggression_chance * delta * (2.0 + player_near_timer * 2.0)
		
		#print("DEBUG: Checking aggression with chance: ", current_aggression_chance)
		
		if randf() < current_aggression_chance:
			print("DEBUG: Becoming aggressive. Chance was: ", current_aggression_chance)
			set_state(State.SPIKEY)
			# Reset state change timer to prevent rapid state changes
			state_change_timer = state_change_cooldown
			# Play warning sound
			# AudioManager.play_sfx("pathogen_transform")
	else:
		player_near_timer = max(0, player_near_timer - delta * 0.5)  # Gradually decay player_near_timer
	# Only check for aggression if NOT disinterested, NOT fleeing, cooldown has expired, and state change timer expired
	if player and current_state == State.CUTE and disinterest_timer <= 0 and aggression_cooldown_timer <= 0 and state_change_timer <= 0:
		player_near_timer += delta
		# Chance to become aggressive increases the longer player is nearby
		var current_aggression_chance = aggression_chance * delta * (1.0 + player_near_timer * 0.5)
		
		if randf() < current_aggression_chance:
			print("DEBUG: Becoming aggressive. Chance was: ", current_aggression_chance)
			set_state(State.SPIKEY)
			# Reset state change timer to prevent rapid state changes
			state_change_timer = state_change_cooldown
			# Play warning sound
			# AudioManager.play_sfx("pathogen_transform")
	else:
		player_near_timer = max(0, player_near_timer - delta * 0.5)  # Gradually decay player_near_timer

func process_cute_state(delta):
	# Update stunned timer if active
	if stunned_timer > 0:
		stunned_timer -= delta
		
		# Visual indicator of stunned state
		if int(stunned_timer * 5) % 2 == 0:  # Blink effect
			sprite.modulate = Color(1.5, 0.5, 0.5)
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0)
			
		# When stunned timer expires, reset modulate
		if stunned_timer <= 0:
			sprite.modulate = Color(1.0, 1.0, 1.0)
	
	# Apply velocity decay - more gentle during disinterest
	if velocity.length() > 5:
		if disinterest_timer > 0 || stunned_timer > 0:
			velocity = velocity * 0.92  # Slower decay when disinterested/stunned
		else:
			velocity = velocity * 0.85
	
	# Add cute pulsing effect when idle
	if velocity.length() < 20 and stunned_timer <= 0 and disinterest_timer <= 0:
		# Apply gentle breathing effect
		scale = initial_scale * (Vector2(1.0, 1.0) + Vector2(pulse_effect, pulse_effect))
	
	# Determine movement behavior
	if stunned_timer > 0:
		# While stunned, just slow down but don't change direction
		if velocity.length() > 20:
			print("DEBUG: Stunned state. Velocity: ", velocity)
	elif disinterest_timer > 0:
		# Move more predictably during disinterest - slower decay of velocity
		if velocity.length() > 20:
			print("DEBUG: Cute state with disinterest. Velocity: ", velocity)
	else:
		# Always wander in CUTE state, don't run away from player
		velocity = wander_direction * wander_speed
		
		# Debug logging for wandering behavior
		#if velocity.length() > 20:
			#print("DEBUG: Wandering in CUTE state, direction: ", wander_direction)
	
	# Apply the velocity
	move_and_slide()

func process_spikey_state(delta):
	if player and is_instance_valid(player):
		# Chase the player
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		
		# Calculate distance to player
		var distance = global_position.distance_to(player.global_position)
		#print("DEBUG: SPIKEY state chasing player, distance: ", distance)
		
		if Engine.get_frames_drawn() % 120 == 0:
			print("DEBUG: Still in SPIKEY state, velocity: ", velocity)
		
		# Apply deformation effect based on movement direction
		if deform_effect:
			var squish = 0.2
			scale = initial_scale * Vector2(
				1.0 - squish * abs(direction.x) + squish * abs(direction.y),
				1.0 - squish * abs(direction.y) + squish * abs(direction.x)
			)
		
		# Add aggressive pulsing if close to player
		if distance < flee_distance:
			# Increase pulse in anticipation of attachment
			pulse_strength = 0.15
			pulse_speed = 8.0
			
			# Add subtle red color shift
			sprite.modulate = Color(1.0 + pulse_effect * 0.5, 1.0 - pulse_effect * 0.2, 1.0 - pulse_effect * 0.2)
		else:
			pulse_strength = 0.1
			pulse_speed = 5.0
			sprite.modulate = Color(1.0, 1.0, 1.0)
		
		move_and_slide()
	else:
		# If player reference becomes invalid, revert to CUTE state
		print("DEBUG: Player reference lost in SPIKEY state, reverting to CUTE")
		set_state(State.CUTE)

func process_attached_state(delta):
	if player and is_instance_valid(player):
		# Stay attached to the player
		global_position = player.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		
		# Apply pulsing effect when attached
		pulse_strength = 0.15
		pulse_speed = 3.0
		scale = initial_scale * (Vector2(1.0, 1.0) + Vector2(pulse_effect, pulse_effect))
		
		# Alternate color slightly for visual feedback
		sprite.modulate = Color(1.0 + pulse_effect * 0.3, 1.0 - pulse_effect * 0.3, 1.0 - pulse_effect * 0.3)
		
		# Deal damage at intervals
		damage_timer += delta
		if damage_timer >= damage_interval:
			damage_timer = 0
			print("DEBUG: Pathogen attempting to damage player")
			
			# Safety check
			if !is_instance_valid(player):
				print("DEBUG: Player not valid when trying to apply damage")
				return
				
			# Check if player has PlayerStats component
			var player_stats = null
			if player.has_node("PlayerStats"):
				player_stats = player.get_node("PlayerStats")
			
			if player_stats and is_instance_valid(player_stats):
				print("DEBUG: About to call take_damage on player")
				# Use the non-awaited version
				var damage_applied = player_stats.take_damage(1)
				
				print("DEBUG: Damage applied result: ", damage_applied)
				
				# Play sound effect if damage was applied
				if damage_applied:
					# AudioManager.play_sfx("pathogen_damage")
					pass
			else:
				print("DEBUG: Player doesn't have valid PlayerStats component")
	else:
		print("DEBUG: Player not valid in process_attached_state, current_state: ", current_state)
		# Automatically detach if player is no longer valid
		if current_state == State.ATTACHED:
			print("DEBUG: Auto-detaching from invalid player")
			set_state(State.FLEEING)  # Change to FLEEING instead of CUTE
			fleeing_timer = fleeing_duration
			disinterest_timer = disinterest_time

# Updated process_fleeing_state function to fix scaling issues
func process_fleeing_state(delta):
	#print("DEBUG: Processing FLEEING state, timer: ", fleeing_timer)
	
	# Apply high velocity decay to make movement more pronounced
	velocity = velocity * 0.95
	
	# If we have a player reference, update fleeing direction
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		# Always prioritize moving away from player when fleeing
		var flee_direction = (global_position - player.global_position).normalized()
		
		# Apply a strong fleeing force
		if distance < flee_distance * 2:  # Wider range for fleeing
			velocity = flee_direction * flee_speed
			#print("DEBUG: Fleeing from player, velocity: ", velocity)
		else:
			# Still flee but with reduced speed when farther away
			velocity = flee_direction * flee_speed * 0.7
	
	# IMPORTANT: Ensure scale is maintained at initial_scale - NO DEFORMATION in fleeing
	# Instead of deformation, use color-based feedback for fleeing
	scale = initial_scale
	
	# Use color pulsing instead of scale pulsing for visual feedback
	var color_pulse = abs(sin(Time.get_ticks_msec() * 0.01)) * 0.3
	sprite.modulate = Color(1.0 + color_pulse, 1.0, 1.0)
	
	# Log the current scale to track any changes
	if Engine.get_frames_drawn() % 30 == 0:
		print("DEBUG: Current scale during FLEEING: ", scale, ", initial_scale: ", initial_scale)
	
	# Apply the velocity
	move_and_slide()

func set_state(new_state):
	var old_state = current_state
	current_state = new_state
	
	print("DEBUG: State changing from ", old_state, " to ", new_state)
	
	# IMPORTANT: Explicitly set scale to initial_scale on EVERY state change
	scale = initial_scale
	print("DEBUG: Reset scale to initial: ", initial_scale)
	
	# Reset certain values on state change
	if old_state != new_state:
		emit_signal("state_changed", new_state)
		
		# Visual feedback for state change
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color(2.0, 1.5, 1.5), 0.15)  # More noticeable flash
		flash_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.15)
		
		# Scale pop effect on state change but not too big
		var pop_tween = create_tween()
		pop_tween.tween_property(self, "scale", initial_scale * 1.2, 0.1)  # Reduced from 1.3 to 1.2
		pop_tween.tween_property(self, "scale", initial_scale, 0.2)
		
		# IMPORTANT: Manage group membership based on state
		if new_state == State.CUTE || new_state == State.FLEEING:
			# Remove from attack group when in CUTE or FLEEING state
			if is_in_group("enemy_attack"):
				remove_from_group("enemy_attack")
			print("DEBUG: Removed from enemy_attack group")
		else:
			# Add to attack group when in SPIKEY or ATTACHED state
			if !is_in_group("enemy_attack"):
				add_to_group("enemy_attack")
			print("DEBUG: Added to enemy_attack group")
		
		# Manage hit_area groups too
		if new_state == State.CUTE || new_state == State.FLEEING:
			if hit_area.is_in_group("enemy_attack"):
				hit_area.remove_from_group("enemy_attack")
		else:
			if !hit_area.is_in_group("enemy_attack"):
				hit_area.add_to_group("enemy_attack")
		
		# Hide click counter when changing states
		if is_instance_valid(click_label):
			click_label.visible = false
	
	match new_state:
		State.CUTE:
			update_sprite(true)  # true for cute sprite
			# Use set_deferred to avoid errors when changing physics properties
			collision_shape.set_deferred("disabled", false)
			
			# Reset pulse parameters
			pulse_strength = 0.1
			pulse_speed = 5.0
			
			# Make sure physics processing is enabled when returning to CUTE state
			set_physics_process(true)
			
			# Emit particles for transformation if returning from spikey
			if old_state == State.SPIKEY or old_state == State.ATTACHED:
				print("DEBUG: Transforming back to CUTE from ", old_state)
				# Could add particles here if desired
		
		State.SPIKEY:
			update_sprite(false)  # false for spikey sprite
			# Use set_deferred to avoid errors when changing physics properties
			collision_shape.set_deferred("disabled", false)
			
			# Adjust pulse parameters for aggressive look
			pulse_strength = 0.15
			pulse_speed = 6.0
			
			# Reset player near timer
			player_near_timer = 0
		
		State.ATTACHED:
			update_sprite(false)  # false for spikey sprite
			# Use set_deferred to avoid errors when changing physics properties
			collision_shape.set_deferred("disabled", true)
			damage_timer = 0
			current_clicks = 0
			
			# Set pulse parameters for attached state
			pulse_strength = 0.15
			pulse_speed = 3.0
			
			# Show click counter with a more concise message when attached
			if is_instance_valid(click_label):
				click_label.text = "Click " + str(clicks_to_remove) + "x"
				click_label.visible = true
		
		State.FLEEING:
			update_sprite(true)  # true for cute sprite
			# Use set_deferred to avoid errors when changing physics properties
			collision_shape.set_deferred("disabled", false)
			
			# Set pulse parameters for fleeing state - faster breathing
			pulse_strength = 0.15  # Reduced from 0.2 to prevent looking bigger
			pulse_speed = 10.0
			
			print("DEBUG: Entering FLEEING state, timer set to: ", fleeing_timer)
	
	# Force scale reset again after state change to be absolutely sure
	scale = initial_scale
	print("DEBUG: Additional explicit scale reset after state change: ", scale)

# Update the sprite based on the state
func update_sprite(is_cute: bool):
	if is_cute:
		# Change to cute sprite
		sprite.texture = preload("res://assets/sprites/enemies/pathogen/pathogen_nice.png")  # Replace with your actual path
	else:
		# Change to spikey sprite
		sprite.texture = preload("res://assets/sprites/enemies/pathogen/pathogen_attack.png")  # Replace with your actual path

func _on_detection_area_body_entered(body):
	if body.is_in_group("player") and disinterest_timer <= 0:
		player = body
		print("DEBUG: Player entered detection area, distance: ", global_position.distance_to(body.global_position))
		print("DEBUG: Current state: ", current_state, ", aggression_cooldown_timer: ", aggression_cooldown_timer, ", state_change_timer: ", state_change_timer)
		
		# In cute state, initially be scared but don't immediately turn aggressive
		if current_state == State.CUTE:
			fear_timer = 0.5
			
			# Small chance to immediately become aggressive if cooldown allows
			if randf() < 0.1 and aggression_cooldown_timer <= 0 and state_change_timer <= 0:
				print("DEBUG: Immediate aggression triggered")
				# Use call_deferred to avoid physics callback errors
				call_deferred("set_state", State.SPIKEY)
				# Reset state change timer
				state_change_timer = state_change_cooldown
				# AudioManager.play_sfx("pathogen_transform")

func _on_detection_area_body_exited(body):
	if body == player:
		print("DEBUG: Player exited detection area")
		player = null
		player_near_timer = 0

func _on_hit_area_body_entered(body):
	print("DEBUG: Something entered hit area: ", body.name)
	if body.is_in_group("player"):
		print("DEBUG: Player entered hit area")
		if current_state == State.SPIKEY:
			# Use call_deferred to avoid physics callback errors
			call_deferred("set_state", State.ATTACHED)
			print("DEBUG: Attaching to player")
			# AudioManager.play_sfx("pathogen_attach")
		elif current_state == State.CUTE:
			# Player "attacked" the pathogen while it was in cute state
			print("DEBUG: Player hit pathogen in CUTE state")
			# take_damage is safe to call directly since it doesn't modify physics properties
			take_damage(1)
			
			# Push the pathogen away
			var dir = (global_position - body.global_position).normalized()
			velocity = dir * 250

func _input(event):
	if current_state == State.ATTACHED and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Make the click detection area larger for better user experience
			var mouse_pos = get_global_mouse_position()
			
			# Create a larger detection area (2x the sprite size)
			if sprite.texture:
				var texture_size = sprite.texture.get_size()
				var pathogen_rect = Rect2(
					global_position - texture_size * 0.7,  # Increased size for easier clicking
					texture_size * 1.4                     # Doubled size
				)
				
				if pathogen_rect.has_point(mouse_pos):
					handle_click()
					print("DEBUG: Click detected in enlarged hit area")

var stunned_timer: float = 0.0  # Timer for stunned effect after detachment

func handle_click():
	print("DEBUG: handle_click() called, current_clicks: ", current_clicks, " of ", clicks_to_remove)
	current_clicks += 1
	
	# Visual feedback for click - MORE OBVIOUS FEEDBACK
	# Flash more dramatically
	sprite.modulate = Color(2.0, 2.0, 2.0)  # Brighter flash
	var click_tween = create_tween()
	click_tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
	
	# Apply more dramatic squishing effect
	scale = initial_scale * Vector2(0.7, 1.3)  # More extreme for better feedback
	var click_squish_tween = create_tween()
	click_squish_tween.tween_property(self, "scale", initial_scale, 0.3)  # Longer duration
	
	# Play click sound
	# AudioManager.play_sfx("pathogen_click")
	
	# Show click feedback (number of clicks remaining)
	var clicks_remaining = clicks_to_remove - current_clicks
	print("DEBUG: Remaining clicks to remove: ", clicks_remaining)
	
	# Update and show the click counter label
	if is_instance_valid(click_label):
		if clicks_remaining > 0:
			click_label.text = str(clicks_remaining) + "x"
		else:
			click_label.text = "Removing!"
		click_label.visible = true
		
		# Auto-hide the label after a delay using a tween
		if clicks_remaining > 0:
			var label_tween = create_tween()
			label_tween.tween_property(click_label, "modulate:a", 1.0, 0.1)
			# Keep it visible for a moment then fade out if not removed yet
			label_tween.tween_interval(0.5)  # Reduced from 0.7 to 0.5
			label_tween.tween_property(click_label, "modulate:a", 0.0, 0.2)  # Reduced from 0.3 to 0.2
	
	# Display number of clicks remaining on screen
	if clicks_remaining > 0:
		# Visual indicator of progress - pulse effect
		var progress_pulse_tween = create_tween()
		progress_pulse_tween.tween_property(self, "scale", initial_scale * 1.3, 0.1)
		progress_pulse_tween.tween_property(self, "scale", initial_scale, 0.2)
	
	if current_clicks >= clicks_to_remove:
		print("DEBUG: Detaching from player")
		
		# Hide the click counter
		if is_instance_valid(click_label):
			click_label.visible = false
		
		# Store player reference before changing state
		var player_ref = player
		
		# IMPORTANT: Finish all active tweens before state change
		var active_tweens = get_tree().get_processed_tweens()
		for tween in active_tweens:
			if tween.is_valid():
				tween.kill()  # Stop all ongoing tweens
		
		# Reset scale immediately before state change - CRUCIAL
		scale = initial_scale
		print("DEBUG: Explicit scale reset before state change: ", scale)
		
		# Change state to FLEEING instead of CUTE
		set_state(State.FLEEING)
		
		# Force scale reset again after state change to be absolutely sure
		scale = initial_scale
		print("DEBUG: Additional explicit scale reset after state change: ", scale)
		
		disinterest_timer = disinterest_time
		# Ensure fleeing timer is positive
		fleeing_timer = max(0.1, fleeing_duration)  # Always ensure positive value
		print("DEBUG: Set fleeing_timer to: ", fleeing_timer)
		
		# Move away from player (using stored reference) - but more smoothly
		if player_ref and is_instance_valid(player_ref):
			print("DEBUG: Player position: ", player_ref.global_position)
			print("DEBUG: Pathogen position: ", global_position)
			
			# Calculate direction away from player
			var away_dir = (global_position - player_ref.global_position).normalized()
			
			# If direction is zero (rare case when positions are identical), use a random direction
			if away_dir.length() < 0.1:
				away_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				
			print("DEBUG: Away direction vector: ", away_dir)
			
			# Apply a SMALLER immediate position offset - just enough to separate
			global_position += away_dir * 20
			
			# Apply STRONGER velocity for more obvious fleeing
			velocity = away_dir * flee_speed * 1.5
			
			print("DEBUG: New pathogen position: ", global_position)
			print("DEBUG: Applied fleeing velocity: ", velocity)
			print("DEBUG: Scale after detach: ", scale)
		else:
			print("DEBUG: Player reference invalid during detach")
			# If player reference is invalid, still give it a random push
			var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			velocity = random_dir * flee_speed * 1.0
		
		# Flash effect to indicate removal (no scale changes)
		var flash_sequence = create_tween()
		flash_sequence.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.1)  # Bright white
		flash_sequence.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
		flash_sequence.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.1)
		flash_sequence.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
		
		# Make sure physics processing is enabled
		set_physics_process(true)
			
		# Play detach sound
		# AudioManager.play_sfx("pathogen_detach")

func take_damage(amount):
	# Allow taking damage in CUTE state only
	if current_state == State.CUTE:
		print("DEBUG: Pathogen taking damage: ", amount, ", current health: ", health)
		health -= amount
		
		# Reset visual properties directly before creating new tweens
		sprite.modulate = Color(2.0, 0.3, 0.3)  # Brighter red flash
		scale = initial_scale * Vector2(1.3, 0.7)  # More dramatic squish effect
		
		# Visual feedback
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)  # Longer flash duration
		
		# Apply squishing effect with more dramatic elastic rebound
		var squish_tween = create_tween()
		squish_tween.tween_property(self, "scale", initial_scale, 0.4).set_trans(Tween.TRANS_ELASTIC)
		
		# Play hit sound
		# AudioManager.play_sfx("pathogen_hit")
		
		# Apply a stronger knockback force when hit
		if player and is_instance_valid(player):
			var knockback_dir = (global_position - player.global_position).normalized()
			velocity = knockback_dir * flee_speed * 1.5
		
		# Small chance to turn aggressive when damaged, but not when disinterested
		if health > 0 and randf() < 0.3 and disinterest_timer <= 0 and stunned_timer <= 0 and state_change_timer <= 0:
			set_state(State.SPIKEY)
			state_change_timer = state_change_cooldown
			# AudioManager.play_sfx("pathogen_angry")
		
		if health <= 0:
			die()
		
		return true
	else:
		print("DEBUG: Pathogen cannot take damage in current state: ", current_state)
	return false

# Modified to be non-async
func die():
	print("DEBUG: Pathogen die() function executing, health: ", health)
	
	# Disable collisions immediately
	collision_shape.set_deferred("disabled", true)
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)
	
	# Disable processing
	set_process(false)
	set_physics_process(false)
	
	# Death animation - more dramatic splat effect
	var death_tween = create_tween()
	# First expand
	death_tween.tween_property(self, "scale", initial_scale * Vector2(1.5, 1.5), 0.1)
	# Then splat
	death_tween.tween_property(self, "scale", initial_scale * Vector2(2.0, 0.1), 0.2)
	death_tween.tween_property(self, "scale", initial_scale * 0.1, 0.3)
	death_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Flash red before disappearing
	var color_tween = create_tween()
	color_tween.tween_property(self, "modulate", Color(2.0, 0.3, 0.3), 0.1)
	color_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	
	# Play death sound
	# AudioManager.play_sfx("pathogen_death")
	
	# Connect to tween finished signal and ensure it actually queues_free
	# the node when completed
	death_tween.finished.connect(func():
		print("DEBUG: Pathogen being removed from scene")
		queue_free()
	)
	
	# Safety mechanism - queue_free after a delay even if tween fails
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			print("DEBUG: Safety queue_free triggered for pathogen")
			queue_free() 
	)
