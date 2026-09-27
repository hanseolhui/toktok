import Foundation
import AppKit
import CryptoKit
import IOKit

// MARK: - 판매·후원 설정

enum Store {
    /// 라이선스 서버 (구매·기기 등록·코드 재발송)
    static let server = URL(string: "https://toktok.seoriarts.com")!
    /// Pro 구매 페이지 (PayPal)
    static let checkoutURL: URL? = server.appendingPathComponent("buy")
    /// 기기 관리 · 코드 다시 받기 페이지
    static var manageURL: URL { URL(string: "https://toktok.seoriarts.com/manage?lang=\(langCode)")! }
    static var resendURL: URL { URL(string: "https://toktok.seoriarts.com/resend?lang=\(langCode)")! }
    static var langCode: String { AppLanguage.shared.isKorean ? "ko" : "en" }
    /// 사용 설명서
    static var guideURL: URL { server.appendingPathComponent(AppLanguage.shared.isKorean ? "guide" : "guide-en") }
    /// 구매 페이지 (언어에 맞게)
    static var buyPageURL: URL { URL(string: AppLanguage.shared.isKorean ? "https://toktok.seoriarts.com/buy?lang=ko#buy" : "https://toktok.seoriarts.com/en#buy")! }
    /// 개발자에게 커피 사주기
    static let tipURL: URL? = URL(string: "https://seoriarts.gumroad.com/coffee")
    /// 가격 표시
    static var priceText: String { t("평생 ₩4,900 · 맥 3대", "₩4,900 (about US$3.99) lifetime · 3 Macs") }
    /// 기기 인증서 서명 확인용 공개 키 (서버의 LICENSE_PRIVATE_KEY 짝)
    static let publicKey = "3LB12Dy_fPtx7EnTk-xIfPF_vcToLsKTmDmVzhUuFQQ"

    static var sellsPro: Bool { checkoutURL != nil && !publicKey.isEmpty }
}

// MARK: - Pro 라이선스

/// 서버에서 "이 맥" 앞으로 발급받은 인증서로 확인 (한 번 등록하면 인터넷 없이 동작)
///
/// 인증서 형식: TOKTOK2.<base64url(JSON)>.<base64url(Ed25519 서명)>
/// JSON: { v, p: "toktok-pro", lic: 라이선스 코드, email, did: 기기 ID, iat }
final class License: ObservableObject {
    static let shared = License()

    struct Payload: Decodable { let p: String; let lic: String; let email: String; let did: String }
    struct Device: Decodable, Identifiable {
        let device_id: String
        let device_name: String?
        let activated_at: String
        var id: String { device_id }
        var isThisMac: Bool { device_id == License.deviceID }
    }

    @Published private(set) var payload: Payload? { didSet { DispatchQueue.main.async { Settings.shared.syncDetector() } } }

    var isPro: Bool { !Store.sellsPro || payload != nil }
    var email: String? { payload?.email }
    var code: String? { payload?.lic }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "license.certificate") {
            payload = License.verify(saved)
        }
    }

    /// 이 맥의 고유 ID (하드웨어 UUID 를 톡톡 전용으로 해시 — 원래 값은 서버에 보내지 않음)
    static let deviceID: String = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        let uuid = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String ?? Host.current().name ?? "unknown"
        let digest = SHA256.hash(data: Data("toktok:\(uuid)".utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(32))
    }()

    static var deviceName: String { Host.current().localizedName ?? "Mac" }

    // MARK: 서버 호출

    struct ServerError: LocalizedError {
        let message: String
        var devices: [Device] = []
        var errorDescription: String? { message }
    }

    private struct Response: Decodable {
        let certificate: String?
        let devices: [Device]?
        let limit: Int?
        let error: String?
    }

    private func call(_ path: String, _ body: [String: String]) async throws -> Response {
        var req = URLRequest(url: Store.server.appendingPathComponent("api/\(path)"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Store.langCode, forHTTPHeaderField: "Accept-Language")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else {
            throw ServerError(message: t("인터넷 연결을 확인하고 다시 시도해 주세요.", "Please check your internet connection and try again."))
        }
        let r = (try? JSONDecoder().decode(Response.self, from: data))
            ?? Response(certificate: nil, devices: nil, limit: nil, error: t("서버 응답을 읽지 못했어요.", "Couldn’t read the server response."))
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw ServerError(message: r.error ?? t("오류가 났어요 (\(http.statusCode))", "Something went wrong (\(http.statusCode))"), devices: r.devices ?? [])
        }
        return r
    }

    /// 코드로 이 맥 등록 → 인증서 저장
    @MainActor
    func activate(code: String) async throws {
        let r = try await call("activate", ["code": code, "deviceId": License.deviceID, "deviceName": License.deviceName])
        guard let cert = r.certificate, let p = License.verify(cert) else {
            throw ServerError(message: t("인증서를 확인하지 못했어요. 톡톡을 최신 버전으로 업데이트해 주세요.", "Couldn’t verify the certificate. Please update TokTok to the latest version."))
        }
        UserDefaults.standard.set(cert, forKey: "license.certificate")
        payload = p
    }

    /// 등록된 기기 목록 (코드를 주지 않으면 이 맥에 등록된 코드 사용)
    func devices(code: String? = nil) async throws -> [Device] {
        guard let c = code ?? self.code else { return [] }
        return try await call("devices", ["code": c]).devices ?? []
    }

    /// 기기 해제. 이 맥이면 Pro 도 해제
    @MainActor
    func deactivate(deviceID: String, code: String? = nil) async throws -> [Device] {
        guard let c = code ?? self.code else { return [] }
        let list = try await call("deactivate", ["code": c, "deviceId": deviceID]).devices ?? []
        if deviceID == License.deviceID { removeLocal() }
        return list
    }

    @MainActor
    func removeLocal() {
        UserDefaults.standard.removeObject(forKey: "license.certificate")
        payload = nil
    }

    // MARK: 오프라인 확인

    static func verify(_ cert: String) -> Payload? {
        let parts = cert.split(separator: ".")
        guard parts.count == 3, parts[0] == "TOKTOK2",
              let pubData = Data(base64URL: Store.publicKey),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData),
              let body = Data(base64URL: String(parts[1])),
              let sig = Data(base64URL: String(parts[2])),
              pub.isValidSignature(sig, for: body),
              let p = try? JSONDecoder().decode(Payload.self, from: body),
              p.p == "toktok-pro", p.did == deviceID else { return nil }
        return p
    }

    func openCheckout() { if Store.checkoutURL != nil { NSWorkspace.shared.open(Store.buyPageURL) } }
    func openTip() { if let u = Store.tipURL { NSWorkspace.shared.open(u) } }
    func openResend() { NSWorkspace.shared.open(Store.resendURL) }
}

extension Data {
    init?(base64URL s: String) {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        self.init(base64Encoded: b)
    }
}
