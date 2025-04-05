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

## Dictionary containing preloaded sound effect resources
## Keys should be descriptive names, values are the actual audio resources
var sound_effects: Dictionary = {
	# Add sound effects here
	# Examples:
	# "swim": preload("res://assets/audio/sfx/swim.ogg"),
	# "attack": preload("res://assets/audio/sfx/engulf.ogg"),
	# "bacteria_death": preload("res://assets/audio/sfx/bacteria_pop.ogg"),
}

## Dictionary containing preloaded music track resources
## Keys should be track names, values are the actual audio resources
var music_tracks: Dictionary = {
	# Add music tracks here
	# Examples:
	# "main_theme": preload("res://assets/audio/music/calm_flow.ogg"),
	# "battle": preload("res://assets/audio/music/infection_combat.ogg"),
}

## Initializes the node with process mode set to always
## This allows audio to continue playing even when the game is paused
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Called when the node enters the scene tree
## Sets up the audio buses and connects signals
func _ready() -> void:
	_setup_audio_buses()
	_connect_signals()

## Configures the default volume levels for audio buses
func _setup_audio_buses() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), -5.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), 0.0)

## Connects signals for audio player events
## Can be extended to handle audio event callbacks
func _connect_signals() -> void:
	# Connect signals for audio player events if needed
	# $ChildAudioPlayer.connect("finished", self, "_on_ChildAudioPlayer_finished")
	pass

## Plays a music track by name
##
## @param track_name - The name of the track to play (key in music_tracks dictionary)
func play_music(track_name: String) -> void:
	if music_tracks.has(track_name):
		music_player.stream = music_tracks[track_name]
		music_player.play()

## Plays a sound effect by name
##
## @param sound_name - The name of the sound to play (key in sound_effects dictionary)
func play_sfx(sound_name: String) -> void:
	if sound_effects.has(sound_name):
		sfx_player.stream = sound_effects[sound_name]
		sfx_player.play()

## Plays a UI sound by name
##
## @param sound_name - The name of the UI sound to play (key in sound_effects dictionary)
func play_ui_sound(sound_name: String) -> void:
	if sound_effects.has(sound_name):
		ui_player.stream = sound_effects[sound_name]
		ui_player.play()

## Sets the volume of a specific audio bus
##
## @param bus_name - The name of the bus to adjust (e.g., "Master", "Music")
## @param volume_db - The volume in decibels to set
func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus_index, volume_db)