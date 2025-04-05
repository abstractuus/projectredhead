## AudioFramework
## 
## Contributor(s): mixieculez (05-Apr-2025)
## Some contributions by GitHub Copilot
## 
## 
## A centralized audio management system for handling different audio types
## in Abstractus Games Ludum Dare 57 title 'Hemoknight'
##
## This class manages:
## - Different types of audio (music, sound effects, UI sounds)
## - Audio bus configuration and volume control
## - Playing various audio streams based on game events
##
class_name AudioFramework
extends Node

## Audio bus names
const MASTER_BUS: String = "Master"  # Main audio output
const MUSIC_BUS: String = "Music"    # Background music
const SFX_BUS: String = "SFX"        # Sound effects
const UI_BUS: String = "UI"          # UI interaction sounds

## Node references to AudioStreamPlayer nodes
## These should be added as children to the AudioFramework node
@onready var music_player: AudioStreamPlayer = $MusicPlayer  # For background music
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer      # For game sound effects
@onready var ui_player: AudioStreamPlayer = $UIPlayer        # For UI sounds

## Dictionary containing preloaded player sound resources
## Keys should be descriptive names, values are filepath
var sfx_sound: Dictionary = {
	"player_attack_1": preload("res://assets/audio/sfx/player/player_attack_1.ogg"),
	"player_attack_2": preload("res://assets/audio/sfx/player/player_attack_2.ogg"),
	"player_attack_3": preload("res://assets/audio/sfx/player/player_attack_3.ogg"),
	"player_swim": {
		"varied": true,
		"files": [
			preload("res://assets/audio/sfx/player/swim_1.ogg"),
			preload("res://assets/audio/sfx/player/swim_2.ogg"),
			preload("res://assets/audio/sfx/player/swim_3.ogg"),
			preload("res://assets/audio/sfx/player/swim_4.ogg")
		]
	}
}

## Dictionary containing preloaded UI sound resources
## Keys should be descriptive names, values are filepath
var ui_sound: Dictionary = {
	"ui_seek": preload("res://assets/audio/sfx/ui/ui_seek.ogg"),
	"ui_select": preload("res://assets/audio/sfx/ui/ui_select.ogg")
}

## Dictionary containing preloaded music track resources
## Keys should be track names, values are filepath
var music_sound: Dictionary = {
	# Add music tracks here
	# Examples:
	# "main_theme": preload("res://assets/audio/music/calm_flow.ogg"),
	# "battle": preload("res://assets/audio/music/infection_combat.ogg"),
}

## Lifecycle Methods
## -------------------------------------------------------

## Initializes the node with process mode set to always
## This allows audio to continue playing even when the game is paused
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Called when the node enters the scene tree
## Sets up the audio buses and connects signals
func _ready() -> void:
	_setup_audio_buses()
	_connect_signals()

## Configuration Methods
## -------------------------------------------------------

## Configures the default volume levels for audio buses
func _setup_audio_buses() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), -5.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(UI_BUS), 0.0)  # Added missing UI bus

## Connects signals for audio player events
## Can be extended to handle audio event callbacks
func _connect_signals() -> void:
	# Connect signals for audio player events if needed
	# Example: music_player.connect("finished", Callable(self, "_on_music_finished"))
	pass

## Audio Playback Methods
## -------------------------------------------------------

## Plays a music track by name
##
## @param track_name - The name of the track to play (key in music_sound dictionary)
func play_music(track_name: String) -> void:
	if music_sound.has(track_name):
		music_player.stream = music_sound[track_name]
		music_player.play()

## Stops the currently playing music track
func stop_music() -> void:
	music_player.stop()
## Plays a sound effect by name
##
## @param sound_name - The name of the sound to play (key in sound_effects dictionary)
func play_sfx(sound_name: String) -> void:
	if sfx_sound.has(sound_name):
		if sfx_sound[sound_name] is Dictionary and sfx_sound[sound_name].get("varied", true):
			# Randomly select a sound from the files array
			var files = sfx_sound[sound_name]["files"]
			sfx_player.stream = files[randi() % files.size()]
		else:
			sfx_player.stream = sfx_sound[sound_name]
		sfx_player.play()

## Plays a UI sound by name
##
## @param sound_name - The name of the UI sound to play (key in sound_effects dictionary)
func play_ui(sound_name: String) -> void:
	if ui_sound.has(sound_name):
		if ui_sound[sound_name] is Dictionary and ui_sound[sound_name].get("varied", true):
			# Randomly select a sound from the files array
			var files = ui_sound[sound_name]["files"]
			ui_player.stream = files[randi() % files.size()]
		else:
			ui_player.stream = ui_sound[sound_name]
			ui_player.play()

## Volume Control Methods
## -------------------------------------------------------

## Sets the volume of a specific audio bus
##
## @param bus_name - The name of the bus to adjust (e.g., "Master", "Music")
## @param volume_db - The volume in decibels to set
func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus_index, volume_db)

## Sets the volume of a specific audio bus as a percentage (0-100)
##
## @param bus_name - The name of the bus to adjust 
## @param volume_percent - The volume as a percentage (0-100)
func set_bus_volume_percent(bus_name: String, volume_percent: float) -> void:
	volume_percent = clamp(volume_percent, 0.0, 100.0)
	# Convert percentage to decibels (logarithmic scale)
	# -80dB is used as the minimum audible level (practically silent)
	var volume_db: float = linear_to_db(volume_percent / 100.0)
	if volume_percent == 0:
		volume_db = -80.0  # Effectively mute
	set_bus_volume(bus_name, volume_db)
