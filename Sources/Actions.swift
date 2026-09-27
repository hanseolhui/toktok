import Cocoa

// MARK: - 동작

/// 미리 준비된 동작
enum PresetAction: String, CaseIterable, Codable, Identifiable {
    case back, forward, prevTab, nextTab
    case middleClick, closeTab, reopenTab, newTab
    case windowLeft, windowRight, windowFill
    case missionControl, appWindows

    var id: String { rawValue }

    var title: String {
        switch self {
        case .back:           return "뒤로 가기  ⌘["
        case .forward:        return "앞으로 가기  ⌘]"
        case .prevTab:        return "이전 탭  ⌃⇧⇥"
        case .nextTab:        return "다음 탭  ⌃⇥"
        case .middleClick:    return "가운데 클릭 (링크를 새 탭으로)"
        case .closeTab:       return "탭·창 닫기  ⌘W"
        case .reopenTab:      return "닫은 탭 다시 열기  ⌘⇧T"
        case .newTab:         return "새 탭  ⌘T"
        case .windowLeft:     return "창을 왼쪽 반으로"
        case .windowRight:    return "창을 오른쪽 반으로"
        case .windowFill:     return "창을 화면 가득"
        case .missionControl: return "Mission Control"
        case .appWindows:     return "앱 윈도우 보기"
        }
    }

    func perform() {
        switch self {
        case .back:           Keys.press(Keys.leftBracket, [.maskCommand])
        case .forward:        Keys.press(Keys.rightBracket, [.maskCommand])
        case .prevTab:        Keys.press(Keys.tab, [.maskControl, .maskShift])
        case .nextTab:        Keys.press(Keys.tab, [.maskControl])
        case .middleClick:    Keys.middleClick()
        case .closeTab:       Keys.press(Keys.w, [.maskCommand])
        case .reopenTab:      Keys.press(Keys.t, [.maskCommand, .maskShift])
        case .newTab:         Keys.press(Keys.t, [.maskCommand])
        case .windowLeft:     WindowTiler.tile(.left)
        case .windowRight:    WindowTiler.tile(.right)
        case .windowFill:     WindowTiler.tile(.fill)
        case .missionControl: Keys.press(Keys.upArrow, [.maskControl, .maskSecondaryFn])
        case .appWindows:     Keys.press(Keys.downArrow, [.maskControl, .maskSecondaryFn])
        }
    }
}

/// 사용자가 녹화한 단축키
struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var flags: UInt64      // CGEventFlags
    var display: String

    func perform() { Keys.press(CGKeyCode(keyCode), CGEventFlags(rawValue: flags)) }

    /// 설정 창에서 누른 키로 만들기
    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let m = event.modifierFlags
        var f: CGEventFlags = []
        var text = ""
        if m.contains(.control)  { f.insert(.maskControl);   text += "⌃" }
        if m.contains(.option)   { f.insert(.maskAlternate); text += "⌥" }
        if m.contains(.shift)    { f.insert(.maskShift);     text += "⇧" }
        if m.contains(.command)  { f.insert(.maskCommand);   text += "⌘" }
        if m.contains(.function), Keys.names[event.keyCode] == nil { f.insert(.maskSecondaryFn); text += "fn " }
        let key = Keys.names[event.keyCode] ?? (event.charactersIgnoringModifiers ?? "").uppercased()
        guard !key.isEmpty else { return nil }
        keyCode = event.keyCode; flags = f.rawValue; display = text + key
    }
}

enum Action: Codable, Equatable {
    case preset(PresetAction)
    case shortcut(Shortcut)
    /// 여러 단축키를 순서대로 (예: ⌘A → ⌘C)
    case sequence([Shortcut])

    /// 녹화한 단축키 목록으로 만들기 (하나면 단축키, 여러 개면 순서대로)
    static func keys(_ list: [Shortcut]) -> Action {
        list.count == 1 ? .shortcut(list[0]) : .sequence(list)
    }

    var title: String {
        switch self {
        case .preset(let p):    return p.title
        case .shortcut(let s):  return "단축키  \(s.display)"
        case .sequence(let l):  return "단축키  " + l.map(\.display).joined(separator: " → ")
        }
    }

    func perform() {
        switch self {
        case .preset(let p):   p.perform()
        case .shortcut(let s): s.perform()
        case .sequence(let l):
            // 앱이 앞의 키를 처리할 틈을 두고 차례로
            for (i, s) in l.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(i * 120)) { s.perform() }
            }
        }
    }
}

// MARK: - 키·마우스 입력 보내기

enum Keys {
    static let leftBracket: CGKeyCode = 0x21, rightBracket: CGKeyCode = 0x1E
    static let tab: CGKeyCode = 0x30, w: CGKeyCode = 0x0D, t: CGKeyCode = 0x11, f: CGKeyCode = 0x03
    static let leftArrow: CGKeyCode = 0x7B, rightArrow: CGKeyCode = 0x7C
    static let upArrow: CGKeyCode = 0x7E, downArrow: CGKeyCode = 0x7D

    static let names: [UInt16: String] = [
        0x7B: "←", 0x7C: "→", 0x7E: "↑", 0x7D: "↓", 0x30: "⇥", 0x24: "↩", 0x31: "Space",
        0x33: "⌫", 0x75: "⌦", 0x35: "esc", 0x73: "Home", 0x77: "End", 0x74: "PgUp", 0x79: "PgDn",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    ]

    static func press(_ key: CGKeyCode, _ flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
    }

    static func middleClick() {
        let src = CGEventSource(stateID: .hidSystemState)
        let location = CGEvent(source: nil)?.location ?? .zero
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            let e = CGEvent(mouseEventSource: src, mouseType: type,
                            mouseCursorPosition: location, mouseButton: .center)
            e?.post(tap: .cghidEventTap)
        }
    }
}
