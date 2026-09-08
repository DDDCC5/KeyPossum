# KeyPossum Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the independent Windows task and a final code review. Execute macOS and integration locally. Steps use checkbox tracking.

**Goal:** Deliver runnable native Mac and Windows alpha builds and a complete open-source project.

**Architecture:** Independent native shells and input controllers consume equivalent deterministic session state machines. No external runtime dependencies beyond platform libraries and the bundled .NET runtime. Native interception and emergency recovery remain separate from the UI.

**Tech Stack:** Swift 6 in Swift 5 language mode, AppKit/SwiftUI, CoreGraphics; .NET 10, C#, WPF, Win32; Python for release assembly.

**Spec:** `docs/design.md`

## Global constraints

macOS 26+ ARM64; Windows 11 x64. Four distinct characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. 3-second preparation, exact four-key 5-second hold, 180-second hard session ceiling. Chinese/English. MIT. No drivers, telemetry or network activity. Windows touchscreen devices blocked. Synced `sources/` remain untouched.

## Task 1: macOS application

Files: `macos/Package.swift`, `macos/Sources/KeyPossumCore/Session.swift`, `macos/Tests/KeyPossumCoreTests/SessionTests.swift`, `macos/Sources/KeyPossum/{main,InputController,Application}.swift`, `scripts/build-macos.sh`.

Interfaces: pure session receives physical integer key IDs and monotonic seconds. Input controller owns session on its event thread; UI receives immutable snapshots. Preparation occurs after exact chord recognition and all keys released. Session exposes phase, remaining, progress and transitions. Emergency stop is idempotent.

- [x] Write literal behavior tests first: invalid duplicates; no lock before chord check; preparation cancelled by input; exact hold completes at 5 not 4.99 seconds; a fifth key and modifiers reset; repeats do not reset; 180-second timeout; backward time never advances; after success require release or bounded drain.
- [x] Run `swift run --package-path macos --scratch-path .cache/swift-build --disable-sandbox SessionTests` and record missing implementation failure, then implement core and get tests green.
- [x] Implement permission preflight, session-level event tap, all relevant event mask, key mapping, failure callbacks and independent timers. Do not claim unverified gesture suppression; add first-run short qualification trial and explicit user confirmation.
- [x] Implement UI with combination editor, random generation, phase-specific instructions, ring, local custom settings, capability qualification, reset qualification button and exit.
- [x] Build an ARM64 .app with Info.plist and icon; ad-hoc sign. Test pure logic, compile, inspect binary and open UI without initiating interception automatically.

## Task 2: Windows application

Files: `windows/KeyPossum.Core/`, `windows/KeyPossum.Core.Tests/`, `windows/KeyPossum/`, `scripts/build-windows.ps1`.

Interfaces: equivalent pure session, dedicated hook thread with message pump and immutable UI snapshots. Separate process supervisor watches the owning application and may terminate only it if the bounded safety deadline is breached.

- [x] Write executable dependency-free core tests covering the same boundaries as Task 1; record red/green output with .NET 10.
- [x] Implement pure session and production Win32 controller. Use low-level hooks; never BlockInput alone because unlock observation must remain available. Block touchscreen capability before starting and on hotplug; cancel on session/power transitions and UI heartbeat loss. Filter injected keys from unlock recognition.
- [x] Build native WPF window and offline JSON settings. Validate persisted values. Use exact physical IDs including modifiers and distinguish key-up events; no raw keystroke logs.
- [x] Include qualification mode for trackpad gestures and elevated windows. Only explicit post-trial success enables normal mode; invalidate qualification on OS/app/device changes.
- [x] Publish self-contained `win-x64` directory so no .NET installation is required by users. Include icon. Compile locally if Windows targeting restore is available, and run core tests on Mac; physical Windows tests remain pending.

## Task 3: identity, packaging and open-source handoff

Files: `assets/`, `.github/workflows/build.yml`, `README.md`, `README.en.md`, `LICENSE`, `docs/{testing,github-guide,installation,verification}.md`, `scripts/`.

- [x] Generate an original possum-playing-dead icon via built-in image generation; keep source PNG and produce ICO/ICNS by deterministic format conversion.
- [x] Build both platforms, bundle release archives and SHA-256 sums, and assemble clean source ZIP excluding caches/toolchains/generated binaries.
- [x] Configure CI to test, build and upload artifacts for macOS and Windows. Do not automatically publish releases from branch pushes.
- [x] Write beginner instructions for uploading source and using Actions/Release downloads. Document unsigned installation, accessibility permissions, reserved keys, unsupported touch and pending real-device checks.
- [x] Review the complete input/recovery code with a fresh reviewer; fix load-bearing issues, run covering tests, record verification evidence and remaining limitations.

## Progress / rulings

- Existing directory contains only read-only project references. A new `KeyPossum/` directory provides isolation; no existing code or git branch is modified.
- User has approved implementation; execute without intermediate approval checkpoints. Keep public GitHub publishing pending until destination is known.
- Qualification trial is necessary because successful hook installation cannot prove complete gesture interception. This implements the agreed capability gate rather than silently downgrading protection.

## Verification status

Implementation, compilation, automated core/supervisor tests, Mac UI preview and source packaging are complete. Physical input acceptance on macOS26 and Intel Windows11 remains pending with the user; no global keyboard/mouse lock was initiated automatically. See `docs/verification.md`. GitHub publishing remains pending a user repository destination.
