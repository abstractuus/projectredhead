extends Area2D

@onready var pathogen = get_parent()

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Add to the appropriate groups
	add_to_group("enemy_hitbox")
	add_to_group("enemy_attack")  # Important for player detection
	
func _on_area_entered(area):
	# Prevent processing if pathogen is already destroyed
	if !is_instance_valid(pathogen) or pathogen.health <= 0:
		return
		
	if area.is_in_group("player_attack") or area.get_parent().is_in_group("player"):
		print("DEBUG: Player area hit pathogen")
		# The player is attacking us with a weapon/projectile or directly
		if pathogen.current_state == pathogen.State.CUTE:
			# Only take damage in cute state
			pathogen.take_damage(1)

# Fix for Pathogen_Hit_Box.gd - ensure it doesn't damage player in CUTE state
func _on_body_entered(body):
	# Prevent processing if pathogen is already destroyed
	if !is_instance_valid(pathogen) or pathogen.health <= 0:
		return
	
	# Check if this is the player
	if body.is_in_group("player") and is_instance_valid(body):
		print("DEBUG: Pathogen detected player body collision")
		
		# Handle collision based on pathogen state
		match pathogen.current_state:
			pathogen.State.CUTE:
				# ONLY take damage, don't hurt player
				print("DEBUG: Player touched cute pathogen - pathogen taking damage")
				var damage_applied = pathogen.take_damage(1)
				print("DEBUG: Damage applied to pathogen: ", damage_applied)
				
				# Visual feedback
				var hit_tween = create_tween()
				hit_tween.tween_property(pathogen.sprite, "modulate", Color(1.5, 0.3, 0.3), 0.1)
				hit_tween.tween_property(pathogen.sprite, "modulate", Color(1, 1, 1), 0.2)
				
				# Apply knockback ONLY to pathogen, NOT to player
				var knockback_dir = (pathogen.global_position - body.global_position).normalized()
				pathogen.velocity = knockback_dir * pathogen.flee_speed * 1.5
			
			pathogen.State.SPIKEY:
				# In spikey state, attach to player on contact
				print("DEBUG: Spikey pathogen attaching to player")
				# Use call_deferred to avoid physics callback errors
				pathogen.call_deferred("set_state", pathogen.State.ATTACHED)
	# Prevent processing if pathogen is already destroyed
	if !is_instance_valid(pathogen) or pathogen.health <= 0:
		return
	
	# Check if this is the player
	if body.is_in_group("player") and is_instance_valid(body):
		print("DEBUG: Pathogen detected player body collision")
		
		# Handle collision based on pathogen state
		match pathogen.current_state:
			pathogen.State.CUTE:
				# ALWAYS damage pathogen in CUTE state when player touches it
				print("DEBUG: Player touched cute pathogen - taking damage")
				var damage_applied = pathogen.take_damage(1)
				print("DEBUG: Damage applied: ", damage_applied)
				
				# Visual feedback
				var hit_tween = create_tween()
				hit_tween.tween_property(pathogen.sprite, "modulate", Color(1.5, 0.3, 0.3), 0.1)
				hit_tween.tween_property(pathogen.sprite, "modulate", Color(1, 1, 1), 0.2)
				
				# Apply knockback ONLY to pathogen, NOT to player
				var knockback_dir = (pathogen.global_position - body.global_position).normalized()
				pathogen.velocity = knockback_dir * pathogen.flee_speed * 1.5
			
			pathogen.State.SPIKEY:
				# In spikey state, attach to player on contact
				print("DEBUG: Spikey pathogen attaching to player")
				# Use call_deferred to avoid physics callback errors
				pathogen.call_deferred("set_state", pathogen.State.ATTACHED)
				
				# Visual feedback
				var attach_tween = create_tween()
				attach_tween.tween_property(pathogen.sprite, "scale", pathogen.initial_scale * 1.3, 0.1)
				attach_tween.tween_property(pathogen.sprite, "scale", pathogen.initial_scale, 0.2)
