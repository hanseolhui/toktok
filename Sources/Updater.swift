import Cocoa

// MARK: - 앱 업데이트 (GitHub 최신 릴리스 → 받아서 바꿔 끼우고 다시 실행)

final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String, url: URL)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    static let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private static let api = URL(string: "https://api.github.com/repos/hanseolhui/toktok/releases/latest")!
    /// 릴리스 서명 확인용 (Developer ID 팀)
    private static let teamID = "967DUR6926"

    var availableVersion: String? {
        if case .available(let v, _) = state { return v }
        return nil
    }

    /// 새 버전 확인 (silent: 실패해도 조용히)
    @MainActor
    func check(silent: Bool = false) async {
        if case .installing = state { return }
        state = .checking
        do {
            var req = URLRequest(url: Self.api)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Release: Decodable { let tag_name: String; let assets: [Asset] }
            struct Asset: Decodable { let name: String; let browser_download_url: URL }
            let r = try JSONDecoder().decode(Release.self, from: data)
            let latest = r.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard let asset = r.assets.first(where: { $0.name == "TokTok.zip" }) ?? r.assets.first(where: { $0.name.hasSuffix(".zip") })
            else { state = silent ? .idle : .failed(t("릴리스 파일을 찾지 못했어요.", "Couldn't find the release file.")); return }
            state = Self.isNewer(latest, than: Self.current) ? .available(version: latest, url: asset.browser_download_url) : .upToDate
        } catch {
            state = silent ? .idle : .failed(t("업데이트를 확인하지 못했어요. 인터넷 연결을 확인해 주세요.",
                                               "Couldn't check for updates. Please check your internet connection."))
        }
    }

    /// 받아서 설치하고 다시 실행
    @MainActor
    func install() async {
        guard case .available(_, let url) = state else { return }
        state = .installing
        do {
            let fm = FileManager.default
            let dir = fm.temporaryDirectory.appendingPathComponent("toktok-update-\(UUID().uuidString)")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let (zip, _) = try await URLSession.shared.download(from: url)
            try Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, dir.path])
            let newApp = dir.appendingPathComponent("TokTok.app")
            guard fm.fileExists(atPath: newApp.path) else { throw Fail(t("받은 파일이 올바르지 않아요.", "The downloaded file is invalid.")) }

            // 서명 확인: 같은 개발자(Developer ID)가 서명한 앱만 설치
            try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])
            let info = try Self.run("/usr/bin/codesign", ["-dv", newApp.path])
            guard info.contains("TeamIdentifier=\(Self.teamID)") else { throw Fail(t("서명을 확인하지 못했어요.", "Couldn't verify the signature.")) }

            let target = Bundle.main.bundleURL
            guard fm.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
                throw Fail(t("응용 프로그램 폴더에 쓸 권한이 없어요. 웹사이트에서 받아 설치해 주세요.",
                             "No permission to write to the Applications folder. Please download it from the website."))
            }

            // 이 앱이 끝나면 바꿔 끼우고 다시 실행
            let script = """
            while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
            rm -rf "$1" && /usr/bin/ditto "$2" "$1" && /usr/bin/xattr -dr com.apple.quarantine "$1" 2>/dev/null
            /usr/bin/open "$1"; rm -rf "$3"
            """
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", script, "toktok-update", target.path, newApp.path, dir.path]
            try p.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed((error as? Fail)?.message ?? t("업데이트에 실패했어요: ", "Update failed: ") + error.localizedDescription)
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/hanseolhui/toktok/releases/latest")!)
    }

    // MARK: 도우미

    private struct Fail: Error { let message: String; init(_ m: String) { message = m } }

    /// "0.10.0" > "0.9.1" 같은 버전 비교
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) throws -> String {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        p.standardOutput = pipe; p.standardError = pipe
        try p.run(); p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard p.terminationStatus == 0 else { throw Fail(t("업데이트 파일을 확인하지 못했어요.", "Couldn't verify the update file.")) }
        return out
    }
}
