extends Area2D

@onready var stats = get_parent().get_node("PlayerStats")

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))
	
func _on_area_entered(area):
	if area.is_in_group("enemy_attack") and is_instance_valid(stats) and stats.is_alive:
		# Get damage amount if the area has this property
		var damage = 1
		if area.has_method("get_damage"):
			damage = area.get_damage()
		
		stats.take_damage(damage)

# Add body detection for better collision with pathogen
func _on_body_entered(body):
	if body.is_in_group("enemy") and is_instance_valid(stats) and stats.is_alive:
		print("DEBUG: Player collided with enemy body")
		
		# Get the pathogen component if this is a pathogen
		if body.has_method("take_damage") and body.current_state == body.State.CUTE:
			print("DEBUG: Player attacking pathogen")
			body.take_damage(1)
