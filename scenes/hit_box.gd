# PlayerHitBox.gd
extends Area2D

@onready var stats = get_parent().get_node("PlayerStats")

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	
func _on_area_entered(area):
	if area.is_in_group("enemy_attack"):
		# Get damage amount if the area has this property
		var damage = 1
		if area.has_method("get_damage"):
			damage = area.get_damage()
		
		stats.take_damage(damage)
