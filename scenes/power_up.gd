# power_up.gd - Simplified version
extends Area2D

enum PowerUpType {
	SPEED,
	ATTACK,
	SHIELD
}

@export var power_up_type: PowerUpType = PowerUpType.SPEED
@export var duration: float = 10.0
@export var effect_strength: float = 1.5  # Multiplier for the effect
@export var bobbing_height: float = 5.0
@export var bobbing_speed: float = 2.0
@export var rotation_speed: float = 1.0

var initial_position: Vector2
var time_offset: float
var ui_reference: CanvasLayer

func _ready():
	# Connect signal for body entered
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Store initial position for bobbing animation
	initial_position = position
	
	# Random time offset for bobbing animation
	time_offset = randf() * 10.0
	
	# Setup visuals based on power-up type
	setup_visuals()
	
	# Try to find the UI
	await get_tree().process_frame
	var ui_nodes = get_tree().get_nodes_in_group("game_ui")
	if ui_nodes.size() > 0:
		ui_reference = ui_nodes[0]
		print("DEBUG: Power-up found UI reference")

func _process(delta):
	# Bobbing animation
	position.y = initial_position.y + sin((Time.get_ticks_msec() * 0.001 + time_offset) * bobbing_speed) * bobbing_height
	
	# Slow rotation
	rotation += delta * rotation_speed

func setup_visuals():
	print("DEBUG: Setting up power-up visuals of type: ", PowerUpType.keys()[power_up_type])
	
	# Add a collision shape if not already present
	if not has_node("CollisionShape2D"):
		var collision = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 16.0
		collision.shape = circle_shape
		add_child(collision)
	
	# Create a ColorRect for the power-up
	var visual = ColorRect.new()
	visual.name = "Visual"
	visual.size = Vector2(32, 32)
	visual.position = Vector2(-16, -16)  # Center it
	
	# Set color based on type
	match power_up_type:
		PowerUpType.SPEED:
			visual.color = Color(0.2, 0.6, 1.0)  # Blue
		PowerUpType.ATTACK:
			visual.color = Color(1.0, 0.3, 0.3)  # Red
		PowerUpType.SHIELD:
			visual.color = Color(0.3, 1.0, 0.4)  # Green
	
	add_child(visual)
	
	# Add simple particles
	add_simple_particles()

func add_simple_particles():
	# Create a CPUParticles2D node (simpler than GPUParticles2D)
	var particles = CPUParticles2D.new()
	particles.name = "Particles"
	
	# Configure basic properties
	particles.amount = 8
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 16.0
	
	# Set direction and spread
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	
	# Set speed and size
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 20.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	
	# Set color based on type
	match power_up_type:
		PowerUpType.SPEED:
			particles.color = Color(0.2, 0.6, 1.0)  # Blue
		PowerUpType.ATTACK:
			particles.color = Color(1.0, 0.3, 0.3)  # Red
		PowerUpType.SHIELD:
			particles.color = Color(0.3, 1.0, 0.4)  # Green
	
	add_child(particles)

func _on_body_entered(body):
	print("DEBUG: Power-up collision with body: ", body.name)
	if body.is_in_group("player"):
		print("DEBUG: Player collected power-up of type: ", PowerUpType.keys()[power_up_type])
		apply_power_up(body)
		# Play pickup sound
		# AudioManager.play_sfx("power_up_collect")
		queue_free()

func apply_power_up(player):
	print("DEBUG: Applying power-up: ", PowerUpType.keys()[power_up_type])
	
	match power_up_type:
		PowerUpType.SPEED:
			if player.has_method("apply_speed_boost"):
				print("DEBUG: Applying speed boost")
				player.apply_speed_boost(effect_strength, duration)
				update_ui("SPEED", duration)
			else:
				print("DEBUG: Player has no apply_speed_boost method")
				
		PowerUpType.ATTACK:
			# Assuming player has a special_attack_damage property
			if "special_attack_damage" in player:
				print("DEBUG: Applying attack boost")
				var original_damage = player.special_attack_damage
				player.special_attack_damage = round(original_damage * effect_strength)
				
				# Create a timer to reset the attack boost
				var timer = Timer.new()
				timer.one_shot = true
				timer.wait_time = duration
				player.add_child(timer)
				timer.start()
				
				# Connect timer timeout
				timer.timeout.connect(func():
					if is_instance_valid(player):
						print("DEBUG: Attack boost expired")
						player.special_attack_damage = original_damage
						timer.queue_free()
				)
				
				update_ui("ATTACK", duration)
			else:
				print("DEBUG: Player has no special_attack_damage property")
				
		PowerUpType.SHIELD:
			# Assuming player has PlayerStats for immunity
			if player.has_node("PlayerStats"):
				print("DEBUG: Applying shield")
				var stats = player.get_node("PlayerStats")
				
				# Save original immunity time
				var original_immunity = stats.immunity_time
				
				# Set to much longer immunity
				stats.immunity_time = duration
				stats.immune_timer = duration
				
				# Create a timer to reset
				var timer = Timer.new()
				timer.one_shot = true
				timer.wait_time = duration
				player.add_child(timer)
				timer.start()
				
				# Connect timer timeout
				timer.timeout.connect(func():
					if is_instance_valid(stats):
						print("DEBUG: Shield expired")
						stats.immunity_time = original_immunity
						timer.queue_free()
				)
				
				update_ui("SHIELD", duration)
			else:
				print("DEBUG: Player has no PlayerStats node")

func update_ui(type: String, duration: float):
	# Try to update the UI if reference exists
	if ui_reference and ui_reference.has_method("activate_power_up"):
		print("DEBUG: Updating UI for power-up: ", type)
		ui_reference.activate_power_up(type, duration)
	else:
		print("DEBUG: No UI reference found or UI doesn't have activate_power_up method")
