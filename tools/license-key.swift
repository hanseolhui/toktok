// 톡톡 Pro 라이선스 키 도구 (판매자용)
//
//   swift tools/license-key.swift init              서명 키 만들기 (처음 한 번). 공개 키를 Store.publicKey 에 넣으세요.
//   swift tools/license-key.swift make 이메일        구매자에게 보낼 라이선스 키 만들기
//
// 개인 키는 ~/.toktok/license-private-key 에 저장돼요. 절대 공유하거나 저장소에 올리지 마세요.
import Foundation
import CryptoKit

let keyURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".toktok/license-private-key")

func b64url(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "init":
    if FileManager.default.fileExists(atPath: keyURL.path) {
        print("이미 서명 키가 있어요: \(keyURL.path)"); exit(1)
    }
    let key = Curve25519.Signing.PrivateKey()
    try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try key.rawRepresentation.write(to: keyURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
    print("개인 키 저장: \(keyURL.path)  (꼭 따로 백업해 두세요)")
    print("공개 키 (Sources/License.swift 의 Store.publicKey 에 넣기):")
    print(b64url(key.publicKey.rawRepresentation))
case "make":
    guard let email = args.dropFirst().first, email.contains("@") else {
        print("사용법: swift tools/license-key.swift make 이메일"); exit(1)
    }
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(contentsOf: keyURL))
    let data = Data(email.lowercased().utf8)
    print("TOKTOK-\(b64url(data)).\(b64url(try key.signature(for: data)))")
default:
    print("사용법: swift tools/license-key.swift init | make 이메일")
}
