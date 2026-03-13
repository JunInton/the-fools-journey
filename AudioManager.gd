extends Node

# ------------------------------------
# AUDIO MANAGER
# Handles all music and sound effects for the game.
# Sits as an Autoload so any scene can trigger sounds without
# needing direct node references - like a global audio service.
#
# Two separate AudioStreamPlayer nodes:
# - music_player: loops background music, one track at a time
# - sfx_player: fires one-shot sound effects on top of music
# Having two players means music never gets interrupted by SFX.
# ------------------------------------

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# SFX file paths - keyed by signal name for easy lookup
# All paths relative to res://assets/audio/sfx/
const SFX_PATHS = {
	"sfx_card_deal":          "res://assets/audio/sfx/card_deal.ogg",
	"sfx_card_discard":       "res://assets/audio/sfx/card_discard.ogg",
	"sfx_card_equip":         "res://assets/audio/sfx/card_equip.ogg",
	"sfx_challenge_resolved": "res://assets/audio/sfx/challenge_resolved.ogg",
	"sfx_vitality_heal":      "res://assets/audio/sfx/vitality_heal.ogg",
	"sfx_vitality_damage":    "res://assets/audio/sfx/vitality_damage.ogg",
	"sfx_shuffle":            "res://assets/audio/sfx/shuffle.ogg",
	"menu_click":             "res://assets/audio/sfx/menu_click.ogg",
	"sfx_sword_hit":              "res://assets/audio/sfx/sword_hit.ogg",
	"sfx_wisdom_equip":       "res://assets/audio/sfx/wisdom_equip.ogg",
	"ping":                   "res://assets/audio/sfx/ping.ogg",
	
}

# Default volumes in decibels
# 0 = full volume, negative = quieter, -80 = silent
const MUSIC_VOLUME_DB = -12.0  # Music at roughly 25% perceived volume
const SFX_VOLUME_DB = -6.0     # SFX slightly louder than music

# Mute state - persists across scene changes since AudioManager is an Autoload
var music_enabled: bool = true
var sfx_enabled: bool = true

func _ready():
	# Create and configure the music player
	# autoplay = false, we control when it starts
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)

	# Create and configure the SFX player
	# A separate player so SFX never cut off the music
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = SFX_VOLUME_DB
	add_child(sfx_player)

	# Connect to all GameState audio signals
	# Each signal maps to exactly one sound - no stacking
	GameState.sfx_card_deal.connect(func(): play_sfx("sfx_card_deal"))
	GameState.sfx_card_discard.connect(func(): play_sfx("sfx_card_discard"))
	GameState.sfx_card_equip.connect(func(): play_sfx("sfx_card_equip"))
	GameState.sfx_challenge_resolved.connect(func(): play_sfx("sfx_challenge_resolved"))
	GameState.sfx_vitality_heal.connect(func(): play_sfx("sfx_vitality_heal"))
	GameState.sfx_vitality_damage.connect(func(): play_sfx("sfx_vitality_damage"))
	GameState.sfx_shuffle.connect(func(): play_sfx("sfx_shuffle"))
	GameState.sfx_sword_hit.connect(func(): play_sfx("sfx_sword_hit"))
	GameState.sfx_wisdom_equip.connect(func(): play_sfx("sfx_wisdom_equip"))

	# Connect to ThemeManager so music changes when theme switches
	ThemeManager.theme_changed.connect(_on_theme_changed)

# ------------------------------------
# MUSIC PLAYBACK
# Loads and plays a music track for the given screen context.
# screen is one of: "menu", "game", "win", "lose"
# Called by each scene's _ready() to set the appropriate music.
# ------------------------------------
func play_music(screen: String):
	var path = ThemeManager.get_music_path(screen)
	if path == "":
		music_player.stop()
		return
		
	# NEW: Don't attempt playback until browser allows audio
	if not _audio_unlocked:
		# Still assign the stream so it's ready when unlock happens
		var stream = load(path)
		if stream != null:
			music_player.stream = stream
		return

	# Don't restart the track if it's already playing the same file
	# This prevents music restarting when state_changed fires repeatedly
	if music_player.playing and music_player.stream != null:
		if music_player.stream.resource_path == path:
			return

	var stream = load(path)
	if stream == null:
		return

	music_player.stream = stream
	# REMOVED: music_player.stream.loop = ... line entirely
	# Loop is now set in the Import tab per file instead of at runtime
	# Setting it at runtime on a loaded resource is unreliable in web exports
	music_player.play()

# ------------------------------------
# SFX PLAYBACK
# Fires a one-shot sound effect by name.
# Uses a single sfx_player so only one SFX plays at a time -
# this prevents sound pile-ups when multiple events happen at once.
# ------------------------------------
func play_sfx(sfx_name: String):
	if not sfx_enabled:
		return
		
	var path = SFX_PATHS.get(sfx_name, "")
	if path == "":
		return

	var stream = load(path)
	if stream == null:
		return

	# play() on an already-playing AudioStreamPlayer restarts it
	# This is intentional - the newest sound always wins
	sfx_player.stream = stream
	sfx_player.play()

# ------------------------------------
# MENU CLICK SOUND
# Called directly by UI elements rather than via GameState signals
# since menu clicks aren't game events
# ------------------------------------
func play_menu_click():
	play_sfx("menu_click")

# When theme changes, restart music for the current screen
# The screen context is passed in so we know which track to switch to
func _on_theme_changed(_new_theme: String):
	# We don't know which screen we're on here, so we re-request
	# the current track. Each scene stores its screen context.
	# Music will restart with the new theme's equivalent track.
	if _current_screen != "":
		play_music(_current_screen)

# Tracks which screen is currently active so theme changes
# can request the right music track
var _current_screen: String = ""
var _audio_unlocked: bool = false

func set_screen(screen: String):
	_current_screen = screen
	play_music(screen)

# ← ADD THIS right below set_screen()
func _input(event: InputEvent):
	if not _audio_unlocked and (
		event is InputEventMouseButton or
		event is InputEventKey or
		event is InputEventScreenTouch):
		_audio_unlocked = true
		if _current_screen != "":
			play_music(_current_screen)
	
# Sound toggle
func toggle_music():
	music_enabled = not music_enabled
	# Setting volume_db to -80 is effectively silent but keeps the player
	# running so resuming is instant - like CSS visibility vs display:none
	music_player.volume_db = MUSIC_VOLUME_DB if music_enabled else -80.0

func toggle_sfx():
	sfx_enabled = not sfx_enabled
	sfx_player.volume_db = SFX_VOLUME_DB if sfx_enabled else -80.0
