extends GutTest

const FACTORY_SCRIPT := preload("res://addons/aerobeat-vendor-godot-audio/src/AeroGodotAudioBackendFactory.gd")
const TOOL_MANAGER_SCRIPT := preload("res://src/AeroToolManager.gd")
const FAKE_PLAYER_SCRIPT := preload("res://tests/helpers/FakeAudioStreamPlayer.gd")
const SAMPLE_OGG_PATH := "res://assets/audio/test-tone.ogg"
const SAMPLE_WAV_PATH := "res://assets/audio/test-tone.wav"

var _factory: AeroGodotAudioBackendFactory
var _manager: AeroToolManager
var _external_tmp_dir: String = ""
var _external_ogg_path: String = ""
var _external_wav_path: String = ""

func _make_fake_player() -> Node:
	return FAKE_PLAYER_SCRIPT.new()

func before_each() -> void:
	_factory = FACTORY_SCRIPT.new()
	_manager = TOOL_MANAGER_SCRIPT.new()
	_manager.set_backend(_factory.create_backend(Callable(self, "_make_fake_player")))
	add_child_autofree(_manager)
	_manager._initialize()
	_prepare_external_samples()

func after_each() -> void:
	for path in [_external_ogg_path, _external_wav_path]:
		if not String(path).is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if not _external_tmp_dir.is_empty() and DirAccess.dir_exists_absolute(_external_tmp_dir):
		DirAccess.remove_absolute(_external_tmp_dir)
	_external_tmp_dir = ""
	_external_ogg_path = ""
	_external_wav_path = ""

func _prepare_external_samples() -> void:
	_external_tmp_dir = OS.get_cache_dir().path_join("aerobeat-tool-audio-player-external-%s" % str(Time.get_unix_time_from_system()))
	assert_eq(DirAccess.make_dir_recursive_absolute(_external_tmp_dir), OK, "Should create a temporary directory for external audio coverage")
	_external_ogg_path = _external_tmp_dir.path_join("external-sample.ogg")
	_external_wav_path = _external_tmp_dir.path_join("external-sample.wav")
	assert_eq(DirAccess.copy_absolute(ProjectSettings.globalize_path(SAMPLE_OGG_PATH), _external_ogg_path), OK, "Should copy the OGG sample outside the project tree")
	assert_eq(DirAccess.copy_absolute(ProjectSettings.globalize_path(SAMPLE_WAV_PATH), _external_wav_path), OK, "Should copy the WAV sample outside the project tree")

func _global_class_names() -> Array[String]:
	var names: Array[String] = []
	for class_info in ProjectSettings.get_global_class_list():
		names.append(str(class_info.get("class", "")))
	return names

func test_public_surface_keeps_aerotoolmanager_and_vendor_abstraction_entrypoint() -> void:
	var class_names := _global_class_names()
	assert_true(class_names.has("AeroToolManager"), "Repo should still export AeroToolManager as the stable singleton entrypoint")
	assert_eq(AeroToolManager.VERSION, "0.1.0", "Audio tool manager version should reflect the real abstraction slice")
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_IDLE, "Fresh tool manager should begin idle")

func test_tool_manager_proxies_load_unload_play_pause_resume_stop_volume_and_seek_with_callbacks() -> void:
	var surface := Node.new()
	surface.name = "ManagedSurface"
	add_child_autofree(surface)
	_manager.attach_surface(surface)

	var state_events: Array[String] = []
	_manager.listen_for_state(func(state: String, _detail: Dictionary) -> void:
		state_events.append(state)
	)

	var callback_state := {"load_success": false}
	_manager.load({
		"path": SAMPLE_WAV_PATH,
		"start_time": 0.2,
		"volume_db": -6.0,
		"metadata": {"fixture": "wav"},
	}).on_success(func(result: Dictionary) -> void:
		callback_state["load_success"] = str(result.get("media_info", {}).get("path", "")) == SAMPLE_WAV_PATH
	)
	assert_true(bool(callback_state.get("load_success", false)), "Load should resolve through the promise-like success callback")
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_READY, "Manager should become ready after load")
	assert_almost_eq(_manager.get_position(), 0.2, 0.001, "Manager should honor start_time")

	_manager.play().on_success(func(_result: Dictionary) -> void:
		pass
	)
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_PLAYING, "play should transition into playing")
	_manager.pause()
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_PAUSED, "pause should transition into paused")
	_manager.resume()
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_PLAYING, "resume should transition back into playing")
	_manager.seek(0.7)
	assert_almost_eq(_manager.get_position(), 0.7, 0.001, "seek should update the manager position")
	_manager.set_volume_db(-12.0)
	assert_almost_eq(float(_manager.get_state().get("volume_db", 0.0)), -12.0, 0.001, "set_volume_db should update the manager state")
	_manager.stop()
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_READY, "stop should return the manager to ready")
	assert_almost_eq(_manager.get_position(), 0.0, 0.001, "stop should reset playback position")
	_manager.unload()
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_IDLE, "unload should return the manager to idle")
	assert_true(state_events.has(AeroToolManager.STATE_PLAYING), "State listener should receive playing transitions")
	assert_true(state_events.has(AeroToolManager.STATE_PAUSED), "State listener should receive paused transitions")

func test_tool_manager_supports_packaged_and_external_audio_paths() -> void:
	var surface := Node.new()
	surface.name = "ExternalSurface"
	add_child_autofree(surface)
	_manager.attach_surface(surface)

	var packaged_result := _manager.load({"path": SAMPLE_OGG_PATH})
	assert_true(packaged_result.did_succeed(), "Manager should load packaged OGG assets through the abstraction")
	assert_eq(str(_manager.get_media_info().get("locality", "")), "project_resource", "Packaged audio should report project_resource locality")

	var external_result := _manager.load({"path": _external_wav_path})
	assert_true(external_result.did_succeed(), "Manager should load external absolute WAV assets through the abstraction")
	assert_eq(str(_manager.get_media_info().get("locality", "")), "absolute_path", "External audio should report absolute-path locality")
	assert_eq(str(_manager.get_media_info().get("extension", "")), "wav", "External WAV should preserve its extension")

func test_failure_callbacks_and_state_listener_helpers_surface_honest_errors() -> void:
	var callback_state := {"failure_code": "", "listener_calls": 0}
	var listener := func(_state: String, detail: Dictionary) -> void:
		if not detail.is_empty():
			callback_state["listener_calls"] = int(callback_state.get("listener_calls", 0)) + 1
	_manager.listen_for_state(listener)
	_manager.load({"path": "https://example.com/demo.ogg"}).on_failure(func(error_info: Dictionary) -> void:
		callback_state["failure_code"] = str(error_info.get("code", ""))
	)
	assert_eq(str(callback_state.get("failure_code", "")), AeroToolManager.ERROR_INVALID_SOURCE, "Remote URLs should reject through the promise-like failure callback")
	assert_eq(str(_manager.get_last_error().get("code", "")), AeroToolManager.ERROR_INVALID_SOURCE, "Manager should retain the invalid-source error")
	assert_true(int(callback_state.get("listener_calls", 0)) >= 1, "listen_for_state should optionally emit the current state immediately")
	_manager.stop_listening_for_state(listener)
	assert_false(_manager.state_changed.is_connected(listener), "stop_listening_for_state should disconnect the callback")
