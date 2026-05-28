# AeroBeat Tool Audio Player Testbed Load→Play Regression

**Date:** 2026-05-28  
**Status:** Complete  
**Last Updated:** 2026-05-28 10:18 EDT  
**Blocked Reason:** None  
**Agent:** `cookie`

---

## Goal

Fix the `.testbed` regression in `aerobeat-tool-audio-player` where loading a sample OGG/WAV in `audio_tool_testbed` does not leave the slot in a playable state, even though the underlying vendor audio package works.

---

## Overview

This work belongs to the owning repo `aerobeat-tool-audio-player`, so the plan lives in that repo’s `/.plans/` folder. Derrick’s human repro is specific and narrow: in `audio_tool_testbed.tscn`, choosing a sample OGG/WAV, pressing **Load**, and then pressing **Play** leaves the slot reporting that audio must be loaded before it can be played. That pointed to a likely wrapper/state propagation mismatch between `src/AeroToolManager.gd` and the vendor audio manager contract it wraps, rather than a raw decoding problem in the vendor backend itself.

Derrick explicitly instructed execution with QA and audit skipped because Derrick would perform the human confirmation pass directly. The implementation therefore stopped after the coder fix plus repo-local automated validation, and this plan records that QA/audit were intentionally skipped by request rather than forgotten.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Owning repo root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player` |
| `REF-02` | Testbed scene repro surface | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/scenes/audio_tool_testbed.tscn` |
| `REF-03` | Testbed controller script | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/scripts/audio_tool_testbed.gd` |
| `REF-04` | Tool wrapper implementation | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/AeroToolManager.gd` |
| `REF-05` | Vendor manager/backend surface imported into the testbed | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/addons/aerobeat-vendor-godot-audio/src/` |

---

## Tasks

### Task 1: Diagnose and implement the repo-owned fix

**Bead ID:** `aerobeat-tool-audio-player-8gq`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Claim the assigned bead with `bd update <id> --status in_progress --json` at start. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player`, reproduce or reason through the `.testbed` bug where the audio slot reports that audio must be loaded before play after using the sample OGG/WAV load flow. Compare the repo-owned wrapper (`src/AeroToolManager.gd`) and testbed glue against the underlying vendor manager behavior, then implement the fix in the real owning source repo. Do not patch generated addon copies. Run relevant repo-local validation and commit/push to `main` by default before handoff. Record root cause, changed files, validation, and commit hash.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/src/AeroToolManager.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-audio-player/.testbed/tests/test_AeroToolManager.gd`

**Status:** ✅ Complete

**Results:** The root cause was slot-routing drift inside `AeroToolManager`. The tool wrapper creates one vendor runtime manager per tool-facing `audio_id`, but `load()` was still allowing vendor/testbed slot metadata like `default` and `secondary` to control where media was loaded, while later wrapper calls such as `play()`, `seek()`, and `get_state()` relied on that runtime manager’s own internal default vendor slot. That meant media could be loaded into one vendor slot and then `play()` would check a different slot and report that audio must be loaded first. The fix forced wrapper operations for a given `audio_id` to use that runtime manager’s actual vendor slot consistently, and stamped normalized sources with the runtime slot before delegating to the vendor manager. A regression test was added to mimic the testbed-style `metadata.slot` flow and verify load → play works for both the default and secondary audio IDs. Repo-local validation passed: `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` completed with `9/9 passed`. The fix was committed and pushed in `a710778` (`Fix testbed load-to-play slot routing`).

---

### Task 2: QA the exact human repro in the `.testbed`

**Bead ID:** `Skipped by user`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`  
**Prompt:** Skipped by Derrick for this execution pass; Derrick will perform the human verification directly.

**Folders Created/Deleted/Modified:**
- None for this execution pass

**Files Created/Deleted/Modified:**
- None for this execution pass

**Status:** ⏭️ Skipped by user

**Results:** Derrick explicitly asked to skip QA and confirm the behavior manually after the fix lands.

---

### Task 3: Audit the final fix and source-of-truth placement

**Bead ID:** `Skipped by user`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Skipped by Derrick for this execution pass; Derrick will perform the human confirmation directly.

**Folders Created/Deleted/Modified:**
- None for this execution pass

**Files Created/Deleted/Modified:**
- None for this execution pass

**Status:** ⏭️ Skipped by user

**Results:** Derrick explicitly asked to skip audit and rely on direct human confirmation for this slice.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Fixed the `.testbed` audio load → play regression in `aerobeat-tool-audio-player` by making the tool wrapper route all operations for each `audio_id` through a consistent vendor runtime slot, and added a regression test that covers the same slot metadata flow the testbed UI exercises.

**Reference Check:** `REF-01` through `REF-05` were satisfied for the implementation slice. Human QA and audit were intentionally deferred to Derrick by request.

**Commits:**
- `a710778` — `Fix testbed load-to-play slot routing`

**Lessons Learned:** Wrapper layers that virtualize multiple logical audio IDs on top of a vendor manager must stamp and preserve the vendor-facing slot identity consistently across load, play, seek, and state queries. Letting UI/vendor metadata drive slot selection on some calls but not others creates state drift that looks like a load failure even when media actually loaded successfully.

---

*Completed on 2026-05-28*
