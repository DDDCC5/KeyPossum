# KeyPossum 0.1.0-alpha.1 — approved design

Approved by the user on 2026-09-08. This is an offline, MIT-licensed keyboard-cleaning utility, not a security lock.

## Product contract

- macOS 26+ Apple Silicon and Windows 11 x64 (Intel/AMD). Two native applications: Swift/AppKit and C#/.NET/WPF.
- Small always-on-top cleaning window; Chinese when the OS language is Chinese, English otherwise.
- Four distinct uppercase ASCII letters or digits from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Random by default; custom combinations persist locally. Never store keyboard activity.
- Confirm the combination using physical key presses before locking. Only exactly the four selected physical keys qualify. Require release of all keys before the 3-second preparation countdown. Any activity during preparation cancels it.
- Suppress internal and external keyboard, mouse and trackpad input while cleaning, while privately observing keyboard state for the unlock gesture.
- Display the combination and remaining time throughout cleaning. Holding exactly those four keys for 5 continuous seconds fills a circular progress indicator and unlocks. Release, extra key or modifiers reset progress.
- Restore input at 180 seconds even when the UI stops responding. Use monotonic time. The unlock keys must not leak into the foreground app during release; bound release draining so it cannot create an indefinite lock.
- Stay in the window after cleaning. Do not start automatically at login. Do not access network or collect telemetry.
- Windows touch support deferred. Detect touch devices before starting; fail closed if device capability cannot be determined. Abort on device topology changes during a session.
- System-reserved/hardware operations (including power and Windows secure attention) are explicit exceptions. Do not disable hardware or install a driver in this release.
- On permission loss, hook failure, session change or backend failure restore input and show that protection ended. Never report complete protection solely because an API was installed.

## Capability qualification

OS APIs cannot prove all input pathways are covered. First-run manual capability qualification must cover mouse motion/buttons/scroll and trackpad taps/multifinger gestures, media keys and relevant external devices. Until qualified the UI must label the session as a TEST, not full protection. During a short trial user should attempt gestures and report any leakage. Store a local qualification only after trial ends and user explicitly confirms; clear it on application/OS version or device configuration change. Any unsupported path blocks normal cleaning. Actual product release requires both physical test machines; source/build success alone does not qualify a platform.

## Architecture and delivery

Each platform has a pure state machine, native input controller, native UI, local settings and packaging script. Pure logic is tested independently from OS hooks. Native controllers run outside the UI thread; callback work is constant/bounded and does not log events. A watchdog stops interception if the UI heartbeat expires. A separate supervisor process bounds a frozen worker to no more than the session deadline. Supervisor termination targets only its owned worker.

Deliver source, PNG/ICNS/ICO icon files, build scripts, CI for both OSs, installation guide, test matrix, MIT license, contribution/security guidance and a beginner GitHub guide. Alpha packages may be unsigned (Mac ad-hoc signed). No paid signing or publishing without a concrete repository destination.
