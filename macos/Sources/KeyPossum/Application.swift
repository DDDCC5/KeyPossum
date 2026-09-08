import AppKit
import SwiftUI
import KeyPossumCore

func tr(_ chinese: String, _ english: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? chinese : english
}

final class AppModel: ObservableObject {
    @Published var code: String
    @Published var saveCustom: Bool
    @Published var snapshot: InputSnapshot?
    @Published var busy = false
    @Published var qualified = false
    @Published var confirmTrial = false
    @Published var message = ""
    private var controller: InputController?
    private var heartbeatTimer: Timer?
    private var trialFingerprint: String?
    private var observers: [NSObjectProtocol] = []
    private let defaults = UserDefaults.standard

    init() {
        let saved = UserDefaults.standard.string(forKey: "customCode").flatMap(Combination.normalize)
        code = saved ?? Combination.random()
        saveCustom = saved != nil
        if UserDefaults.standard.bool(forKey: "sessionActive") {
            UserDefaults.standard.removeObject(forKey: "qualifiedDevices")
            UserDefaults.standard.removeObject(forKey: "sessionActive")
        }
        refreshQualification()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.controller?.heartbeat()
        }
        for event in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                self?.controller?.stop("session")
            })
        }
    }

    func refreshQualification() {
        let current = DeviceInventory.fingerprint()
        qualified = current != nil && current == defaults.string(forKey: "qualifiedDevices")
    }
    func randomize() { code = Combination.random(); saveCustom = false; defaults.removeObject(forKey: "customCode") }
    func forgetQualification() {
        defaults.removeObject(forKey: "qualifiedDevices"); qualified = false; confirmTrial = false
        message = tr("下次开始前将重新试测。", "A new device trial is required before cleaning.")
    }

    func start() {
        guard !busy else { return }
        refreshQualification()
        confirmTrial = false
        guard let valid = Combination.normalize(code) else {
            message = tr("请输入四个不同的字母或数字，不含 O、0、I、1。", "Use four different letters or digits, excluding O, 0, I, 1."); return
        }
        code = valid
        guard InputController.permitted else {
            message = tr("请先授权“辅助功能”和“输入监控”，然后重新打开应用。", "Grant Accessibility and Input Monitoring, then reopen KeyPossum."); return
        }
        guard !InputController.secureInput else {
            message = tr("系统正在保护密码输入。请退出密码输入界面后重试。", "Secure Input is active. Leave the password field and try again."); return
        }
        guard let fingerprint = DeviceInventory.fingerprint() else {
            message = tr("无法确认输入设备，暂不能开始。", "Cannot identify input devices. Cleaning cannot start."); return
        }
        if saveCustom { defaults.set(valid, forKey: "customCode") } else { defaults.removeObject(forKey: "customCode") }
        let trial = !qualified
        trialFingerprint = fingerprint
        defaults.set(true, forKey: "sessionActive")
        busy = true; message = ""
        snapshot = InputSnapshot(phase: .checking, progress: 0, remaining: trial ? 15 : 180, reason: nil, trial: trial, reachedCleaning: false, error: nil)
        let controller = InputController(code: valid, trial: trial, fingerprint: fingerprint) { [weak self] value in
            self?.receive(value)
        }
        self.controller = controller
        controller.start()
    }

    private func receive(_ value: InputSnapshot) {
        snapshot = value
        guard value.phase == .finished else { return }
        defaults.removeObject(forKey: "sessionActive")
        busy = false; controller = nil
        if value.reason == .failure || (value.error != nil && value.error != "cancelled") {
            forgetQualification()
            message = errorMessage(value.error ?? "backend")
        } else if value.reason == .cancelled {
            message = tr("已取消，输入已恢复。", "Cancelled. Input is restored.")
        } else if value.trial && value.reachedCleaning {
            confirmTrial = true
            message = tr("试测结束。请确认是否有输入漏出。", "Trial ended. Confirm whether any input got through.")
        } else {
            message = tr("键盘复活啦。输入已恢复。", "Possum is awake. Input is restored.")
        }
    }

    func confirm(success: Bool) {
        confirmTrial = false
        guard success, let trialFingerprint, DeviceInventory.fingerprint() == trialFingerprint else {
            forgetQualification()
            message = tr("此设备尚未通过验证。请勿开始清洁；可重新试测。", "Device not qualified. Do not clean; you may repeat the trial.")
            return
        }
        defaults.set(trialFingerprint, forKey: "qualifiedDevices")
        qualified = true
        message = tr("设备试测已确认，可以开始清洁。", "Device trial confirmed. Ready to clean.")
    }

    func cancel() { controller?.stop() }
    func shutdown() { controller?.stop(); heartbeatTimer?.invalidate() }

    private func errorMessage(_ code: String) -> String {
        switch code {
        case "release-initial": return tr("请松开全部键盘和鼠标按键，再开始。", "Release every key and mouse button, then retry.")
        case "devices": return tr("输入设备发生变化，已恢复输入。请重新试测。", "Input devices changed. Input restored; repeat the trial.")
        case "permissions": return tr("权限或安全输入状态变化，已结束保护。", "Permissions or Secure Input changed. Protection ended.")
        case "session": return tr("系统休眠或会话切换，已结束保护。", "Sleep or session switch ended protection.")
        default: return tr("输入保护异常，已恢复输入。请重新试测。", "Input protection failed. Input restored; repeat the trial.")
        }
    }
}

