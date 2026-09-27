import Cocoa

// MARK: - 동작

/// 미리 준비된 동작
enum PresetAction: String, CaseIterable, Codable, Identifiable {
    case back, forward, prevTab, nextTab
    case middleClick, closeTab, reopenTab, newTab
    case windowLeft, windowRight, windowFill, windowCenter, fullScreen
    case quarterTopLeft, quarterTopRight, quarterBottomLeft, quarterBottomRight, windowNextScreen
    case missionControl, appWindows, spaceLeft, spaceRight
    case reload, quickNote, newNote
    case copy, paste, screenshot, save, quitApp, minimize, playPause, nextTrack, prevTrack

    var id: String { rawValue }

    /// 메뉴에서 묶어 보여 줄 분류
    enum Category: CaseIterable {
        case navigate, tabs, window, screen, media, etc
        var title: String {
            switch self {
            case .navigate: return t("이동", "Navigate")
            case .tabs:     return t("탭", "Tabs")
            case .window:   return t("창", "Windows")
            case .screen:   return t("화면", "Screen")
            case .media:    return t("음악·영상", "Media")
            case .etc:      return t("기타", "Other")
            }
        }
    }

    var category: Category {
        switch self {
        case .back, .forward, .reload: return .navigate
        case .prevTab, .nextTab, .middleClick, .closeTab, .reopenTab, .newTab: return .tabs
        case .windowLeft, .windowRight, .windowFill, .windowCenter, .fullScreen, .quarterTopLeft, .quarterTopRight,
             .quarterBottomLeft, .quarterBottomRight, .windowNextScreen: return .window
        case .missionControl, .appWindows, .spaceLeft, .spaceRight: return .screen
        case .quickNote, .newNote, .copy, .paste, .screenshot, .save, .quitApp: return .etc
        case .minimize: return .window
        case .playPause, .nextTrack, .prevTrack: return .media
        }
    }

    var title: String {
        switch self {
        case .back:           return t("뒤로 가기  ⌘[", "Back  ⌘[")
        case .forward:        return t("앞으로 가기  ⌘]", "Forward  ⌘]")
        case .prevTab:        return t("이전 탭  ⌃⇧⇥", "Previous tab  ⌃⇧⇥")
        case .nextTab:        return t("다음 탭  ⌃⇥", "Next tab  ⌃⇥")
        case .middleClick:    return t("가운데 클릭 (링크를 새 탭으로)", "Middle click (open link in new tab)")
        case .closeTab:       return t("탭·창 닫기  ⌘W", "Close tab/window  ⌘W")
        case .reopenTab:      return t("닫은 탭 다시 열기  ⌘⇧T", "Reopen closed tab  ⌘⇧T")
        case .newTab:         return t("새 탭  ⌘T", "New tab  ⌘T")
        case .windowLeft:     return t("창을 왼쪽 반으로", "Window to left half")
        case .windowRight:    return t("창을 오른쪽 반으로", "Window to right half")
        case .windowFill:     return t("창을 화면 가득", "Fill screen with window")
        case .windowCenter:   return t("창을 가운데로 (작게)", "Center window (smaller)")
        case .fullScreen:     return t("전체 화면 켜기/끄기  ⌃⌘F", "Toggle full screen  ⌃⌘F")
        case .quarterTopLeft:     return t("창을 왼쪽 위 4분의 1로", "Window to top-left quarter")
        case .quarterTopRight:    return t("창을 오른쪽 위 4분의 1로", "Window to top-right quarter")
        case .quarterBottomLeft:  return t("창을 왼쪽 아래 4분의 1로", "Window to bottom-left quarter")
        case .quarterBottomRight: return t("창을 오른쪽 아래 4분의 1로", "Window to bottom-right quarter")
        case .windowNextScreen:   return t("창을 다음 모니터로", "Window to next display")
        case .spaceLeft:          return t("왼쪽 데스크톱으로  ⌃←", "Desktop to the left  ⌃←")
        case .spaceRight:         return t("오른쪽 데스크톱으로  ⌃→", "Desktop to the right  ⌃→")
        case .reload:             return t("새로고침  ⌘R", "Reload  ⌘R")
        case .quickNote:          return t("빠른 메모 (마지막 메모)  fn Q", "Quick Note (last note)  fn Q")
        case .newNote:            return t("새 메모 작성 (메모 앱)", "New note (Notes app)")
        case .copy:               return t("복사  ⌘C", "Copy  ⌘C")
        case .paste:              return t("붙여넣기  ⌘V", "Paste  ⌘V")
        case .screenshot:         return t("영역 스크린샷 → 클립보드  ⌃⇧⌘4", "Area screenshot to clipboard  ⌃⇧⌘4")
        case .save:               return t("저장  ⌘S", "Save  ⌘S")
        case .quitApp:            return t("앱 종료  ⌘Q", "Quit app  ⌘Q")
        case .minimize:           return t("창 최소화  ⌘M", "Minimize window  ⌘M")
        case .playPause:          return t("재생 / 일시정지", "Play / pause")
        case .nextTrack:          return t("다음 곡", "Next track")
        case .prevTrack:          return t("이전 곡", "Previous track")
        case .missionControl: return "Mission Control"
        case .appWindows:     return t("앱 윈도우 보기", "App windows")
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
        case .windowCenter:   WindowTiler.tile(.center)
        case .fullScreen:     Keys.press(Keys.f, [.maskControl, .maskCommand])
        case .quarterTopLeft:     WindowTiler.tile(.topLeft)
        case .quarterTopRight:    WindowTiler.tile(.topRight)
        case .quarterBottomLeft:  WindowTiler.tile(.bottomLeft)
        case .quarterBottomRight: WindowTiler.tile(.bottomRight)
        case .windowNextScreen:   WindowTiler.tile(.nextScreen)
        case .spaceLeft:          Keys.press(Keys.leftArrow, [.maskControl, .maskSecondaryFn])
        case .spaceRight:         Keys.press(Keys.rightArrow, [.maskControl, .maskSecondaryFn])
        case .reload:             Keys.press(Keys.r, [.maskCommand])
        case .quickNote:          Keys.press(Keys.q, [.maskSecondaryFn])
        case .newNote:            Self.openNewNote()
        case .copy:               Keys.press(Keys.c, [.maskCommand])
        case .paste:              Keys.press(Keys.v, [.maskCommand])
        case .screenshot:         Keys.press(Keys.four, [.maskControl, .maskShift, .maskCommand])
        case .save:               Keys.press(Keys.s, [.maskCommand])
        case .quitApp:            Keys.press(Keys.q, [.maskCommand])
        case .minimize:           Keys.press(Keys.m, [.maskCommand])
        case .playPause:          Keys.mediaKey(Keys.play)
        case .nextTrack:          Keys.mediaKey(Keys.next)
        case .prevTrack:          Keys.mediaKey(Keys.previous)
        case .missionControl: Keys.press(Keys.upArrow, [.maskControl, .maskSecondaryFn])
        case .appWindows:     Keys.press(Keys.downArrow, [.maskControl, .maskSecondaryFn])
        }
    }
}

