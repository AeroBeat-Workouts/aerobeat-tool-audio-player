# AeroBeat Tool Audio Player Testbed WAV Loop Playback Bug + Singleton Rename

**Date:** 2026-05-28  
**Status:** Complete  
**Last Updated:** 2026-05-28 10:55 EDT  
**Blocked Reason:** None  
**Agent:** `cookie`

---

## Goal

Fix the `aerobeat-tool-audio-player` `.testbed` bug where the WAV sample fails to play when loop is enabled, and rename the singleton source from `AeroToolManager.gd` to `AeroAudioLoader.gd` with matching testbed/script updates.

---

## Overview

This work belongs to `aerobeat-tool-audio-player`, so the plan lives in that repo’s `/.plans/` folder. The playback report narrowed the failure mode further: loop-enabled playback succeeded for OGG but still failed for the WAV sample. That pointed away from the already-fixed generic wrapper routing bug and toward a format-specific loop seam.

During implementation, the root cause turned out to live in the real owning vendor layer rather than the tool wrapper. Imported `AudioStreamWAV` fixtures were arriving with a zero-length loop window (`loop_begin = 0`, `loop_end = 0`). When loop was enabled after load, the backend switched WAV loop mode to forward but left that zero-length loop span intact, so the WAV sample had no usable loop window. The landed fix expanded the WAV loop end to the stream duration in sample frames when loop is enabled on an open-ended or zero-length WAV. In the same slice, the tool repo renamed its singleton source from `AeroToolManager.gd` to `AeroAudioLoader.gd` and updated repo-owned testbed/scripts/tests/docs to match.

Derrick explicitly instructed that manual QA/audit would be handled personally. This execution pass therefore stopped after the coder implementation, repo-local validation, and pushed commits across the true owning source repo plus the dependent tool repo.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Tool repo root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player` |
| `REF-02` | Testbed controller script | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/scripts/audio_tool_testbed.gd` |
| `REF-03` | Singleton implementation being renamed | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/AeroAudioLoader.gd` |
| `REF-04` | Updated repo-local regression coverage | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/tests/test_AeroAudioLoader.gd` |
| `REF-05` | True owning vendor backend loop logic | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/src/AeroGodotAudioBackend.gd` |
| `REF-06` | Tool testbed WAV import metadata | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/assets/audio/test-tone.wav.import` |

---

## Tasks

### Task 1: Diagnose/fix loop-enabled WAV playback and land the singleton rename

**Bead ID:** `aerobeat-tool-audio-player-t4w`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Claim the assigned bead with `bd update <id> --status in_progress --json` at start. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player`, diagnose why the `.testbed` WAV sample fails to play when loop is enabled even though the OGG sample now works. Compare the wrapper’s loop path, the vendor backend’s loop mutation for WAV streams, and the WAV test asset import metadata. In the same implementation pass, rename the singleton source from `src/AeroToolManager.gd` to `src/AeroAudioLoader.gd` and update repo-owned testbed/scripts/tests/docs to match. Implement the minimal real-source fix, add focused regression coverage for loop-enabled WAV playback plus the renamed singleton surface, run relevant repo-local validation, and commit/push to `main` by default before handoff. Do not patch generated addon copies.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/.testbed/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/src/AeroGodotAudioBackend.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-audio/.testbed/tests/test_AeroGodotAudioBackendFactory.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/AeroAudioLoader.gd` (renamed from `src/AeroToolManager.gd`)
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/tests/test_AeroAudioLoader.gd` (renamed from `.testbed/tests/test_AeroToolManager.gd`)
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/scripts/audio_tool_testbed.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/scenes/audio_tool_testbed.tscn`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/README.md`

**Status:** ✅ Complete

**Results:** The real bug was in the vendor layer, not the tool wrapper. Imported `AudioStreamWAV` fixtures were coming in with `loop_begin = 0` and `loop_end = 0`. When loop got enabled after load, the backend flipped WAV `loop_mode` to forward but left that zero-length loop window intact, so the WAV sample effectively had no usable loop span. The fix landed in the true owning vendor repo by expanding WAV `loop_end` to the stream duration in sample frames when loop is enabled on an open-ended or zero-length WAV. In the same slice, the tool repo renamed `src/AeroToolManager.gd` to `src/AeroAudioLoader.gd`, updated the matching test file name and repo-owned testbed/scripts/docs references, and added focused coverage for the renamed singleton plus WAV loop playback.

Validation passed in both repos:
- Vendor repo:
  - `godot --headless --path .testbed --import`
  - `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  - Result: `15/15 passed`
- Tool repo:
  - `godot --headless --path .testbed --import`
  - `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  - Result: `10/10 passed`

Pushed commits:
- `aerobeat-vendor-godot-audio`: `d33779a` — `Fix WAV loop window expansion`
- `aerobeat-tool-audio-player`: `ba0a10b` — `Rename audio loader and cover WAV loop playback`

---

### Task 2: QA the manual loop-enabled WAV repro + rename fallout

**Bead ID:** `Skipped by user`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-04`, `REF-06`  
**Prompt:** Skipped by Derrick for this execution pass; Derrick will manually verify loop-enabled WAV playback and the singleton rename fallout in the `.testbed`.

**Folders Created/Deleted/Modified:**
- None for this execution pass

**Files Created/Deleted/Modified:**
- None for this execution pass

**Status:** ⏭️ Skipped by user

**Results:** Derrick explicitly asked to handle QA manually.

---

### Task 3: Audit the final WAV-loop fix and rename placement

**Bead ID:** `Skipped by user`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Skipped by Derrick for this execution pass; Derrick will manually confirm the landed behavior and rename.

**Folders Created/Deleted/Modified:**
- None for this execution pass

**Files Created/Deleted/Modified:**
- None for this execution pass

**Status:** ⏭️ Skipped by user

**Results:** Derrick explicitly asked to handle audit manually.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Fixed the real WAV loop bug in `aerobeat-vendor-godot-audio` by expanding zero-length WAV loop windows to the stream duration when loop is enabled, then updated `aerobeat-tool-audio-player` to rename the singleton source to `AeroAudioLoader.gd` and refreshed repo-owned testbed/scripts/tests/docs to match while adding regression coverage for WAV loop playback.

**Reference Check:** `REF-01` through `REF-06` were satisfied for the implementation slice. Manual QA/audit were intentionally deferred to Derrick by request.

**Commits:**
- `d33779a` — `aerobeat-vendor-godot-audio`: `Fix WAV loop window expansion`
- `ba0a10b` — `aerobeat-tool-audio-player`: `Rename audio loader and cover WAV loop playback`

**Lessons Learned:** Format-specific loop bugs can live below the wrapper layer even after generic UI/slot behavior is fixed. For WAV assets specifically, a backend that enables loop mode also needs to ensure the loop window is non-zero and aligned to the stream duration. When a dependent repo exposes that backend through a singleton facade, renames and repro-surface updates are safest to land in the same slice as the regression proof.

---

*Completed on 2026-05-28*
