## AudioManager.gd
## 
## Contributor(s): mixieculez (05-Apr-2025), wanderinglostsoul44 (06-Apr-2025)
## Some contributions by GitHub Copilot
## 
## A centralized audio management system for handling different audio types
## in Abstractus Games Ludum Dare 57 title 'Hemoknight'
##
## This class manages:
## - Different types of audio (music, sound effects, UI sounds)
## - Audio bus configuration and volume control
## - Playing various audio streams based on game events
##
class_name AudioManager
extends Node

## Audio bus names
const MASTER_BUS: String = "Master"  # Main audio output
const MUSIC_BUS: String = "Music"    # Background music
const SFX_BUS: String = "SFX"        # Sound effects
const UI_BUS: String = "UI"          # UI interaction sounds

## Node references to AudioStreamPlayer nodes
## These should be added as children to the AudioManager node
@onready var music_player: AudioStreamPlayer = $MusicPlayer  # For background music
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer      # For game sound effects
@onready var ui_player: AudioStreamPlayer = $UIPlayer        # For UI sounds

## Dictionary containing preloaded player sound resources
## Keys should be descriptive names, values are filepath or dictionary for varied sounds
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
var ui_sound: Dictionary = {
    "ui_seek": preload("res://assets/audio/sfx/ui/ui_seek.ogg"),
    "ui_select": preload("res://assets/audio/sfx/ui/ui_select.ogg")
}

## Dictionary containing preloaded music track resources
var music_sound: Dictionary = {
	"bone_ambient": preload("res://assets/audio/music/bone_ambient.ogg"),
	"brain_ambient": preload("res://assets/audio/music/brain_ambient.ogg")
}

## Lifecycle Methods
## -------------------------------------------------------

func _init() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
    _setup_audio_buses()
    _connect_signals()

## Configuration Methods
## -------------------------------------------------------

func _setup_audio_buses() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), 0.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), -5.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), 0.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(UI_BUS), 0.0)

func _connect_signals() -> void:
    music_player.connect("finished", Callable(self, "_on_music_finished"))

## Audio Playback Methods
## -------------------------------------------------------

func play_music(track_name: String) -> void:
    if music_sound.has(track_name):
        music_player.stream = music_sound[track_name]
        music_player.play()
    else:
        push_warning("Music track '%s' not found in music_sound dictionary" % track_name)

func stop_music() -> void:
    music_player.stop()

func play_sfx(sound_name: String) -> void:
    if sfx_sound.has(sound_name):
        if sfx_sound[sound_name] is Dictionary and sfx_sound[sound_name].get("varied", true):
            var files = sfx_sound[sound_name]["files"]
            sfx_player.stream = files[randi() % files.size()]
        else:
            sfx_player.stream = sfx_sound[sound_name]
        sfx_player.play()
    else:
        push_warning("SFX '%s' not found in sfx_sound dictionary" % sound_name)

func play_ui(sound_name: String) -> void:
    if ui_sound.has(sound_name):
        if ui_sound[sound_name] is Dictionary and ui_sound[sound_name].get("varied", true):
            var files = ui_sound[sound_name]["files"]
            ui_player.stream = files[randi() % files.size()]
        else:
            ui_player.stream = ui_sound[sound_name]
        ui_player.play()  # Moved outside if-else to play in both cases
    else:
        push_warning("UI sound '%s' not found in ui_sound dictionary" % sound_name)

## Volume Control Methods
## -------------------------------------------------------

func set_bus_volume(bus_name: String, volume_db: float) -> void:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_volume_db(bus_index, volume_db)

func set_bus_volume_percent(bus_name: String, volume_percent: float) -> void:
    volume_percent = clamp(volume_percent, 0.0, 100.0)
    var volume_db: float = linear_to_db(volume_percent / 100.0)
    if volume_percent == 0:
        volume_db = -80.0  # Effectively mute
    set_bus_volume(bus_name, volume_db)

func get_bus_volume_percent(bus_name: String) -> float:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
    if volume_db <= -80.0:
        return 0.0
    return db_to_linear(volume_db) * 100.0

## Signal Handlers
## -------------------------------------------------------

func _on_music_finished() -> void:
    if music_player.stream:
        music_player.play()  # Loop the current track

## Optional Enhancements (Uncomment to Use)
## -------------------------------------------------------

# func fade_out_music(duration: float) -> void:
# 	var tween = create_tween()
# 	tween.tween_property(music_player, "volume_db", -80.0, duration)
# 	tween.tween_callback(music_player.stop)

# var sfx_players: Array[AudioStreamPlayer] = []
# var max_sfx_players: int = 5
#
# func _ready() -> void:
# 	for i in range(max_sfx_players):
# 		var player = AudioStreamPlayer.new()
# 		player.bus = SFX_BUS
# 		add_child(player)
# 		sfx_players.append(player)
# 	_setup_audio_buses()
# 	_connect_signals()
#
# func play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
# 	if sfx_sound.has(sound_name):
# 		var stream: AudioStream
# 		if sfx_sound[sound_name] is Dictionary and sfx_sound[sound_name].get("varied", true):
# 			var files = sfx_sound[sound_name]["files"]
# 			stream = files[randi() % files.size()]
# 		else:
# 			stream = sfx_sound[sound_name]
# 		for player in sfx_players:
# 			if not player.playing:
# 				player.stream = stream
# 				player.volume_db = volume_db
# 				player.pitch_scale = pitch
# 				player.play()
# 				return
# 	else:
# 		push_warning("SFX '%s' not found in sfx_sound dictionary" % sound_name)
