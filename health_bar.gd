# HealthBar.gd
extends ProgressBar

func _ready():
	print("HealthBar _ready called")
	await get_tree().process_frame
	
	# Find the player stats
	var player = get_tree().get_first_node_in_group("player")
	print("Found player node: ", player != null)
	
	if player and player.has_node("PlayerStats"):
		var stats = player.get_node("PlayerStats")
		print("Found player stats node: ", stats != null)
		
		# Connect to health changed signal
		stats.connect("health_changed", Callable(self, "_on_health_changed"))
		print("Connected health changed signal")
		
		# Set initial values
		max_value = stats.max_health
		value = stats.current_health * 100 / stats.max_health
		print("Initial health: ", value, "/", max_value)
	else:
		print("Failed to find PlayerStats node")
	
	# Configure appearance
	add_theme_color_override("fill_color", Color(0.2, 0.8, 0.2))  # Green for health

func _on_health_changed(new_health, max_health):
	# Update max value if needed
	if max_value != max_health:
		max_value = max_health
	
	# Smoothly update to new health value
	var tween = create_tween()
	tween.tween_property(self, "value", new_health, 0.2)
	
	# Update color based on health percentage
	var health_percent = float(new_health) / max_health
	if health_percent > 0.6:
		add_theme_color_override("fill_color", Color(0.2, 0.8, 0.2))  # Green when healthy
	elif health_percent > 0.3:
		add_theme_color_override("fill_color", Color(0.9, 0.7, 0.1))  # Yellow when medium
	else:
		add_theme_color_override("fill_color", Color(0.9, 0.2, 0.2))  # Red when low
