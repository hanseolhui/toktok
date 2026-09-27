import Foundation
import AppKit
import ServiceManagement

/// 앱별 동작: 그 앱에서는 끄기 / 다른 동작
enum AppOverride: Codable, Equatable {
    case off
    case action(Action)
}

struct GestureSetting: Codable, Equatable {
    var enabled: Bool
    var action: Action
}

/// 제스처별 사용 여부·동작 (UserDefaults 에 저장)
final class Settings: ObservableObject {
    static let shared = Settings()
    private let key = "gestures.v1"

    /// 톡톡 전체 켜짐/꺼짐 (메뉴바)
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "enabled") } }
    @Published private(set) var gestures: [Gesture: GestureSetting] = [:]
    /// 가장자리 슬라이더
    @Published private(set) var sliders: [EdgeSide: SliderSetting] = [:]
    /// 스와이프 앱 전환 (Pro)
    @Published var appSwitch: Bool { didSet { UserDefaults.standard.set(appSwitch, forKey: "appSwitch"); syncDetector() } }
    /// 타자 중에는 잠깐 쉬기 (키를 누른 뒤 0.5초)
    @Published var typingGuard: Bool { didSet { UserDefaults.standard.set(typingGuard, forKey: "typingGuard") } }
    /// 마지막으로 키보드를 누른 때 (다른 앱에서, 메인 스레드)
    var lastKeyTime = Date.distantPast
    /// 앱별 동작 (번들 ID → 제스처 → 끄기/동작, Pro)
    @Published private(set) var appOverrides: [String: [Gesture: AppOverride]] = [:]
    /// 톡톡을 끌 앱 (번들 ID, Pro)
    @Published var excludedApps: [String] { didSet { UserDefaults.standard.set(excludedApps, forKey: "excludedApps") } }

    private init() {
        UserDefaults.standard.register(defaults: ["enabled": true, "typingGuard": true])
        typingGuard = UserDefaults.standard.bool(forKey: "typingGuard")
        enabled = UserDefaults.standard.bool(forKey: "enabled")
        appSwitch = UserDefaults.standard.bool(forKey: "appSwitch")
        excludedApps = UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []
        if let data = UserDefaults.standard.data(forKey: "appOverrides.v1"),
           let saved = try? JSONDecoder().decode([String: [String: AppOverride]].self, from: data) {
            for (app, m) in saved {
                appOverrides[app] = Dictionary(uniqueKeysWithValues: m.compactMap { k, v in Gesture(rawValue: k).map { ($0, v) } })
            }
        }
        if let data = UserDefaults.standard.data(forKey: "sliders.v1"),
           let saved = try? JSONDecoder().decode([String: SliderSetting].self, from: data) {
            for (k, v) in saved { if let e = EdgeSide(rawValue: k) { sliders[e] = v } }
        }
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: GestureSetting].self, from: data) {
            for (k, v) in saved { if let g = Gesture(rawValue: k) { gestures[g] = v } }
        }
        // 한 번만: 기본값(빠른 메모)으로 켜 둔 쓸기는 새 메모로
        if !UserDefaults.standard.bool(forKey: "migrated.newNote") {
            if var sw = gestures[.swipeInBottomRight], sw.action == .preset(.quickNote) { sw.action = .preset(.newNote); update(.swipeInBottomRight, sw) }
            UserDefaults.standard.set(true, forKey: "migrated.newNote")
        }
    }

    func setting(_ g: Gesture) -> GestureSetting { gestures[g] ?? g.defaultSetting }
    func slider(_ e: EdgeSide) -> SliderSetting { sliders[e] ?? .default(e) }

    func setSlider(_ e: EdgeSide, _ s: SliderSetting) {
        sliders[e] = s
        let raw = Dictionary(uniqueKeysWithValues: sliders.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: "sliders.v1") }
        syncDetector()
    }

    // MARK: 앱별 동작

    var overrideApps: [String] { appOverrides.keys.sorted { ExcludedAppsSection.name($0).localizedCaseInsensitiveCompare(ExcludedAppsSection.name($1)) == .orderedAscending } }
    func override(_ app: String, _ g: Gesture) -> AppOverride? { appOverrides[app]?[g] }
    func addOverrideApp(_ app: String) { if appOverrides[app] == nil { appOverrides[app] = [:]; saveOverrides() } }
    func removeOverrideApp(_ app: String) { appOverrides[app] = nil; saveOverrides() }
    func setOverride(_ app: String, _ g: Gesture, _ o: AppOverride?) {
        var m = appOverrides[app] ?? [:]; m[g] = o; appOverrides[app] = m; saveOverrides()
    }
    private func saveOverrides() {
        let raw = appOverrides.mapValues { m in Dictionary(uniqueKeysWithValues: m.map { ($0.key.rawValue, $0.value) }) }
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: "appOverrides.v1") }
        syncDetector()
    }

    /// 전체 설정에서 켜져 있거나, 어떤 앱에서라도 동작을 지정한 제스처
    private func activeAnywhere(_ g: Gesture, pro: Bool) -> Bool {
        setting(g).enabled || (pro && appOverrides.values.contains { if case .action = $0[g] { return true }; return false })
    }

    /// 인식기에 켜진 추가 제스처 알려 주기 (Pro 전용은 Pro 일 때만)
    func syncDetector() {
        let pro = License.shared.isPro
        var c = GestureDetector.Config()
        c.doubleTaps = pro ? Set(Gesture.allCases.filter { $0.group == .double && activeAnywhere($0, pro: pro) }) : []
        c.sliders = Set(EdgeSide.allCases.filter { slider($0).enabled })
        c.swipeIn = activeAnywhere(.swipeInBottomRight, pro: pro)
        c.appSwitch = pro && appSwitch
        c.titlebar = pro && Gesture.allCases.contains { $0.group == .titlebar && activeAnywhere($0, pro: pro) }
        GestureDetector.shared.config = c
    }

    /// 지금 맨 앞 앱에서 톡톡을 꺼 뒀는지
    var pausedForFrontApp: Bool {
        if typingGuard, Date().timeIntervalSince(lastKeyTime) < 0.5 { return true }
        guard License.shared.isPro, !excludedApps.isEmpty,
              let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return excludedApps.contains(id)
    }

    /// 가장자리 슬라이더 한 칸 (메인 스레드)
    func handleSlider(_ e: EdgeSide, up: Bool) {
        guard enabled, !pausedForFrontApp else { return }
        let s = slider(e)
        guard s.enabled else { return }
        (s.mode.isPro && !License.shared.isPro ? SliderSetting.default(e).mode : s.mode).step(up: up)
    }

    /// 스와이프 앱 전환 (메인 스레드): +1 / -1 한 칸, 0 끝
    private var switching = false
    func handleAppSwitch(_ step: Int) {
        if step == 0 { if switching { Keys.command(down: false); switching = false }; return }
        guard enabled, !pausedForFrontApp else { return }
        if !switching { Keys.command(down: true); switching = true }
        Keys.press(Keys.tab, step > 0 ? [.maskCommand] : [.maskCommand, .maskShift])
    }

    func setEnabled(_ g: Gesture, _ on: Bool) { var s = setting(g); s.enabled = on; update(g, s) }
    func setAction(_ g: Gesture, _ a: Action) { var s = setting(g); s.action = a; update(g, s) }

    /// 사용 체크와 동작을 모두 처음 상태로
    func resetToDefaults() {
        gestures = [:]; sliders = [:]
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: "sliders.v1")
        syncDetector()
    }

    /// 무료 사용자가 Pro 에서 바꾼 동작만 기본값으로 (사용 체크는 유지)
    func resetActionsToDefaults() {
        for g in Gesture.allCases { setAction(g, g.defaultSetting.action) }
    }

    private func update(_ g: Gesture, _ s: GestureSetting) {
        gestures[g] = s
        let raw = Dictionary(uniqueKeysWithValues: gestures.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: key) }
        syncDetector()
    }

    /// 제스처가 인식되면 (메인 스레드에서) 설정에 따라 실행
    func handle(_ g: Gesture) {
        guard enabled, !pausedForFrontApp else { return }
        let pro = License.shared.isPro
        var s = setting(g)
        // 앱별 동작 (Pro): 맨 앞 앱에 지정한 게 있으면 그걸로
        if pro, let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, let o = appOverrides[app]?[g] {
            switch o {
            case .off: return
            case .action(let a): s = GestureSetting(enabled: true, action: a)
            }
        }
        guard s.enabled, !g.isPro || pro else { return }
        // 기본 제공 동작은 누구나, 직접 입력 단축키는 Pro 만 (아니면 기본 동작)
        // 제목 줄 제스처: 포인터가 창 제목 줄에 있을 때만, 그 창을 앞으로 가져온 뒤 실행
        if g.group == .titlebar {
            guard let loc = CGEvent(source: nil)?.location, let win = WindowTiler.titleBarWindow(at: loc) else { return }
            WindowTiler.focus(win)
            let action = s.action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { action.perform() }
            return
        }
        if case .preset = s.action { s.action.perform(); return }
        (License.shared.isPro ? s.action : g.defaultSetting.action).perform()
    }

    // 로그인 시 자동 실행
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }
}
