import Foundation

// MARK: - 언어 (한국어 / English)

/// 설정에서 고른 언어. 기본은 시스템 언어 (한국어가 아니면 영어)
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()

    enum Choice: String, CaseIterable, Identifiable {
        case system, ko, en
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return t("시스템 설정 따르기", "Follow system")
            case .ko:     return "한국어"
            case .en:     return "English"
            }
        }
    }

    @Published var choice: Choice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: "language") }
    }

    private init() {
        choice = Choice(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
    }

    var isKorean: Bool {
        switch choice {
        case .ko: return true
        case .en: return false
        case .system: return (Locale.preferredLanguages.first ?? "").hasPrefix("ko")
        }
    }
}

/// 한국어 / 영어 문구 중 지금 언어에 맞는 것
func t(_ ko: String, _ en: String) -> String { AppLanguage.shared.isKorean ? ko : en }
