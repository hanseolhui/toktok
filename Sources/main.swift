// 톡톡 (TokTok) — 트랙패드 TipTap 제스처로 뒤로/앞으로 가기
//
// 손가락 하나를 댄 채로
//   왼쪽을 톡  → ⌘[  (뒤로)
//   오른쪽을 톡 → ⌘]  (앞으로)

import Cocoa
import ApplicationServices
import ServiceManagement

// MARK: - 설정 값

enum Tuning {
    /// 톡 치는 손가락이 닿아 있는 최대 시간(초)
    static let tapMaxDuration = 0.30
    /// 톡 치는 손가락이 움직여도 되는 최대 거리 (트랙패드 폭 = 1.0)
    static let tapMaxMove: Float = 0.04
    /// 기준 손가락이 톡 치는 손가락보다 최소 이만큼 먼저 닿아 있어야 함(초) — 두 손가락 탭(우클릭)과 구분
    static let anchorMinLead = 0.12
    /// 톡 치는 동안 기준 손가락이 움직여도 되는 최대 거리 — 스크롤·드래그와 구분
    static let anchorMaxMove: Float = 0.04
    /// 연속 입력 사이 최소 간격(초)
    static let minInterval = 0.08
}

// MARK: - 로그

enum Log {
    static var enabled = UserDefaults.standard.bool(forKey: "debug")
        || CommandLine.arguments.contains("--debug")
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/TokTok.log")
    static let queue = DispatchQueue(label: "toktok.log")

    static func write(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message())\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - 제스처 감지

final class TipTapDetector {
    static let shared = TipTapDetector()

    enum Direction { case left, right }

    private struct Finger {
        let startTime: Double
        let startX: Float, startY: Float
        var x: Float, y: Float
        /// 이 손가락이 닿아 있는 동안 동시에 닿았던 손가락 수의 최댓값
        var maxConcurrent: Int
        /// 이 손가락이 닿을 때 이미 닿아 있던 다른 손가락 (정확히 하나일 때만)
        var anchorID: Int32?
        var anchorX0: Float = 0, anchorY0: Float = 0
    }

    var enabled = true
    var onTipTap: ((Direction) -> Void)?

    private var fingers: [Int32: Finger] = [:]
    private var lastFire = 0.0

    /// 멀티터치 콜백 스레드에서 호출됨
    func process(_ touches: UnsafeMutablePointer<MTTouch>?, count: Int, time: Double) {
        var current: [Int32: (x: Float, y: Float)] = [:]
        if let touches {
            for i in 0..<count {
                let t = touches[i]
                guard t.state == 3 || t.state == 4 else { continue } // 실제로 닿아 있는 손가락만
                current[Int32(t.identifier)] = (t.normalized.position.x, t.normalized.position.y)
            }
        }

        // 새로 닿은 손가락 등록 / 위치 갱신
        for (id, p) in current {
            if var f = fingers[id] {
                f.x = p.x; f.y = p.y
                f.maxConcurrent = max(f.maxConcurrent, current.count)
                fingers[id] = f
            } else {
                var f = Finger(startTime: time, startX: p.x, startY: p.y, x: p.x, y: p.y,
                               maxConcurrent: current.count)
                let others = fingers.filter { current[$0.key] != nil }
                if others.count == 1, let (aid, a) = others.first {
                    f.anchorID = aid; f.anchorX0 = a.x; f.anchorY0 = a.y
                }
                fingers[id] = f
            }
        }

        // 떨어진 손가락 처리
        let lifted = fingers.filter { current[$0.key] == nil }
        for id in lifted.keys { fingers[id] = nil }
        for (_, f) in lifted { evaluate(f, time: time) }
    }

