import Foundation
import ServiceManagement

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

    private init() {
        UserDefaults.standard.register(defaults: ["enabled": true])
        enabled = UserDefaults.standard.bool(forKey: "enabled")
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: GestureSetting].self, from: data) {
            for (k, v) in saved { if let g = Gesture(rawValue: k) { gestures[g] = v } }
        }
    }

    func setting(_ g: Gesture) -> GestureSetting { gestures[g] ?? g.defaultSetting }

    func setEnabled(_ g: Gesture, _ on: Bool) { var s = setting(g); s.enabled = on; update(g, s) }
    func setAction(_ g: Gesture, _ a: Action) { var s = setting(g); s.action = a; update(g, s) }

    /// 사용 체크와 동작을 모두 처음 상태로
    func resetToDefaults() {
        gestures = [:]
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// 무료 사용자가 Pro 에서 바꾼 동작만 기본값으로 (사용 체크는 유지)
    func resetActionsToDefaults() {
        for g in Gesture.allCases { setAction(g, g.defaultSetting.action) }
    }

    private func update(_ g: Gesture, _ s: GestureSetting) {
        gestures[g] = s
        let raw = Dictionary(uniqueKeysWithValues: gestures.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// 제스처가 인식되면 (메인 스레드에서) 설정에 따라 실행
    func handle(_ g: Gesture) {
        guard enabled else { return }
        let s = setting(g)
        guard s.enabled else { return }
        // Pro 가 아니면 동작은 항상 기본값
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
