extends CharacterBody2D

enum State {CUTE, SPIKEY, ATTACHED}

signal state_changed(new_state)

# Configuration
@export var move_speed: float = 150.0
@export var flee_speed: float = 100.0
@export var detection_radius: float = 200.0
@export var flee_distance: float = 100.0
@export var aggression_chance: float = 0.2  # Chance to turn aggressive when player is nearby
@export var health: int = 1  # REDUCED from 3 to 1 for easier killing
@export var damage_interval: float = 1.0  # How often it damages the player when attached
@export var disinterest_time: float = 5.0  # Time to remain disinterested after being removed

# State variables
var current_state: int = State.CUTE
var player: CharacterBody2D = null
var damage_timer: float = 0.0
var clicks_to_remove: int = 1
var current_clicks: int = 0
var disinterest_timer: float = 0.0
var initial_scale: Vector2
var fear_timer: float = 0.0
var player_near_timer: float = 0.0
var wander_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO

var aggression_cooldown_timer: float = 0.0
var aggression_cooldown_time: float = 3.0  # Time after disinterest before becoming aggressive again

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
	
	# Set up the initial state
	set_state(State.CUTE)
	
	# Connect signals
	detection_area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))
	hit_area.connect("body_entered", Callable(self, "_on_hit_area_body_entered"))
	
	# Add to enemy group but NOT enemy_attack when starting in CUTE state
	add_to_group("enemy")
	
	# Set up the hit_area group
	hit_area.add_to_group("enemy_hitbox")
	
	# Set up initial wander direction
	randomize_wander()
	
	# Connect click input
	set_process_input(true)
	
	# Debug
	print("DEBUG: Pathogen initialized with health: ", health)
	
func randomize_wander():
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_timer = randf_range(1.0, 3.0)

func _process(delta):
	# Handle state-specific behavior
	match current_state:
		State.CUTE:
			process_cute_state(delta)
		State.SPIKEY:
			process_spikey_state(delta)
		State.ATTACHED:
			process_attached_state(delta)
	
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
				sprite.modulate = Color(1.0, 1.0, 1.0)
			else:
				sprite.modulate = Color(1.2, 1.0, 1.0)
	
	# Fear timer
	if fear_timer > 0:
		fear_timer -= delta

func check_aggression(delta):
	# Only check for aggression if NOT disinterested AND cooldown has expired
	if player and current_state == State.CUTE and disinterest_timer <= 0 and aggression_cooldown_timer <= 0:
		player_near_timer += delta
		# Chance to become aggressive increases the longer player is nearby
		if randf() < aggression_chance * delta * (1 + player_near_timer):
			print("DEBUG: Becoming aggressive")
			set_state(State.SPIKEY)
			# Play warning sound
			# AudioManager.play_sfx("pathogen_transform")
	else:
		player_near_timer = 0.0

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
	
	# Determine movement behavior
	if stunned_timer > 0:
		# While stunned, just slow down but don't change direction
		# This makes the pathogen easier to hit after detachment
		if velocity.length() > 20:
			print("DEBUG: Stunned state. Velocity: ", velocity)
	elif disinterest_timer > 0:
		# Move more predictably during disinterest - slower decay of velocity
		if velocity.length() > 20:
			print("DEBUG: Cute state with disinterest. Velocity: ", velocity)
	elif player and is_instance_valid(player):
		# Calculate distance to player
		var distance = global_position.distance_to(player.global_position)
		
		if distance < flee_distance:
			# Move away from player (act scared)
			var flee_direction = (global_position - player.global_position).normalized()
			velocity = flee_direction * flee_speed
			
			# Visual "scared" effect - slight trembling
			if deform_effect:
				var tremble = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
				scale = initial_scale * (Vector2(1, 1) + tremble)
		else:
			# Normal wandering
			velocity = wander_direction * (move_speed * 0.5)
	else:
		# Normal wandering when no player is around
		velocity = wander_direction * (move_speed * 0.5)
	
	# Apply the velocity
	move_and_slide()

func process_spikey_state(delta):
	if player and is_instance_valid(player):
		# Chase the player
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		
		# Apply deformation effect based on movement direction
		if deform_effect:
			var squish = 0.2
			scale = initial_scale * Vector2(
				1.0 - squish * abs(direction.x) + squish * abs(direction.y),
				1.0 - squish * abs(direction.y) + squish * abs(direction.x)
			)
		
		move_and_slide()

func process_attached_state(delta):
	if player and is_instance_valid(player):
		# Stay attached to the player
		global_position = player.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		
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
			set_state(State.CUTE)
			disinterest_timer = disinterest_time

func set_state(new_state):
	var old_state = current_state
	current_state = new_state
	
	print("DEBUG: State changing from ", old_state, " to ", new_state)
	
	# IMPORTANT: Explicitly set scale to initial_scale on EVERY state change
	scale = initial_scale
	
	# Reset certain values on state change
	if old_state != new_state:
		emit_signal("state_changed", new_state)
		
		# Visual feedback for state change
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		flash_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
		
		# IMPORTANT: Manage group membership based on state
		if new_state == State.CUTE:
			# Remove from attack group when in CUTE state
			if is_in_group("enemy_attack"):
				remove_from_group("enemy_attack")
			print("DEBUG: Removed from enemy_attack group")
		else:
			# Add to attack group when in SPIKEY or ATTACHED state
			if !is_in_group("enemy_attack"):
				add_to_group("enemy_attack")
			print("DEBUG: Added to enemy_attack group")
		
		# Manage hit_area groups too
		if new_state == State.CUTE:
			if hit_area.is_in_group("enemy_attack"):
				hit_area.remove_from_group("enemy_attack")
		else:
			if !hit_area.is_in_group("enemy_attack"):
				hit_area.add_to_group("enemy_attack")
	
	match new_state:
		State.CUTE:
			update_sprite(true)  # true for cute sprite
			# Use set_deferred to avoid errors when changing physics properties
			collision_shape.set_deferred("disabled", false)
			
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
			
			# Reset player near timer
			player_near_timer = 0
		
		State.ATTACHED:
			update_sprite(false)  # false for spikey sprite
			# Use set_deferred to avoid errors when changing physics properties
			collision_shape.set_deferred("disabled", true)
			damage_timer = 0
			current_clicks = 0

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
		
		# In cute state, initially be scared but don't immediately turn aggressive
		if current_state == State.CUTE:
			fear_timer = 0.5
			
			# Small chance to immediately become aggressive
			if randf() < 0.1 and aggression_cooldown_timer <= 0:
				# Use call_deferred to avoid physics callback errors
				call_deferred("set_state", State.SPIKEY)
				# AudioManager.play_sfx("pathogen_transform")

