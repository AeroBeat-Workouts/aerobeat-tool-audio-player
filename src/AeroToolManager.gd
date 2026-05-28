## Vendor-agnostic audio singleton abstraction for AeroBeat tool consumers.
##
## This class keeps the stable tool-facing global name while delegating all
## concrete playback work to the currently wired vendor backend manager.
class_name AeroToolManager
extends Node

const VendorFactoryScript := preload("res://addons/aerobeat-vendor-godot-audio/src/AeroGodotAudioBackendFactory.gd")
const VendorContract := preload("res://addons/aerobeat-vendor-godot-audio/src/AeroAudioPlaybackContract.gd")
const AeroAudioOperationScript := preload("res://addons/aerobeat-vendor-godot-audio/src/AeroAudioOperation.gd")

#region SIGNALS
signal initialized
signal state_changed(state: String, detail: Dictionary)
signal position_changed(seconds: float, normalized: float)
signal media_loaded(info: Dictionary)
signal playback_finished
signal error_raised(error_info: Dictionary)
signal audio_state_changed(audio_id: String, state: String, detail: Dictionary)
signal audio_position_changed(audio_id: String, seconds: float, normalized: float)
signal audio_media_loaded(audio_id: String, info: Dictionary)
signal audio_playback_finished(audio_id: String)
signal audio_error_raised(audio_id: String, error_info: Dictionary)
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

const VERSION: String = "0.2.0"
const DEFAULT_AUDIO_ID := "default"
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
var _runtime_managers: Dictionary = {}
#endregion

#region LIFECYCLE
func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _is_initialized:
		return
	_runtime_manager = _ensure_runtime_manager(DEFAULT_AUDIO_ID)
	_is_initialized = true
	initialized.emit()
#endregion

#region PUBLIC API
func get_default_audio_id() -> String:
	return DEFAULT_AUDIO_ID

func list_audio_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for audio_id in _runtime_managers.keys():
		ids.append(str(audio_id))
	ids.sort()
	return ids

func has_audio(audio_id: String = DEFAULT_AUDIO_ID) -> bool:
	return _runtime_managers.has(_resolve_audio_id(audio_id))

func set_backend(backend: AeroAudioVendorBackend, audio_id: String = DEFAULT_AUDIO_ID) -> void:
	_ensure_runtime_manager(audio_id).set_backend(backend)