    private func evaluate(_ f: Finger, time: Double) {
        guard enabled, let aid = f.anchorID else { return }
        let duration = time - f.startTime
        let moved = hypot(f.x - f.startX, f.y - f.startY)

        func reject(_ why: String) {
            Log.write(String(format: "무시(%@) 시간=%.2fs 이동=%.3f", why, duration, moved))
        }
        guard duration <= Tuning.tapMaxDuration else { return reject("길게 누름") }
        guard moved <= Tuning.tapMaxMove else { return reject("움직임") }
        guard f.maxConcurrent == 2 else { return reject("손가락 \(f.maxConcurrent)개") }
        guard fingers.count == 1, let anchor = fingers[aid] else { return reject("기준 손가락 없음") }
        guard f.startTime - anchor.startTime >= Tuning.anchorMinLead else { return reject("동시에 닿음") }
        guard hypot(anchor.x - f.anchorX0, anchor.y - f.anchorY0) <= Tuning.anchorMaxMove else {
            return reject("기준 손가락 움직임")
        }
        guard time - lastFire >= Tuning.minInterval else { return reject("너무 빠름") }
        lastFire = time

        let direction: Direction = f.startX < anchor.x ? .left : .right
        Log.write(String(format: "✅ %@ 시간=%.2fs", direction == .left ? "왼쪽(뒤로)" : "오른쪽(앞으로)", duration))
        onTipTap?(direction)
    }
}

// MARK: - MultitouchSupport 연결 (비공개 프레임워크를 dlsym 으로 사용)

final class Multitouch {
    private typealias CreateList = @convention(c) () -> Unmanaged<CFMutableArray>?
    private typealias Register = @convention(c) (MTDeviceRef?, MTContactCallbackFunction?) -> Void
    private typealias StartStop = @convention(c) (MTDeviceRef?, Int32) -> Void
    private typealias Stop = @convention(c) (MTDeviceRef?) -> Void

    private let createList: CreateList
    private let register: Register
    private let unregister: Register
    private let start: StartStop
    private let stop: Stop
    private var devices: [MTDeviceRef] = []

    private static let callback: MTContactCallbackFunction = { _, touches, count, timestamp, _ in
        TipTapDetector.shared.process(touches, count: Int(count), time: timestamp)
        return 0
    }

    init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let h = dlopen(path, RTLD_NOW),
              let c = dlsym(h, "MTDeviceCreateList"),
              let r = dlsym(h, "MTRegisterContactFrameCallback"),
              let u = dlsym(h, "MTUnregisterContactFrameCallback"),
              let s = dlsym(h, "MTDeviceStart"),
              let st = dlsym(h, "MTDeviceStop") else { return nil }
        createList = unsafeBitCast(c, to: CreateList.self)
        register = unsafeBitCast(r, to: Register.self)
        unregister = unsafeBitCast(u, to: Register.self)
        start = unsafeBitCast(s, to: StartStop.self)
        stop = unsafeBitCast(st, to: Stop.self)
    }

    /// 연결된 트랙패드를 다시 찾아 감지를 시작 (잠자기 해제·기기 연결 후 호출)
    func restart() {
        for d in devices { unregister(d, Multitouch.callback); stop(d) }
        devices = []
        guard let list = createList()?.takeRetainedValue() as? [AnyObject] else { return }
        for obj in list {
            let d = Unmanaged.passUnretained(obj).toOpaque()
            register(d, Multitouch.callback)
            start(d, 0)
            devices.append(d)
        }
        retained = list // 기기 목록을 살려 둠
        Log.write("트랙패드 \(devices.count)개 감지 시작")
    }
    private var retained: [AnyObject] = []

    var deviceCount: Int { devices.count }
}

// MARK: - 키 입력 보내기

enum Keys {
    static let leftBracket: CGKeyCode = 0x21   // [
    static let rightBracket: CGKeyCode = 0x1E  // ]

