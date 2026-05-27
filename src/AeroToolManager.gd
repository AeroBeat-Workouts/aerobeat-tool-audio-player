## Vendor-agnostic audio singleton abstraction for AeroBeat tool consumers.
##
## This class keeps the stable tool-facing global name while delegating all
## concrete playback work to the currently wired vendor backend manager.
class_name AeroToolManager
extends Node

const VendorFactoryScript := preload("res://addons/aerobeat-vendor-godot-audio/src/AeroGodotAudioBackendFactory.gd")
const VendorContract := preload("res://addons/aerobeat-vendor-godot-audio/src/AeroAudioPlaybackContract.gd")

#region SIGNALS
signal initialized
signal state_changed(state: String, detail: Dictionary)
signal position_changed(seconds: float, normalized: float)
signal media_loaded(info: Dictionary)
signal playback_finished
signal error_raised(error_info: Dictionary)
#endregion

#region ENUMS & CONSTANTS
enum PlaybackState {
	IDLE,
	LOADING,
	READY,
	PLAYING,
	PAUSED,
	STOPPING,
	ERROR,
}

const VERSION: String = "0.1.0"
const STATE_IDLE := VendorContract.STATE_IDLE
const STATE_LOADING := VendorContract.STATE_LOADING
const STATE_READY := VendorContract.STATE_READY
const STATE_PLAYING := VendorContract.STATE_PLAYING
const STATE_PAUSED := VendorContract.STATE_PAUSED
const STATE_STOPPING := VendorContract.STATE_STOPPING
const STATE_ERROR := VendorContract.STATE_ERROR
const STATE_NAMES := {
	PlaybackState.IDLE: STATE_IDLE,
	PlaybackState.LOADING: STATE_LOADING,
	PlaybackState.READY: STATE_READY,
	PlaybackState.PLAYING: STATE_PLAYING,
	PlaybackState.PAUSED: STATE_PAUSED,
	PlaybackState.STOPPING: STATE_STOPPING,
	PlaybackState.ERROR: STATE_ERROR,
}

const SOURCE_KIND_FILE := VendorContract.SOURCE_KIND_FILE
const SOURCE_KIND_PACKAGE := VendorContract.SOURCE_KIND_PACKAGE
const SOURCE_KIND_URL := VendorContract.SOURCE_KIND_URL
const SOURCE_KINDS := VendorContract.SOURCE_KINDS

const ERROR_INVALID_SOURCE := VendorContract.ERROR_INVALID_SOURCE
const ERROR_INVALID_SURFACE := VendorContract.ERROR_INVALID_SURFACE
const ERROR_BACKEND_REJECTED := VendorContract.ERROR_BACKEND_REJECTED
const ERROR_NOT_READY := VendorContract.ERROR_NOT_READY
#endregion

#region EXPORTS
@export var is_active: bool = true
#endregion

#region PRIVATE VARIABLES
var _is_initialized: bool = false
var _factory: AeroGodotAudioBackendFactory = VendorFactoryScript.new()
var _runtime_manager: AeroAudioPlaybackManager = null
#endregion

#region LIFECYCLE
func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized:
		return
	_ensure_runtime_manager()
	_runtime_manager._initialize()
	_is_initialized = true
	initialized.emit()
#endregion

#region PUBLIC API
func set_backend(backend: AeroAudioVendorBackend) -> void:
	_ensure_runtime_manager()
	_runtime_manager.set_backend(backend)

func get_backend() -> AeroAudioVendorBackend:
	return _manager().get_backend()

func create_default_backend() -> AeroAudioVendorBackend:
	return _factory.create_backend()

func get_default_source_config() -> Dictionary:
	return _manager().get_default_source_config()

func normalize_source(source: Dictionary) -> Dictionary:
	return _manager().normalize_source(source)

func can_load_source(source: Dictionary) -> bool:
	return _manager().can_load_source(source)

func load(source: Dictionary) -> AeroAudioOperation:
	return _manager().load(source)

func unload() -> AeroAudioOperation:
	return _manager().unload()

func play() -> AeroAudioOperation:
	return _manager().play()

func pause() -> AeroAudioOperation:
	return _manager().pause()

func resume() -> AeroAudioOperation:
	return _manager().resume()

func stop() -> AeroAudioOperation:
	return _manager().stop()

func seek(seconds: float) -> AeroAudioOperation:
	return _manager().seek(seconds)

func set_volume_db(volume_db: float) -> AeroAudioOperation:
	return _manager().set_volume_db(volume_db)

func get_state() -> Dictionary:
	return _manager().get_state()

func get_duration() -> float:
	return _manager().get_duration()

func get_position() -> float:
	return _manager().get_position()

func get_media_info() -> Dictionary:
	return _manager().get_media_info()

func attach_surface(node: Node) -> AeroAudioOperation:
	return _manager().attach_surface(node)

func detach_surface() -> AeroAudioOperation:
	return _manager().detach_surface()

func get_last_error() -> Dictionary:
	return _manager().get_last_error()

func listen_for_state(callback: Callable, emit_immediately: bool = true) -> void:
	if callback.is_valid() and not state_changed.is_connected(callback):
		state_changed.connect(callback)
	if emit_immediately and callback.is_valid():
		callback.call(get_state().get("state", STATE_IDLE), get_state())

func stop_listening_for_state(callback: Callable) -> void:
	if callback.is_valid() and state_changed.is_connected(callback):
		state_changed.disconnect(callback)
#endregion

#region PRIVATE HELPERS
func _manager() -> AeroAudioPlaybackManager:
	_initialize()
	_sync_runtime_configuration()
	return _runtime_manager

func _ensure_runtime_manager() -> void:
	if _runtime_manager != null:
		_sync_runtime_configuration()
		return
	_runtime_manager = _factory.create_manager()
	_runtime_manager.name = "AeroToolAudioRuntime"
	add_child(_runtime_manager)
	_runtime_manager.initialized.connect(_on_runtime_initialized)
	_runtime_manager.state_changed.connect(_on_runtime_state_changed)
	_runtime_manager.position_changed.connect(_on_runtime_position_changed)
	_runtime_manager.media_loaded.connect(_on_runtime_media_loaded)
	_runtime_manager.playback_finished.connect(_on_runtime_playback_finished)
	_runtime_manager.error_raised.connect(_on_runtime_error_raised)
	_sync_runtime_configuration()

func _sync_runtime_configuration() -> void:
	if _runtime_manager == null:
		return
	_runtime_manager.is_active = is_active

func _on_runtime_initialized() -> void:
	pass

func _on_runtime_state_changed(state: String, detail: Dictionary) -> void:
	state_changed.emit(state, detail.duplicate(true))

func _on_runtime_position_changed(seconds: float, normalized: float) -> void:
	position_changed.emit(seconds, normalized)

func _on_runtime_media_loaded(info: Dictionary) -> void:
	media_loaded.emit(info.duplicate(true))

func _on_runtime_playback_finished() -> void:
	playback_finished.emit()

func _on_runtime_error_raised(error_info: Dictionary) -> void:
	error_raised.emit(error_info.duplicate(true))
#endregion