func get_backend(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioVendorBackend:
	return _manager(audio_id).get_backend()

func create_default_backend() -> AeroAudioVendorBackend:
	return _factory.create_backend()

func get_default_source_config(audio_id: String = DEFAULT_AUDIO_ID) -> Dictionary:
	return _manager(audio_id).get_default_source_config()

func normalize_source(source: Dictionary, audio_id: String = DEFAULT_AUDIO_ID) -> Dictionary:
	return _normalize_source_for_audio(source, audio_id)

func can_load_source(source: Dictionary, audio_id: String = DEFAULT_AUDIO_ID) -> bool:
	return _manager(audio_id).can_load_source(_normalize_source_for_audio(source, audio_id))

func load(source: Dictionary, audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).load(_normalize_source_for_audio(source, resolved_audio_id), _runtime_slot_name(resolved_audio_id))

func unload(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).unload(_runtime_slot_name(resolved_audio_id))

func play(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).play(_runtime_slot_name(resolved_audio_id))

func pause(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).pause(_runtime_slot_name(resolved_audio_id))

func resume(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).resume(_runtime_slot_name(resolved_audio_id))

func stop(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).stop(_runtime_slot_name(resolved_audio_id))

func seek(seconds: float, audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).seek(seconds, _runtime_slot_name(resolved_audio_id))

func set_volume_db(volume_db: float, audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).set_volume_db(volume_db, _runtime_slot_name(resolved_audio_id))

func set_loop_enabled(enabled: bool, audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	var manager := _manager(resolved_audio_id)
	var runtime_slot := _runtime_slot_name(resolved_audio_id)
	var operation: AeroAudioOperation = AeroAudioOperationScript.new()
	var state := get_state(resolved_audio_id)
	var source: Dictionary = state.get("source", {}).duplicate(true)
	if source.is_empty():
		return operation.settle_failure({
			"code": ERROR_NOT_READY,
			"message": "Cannot change loop mode before media has been loaded.",
			"detail": {"audio_id": resolved_audio_id},
			"state": str(state.get("state", STATE_IDLE)),
		})
	var loop_operation := manager.set_loop(enabled, runtime_slot)
	if not loop_operation.did_succeed():
		return loop_operation
	source["loop"] = enabled
	return operation.settle_success({
		"audio_id": resolved_audio_id,
		"loop": enabled,
		"source": source,
		"state": get_state(resolved_audio_id),
	})

func is_loop_enabled(audio_id: String = DEFAULT_AUDIO_ID) -> bool:
	return bool(get_state(audio_id).get("loop", false))

func get_state(audio_id: String = DEFAULT_AUDIO_ID) -> Dictionary:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	var state := _manager(resolved_audio_id).get_state(_runtime_slot_name(resolved_audio_id)).duplicate(true)
	state["audio_id"] = resolved_audio_id
	state["loop"] = bool(state.get("source", {}).get("loop", false))
	return state

func get_all_states() -> Dictionary:
	var states := {}
	for audio_id in _runtime_managers.keys():
		states[str(audio_id)] = get_state(str(audio_id))
	return states

func get_duration(audio_id: String = DEFAULT_AUDIO_ID) -> float:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).get_duration(_runtime_slot_name(resolved_audio_id))

func get_position(audio_id: String = DEFAULT_AUDIO_ID) -> float:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).get_position(_runtime_slot_name(resolved_audio_id))

func get_media_info(audio_id: String = DEFAULT_AUDIO_ID) -> Dictionary:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	var media_info := _manager(resolved_audio_id).get_media_info(_runtime_slot_name(resolved_audio_id)).duplicate(true)
	media_info["audio_id"] = resolved_audio_id
	media_info["loop"] = bool(get_state(resolved_audio_id).get("loop", false))
	return media_info

func attach_surface(node: Node, audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).attach_surface(node, _runtime_slot_name(resolved_audio_id))

