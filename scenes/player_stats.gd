# PlayerStats.gd
extends Node

signal health_changed(new_health, max_health)
signal player_died

@export var max_health: int = 3
@export var current_health: int = 3
@export var immunity_time: float = 1.0

var init_position: Vector2
var immune_timer: float = 0.0
var is_alive: bool = true
var player_node: CharacterBody2D
var death_tween: Tween = null
var is_respawning: bool = false

func _ready():
	print("DEBUG: PlayerStats._ready()")
	# Initialize health
	current_health = max_health
	
	# Get reference to parent player node
	player_node = get_parent()
	init_position = player_node.global_position

func _process(delta):
	# Update immunity timer
	if immune_timer > 0:
		immune_timer -= delta
		# Make the sprite blink when immune
		if is_instance_valid(player_node):
			player_node.modulate.a = 0.6 if int(immune_timer * 10) % 2 == 0 else 1.0
	else:
		if is_instance_valid(player_node):
			player_node.modulate.a = 1.0

func take_damage(amount: int = 1):
	print("DEBUG: take_damage() called with amount: ", amount, ", current health: ", current_health)
	# Skip if currently immune or dead
	if immune_timer > 0 or !is_alive:
		print("DEBUG: Damage ignored - immune: ", immune_timer > 0, ", dead: ", !is_alive)
		return false
	
	# Apply damage
	current_health -= amount
	print("DEBUG: Health after damage: ", current_health)
	
	# Skip visual effects if player_node is not valid
	if !is_instance_valid(player_node):
		print("DEBUG: Player node is not valid during take_damage")
		return false
	
	# Flash red
	player_node.modulate = Color(1.5, 0.3, 0.3)
	flash_after_delay()
	
	# Apply deformation effect for damage
	apply_damage_deformation()
	
	# Disable movement briefly when hit
	var was_moving = false
	if player_node.has_method("disable_movement"):
		was_moving = player_node.can_move
		player_node.disable_movement()
		stun_for_duration(0.2, was_moving)
	
	# Start immunity period
	immune_timer = immunity_time
	
	# Emit signal that health changed
	emit_signal("health_changed", current_health, max_health)
	
	# Check for death
	if current_health <= 0:
		die()
		return true
	
	# Play damage sound
	# AudioManager.play_sfx("player_hurt")
	
	return true

# Non-async helper functions that schedule tasks without awaiting
func flash_after_delay():
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func():
		if is_instance_valid(player_node):
			player_node.modulate = Color(1, 1, 1)
	)

func stun_for_duration(duration, was_moving):
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if was_moving and is_alive and is_instance_valid(player_node) and player_node.has_method("enable_movement"):
			player_node.enable_movement()
	)

func apply_damage_deformation():
	if !is_instance_valid(player_node):
		print("DEBUG: Cannot apply deformation - player node invalid")
		return
		
	# Check if initial_scale exists as a property using get_property_list()
	var has_initial_scale = false
	for property in player_node.get_property_list():
		if property["name"] == "initial_scale":
			has_initial_scale = true
			break
			
	if !has_initial_scale:
		print("DEBUG: Player node doesn't have initial_scale property")
		return
		
	# Apply stronger, random deformation
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var squish = 0.4  # Stronger deformation when hit
	
	player_node.scale = player_node.initial_scale * Vector2(
		1.0 - squish * random_dir.x,
		1.0 - squish * random_dir.y
	)

func heal(amount: int = 1):
	print("DEBUG: heal() called with amount: ", amount)
	if current_health < max_health and is_alive:
		current_health = min(current_health + amount, max_health)
		print("DEBUG: Health after healing: ", current_health)
		
		if !is_instance_valid(player_node):
			print("DEBUG: Player node is not valid during heal")
			return
			
		# Flash green for healing
		player_node.modulate = Color(0.3, 1.5, 0.3)
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(func():
			if is_instance_valid(player_node):
				player_node.modulate = Color(1, 1, 1)
		)
		
		# Emit signal that health changed
		emit_signal("health_changed", current_health, max_health)
		
		# Play healing sound
		# AudioManager.play_sfx("player_heal")

func die():
	print("DEBUG: die() called, is_alive: ", is_alive)
	# Safety check - don't run die() more than once
	if !is_alive:
		print("DEBUG: Player already dead, ignoring die() call")
		return
		
	is_alive = false
	
	if !is_instance_valid(player_node):
		print("DEBUG: Player node is not valid during die()")
		return
		
	if player_node.has_method("disable_movement"):
		player_node.disable_movement()
	
	# If there's an existing death tween, kill it
	if death_tween != null and death_tween.is_valid():
		death_tween.kill()
		print("DEBUG: Killed existing death tween")
	
	# Death animation - break apart
	death_tween = create_tween()
	if !is_instance_valid(player_node):
		print("DEBUG: Player node is not valid after creating death tween")
		return
	
	# Try to safely access initial_scale	
	var initial_scale_value = Vector2(1, 1)  # Default fallback
	if player_node.get("initial_scale") != null:
		initial_scale_value = player_node.initial_scale
		
	death_tween.tween_property(player_node, "scale", initial_scale_value * 0.1, 0.5)
	death_tween.parallel().tween_property(player_node, "modulate:a", 0.0, 0.5)
	
	# Emit signal that player died
	emit_signal("player_died")
	print("DEBUG: Player died signal emitted")
	
	# Schedule respawn 
	var respawn_timer = get_tree().create_timer(1.0)
	# Use a lambda to avoid async
	respawn_timer.timeout.connect(func(): 
		print("DEBUG: Respawn timer triggered")
		respawn()
	)

func respawn():
	print("DEBUG: respawn() called, is_respawning: ", is_respawning)
	# Prevent multiple respawns
	if is_respawning:
		print("DEBUG: Already respawning, ignoring additional respawn call")
		return
		
	is_respawning = true
	
	# Safety check - don't respawn if the node is being freed
	if !is_instance_valid(player_node) or player_node.is_queued_for_deletion():
		print("DEBUG: Cannot respawn - player node invalid or being deleted")
		is_respawning = false
		return
	
	print("DEBUG: Resetting player position and state")
	# Reset position to last checkpoint
	player_node.global_position = init_position
	player_node.velocity = Vector2.ZERO
	
	# Reset health
	current_health = max_health
	is_alive = true
	
	# Reset visual properties
	if player_node.get("initial_scale") != null:
		player_node.scale = player_node.initial_scale
	else:
		player_node.scale = Vector2(1, 1)  # Default fallback
	
	player_node.modulate = Color(1, 1, 1)
	
	# Clear trail
	if player_node.has_method("clear_trail"):
		player_node.clear_trail()
	
	# Enable movement
	if player_node.has_method("enable_movement"):
		player_node.enable_movement()
	
	# Reset immunity
	immune_timer = 2.0  # Give player time after respawn
	
	# Emit signal that health changed
	emit_signal("health_changed", current_health, max_health)
	
	is_respawning = false
	print("DEBUG: Respawn completed successfully")
