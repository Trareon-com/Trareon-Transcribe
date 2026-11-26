# Computer Use untuk Trareon Transcribe

Dokumen ini menjelaskan cara menggunakan `computer_use` (cua-driver) untuk melakukan GUI testing otomatis pada aplikasi Trareon Transcribe — mirip seperti Claude Code melakukan automated browser testing.

## Prerequisites

cua-driver v0.12.6 sudah terinstall dan terverifikasi:

| Check | Status |
|-------|--------|
| **Version** | ✅ 0.12.6 |
| **Accessibility** | ✅ Granted |
| **Screen Recording** | ✅ Granted |
| **Daemon** | ✅ Running (PID 51838) |
| **Platform** | macOS 26.5.2 (arm64, M4 Pro) |

## Quick Start

### 1. Screenshot + Element Detection

```python
computer_use(action="capture", mode="som", app="Trareon Transcribe")
```

Returns numbered overlays + AX tree. Gunakan nomor element untuk klik.

### 2. Click by Element Index (PREFERRED)

```python
computer_use(action="click", element=7, capture_after=True)
```

### 3. Click by Coordinate (fallback)

```python
computer_use(action="click", coordinate=[x, y], capture_after=True)
```

### 4. Type Text

```python
computer_use(action="type", text="Hello world")
```

### 5. Keyboard Shortcuts

```python
computer_use(action="key", keys="cmd+r")     # Start/stop recording
computer_use(action="key", keys="cmd+l")     # Open library
computer_use(action="key", keys="cmd+,")     # Open settings
computer_use(action="key", keys="cmd+/")     # Toggle shortcuts panel
```

### 6. Scroll

```python
computer_use(action="scroll", direction="down", amount=5, element=12)
```

## Smoke Test Workflow

### TC1: Launch App

```python
# 1. Launch via shell
terminal(command="open build/macos/Build/Products/Debug/Trareon Transcribe.app")
# 2. Wait
computer_use(action="wait", seconds=3)
# 3. Capture
computer_use(action="capture", mode="som")
# 4. Verify title or key element visible
```

### TC2: Wizard Flow

```python
# Step detection → Step 2
computer_use(action="click", element=<next_button_index>)
computer_use(action="capture", mode="som", capture_after=True)
# ... repeat for all 5 steps
```

### TC3: Main Screen Verification

```python
computer_use(action="capture", mode="som")
# Verify: Mulai button, mode selector, MIC/SPK indicators
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `cua-driver: command not found` | Run: `export PATH="$HOME/.local/bin:$PATH"` |
| Element index stale | Re-capture before clicking |
| Click had no effect | Try `delivery_mode="foreground"` |
| Type not working | Use `key` for shortcuts, `type` for text input |
| App not found | Build first: `flutter build macos --debug` |

## References

- `scripts/gui_smoke_test.sh` — Automated smoke test script
- Hermes `computer_use` skill — Detailed action reference
- `cua-driver skills install` — Install cua-driver skill pack for platform deep dives