func detach_surface(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioOperation:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	return _manager(resolved_audio_id).detach_surface(_runtime_slot_name(resolved_audio_id))

func get_last_error(audio_id: String = DEFAULT_AUDIO_ID) -> Dictionary:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	var error_info := _manager(resolved_audio_id).get_last_error(_runtime_slot_name(resolved_audio_id)).duplicate(true)
	error_info["audio_id"] = resolved_audio_id
	return error_info

func listen_for_state(callback: Callable, emit_immediately: bool = true, audio_id: String = DEFAULT_AUDIO_ID) -> void:
	if callback.is_valid() and not state_changed.is_connected(callback):
		state_changed.connect(callback)
	if emit_immediately and callback.is_valid():
		var state := get_state(audio_id)
		callback.call(str(state.get("state", STATE_IDLE)), state)

func stop_listening_for_state(callback: Callable) -> void:
	if callback.is_valid() and state_changed.is_connected(callback):
		state_changed.disconnect(callback)
#endregion

#region PRIVATE HELPERS
func _manager(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioPlaybackManager:
	_initialize()
	_sync_runtime_configuration()
	return _ensure_runtime_manager(audio_id)

func _ensure_runtime_manager(audio_id: String = DEFAULT_AUDIO_ID) -> AeroAudioPlaybackManager:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	if _runtime_managers.has(resolved_audio_id):
		var existing: AeroAudioPlaybackManager = _runtime_managers[resolved_audio_id]
		_sync_runtime_configuration()
		return existing
	var runtime_manager: AeroAudioPlaybackManager = _factory.create_manager()
	runtime_manager.name = "AeroToolAudioRuntime_%s" % _sanitize_audio_id_for_name(resolved_audio_id)
	add_child(runtime_manager)
	runtime_manager.initialized.connect(_on_runtime_initialized.bind(resolved_audio_id))
	runtime_manager.state_changed.connect(_on_runtime_state_changed.bind(resolved_audio_id))
	runtime_manager.position_changed.connect(_on_runtime_position_changed.bind(resolved_audio_id))
	runtime_manager.media_loaded.connect(_on_runtime_media_loaded.bind(resolved_audio_id))
	runtime_manager.playback_finished.connect(_on_runtime_playback_finished.bind(resolved_audio_id))
	runtime_manager.error_raised.connect(_on_runtime_error_raised.bind(resolved_audio_id))
	_runtime_managers[resolved_audio_id] = runtime_manager
	if resolved_audio_id == DEFAULT_AUDIO_ID:
		_runtime_manager = runtime_manager
	_sync_runtime_configuration()
	runtime_manager._initialize()
	return runtime_manager

func _resolve_audio_id(audio_id: String) -> String:
	var trimmed := String(audio_id).strip_edges()
	return DEFAULT_AUDIO_ID if trimmed.is_empty() else trimmed

func _sanitize_audio_id_for_name(audio_id: String) -> String:
	return _resolve_audio_id(audio_id).replace("/", "_").replace(":", "_").replace(" ", "_")

func _normalize_source_for_audio(source: Dictionary, audio_id: String) -> Dictionary:
	var resolved_audio_id := _resolve_audio_id(audio_id)
	var normalized_source := source.duplicate(true)
	normalized_source["audio_id"] = resolved_audio_id
	normalized_source["slot"] = _runtime_slot_name(resolved_audio_id)
	return _manager(resolved_audio_id).normalize_source(normalized_source)

func _runtime_slot_name(audio_id: String) -> String:
	var slot_name := str(_ensure_runtime_manager(audio_id).get_default_source_config().get("slot", "")).strip_edges()
	return slot_name if not slot_name.is_empty() else "primary"

func _sync_runtime_configuration() -> void:
	for runtime_manager in _runtime_managers.values():
		if runtime_manager != null:
			runtime_manager.is_active = is_active

func _with_audio_id(detail: Dictionary, audio_id: String) -> Dictionary:
	var payload := detail.duplicate(true)
	payload["audio_id"] = _resolve_audio_id(audio_id)
	if not payload.has("loop"):
		payload["loop"] = bool(payload.get("source", {}).get("loop", false))
	return payload

func _on_runtime_initialized(_audio_id: String) -> void:
	pass

func _on_runtime_state_changed(state: String, detail: Dictionary, audio_id: String) -> void:
	var payload := _with_audio_id(detail, audio_id)
	audio_state_changed.emit(_resolve_audio_id(audio_id), state, payload)
	if _resolve_audio_id(audio_id) == DEFAULT_AUDIO_ID:
		state_changed.emit(state, payload)

func _on_runtime_position_changed(seconds: float, normalized: float, audio_id: String) -> void:
	audio_position_changed.emit(_resolve_audio_id(audio_id), seconds, normalized)
	if _resolve_audio_id(audio_id) == DEFAULT_AUDIO_ID:
		position_changed.emit(seconds, normalized)

func _on_runtime_media_loaded(info: Dictionary, audio_id: String) -> void:
	var payload := _with_audio_id(info, audio_id)
	audio_media_loaded.emit(_resolve_audio_id(audio_id), payload)
	if _resolve_audio_id(audio_id) == DEFAULT_AUDIO_ID:
		media_loaded.emit(payload)

func _on_runtime_playback_finished(audio_id: String) -> void:
	audio_playback_finished.emit(_resolve_audio_id(audio_id))
	if _resolve_audio_id(audio_id) == DEFAULT_AUDIO_ID:
		playback_finished.emit()

func _on_runtime_error_raised(error_info: Dictionary, audio_id: String) -> void:
	var payload := _with_audio_id(error_info, audio_id)
	audio_error_raised.emit(_resolve_audio_id(audio_id), payload)
	if _resolve_audio_id(audio_id) == DEFAULT_AUDIO_ID:
		error_raised.emit(payload)
#endregion
