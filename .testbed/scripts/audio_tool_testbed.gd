extends Control

const SAMPLE_OGG_PATH := "res://assets/audio/test-tone.ogg"
const SAMPLE_WAV_PATH := "res://assets/audio/test-tone.wav"
const SLOT_IDS := [AeroAudioLoader.DEFAULT_AUDIO_ID, "secondary"]

@onready var summary_label: Label = %SummaryLabel
@onready var picker: FileDialog = %FileDialog

@onready var default_path_label: Label = %DefaultPathLabel
@onready var default_status_label: Label = %DefaultStatusLabel
@onready var default_detail_label: Label = %DefaultDetailLabel
@onready var default_result_label: Label = %DefaultResultLabel
@onready var default_slider_label: Label = %DefaultSliderLabel
@onready var default_player_host: Node = %DefaultPlayerHost
@onready var default_seek_slider: HSlider = %DefaultSeekSlider
@onready var default_volume_slider: HSlider = %DefaultVolumeSlider
@onready var default_loop_check: CheckBox = %DefaultLoopCheck

@onready var secondary_path_label: Label = %SecondaryPathLabel
@onready var secondary_status_label: Label = %SecondaryStatusLabel
@onready var secondary_detail_label: Label = %SecondaryDetailLabel
@onready var secondary_result_label: Label = %SecondaryResultLabel
@onready var secondary_slider_label: Label = %SecondarySliderLabel
@onready var secondary_player_host: Node = %SecondaryPlayerHost
@onready var secondary_seek_slider: HSlider = %SecondarySeekSlider
@onready var secondary_volume_slider: HSlider = %SecondaryVolumeSlider
@onready var secondary_loop_check: CheckBox = %SecondaryLoopCheck

var _manager: AeroAudioLoader
var _slot_ui: Dictionary = {}
var _selected_paths: Dictionary = {}
var _suspend_seek_updates: Dictionary = {}
var _active_dialog_slot: String = AeroAudioLoader.DEFAULT_AUDIO_ID

func _ready() -> void:
	_slot_ui = {
		AeroAudioLoader.DEFAULT_AUDIO_ID: {
			"path_label": default_path_label,
			"status_label": default_status_label,
			"detail_label": default_detail_label,
			"result_label": default_result_label,
			"slider_label": default_slider_label,
			"player_host": default_player_host,
			"seek_slider": default_seek_slider,
			"volume_slider": default_volume_slider,
			"loop_check": default_loop_check,
		},
		"secondary": {
			"path_label": secondary_path_label,
			"status_label": secondary_status_label,
			"detail_label": secondary_detail_label,
			"result_label": secondary_result_label,
			"slider_label": secondary_slider_label,
			"player_host": secondary_player_host,
			"seek_slider": secondary_seek_slider,
			"volume_slider": secondary_volume_slider,
			"loop_check": secondary_loop_check,
		},
	}
	_selected_paths = {
		AeroAudioLoader.DEFAULT_AUDIO_ID: SAMPLE_OGG_PATH,
		"secondary": SAMPLE_WAV_PATH,
	}
	_suspend_seek_updates = {
		AeroAudioLoader.DEFAULT_AUDIO_ID: false,
		"secondary": false,
	}

	_manager = AeroAudioLoader.new()
	add_child(_manager)
	_manager.audio_state_changed.connect(_on_audio_state_changed)
	_manager.audio_media_loaded.connect(_on_audio_media_loaded)
	_manager.audio_error_raised.connect(_on_audio_error_raised)
	_manager.audio_position_changed.connect(_on_audio_position_changed)
	_manager.audio_playback_finished.connect(_on_audio_playback_finished)

	picker.filters = PackedStringArray(["*.ogg ; Ogg Vorbis", "*.wav ; Waveform Audio"])
	for slot_id in SLOT_IDS:
		var ui: Dictionary = _ui(slot_id)
		ui["path_label"].text = str(_selected_paths.get(slot_id, ""))
		ui["volume_slider"].value = 0.0
		ui["loop_check"].button_pressed = slot_id == AeroAudioLoader.DEFAULT_AUDIO_ID
		_manager.attach_surface(ui["player_host"], slot_id)
	set_process(true)
	_refresh_all()

func _process(_delta: float) -> void:
	_refresh_all()

func _ui(slot_id: String) -> Dictionary:
	return _slot_ui.get(slot_id, {})

func _refresh_all() -> void:
	if _manager == null:
		return
	summary_label.text = "Slots: %s" % ", ".join(_manager.list_audio_ids())
	for slot_id in SLOT_IDS:
		_refresh_slot(slot_id)

