[**Download prebuilt apps**](https://github.com/DDDCC5/KeyPossum/releases/tag/v0.1.1-alpha.1) — macOS DMG and Windows portable ZIP. Version 0.1.1-alpha.1 fixes the macOS Caps Lock/input-source event crash. macOS builds are ad-hoc signed, not notarized.

<p align="center"><img src="assets/keypossum.png" width="140" alt="An opossum playing dead on a keycap"></p>

# KeyPossum

**Play dead. Clean happy.** A native, offline keyboard-cleaning utility for macOS and Windows.

[简体中文](README.md)

**0.1.0-alpha.1 is an early build. The project owner reports successful operation and normal functionality on their macOS and Windows target devices.** Compilation does not verify input suppression. Complete the first-run 15-second trial, including media keys, mouse actions and multi-finger trackpad gestures. Confirm only if every tested input is blocked; do not clean if anything leaks. Touchscreen Windows devices are not supported. See [verification status](docs/verification.md).

## Flow

Choose a random or custom four-character combination. The characters must be distinct ASCII letters/digits, excluding O, 0, I and 1; custom combinations can be saved locally. Press the four physical keys together for recognition, release all keys, then wait through a 3-second countdown. Any input during preparation cancels the countdown.

The small topmost window keeps your four keys and remaining time visible. Hold **only those four keys for 5 continuous seconds** to unlock. Releasing a key or pressing an extra key/modifier resets progress. Input automatically returns at **180 seconds**. The first capability trial lasts only 15 seconds. The app stays open after cleaning.

Uses English keycap positions, independent of IME text. Other keyboard layouts need physical chord qualification. This gesture prevents accidental activation; it is not a secret or security password.

## Platforms

- macOS 26+, Apple Silicon; Swift, AppKit/SwiftUI, CoreGraphics.
- Windows 11 x64, Intel/AMD, non-touchscreen; C#, .NET 10, WPF, Win32.
- System language selects Chinese or English (English fallback).

Internal and external devices are included in qualification. Device changes end the session. Power/firmware controls, Windows secure attention and protected system pathways are exceptions. Native hooks do not imply complete driver/gesture coverage.

## Build

macOS with Xcode 26+ or equivalent Command Line Tools:

```sh
bash scripts/build-macos.sh
```

Windows with .NET 10 SDK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-windows.ps1
```

Build outputs go to `dist/`. The Windows distribution bundles the .NET runtime. Keep its files together. GitHub Actions builds and uploads artifacts without publishing releases automatically.

## Privacy and recovery

No accounts, telemetry, network requests or keystroke logs. Only local preferences and capability confirmation are stored. Separate UI heartbeat, native timers and a supervisor restore input if the app becomes unresponsive. No drivers are installed or hardware devices disabled. This is a cleaning aid, not a security lock.

Alpha builds are unsigned (macOS uses ad-hoc signing) and are not notarized. Use the OS's per-app approval UI if you trust the source; do not disable system-wide security controls.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [test checklist](docs/testing.md), and [MIT license](LICENSE). Artwork provenance and prompt are in [assets/README.md](assets/README.md).
