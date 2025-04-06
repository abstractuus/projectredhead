# Corrected game_ui.gd - Fixed styling for ProgressBar
extends CanvasLayer

# References to UI elements
var special_attack_cooldown: ProgressBar
var power_up_indicators: Dictionary = {}
var health_bar: ProgressBar

# Player reference
var player: CharacterBody2D

func _ready():
	add_to_group("game_ui")
	
	print("Game UI initializing")
	# Setup the UI elements
	setup_cooldown_indicator()
	setup_power_up_indicators()
	setup_health_bar()
	
	# Find the player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	print("Found player node: ", player != null)
	
	if player and player.has_node("PlayerStats"):
		var stats = player.get_node("PlayerStats")
		print("Found player stats node: ", stats != null)
		stats.connect("health_changed", Callable(self, "_on_player_health_changed"))
		
		# Initial update
		_on_player_health_changed(stats.current_health, stats.max_health)
	
	print("Game UI initialized")

func setup_cooldown_indicator():
	# Create a container for the cooldown indicator
	var cooldown_container = HBoxContainer.new()
	cooldown_container.name = "CooldownContainer"
	cooldown_container.position = Vector2(20, 20)
	add_child(cooldown_container)
	
	# Add a label for the special attack
	var label = Label.new()
	label.text = "Special:"
	cooldown_container.add_child(label)
	
	# Create the cooldown progress bar - USING STANDARD CONTROL
	special_attack_cooldown = ProgressBar.new()
	special_attack_cooldown.name = "SpecialAttackCooldown"
	special_attack_cooldown.custom_minimum_size = Vector2(100, 20)
	special_attack_cooldown.value = 100
	
	# Set colors using modulate instead of tint_progress
	special_attack_cooldown.modulate = Color(0.3, 0.7, 1.0)  # Blue
	
	cooldown_container.add_child(special_attack_cooldown)

func setup_power_up_indicators():
	# Create a container for power-up indicators
	var power_up_container = HBoxContainer.new()
	power_up_container.name = "PowerUpContainer"
	power_up_container.position = Vector2(20, 70)
	power_up_container.add_theme_constant_override("separation", 10)
	add_child(power_up_container)
	
	# Create indicators for each power-up type
	var power_up_types = ["SPEED", "ATTACK", "SHIELD"]
	var colors = [Color(0.2, 0.6, 1.0), Color(1.0, 0.3, 0.3), Color(0.3, 1.0, 0.4)]
	
	for i in range(power_up_types.size()):
		var type = power_up_types[i]
		var color = colors[i]
		
		# Create a container for this power-up
		var indicator_container = VBoxContainer.new()
		indicator_container.name = type + "Container"
		power_up_container.add_child(indicator_container)
		
		# Add a colored rect for the icon
		var icon = ColorRect.new()
		icon.color = color
		icon.custom_minimum_size = Vector2(30, 30)
		indicator_container.add_child(icon)
		
		# Add a timer label
		var timer_label = Label.new()
		timer_label.name = type + "Timer"
		timer_label.text = ""
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator_container.add_child(timer_label)
		
		# Store reference and make initially invisible
		power_up_indicators[type] = {
			"container": indicator_container,
			"icon": icon,
			"label": timer_label,
			"time_left": 0.0
		}
		
		indicator_container.visible = false

func setup_health_bar():
	# Create a container for the health bar
	var health_container = HBoxContainer.new()
	health_container.name = "HealthContainer"
	health_container.position = Vector2(20, 120)
	add_child(health_container)
	
	# Add a label for health
	var label = Label.new()
	label.text = "Health:"
	health_container.add_child(label)
	
	# Create the health bar - USING STANDARD CONTROL
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0
	health_bar.max_value = 3  # Default max health
	health_bar.value = 3
	health_bar.custom_minimum_size = Vector2(100, 20)
	
	# Set colors using modulate instead of tint_progress
	health_bar.modulate = Color(1.0, 0.3, 0.3)  # Red
	
	health_container.add_child(health_bar)

func _process(delta):
	# Update cooldown indicator if player exists
	if player and "cooldown_timer" in player and "special_attack_cooldown" in player:
		var cooldown_percent = (1.0 - (player.cooldown_timer / player.special_attack_cooldown)) * 100
		special_attack_cooldown.value = cooldown_percent
	
	# Update power-up timers
	for type in power_up_indicators.keys():
		var indicator = power_up_indicators[type]
		if indicator["time_left"] > 0:
			indicator["time_left"] -= delta
			indicator["label"].text = "%.1fs" % indicator["time_left"]
			
			# Make it visible
			indicator["container"].visible = true
			
			# Flash the icon as time runs out
			if indicator["time_left"] < 3.0:
				var flash_alpha = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
				indicator["icon"].modulate.a = flash_alpha
			
			# Hide when expired
			if indicator["time_left"] <= 0:
				indicator["container"].visible = false
				indicator["icon"].modulate.a = 1.0

func activate_power_up(type: String, duration: float):
	if power_up_indicators.has(type):
		var indicator = power_up_indicators[type]
		indicator["time_left"] = duration
		indicator["container"].visible = true
		indicator["label"].text = "%.1fs" % duration
		
		# Reset icon alpha
		indicator["icon"].modulate.a = 1.0

func _on_player_health_changed(current_health, max_health):
	# Update health bar
	health_bar.max_value = max_health
	health_bar.value = current_health
	print("Health update: " + str(current_health) + "/" + str(max_health))
	
	# Visual feedback for health change
	var tween = create_tween()
	tween.tween_property(health_bar, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(health_bar, "modulate", Color(1.0, 0.3, 0.3), 0.2)  # Return to red