struct PossumView: View {
    @ObservedObject var model: AppModel
    private let plum = Color(red: 0.39, green: 0.26, blue: 0.47)
    private let ivory = Color(red: 0.98, green: 0.97, blue: 0.95)
    private var phase: Phase? { model.snapshot?.phase }
    private var isLocked: Bool { model.busy && (phase == .cleaning || phase == .draining) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                if let image = NSImage(named: "keypossum") {
                    Image(nsImage: image).resizable().frame(width: 72, height: 72)
                } else { Image(systemName: "keyboard").font(.system(size: 40)).frame(width: 72, height: 72) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("KeyPossum").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(plum)
                    Text(tr("键盘装死，安心擦擦。", "Play dead. Clean happy.")).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Circle().fill(model.qualified ? Color.green : Color.orange).frame(width: 7, height: 7)
                Text(model.qualified ? tr("本机试测已确认", "Device trial confirmed") : tr("首次使用 · 需做 15 秒试测", "First use · 15-second device trial"))
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("ALPHA 0.1").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Text(tr("你的四键唤醒组合", "YOUR FOUR WAKE-UP KEYS")).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                if model.busy {
                    HStack(spacing: 10) {
                        ForEach(Array(model.code.enumerated()), id: \.offset) { _, character in
                            Text(String(character)).font(.system(size: 29, weight: .bold, design: .monospaced))
                                .frame(width: 58, height: 58).background(ivory, in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(plum.opacity(0.15)))
                        }
                    }.foregroundStyle(plum)
                } else {
                    HStack(spacing: 12) {
                        TextField("AB23", text: $model.code)
                            .font(.system(size: 27, weight: .bold, design: .monospaced)).multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder).frame(width: 200)
                            .accessibilityLabel(tr("四位解锁组合", "Four-key combination"))
                        Button(action: model.randomize) { Image(systemName: "shuffle").font(.system(size: 17)) }
                            .help(tr("随机生成", "Generate randomly"))
                    }
                }
                if !model.busy {
                    Toggle(tr("记住我的自定义组合", "Remember my custom combination"), isOn: $model.saveCustom).font(.system(size: 11))
                } else {
                    Text(tr("按英文键帽位置，不需要 Shift", "Use English keycap positions. No Shift.")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(18).frame(maxWidth: .infinity).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))

            ZStack {
                Circle().stroke(plum.opacity(0.10), lineWidth: 7)
                Circle().trim(from: 0, to: model.snapshot?.progress ?? 0)
                    .stroke(plum, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(ringText).font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(ringCaption).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.frame(width: 98, height: 98).foregroundStyle(plum)

            VStack(spacing: 7) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(instructions).font(.system(size: 12)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 70)

            if model.confirmTrial {
                VStack(spacing: 8) {
                    Text(tr("刚才是否所有按键、鼠标及触控板手势都无效？", "Were ALL keys, mouse actions and trackpad gestures blocked?"))
                        .font(.system(size: 11)).multilineTextAlignment(.center)
                    HStack {
                        Button(tr("有漏出 / 不确定", "Leaked / unsure")) { model.confirm(success: false) }
                        Button(tr("全部无效", "All blocked")) { model.confirm(success: true) }.tint(plum)
                    }
                }
            } else if model.busy {
                if !isLocked { Button(tr("取消", "Cancel"), action: model.cancel) }
                else { Text(tr("仅四键长按或到时解锁", "Hold the four keys, or wait for automatic unlock")).font(.system(size: 11)).foregroundStyle(plum) }
            } else {
                Button(action: model.start) {
                    Text(model.qualified ? tr("开始清洁", "Start cleaning") : tr("开始设备试测", "Start device trial"))
                        .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(.borderedProminent).tint(plum)
            }

            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(plum).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !model.busy {
                HStack {
                    Button(tr("授予权限", "Permissions"), action: InputController.requestPermissions)
                    Spacer()
                    Button(tr("重新试测", "Reset trial"), action: model.forgetQualification)
                }.buttonStyle(.link).font(.system(size: 11))
            }
            Text(tr("最长 3 分钟自动恢复 · 不拦截电源键等系统保留操作\n先试测触控板多指手势和媒体键；有漏出请勿清洁。", "Auto-restores within 3 minutes · System / power controls excepted\nTest trackpad gestures and media keys first. Do not clean if input leaks."))
                .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(26).frame(width: 440, height: 680)
        .background(ivory).preferredColorScheme(.light)
    }

    private var ringText: String {
        guard model.busy, let s = model.snapshot else { return "3:00" }
        if s.phase == .cleaning || s.phase == .draining {
            let value = max(0, Int(ceil(s.remaining)))
            return String(format: "%d:%02d", value / 60, value % 60)
        }
        if s.phase == .preparing { return String(max(1, Int(ceil(s.remaining)))) }
        return "4"
    }
    private var ringCaption: String {
        if phase == .preparing && model.busy { return tr("准备锁定", "GET READY") }
        if isLocked { return tr("剩余时间", "REMAINING") }
        return model.busy ? tr("同时按下", "PRESS TOGETHER") : tr("最长清洁时间", "MAX CLEAN TIME")
    }
    private var title: String {
        guard model.busy else { return tr("给键盘放个小假", "A little break for your keyboard") }
        switch phase {
        case .checking: return tr("先试一下四个键", "Check your four keys")
        case .releaseToPrepare: return tr("很好，现在全部松开", "Great. Release all keys")
        case .preparing: return tr("马上开始，暂时别碰", "Starting soon. Hands off")
        case .cleaning: return model.snapshot?.trial == true ? tr("设备试测中 · 请尝试输入", "DEVICE TRIAL · Try your inputs") : tr("负鼠装死中，开始擦擦吧", "Possum is playing dead. Time to clean")
        case .draining: return tr("解锁成功，请松开按键", "Unlocked. Release the keys")
        default: return tr("输入已恢复", "Input restored")
        }
    }
    private var instructions: String {
        guard model.busy else { return tr("暂时停用键盘、鼠标与触控板。\n只按住指定四键 5 秒即可唤醒。", "Pause keyboard, mouse and trackpad input.\nHold only your four keys for 5 seconds to wake them.") }
        switch phase {
        case .checking: return tr("同时按下上方四个键，确认键盘能够识别。", "Press the four keys above together to verify recognition.")
        case .releaseToPrepare: return tr("松开所有按键后进入 3 秒倒计时。", "Release all keys to begin the 3-second countdown.")
        case .preparing: return tr("任何输入都会取消倒计时，需要重新确认四键。", "Any input cancels the countdown and requires a new key check.")
        case .cleaning:
            return model.snapshot?.trial == true
                ? tr("请试按媒体键、滚动、轻点和多指手势。\n15 秒后恢复，再确认是否全部无效。", "Try media keys, scrolling, taps and multi-finger gestures.\nInput returns in 15 seconds; then confirm the result.")
                : tr("只按住这四个键 5 秒解锁。\n松开任意键或多按其他键，进度清零。", "Hold only these four keys for 5 seconds to unlock.\nReleasing a key or adding another resets progress.")
        case .draining: return tr("松开四键，避免继续按住时输入到其他应用。", "Release the four keys before returning to other apps.")
        default: return ""
        }
    }
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var model: AppModel!
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        let content = NSHostingView(rootView: PossumView(model: model))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 680), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "KeyPossum"
        window.contentView = content
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let menu = NSMenu()
        let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("退出 KeyPossum", "Quit KeyPossum"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; NSApp.mainMenu = menu
        // Explicit preview mode renders our own view only; it never installs hooks.
        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
            let destination = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                    content.cacheDisplay(in: content.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: destination))
                }
                NSApp.terminate(nil)
            }
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { model.shutdown(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}
