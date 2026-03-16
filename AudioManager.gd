extends Node

# ------------------------------------
# AUDIO MANAGER
# Autoload that handles all music and sound effects for the game.
# Any scene can trigger audio without needing direct node references.
#
# Two separate AudioStreamPlayer nodes run in parallel:
#   music_player — loops background music, one track at a time
#   sfx_player   — fires one-shot sound effects on top of the music
# Keeping them separate means music is never interrupted by SFX.
# ------------------------------------

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Maps GameState signal names to their SFX file paths
const SFX_PATHS = {
	"sfx_card_deal":          "res://assets/audio/sfx/card_deal.ogg",
	"sfx_card_discard":       "res://assets/audio/sfx/card_discard.ogg",
	"sfx_card_equip":         "res://assets/audio/sfx/card_equip.ogg",
	"sfx_challenge_resolved": "res://assets/audio/sfx/challenge_resolved.ogg",
	"sfx_vitality_heal":      "res://assets/audio/sfx/vitality_heal.ogg",
	"sfx_vitality_damage":    "res://assets/audio/sfx/vitality_damage.ogg",
	"sfx_shuffle":            "res://assets/audio/sfx/shuffle.ogg",
	"menu_click":             "res://assets/audio/sfx/menu_click.ogg",
	"sfx_sword_hit":          "res://assets/audio/sfx/sword_hit.ogg",
	"sfx_wisdom_equip":       "res://assets/audio/sfx/wisdom_equip.ogg",
	"ping":                   "res://assets/audio/sfx/ping.ogg",
}

# Volume levels in decibels. 0 = full volume, negative = quieter, -80 = silent.
const MUSIC_VOLUME_DB = -12.0
const SFX_VOLUME_DB   = -6.0

# Persists across scene changes since AudioManager is an Autoload
var music_enabled: bool = true
var sfx_enabled: bool   = true

# Tracks which screen is currently active so theme changes and
# the browser autoplay unlock know which track to (re)start
var _current_screen: String = ""

# Browsers block audio playback until the user interacts with the page.
# This flag is set on first input so music begins at that moment rather
# than silently failing on load.
var _audio_unlocked: bool = false

func _ready():
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = SFX_VOLUME_DB
	add_child(sfx_player)

	# Connect to all GameState audio signals — each maps to exactly one sound
	GameState.sfx_card_deal.connect(func():          play_sfx("sfx_card_deal"))
	GameState.sfx_card_discard.connect(func():       play_sfx("sfx_card_discard"))
	GameState.sfx_card_equip.connect(func():         play_sfx("sfx_card_equip"))
	GameState.sfx_challenge_resolved.connect(func(): play_sfx("sfx_challenge_resolved"))
	GameState.sfx_vitality_heal.connect(func():      play_sfx("sfx_vitality_heal"))
	GameState.sfx_vitality_damage.connect(func():    play_sfx("sfx_vitality_damage"))
	GameState.sfx_shuffle.connect(func():            play_sfx("sfx_shuffle"))
	GameState.sfx_sword_hit.connect(func():          play_sfx("sfx_sword_hit"))
	GameState.sfx_wisdom_equip.connect(func():       play_sfx("sfx_wisdom_equip"))

	ThemeManager.theme_changed.connect(_on_theme_changed)

# ------------------------------------
# SCREEN CONTEXT
# Called by each scene's _ready() to set the current screen so
# AudioManager knows which music track to play.
# ------------------------------------
func set_screen(screen: String):
	_current_screen = screen
	play_music(screen)

# ------------------------------------
# MUSIC PLAYBACK
# Loads and plays the appropriate music track for the given screen.
# screen is one of: "menu", "game", "win", "lose"
# Skips playback if the same track is already playing to avoid restarts.
# If the browser hasn't been unlocked yet, stores the stream so it can
# start immediately when the user first interacts with the page.
# ------------------------------------
func play_music(screen: String):
	var path = ThemeManager.get_music_path(screen)
	if path == "":
		music_player.stop()
		return

	var stream = load(path)
	if stream == null:
		return

	# Store the stream so _input() can start it once the browser unlocks
	if not _audio_unlocked:
		music_player.stream = stream
		return

	# Skip if the same track is already playing
	if music_player.playing and music_player.stream != null:
		if music_player.stream.resource_path == path:
			return

	music_player.stream = stream
	music_player.play()

# ------------------------------------
# SFX PLAYBACK
# Fires a one-shot sound effect by name.
# Only one SFX plays at a time — the newest sound always replaces
# any currently playing effect, preventing pile-ups during rapid actions.
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
	# Calling play() on an already-playing player restarts from the beginning
	sfx_player.stream = stream
	sfx_player.play()

func play_menu_click():
	# Called directly by UI elements rather than via GameState signals
	# since menu clicks are UI events, not game logic events
	play_sfx("menu_click")

# ------------------------------------
# AUDIO CONTROLS
# toggle functions mute by setting volume to -80db rather than stopping
# playback entirely, so resuming is instant with no load delay.
# Like CSS visibility:hidden vs display:none — the player keeps running.
# ------------------------------------
func toggle_music():
	music_enabled = not music_enabled
	music_player.volume_db = MUSIC_VOLUME_DB if music_enabled else -80.0

func toggle_sfx():
	sfx_enabled = not sfx_enabled
	sfx_player.volume_db = SFX_VOLUME_DB if sfx_enabled else -80.0

func _on_theme_changed(_new_theme: String):
	# Restart music for the current screen using the new theme's track
	if _current_screen != "":
		play_music(_current_screen)

func _input(event: InputEvent):
	# Browsers block audio until the user interacts with the page.
	# On first mouse click, key press, or touch, unlock audio and start
	# whatever track was queued for the current screen.
	if not _audio_unlocked and (
		event is InputEventMouseButton or
		event is InputEventKey or
		event is InputEventScreenTouch):
		_audio_unlocked = true
		if music_player.stream != null:
			# Win and lose screens use one-shot tracks that shouldn't loop
			music_player.stream.loop = _current_screen not in ["win", "lose"]
			music_player.play()
		elif _current_screen != "":
			play_music(_current_screen)