func _refresh_slot(slot_id: String) -> void:
	var ui := _ui(slot_id)
	if ui.is_empty():
		return
	var state: Dictionary = _manager.get_state(slot_id)
	var media_info: Dictionary = _manager.get_media_info(slot_id)
	var duration := float(state.get("duration", 0.0))
	var position := float(state.get("position", 0.0))
	ui["status_label"].text = "%s state: %s" % [_display_slot_name(slot_id), str(state.get("state", "idle"))]
	ui["detail_label"].text = "Loop: %s | Position: %.2f / %.2f | Volume: %.1f dB | Format: %s | Path type: %s" % [
		"on" if bool(state.get("loop", false)) else "off",
		position,
		duration,
		float(state.get("volume_db", 0.0)),
		str(media_info.get("extension", "")),
		str(media_info.get("locality", "")),
	]
	ui["slider_label"].text = "Seek %.2fs | Volume %.1f dB" % [ui["seek_slider"].value, ui["volume_slider"].value]
	if not bool(_suspend_seek_updates.get(slot_id, false)):
		ui["seek_slider"].max_value = maxf(duration, 0.01)
		ui["seek_slider"].value = clampf(position, 0.0, ui["seek_slider"].max_value)
	ui["path_label"].text = str(_selected_paths.get(slot_id, ""))

func _display_slot_name(slot_id: String) -> String:
	return "Default" if slot_id == AeroAudioLoader.DEFAULT_AUDIO_ID else "Secondary"

func _choose_path(slot_id: String, path: String) -> void:
	_selected_paths[slot_id] = path
	_ui(slot_id)["path_label"].text = path
	_ui(slot_id)["result_label"].text = "%s selected %s" % [_display_slot_name(slot_id), path]

func _load_selected_path(slot_id: String) -> void:
	var ui := _ui(slot_id)
	var path := str(_selected_paths.get(slot_id, ""))
	if path.is_empty():
		ui["result_label"].text = "Pick an .ogg or .wav file first."
		return
	var source := {
		"path": path,
		"loop": bool(ui["loop_check"].button_pressed),
		"volume_db": float(ui["volume_slider"].value),
		"metadata": {"source": "audio_tool_testbed", "slot": slot_id},
	}
	_manager.load(source, slot_id).on_success(func(result: Dictionary) -> void:
		ui["result_label"].text = "%s loaded %s" % [_display_slot_name(slot_id), str(result.get("media_info", {}).get("path", path))]
	).on_failure(func(error_info: Dictionary) -> void:
		ui["result_label"].text = "%s load failed: %s" % [_display_slot_name(slot_id), str(error_info.get("message", "Unknown error"))]
	)

func _play_slot(slot_id: String) -> void:
	var ui := _ui(slot_id)
	_manager.play(slot_id).on_failure(func(error_info: Dictionary) -> void:
		ui["result_label"].text = "%s play failed: %s" % [_display_slot_name(slot_id), str(error_info.get("message", "Unknown error"))]
	)

func _pause_slot(slot_id: String) -> void:
	var ui := _ui(slot_id)
	_manager.pause(slot_id).on_failure(func(error_info: Dictionary) -> void:
		ui["result_label"].text = "%s pause failed: %s" % [_display_slot_name(slot_id), str(error_info.get("message", "Unknown error"))]
	)

func _resume_slot(slot_id: String) -> void:
	var ui := _ui(slot_id)
	_manager.resume(slot_id).on_failure(func(error_info: Dictionary) -> void:
		ui["result_label"].text = "%s resume failed: %s" % [_display_slot_name(slot_id), str(error_info.get("message", "Unknown error"))]
	)

func _stop_slot(slot_id: String) -> void:
	var ui := _ui(slot_id)
	_manager.stop(slot_id).on_failure(func(error_info: Dictionary) -> void:
		ui["result_label"].text = "%s stop failed: %s" % [_display_slot_name(slot_id), str(error_info.get("message", "Unknown error"))]
	)

func _unload_slot(slot_id: String) -> void:
	var ui := _ui(slot_id)
	_manager.unload(slot_id).on_success(func(_result: Dictionary) -> void:
		ui["result_label"].text = "%s unloaded" % _display_slot_name(slot_id)
	)

func _set_loop(slot_id: String, enabled: bool) -> void:
	var ui := _ui(slot_id)
	if not bool(_manager.get_state(slot_id).get("media_loaded", false)):
		ui["result_label"].text = "%s loop will apply on next load" % _display_slot_name(slot_id)
		_refresh_slot(slot_id)
		return
	_manager.set_loop_enabled(enabled, slot_id).on_success(func(_result: Dictionary) -> void:
		ui["result_label"].text = "%s loop %s" % [_display_slot_name(slot_id), "enabled" if enabled else "disabled"]
	).on_failure(func(error_info: Dictionary) -> void:
		ui["result_label"].text = "%s loop change failed: %s" % [_display_slot_name(slot_id), str(error_info.get("message", "Unknown error"))]
	)