extension PresetAction {
    /// 메모 앱을 앞으로 띄우고 새 메모 (⌘N)
    static func openNewNote() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") else { return }
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, _ in
            // 창이 뜰 시간을 두고 새 메모
            DispatchQueue.main.asyncAfter(deadline: .now() + (app?.isFinishedLaunching == true ? 0.25 : 0.8)) {
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Notes" {
                    Keys.press(Keys.n, [.maskCommand])
                }
            }
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
        case .shortcut(let s):  return t("단축키  ", "Shortcut  ") + s.display
        case .sequence(let l):  return t("단축키  ", "Shortcut  ") + l.map(\.display).joined(separator: " → ")
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
    static let r: CGKeyCode = 0x0F, q: CGKeyCode = 0x0C, equal: CGKeyCode = 0x18, minus: CGKeyCode = 0x1B
    static let command: CGKeyCode = 0x37
    static let n: CGKeyCode = 0x2D
    static let c: CGKeyCode = 0x08, v: CGKeyCode = 0x09, s: CGKeyCode = 0x01, m: CGKeyCode = 0x2E, four: CGKeyCode = 0x15
    static let play: Int32 = 16, next: Int32 = 17, previous: Int32 = 18
    /// 미디어 키 (NX_KEYTYPE_*)
    static let soundUp: Int32 = 0, soundDown: Int32 = 1, brightnessUp: Int32 = 2, brightnessDown: Int32 = 3
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

    /// 볼륨·밝기 키 (화면에 조절 표시가 떠요)
    static func mediaKey(_ key: Int32) {
        for down in [true, false] {
            let state: Int32 = down ? 0xa : 0xb
            let e = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                       modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state) << 8),
                                       timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                                       data1: Int((key << 16) | (state << 8)), data2: -1)
            e?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    /// 가로 스크롤 (양수: 오른쪽으로)
    static func scrollHorizontally(_ pixels: Int32) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -pixels, wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    /// ⌘ 를 누른 채로 두기 / 떼기 (스와이프 앱 전환)
    static func command(down: Bool) {
        let e = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: command, keyDown: down)
        e?.flags = down ? .maskCommand : []
        e?.post(tap: .cghidEventTap)
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
