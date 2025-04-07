extends Area2D

@onready var pathogen = get_parent()

# Constants for maintainability
const DAMAGE_AMOUNT = 1
const HIT_COLOR = Color(1.5, 0.3, 0.3)  # Red flash for damage
const HIT_DURATION = 0.1
const FADE_DURATION = 0.2
const ATTACH_SCALE_FACTOR = 1.3

# Optional debug flag
const DEBUG = true

func _ready():
    connect("area_entered", Callable(self, "_on_area_entered"))
    connect("body_entered", Callable(self, "_on_body_entered"))
    
    # Add to the appropriate groups
    add_to_group("enemy_hitbox")
    add_to_group("enemy_attack")  # Important for player detection

func _on_area_entered(area):
    # Prevent processing if pathogen is invalid or dead
    if not _is_pathogen_valid():
        return
    
    if area.is_in_group("player_attack") or area.get_parent().is_in_group("player"):
        if DEBUG:
            print("DEBUG: Player area hit pathogen")
        # The player is attacking with a weapon/projectile or directly
        if pathogen.current_state == pathogen.State.CUTE:
            # Take damage in cute state with optional visual feedback
            pathogen.take_damage(DAMAGE_AMOUNT)
            _apply_hit_effect()  # Optional: add if consistent feedback is desired

func _on_body_entered(body):
    # Prevent processing if pathogen is invalid or dead
    if not _is_pathogen_valid():
        return
    
    # Check if this is the player
    if body.is_in_group("player") and is_instance_valid(body):
        if DEBUG:
            print("DEBUG: Pathogen detected player body collision")
        
        # Handle collision based on pathogen state
        match pathogen.current_state:
            pathogen.State.CUTE:
                if DEBUG:
                    print("DEBUG: Player touched cute pathogen - taking damage")
                var damage_applied = pathogen.take_damage(DAMAGE_AMOUNT)
                if DEBUG:
                    print("DEBUG: Damage applied: ", damage_applied)
                
                # Visual feedback
                _apply_hit_effect()
                
                # Apply knockback to pathogen only
                var knockback_dir = (pathogen.global_position - body.global_position).normalized()
                pathogen.velocity = knockback_dir * pathogen.flee_speed * 1.5
            
            pathogen.State.SPIKEY:
                if DEBUG:
                    print("DEBUG: Spikey pathogen attaching to player")
                # Attach to player safely
                pathogen.call_deferred("set_state", pathogen.State.ATTACHED)
                
                # Visual feedback for attachment
                var attach_tween = create_tween()
                attach_tween.tween_property(pathogen.sprite, "scale", pathogen.initial_scale * ATTACH_SCALE_FACTOR, HIT_DURATION)
                attach_tween.tween_property(pathogen.sprite, "scale", pathogen.initial_scale, FADE_DURATION)

# Helper function to check pathogen validity
func _is_pathogen_valid() -> bool:
    return is_instance_valid(pathogen) and pathogen.health > 0

# Optional helper for hit visual effect
func _apply_hit_effect():
    var hit_tween = create_tween()
    hit_tween.tween_property(pathogen.sprite, "modulate", HIT_COLOR, HIT_DURATION)
    hit_tween.tween_property(pathogen.sprite, "modulate", Color.WHITE, FADE_DURATION)