    static func commandPress(_ key: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - 아이콘 (V자 두 손가락 + 톡 표시)

enum Icon {
    /// 크기 `side` 의 정사각형 안에 V자로 벌린 손과 (active 이면) 손끝의 톡 표시를 그림
    static func draw(side: CGFloat, active: Bool, color: NSColor) {
        let s = side / 18   // 18pt 기준 좌표
        color.setFill(); color.setStroke()

        /// (x, y) 에서 시작해 angle 도 기울어진 손가락 모양
        func capsule(x: CGFloat, y: CGFloat, width: CGFloat, length: CGFloat, angle: CGFloat) -> NSBezierPath {
            let p = NSBezierPath(roundedRect: NSRect(x: -width / 2 * s, y: 0, width: width * s, height: length * s),
                                 xRadius: width / 2 * s, yRadius: width / 2 * s)
            var t = AffineTransform(translationByX: x * s, byY: y * s)
            t.rotate(byDegrees: angle)
            p.transform(using: t)
            return p
        }
        let palm = NSBezierPath(roundedRect: NSRect(x: 5.3 * s, y: 0.6 * s, width: 7.4 * s, height: 6.4 * s),
                                xRadius: 2.6 * s, yRadius: 2.6 * s)
        let hand = [
            palm,
            capsule(x: 7.3, y: 5.2, width: 2.5, length: 9.2, angle: 17),    // 검지
            capsule(x: 10.7, y: 5.2, width: 2.5, length: 9.2, angle: -17),  // 중지
            capsule(x: 6.2, y: 2.8, width: 2.3, length: 4.6, angle: 58),    // 엄지
        ]
        hand.forEach { $0.fill() }
        guard active else { return }

        // 손끝 바깥의 톡 표시 (작은 호)
        for (cx, cy, start, end) in [(4.6, 14.1, 95.0, 190.0), (13.4, 14.1, -10.0, 85.0)]
                as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: cx * s, y: cy * s), radius: 3.0 * s,
                          startAngle: start, endAngle: end)
            arc.lineWidth = 1.1 * s; arc.lineCapStyle = .round
            arc.stroke()
        }
    }

    static func menuBar(active: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(side: rect.width, active: active, color: .black); return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "톡톡"
        return img
    }
}

// MARK: - 메뉴바 앱

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var multitouch: Multitouch?
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["enabled": true])
        TipTapDetector.shared.enabled = defaults.bool(forKey: "enabled")
        TipTapDetector.shared.onTipTap = { dir in
            DispatchQueue.main.async {
                Keys.commandPress(dir == .left ? Keys.leftBracket : Keys.rightBracket)
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu(); menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        requestAccessibility(prompt: true)

        // 첫 실행 때 한 번만 로그인 시 자동 실행 등록 (이후엔 메뉴에서 끄고 켬)
        if #available(macOS 13.0, *), !defaults.bool(forKey: "loginConfigured") {
            try? SMAppService.mainApp.register()
            defaults.set(true, forKey: "loginConfigured")
        }

        guard let mt = Multitouch() else {
            alert("트랙패드에 연결할 수 없어요", "이 macOS 버전에서는 톡톡이 동작하지 않을 수 있어요.")
            return
        }
        multitouch = mt
        mt.restart()

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.multitouch?.restart() }
        }
    }

    // 메뉴는 열 때마다 새로 그림
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let on = TipTapDetector.shared.enabled
        let header = NSMenuItem(title: "톡톡 — 손가락 하나 대고 왼쪽 톡: 뒤로 · 오른쪽 톡: 앞으로", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(item(on ? "켜짐" : "꺼짐", #selector(toggleEnabled), checked: on))
        if #available(macOS 13.0, *) {
            menu.addItem(item("로그인 시 자동 실행", #selector(toggleLogin),
                              checked: SMAppService.mainApp.status == .enabled))
        }
        menu.addItem(.separator())

        if !AXIsProcessTrusted() {
            menu.addItem(item("⚠️ 손쉬운 사용 권한 허용하기…", #selector(openAccessibility)))
        }
        menu.addItem(item("트랙패드 다시 찾기 (\(multitouch?.deviceCount ?? 0)개 연결됨)", #selector(rescan)))
        menu.addItem(item("디버그 로그 기록", #selector(toggleDebug), checked: Log.enabled))
        menu.addItem(.separator())
        menu.addItem(item("톡톡 종료", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, checked: Bool = false, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self; i.state = checked ? .on : .off
        return i
    }

    private func updateIcon() {
        statusItem.button?.image = Icon.menuBar(active: TipTapDetector.shared.enabled)
        statusItem.button?.appearsDisabled = !TipTapDetector.shared.enabled
    }

    @objc private func toggleEnabled() {
        TipTapDetector.shared.enabled.toggle()
        defaults.set(TipTapDetector.shared.enabled, forKey: "enabled")
        updateIcon()
    }

    @objc private func toggleLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            alert("자동 실행 설정 실패", error.localizedDescription)
        }
    }

    @objc private func toggleDebug() {
        Log.enabled.toggle()
        defaults.set(Log.enabled, forKey: "debug")
        if Log.enabled { NSWorkspace.shared.open(Log.url.deletingLastPathComponent()) }
    }

    @objc private func rescan() { multitouch?.restart() }
    @objc private func openAccessibility() { requestAccessibility(prompt: true) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func requestAccessibility(prompt: Bool) {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
