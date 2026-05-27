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

func _make_surface(name: String) -> Node:
	var surface := Node.new()
	surface.name = name
	add_child_autofree(surface)
	return surface

func test_public_surface_keeps_aerotoolmanager_and_vendor_abstraction_entrypoint() -> void:
	var class_names := _global_class_names()
	assert_true(class_names.has("AeroToolManager"), "Repo should still export AeroToolManager as the stable singleton entrypoint")
	assert_eq(AeroToolManager.VERSION, "0.2.0", "Audio tool manager version should reflect the loop plus multi-audio abstraction slice")
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_IDLE, "Fresh tool manager should begin idle")
	assert_true(_manager.list_audio_ids().has(AeroToolManager.DEFAULT_AUDIO_ID), "Default audio slot should be created eagerly for backwards compatibility")

func test_tool_manager_proxies_load_unload_play_pause_resume_stop_volume_seek_and_loop_on_default_slot() -> void:
	var surface := _make_surface("ManagedSurface")
	_manager.attach_surface(surface)

	var state_events: Array[String] = []
	_manager.listen_for_state(func(state: String, _detail: Dictionary) -> void:
		state_events.append(state)
	)

	var callback_state := {"load_success": false}
	_manager.load({
		"path": SAMPLE_WAV_PATH,
		"loop": true,
		"start_time": 0.2,
		"volume_db": -6.0,
		"metadata": {"fixture": "wav"},
	}).on_success(func(result: Dictionary) -> void:
		callback_state["load_success"] = str(result.get("media_info", {}).get("path", "")) == SAMPLE_WAV_PATH
	)
	assert_true(bool(callback_state.get("load_success", false)), "Load should resolve through the promise-like success callback")
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_READY, "Manager should become ready after load")
	assert_true(_manager.is_loop_enabled(), "Default slot should preserve the requested loop flag")
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
	var loop_result := _manager.set_loop_enabled(false)
	assert_true(loop_result.did_succeed(), "set_loop_enabled should reconfigure the currently loaded slot")
	assert_false(_manager.is_loop_enabled(), "Loop helper should disable loop without unloading the slot")
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_PLAYING, "Loop reconfiguration should preserve a playing slot")
	assert_almost_eq(_manager.get_position(), 0.7, 0.001, "Loop reconfiguration should preserve playback position")
	_manager.stop()
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_READY, "stop should return the manager to ready")
	assert_almost_eq(_manager.get_position(), 0.0, 0.001, "stop should reset playback position")
	_manager.unload()
	assert_eq(str(_manager.get_state().get("state", "")), AeroToolManager.STATE_IDLE, "unload should return the manager to idle")
	assert_true(state_events.has(AeroToolManager.STATE_PLAYING), "State listener should receive playing transitions")
	assert_true(state_events.has(AeroToolManager.STATE_PAUSED), "State listener should receive paused transitions")

func test_tool_manager_supports_packaged_and_external_audio_paths() -> void:
	var surface := _make_surface("ExternalSurface")
	_manager.attach_surface(surface)

	var packaged_result := _manager.load({"path": SAMPLE_OGG_PATH})
	assert_true(packaged_result.did_succeed(), "Manager should load packaged OGG assets through the abstraction")
	assert_eq(str(_manager.get_media_info().get("locality", "")), "project_resource", "Packaged audio should report project_resource locality")

	var external_result := _manager.load({"path": _external_wav_path})
	assert_true(external_result.did_succeed(), "Manager should load external absolute WAV assets through the abstraction")
	assert_eq(str(_manager.get_media_info().get("locality", "")), "absolute_path", "External audio should report absolute-path locality")
	assert_eq(str(_manager.get_media_info().get("extension", "")), "wav", "External WAV should preserve its extension")

func test_tool_manager_supports_independent_multi_audio_slots() -> void:
	var music_surface := _make_surface("MusicSurface")
	var sfx_surface := _make_surface("SfxSurface")
	_manager.attach_surface(music_surface, "music")
	_manager.attach_surface(sfx_surface, "sfx")
	_manager.set_backend(_factory.create_backend(Callable(self, "_make_fake_player")), "music")
	_manager.set_backend(_factory.create_backend(Callable(self, "_make_fake_player")), "sfx")
	_manager.attach_surface(music_surface, "music")
	_manager.attach_surface(sfx_surface, "sfx")

	var music_result := _manager.load({
		"path": SAMPLE_OGG_PATH,
		"loop": true,
		"volume_db": -3.0,
	}, "music")
	var sfx_result := _manager.load({
		"path": _external_wav_path,
		"loop": false,
		"start_time": 0.4,
		"volume_db": -12.0,
	}, "sfx")
	assert_true(music_result.did_succeed(), "Music slot should load packaged audio independently")
	assert_true(sfx_result.did_succeed(), "SFX slot should load external audio independently")

	_manager.play("music")
	_manager.play("sfx")
	_manager.pause("sfx")
	_manager.seek(0.25, "music")

	assert_eq(str(_manager.get_state("music").get("state", "")), AeroToolManager.STATE_PLAYING, "Music slot should keep playing")
	assert_eq(str(_manager.get_state("sfx").get("state", "")), AeroToolManager.STATE_PAUSED, "SFX slot should pause without affecting music")
	assert_true(_manager.is_loop_enabled("music"), "Music slot should keep loop enabled")
	assert_false(_manager.is_loop_enabled("sfx"), "SFX slot should keep loop disabled")
	assert_almost_eq(_manager.get_position("music"), 0.25, 0.001, "Music slot seek should stay isolated")
	assert_almost_eq(_manager.get_position("sfx"), 0.4, 0.001, "SFX slot position should preserve its own timeline")
	assert_eq(str(_manager.get_media_info("music").get("locality", "")), "project_resource", "Music slot should report packaged locality")
	assert_eq(str(_manager.get_media_info("sfx").get("locality", "")), "absolute_path", "SFX slot should report external locality")
	assert_true(_manager.list_audio_ids().has("music"), "Music slot should be discoverable")
	assert_true(_manager.list_audio_ids().has("sfx"), "SFX slot should be discoverable")

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