func _on_detection_area_body_exited(body):
	if body == player:
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
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Check if the click is on this pathogen
			var mouse_pos = get_global_mouse_position()
			
			# Make sure the texture is loaded before trying to get its size
			if sprite.texture:
				var pathogen_rect = Rect2(global_position - sprite.texture.get_size() * 0.5, sprite.texture.get_size())
				
				if pathogen_rect.has_point(mouse_pos):
					handle_click()

var stunned_timer: float = 0.0  # Timer for stunned effect after detachment

func handle_click():
	print("DEBUG: handle_click() called, current_clicks: ", current_clicks)
	current_clicks += 1
	
	# Visual feedback for click
	sprite.modulate = Color(1.5, 1.5, 1.5)  # Flash white
	var click_tween = create_tween()
	click_tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
	
	# Apply squishing effect - but keep it very subtle
	scale = initial_scale * Vector2(0.9, 1.1)  # Less extreme
	var click_squish_tween = create_tween()
	click_squish_tween.tween_property(self, "scale", initial_scale, 0.2)  # Shorter duration
	
	# Play click sound
	# AudioManager.play_sfx("pathogen_click")
	
	# Show click feedback (number of clicks remaining)
	var clicks_remaining = clicks_to_remove - current_clicks
	print("DEBUG: Remaining clicks to remove: ", clicks_remaining)
	
	if current_clicks >= clicks_to_remove:
		print("DEBUG: Detaching from player")
		
		# Store player reference before changing state
		var player_ref = player
		
		# IMPORTANT: Finish all active tweens before state change
		var active_tweens = get_tree().get_processed_tweens()
		for tween in active_tweens:
			if tween.is_valid():
				tween.kill()  # Stop all ongoing tweens
		
		# Reset scale immediately before state change
		scale = initial_scale
		print("DEBUG: Explicit scale reset before state change: ", scale)
		
		# Change state first (this resets some variables)
		set_state(State.CUTE)
		disinterest_timer = disinterest_time
		stunned_timer = 1.0  # Set stunned timer for 1 second
		
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
			
			# Apply milder velocity for more hittable movement
			velocity = away_dir * flee_speed * 1.2
			
			# NO visual effect for push away - use velocity only
			print("DEBUG: New pathogen position: ", global_position)
			print("DEBUG: Applied velocity: ", velocity)
			print("DEBUG: Scale after detach: ", scale)
		else:
			print("DEBUG: Player reference invalid during detach")
			# If player reference is invalid, still give it a random push
			var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			velocity = random_dir * flee_speed * 1.0
		
		# Flash effect to indicate vulnerability (no scale changes)
		var flash_sequence = create_tween()
		flash_sequence.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		flash_sequence.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
		flash_sequence.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		flash_sequence.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
		
		# Make sure physics processing is enabled
		set_physics_process(true)
			
		# Play detach sound
		# AudioManager.play_sfx("pathogen_detach")

func take_damage(amount):
	# Allow taking damage in CUTE state or while stunned
	if current_state == State.CUTE:
		print("DEBUG: Pathogen taking damage: ", amount)
		health -= amount
		
		# Reset visual properties directly before creating new tweens
		sprite.modulate = Color(1.5, 0.3, 0.3)  # Flash red
		scale = initial_scale * Vector2(1.2, 0.8)  # Squish effect
		
		# Visual feedback
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
		
		# Apply squishing effect
		var squish_tween = create_tween()
		squish_tween.tween_property(self, "scale", initial_scale, 0.3).set_trans(Tween.TRANS_ELASTIC)
		
		# Play hit sound
		# AudioManager.play_sfx("pathogen_hit")
		
		# Apply a stronger knockback force when hit
		if player and is_instance_valid(player):
			var knockback_dir = (global_position - player.global_position).normalized()
			velocity = knockback_dir * flee_speed * 2.0
		
		# Small chance to turn aggressive when damaged, but not when disinterested
		if health > 0 and randf() < 0.3 and disinterest_timer <= 0 and stunned_timer <= 0:
			set_state(State.SPIKEY)
			# AudioManager.play_sfx("pathogen_angry")
		
		if health <= 0:
			die()
		
		return true
	return false

# Modified to be non-async
func die():
	print("DEBUG: Pathogen die() function executing")
	
	# Disable collisions immediately
	collision_shape.set_deferred("disabled", true)
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)
	
	# Disable processing
	set_process(false)
	set_physics_process(false)
	
	# Death animation - splat effect
	var death_tween = create_tween()
	death_tween.tween_property(self, "scale", initial_scale * Vector2(1.5, 0.2), 0.2)
	death_tween.tween_property(self, "scale", initial_scale * 0.1, 0.3)
	death_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	
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
