# PlayerStats.gd
extends Node

signal health_changed(new_health, max_health)
signal player_died

@export var max_health: int = 3
@export var current_health: int = 3
@export var immunity_time: float = 1.0

var immune_timer: float = 0.0
var is_alive: bool = true
var player_node: CharacterBody2D

func _ready():
	# Initialize health
	current_health = max_health
	
	# Get reference to parent player node
	player_node = get_parent()

func _process(delta):
	# Update immunity timer
	if immune_timer > 0:
		immune_timer -= delta
		# Make the sprite blink when immune
		player_node.modulate.a = 0.6 if int(immune_timer * 10) % 2 == 0 else 1.0
	else:
		player_node.modulate.a = 1.0

func take_damage(amount: int = 1):
	# Skip if currently immune or dead
	if immune_timer > 0 or !is_alive:
		return false
	
	# Apply damage
	current_health -= amount
	
	# Flash red
	player_node.modulate = Color(1.5, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	player_node.modulate = Color(1, 1, 1)
	
	# Apply deformation effect for damage
	apply_damage_deformation()
	
	# Disable movement briefly when hit
	var was_moving = player_node.can_move
	player_node.disable_movement()
	await get_tree().create_timer(0.2).timeout
	if was_moving:
		player_node.enable_movement()
	
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

func apply_damage_deformation():
	# Apply stronger, random deformation
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var squish = 0.4  # Stronger deformation when hit
	
	player_node.scale = player_node.initial_scale * Vector2(
		1.0 - squish * random_dir.x,
		1.0 - squish * random_dir.y
	)

func heal(amount: int = 1):
	if current_health < max_health and is_alive:
		current_health = min(current_health + amount, max_health)
		
		# Flash green for healing
		player_node.modulate = Color(0.3, 1.5, 0.3)
		await get_tree().create_timer(0.1).timeout
		player_node.modulate = Color(1, 1, 1)
		
		# Emit signal that health changed
		emit_signal("health_changed", current_health, max_health)
		
		# Play healing sound
		# AudioManager.play_sfx("player_heal")

func die():
	is_alive = false
	player_node.disable_movement()
	
	# Death animation - break apart
	var death_tween = create_tween()
	death_tween.tween_property(player_node, "scale", player_node.initial_scale * 0.1, 0.5)
	death_tween.parallel().tween_property(player_node, "modulate:a", 0.0, 0.5)
	
	# Emit signal that player died
	emit_signal("player_died")
	
	# Trigger game over or respawn
	await get_tree().create_timer(1.0).timeout
	respawn()

func respawn():
	# Reset position to last checkpoint
	# player_node.position = last_checkpoint_position
	
	# Reset health
	current_health = max_health
	is_alive = true
	
	# Reset visual properties
	player_node.scale = player_node.initial_scale
	player_node.modulate.a = 1.0
	
	# Clear trail
	player_node.clear_trail()
	
	# Enable movement
	player_node.enable_movement()
	
	# Reset immunity
	immune_timer = 2.0  # Give player time after respawn
	
	# Emit signal that health changed
	emit_signal("health_changed", current_health, max_health)
