class_name AudioFramework
extends Node

# Audio buses
const MASTER_BUS = "Master"
const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"
const UI_BUS = "UI"

# Node paths
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var ui_player: AudioStreamPlayer = $UIPlayer

# Audio resource paths
var sound_effects: Dictionary = {
								# Add sound effects here
								}

var music_tracks: Dictionary = {
							   # Add music tracks here
							   }

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_setup_audio_buses()
	_connect_signals()

func _setup_audio_buses() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), -5.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), 0.0)

func _connect_signals() -> void:
	# Connect signals for audio player events if needed
	# $ChildAudioPlayer.connect("finished", self, "_on_ChildAudioPlayer_finished")
	pass

func play_music(track_name: String, fade: bool = true) -> void:
	if music_tracks.has(track_name):
		if fade:
			music_player.fade_in(2.0)
		music_player.stream = music_tracks[track_name]
		music_player.play()

func play_sfx(sound_name: String) -> void:
	if sound_effects.has(sound_name):
		sfx_player.stream = sound_effects[sound_name]
		sfx_player.play()

func play_ui_sound(sound_name: String) -> void:
	if sound_effects.has(sound_name):
		ui_player.stream = sound_effects[sound_name]
		ui_player.play()

func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus_index, volume_db)