func _on_audio_state_changed(audio_id: String, _state: String, _detail: Dictionary) -> void:
	_refresh_slot(audio_id)

func _on_audio_media_loaded(audio_id: String, info: Dictionary) -> void:
	_ui(audio_id)["result_label"].text = "%s loaded %s" % [_display_slot_name(audio_id), str(info.get("path", ""))]
	_refresh_slot(audio_id)

func _on_audio_error_raised(audio_id: String, error_info: Dictionary) -> void:
	_ui(audio_id)["result_label"].text = "%s error: %s" % [_display_slot_name(audio_id), str(error_info.get("message", "Unknown error"))]
	_refresh_slot(audio_id)

func _on_audio_position_changed(audio_id: String, _seconds: float, _normalized: float) -> void:
	_refresh_slot(audio_id)

func _on_audio_playback_finished(audio_id: String) -> void:
	_ui(audio_id)["result_label"].text = "%s playback finished" % _display_slot_name(audio_id)
	_refresh_slot(audio_id)

func _on_file_dialog_file_selected(path: String) -> void:
	_choose_path(_active_dialog_slot, path)

func _on_default_choose_file_button_pressed() -> void:
	_active_dialog_slot = AeroAudioLoader.DEFAULT_AUDIO_ID
	picker.popup_centered_ratio(0.8)

func _on_default_use_sample_ogg_button_pressed() -> void:
	_choose_path(AeroAudioLoader.DEFAULT_AUDIO_ID, SAMPLE_OGG_PATH)

func _on_default_use_sample_wav_button_pressed() -> void:
	_choose_path(AeroAudioLoader.DEFAULT_AUDIO_ID, SAMPLE_WAV_PATH)

func _on_default_load_button_pressed() -> void:
	_load_selected_path(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_play_button_pressed() -> void:
	_play_slot(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_pause_button_pressed() -> void:
	_pause_slot(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_resume_button_pressed() -> void:
	_resume_slot(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_stop_button_pressed() -> void:
	_stop_slot(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_unload_button_pressed() -> void:
	_unload_slot(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_seek_slider_drag_started() -> void:
	_suspend_seek_updates[AeroAudioLoader.DEFAULT_AUDIO_ID] = true

func _on_default_seek_slider_drag_ended(_value_changed: bool) -> void:
	_suspend_seek_updates[AeroAudioLoader.DEFAULT_AUDIO_ID] = false
	_manager.seek(default_seek_slider.value, AeroAudioLoader.DEFAULT_AUDIO_ID).on_failure(func(error_info: Dictionary) -> void:
		default_result_label.text = "Default seek failed: %s" % str(error_info.get("message", "Unknown error"))
	)

func _on_default_volume_slider_value_changed(value: float) -> void:
	_manager.set_volume_db(value, AeroAudioLoader.DEFAULT_AUDIO_ID)
	_refresh_slot(AeroAudioLoader.DEFAULT_AUDIO_ID)

func _on_default_loop_check_toggled(toggled_on: bool) -> void:
	_set_loop(AeroAudioLoader.DEFAULT_AUDIO_ID, toggled_on)

func _on_secondary_choose_file_button_pressed() -> void:
	_active_dialog_slot = "secondary"
	picker.popup_centered_ratio(0.8)

func _on_secondary_use_sample_ogg_button_pressed() -> void:
	_choose_path("secondary", SAMPLE_OGG_PATH)

func _on_secondary_use_sample_wav_button_pressed() -> void:
	_choose_path("secondary", SAMPLE_WAV_PATH)

func _on_secondary_load_button_pressed() -> void:
	_load_selected_path("secondary")

func _on_secondary_play_button_pressed() -> void:
	_play_slot("secondary")

func _on_secondary_pause_button_pressed() -> void:
	_pause_slot("secondary")

func _on_secondary_resume_button_pressed() -> void:
	_resume_slot("secondary")

func _on_secondary_stop_button_pressed() -> void:
	_stop_slot("secondary")

func _on_secondary_unload_button_pressed() -> void:
	_unload_slot("secondary")

func _on_secondary_seek_slider_drag_started() -> void:
	_suspend_seek_updates["secondary"] = true

func _on_secondary_seek_slider_drag_ended(_value_changed: bool) -> void:
	_suspend_seek_updates["secondary"] = false
	_manager.seek(secondary_seek_slider.value, "secondary").on_failure(func(error_info: Dictionary) -> void:
		secondary_result_label.text = "Secondary seek failed: %s" % str(error_info.get("message", "Unknown error"))
	)

func _on_secondary_volume_slider_value_changed(value: float) -> void:
	_manager.set_volume_db(value, "secondary")
	_refresh_slot("secondary")

func _on_secondary_loop_check_toggled(toggled_on: bool) -> void:
	_set_loop("secondary", toggled_on)
