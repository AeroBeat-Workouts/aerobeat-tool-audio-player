# AeroBeat Tool Template

This is the official template for creating **Tool** repositories within the current AeroBeat v1 architecture.

It should be read against the locked product direction from `aerobeat-docs`:

- **Primary release target:** PC community first
- **Official v1 gameplay features:** Boxing and Flow
- **Official v1 gameplay input:** camera only
- **Tool stance:** tools should stay workflow-oriented and gameplay-mode agnostic enough to support the current product slice without implying equal-status future gameplay/input/platform scope
- **Tool lane ownership:** shared tool-side DTOs, progress/result models, and workflow interfaces belong in `aerobeat-tool-core`; concrete authoring/import/export/validation tooling belongs in specific `aerobeat-tool-*` repos

## 📋 Repository Details

- **Type:** Tool template
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Dependency contract:**
  - `aerobeat-tool-core` — required shared tool/workflow contract
  - additional adjacent lane/core repos only when the specific tool actually consumes them (commonly `aerobeat-content-core` or `aerobeat-asset-core`)

## Development flow

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

Restore dev/test dependencies from the repo root:

```bash
cd .testbed
godotenv addons install
```

Open the workbench:

```bash
godot --editor --path .testbed
```

## Validation

Run an import smoke check:

```bash
godot --headless --path .testbed --import
```

Run unit tests:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

## Architecture notes

- The singleton mirrors the vendor backend surface for `load`, `unload`, `play`, `pause`, `resume`, `stop`, `seek`, `set_volume_db`, and state/error listeners.
- The hidden proving surface in this repo now exercises the audio abstraction through two independent tool-managed slots. Each slot can load packaged or external `.ogg`/`.wav` assets, toggle loop mode, and drive playback/seek/volume controls without bleeding state into the other slot.
- Repo-local tests cover the singleton callbacks, slot-isolated playback behavior, and packaged/external audio source handling.
- The current package shape is consumed from the repo root (`subfolder: "/"`) for downstream installs.
