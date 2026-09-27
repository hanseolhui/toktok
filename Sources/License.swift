import Foundation
import AppKit
import CryptoKit

// MARK: - 판매·후원 설정
//
// 결제 링크를 넣기 전(checkoutURL == nil)에는 모든 기능이 무료로 열려 있어요.
// PayPal 결제 링크를 넣으면 동작 커스텀이 Pro 로 잠깁니다.

enum Store {
    /// Pro 구매 (PayPal 결제 링크)
    static let checkoutURL = URL(string: "https://www.paypal.com/ncp/payment/H7KRYH358XTJS")
    /// 개발자에게 커피 사주기 (PayPal.me 등)
    static let tipURL = URL(string: "https://paypal.me/hanseolhui")
    /// 가격 표시
    static let priceText = "평생 $2.99 — 커피 한 잔 값"
    /// 라이선스 서명 확인용 공개 키 (tools/license-key.swift 로 만든 키)
    static let publicKey = "3LB12Dy_fPtx7EnTk-xIfPF_vcToLsKTmDmVzhUuFQQ"

    static var sellsPro: Bool { checkoutURL != nil && !publicKey.isEmpty }
}

/// Pro 라이선스 — 서버 없이 확인하는 서명 키
///
/// 키 형식: TOKTOK-<base64url(이메일)>.<base64url(Ed25519 서명)>
/// 판매자가 구매자 이메일에 개인 키로 서명해 보내 주면, 앱은 공개 키로 진짜인지 확인해요.
final class License: ObservableObject {
    static let shared = License()

    @Published private(set) var email: String?

    var isPro: Bool { !Store.sellsPro || email != nil }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "license.key") {
            email = License.verify(saved)
        }
    }

    enum LicenseError: LocalizedError {
        case invalid
        var errorDescription: String? { "올바른 라이선스 키가 아니에요. 받은 키를 그대로 붙여넣어 주세요." }
    }

    func activate(_ rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let owner = License.verify(key) else { throw LicenseError.invalid }
        UserDefaults.standard.set(key, forKey: "license.key")
        email = owner
    }

    func deactivate() {
        UserDefaults.standard.removeObject(forKey: "license.key")
        email = nil
    }

    /// 키가 올바르면 등록된 이메일을 돌려줌
    static func verify(_ key: String) -> String? {
        guard key.hasPrefix("TOKTOK-"),
              let pubData = Data(base64URL: Store.publicKey),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData) else { return nil }
        let parts = key.dropFirst("TOKTOK-".count).split(separator: ".")
        guard parts.count == 2,
              let emailData = Data(base64URL: String(parts[0])),
              let sig = Data(base64URL: String(parts[1])),
              pub.isValidSignature(sig, for: emailData) else { return nil }
        return String(data: emailData, encoding: .utf8)
    }

    func openCheckout() { if let u = Store.checkoutURL { NSWorkspace.shared.open(u) } }
    func openTip() { if let u = Store.tipURL { NSWorkspace.shared.open(u) } }
}

extension Data {
    init?(base64URL s: String) {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        self.init(base64Encoded: b)
    }
}
