import SwiftUI

// MARK: - 설정 창

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var license = License.shared
    @State private var confirmReset = false

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            ForEach(Gesture.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(Gesture.allCases.filter { $0.group == group }) { g in
                        GestureRow(gesture: g).id(g.id)
                    }
                }
            }

            Section {
                HStack {
                    Text("제스처 하는 법, 동작 바꾸기, Pro 등록, 문제 해결")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("📖 사용 설명서") { NSWorkspace.shared.open(Store.guideURL) }
                }
                Toggle("로그인 시 자동 실행", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.launchAtLogin = $0 }))
                HStack {
                    Text("사용 체크와 동작을 처음 상태로 돌려요")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("기본 설정으로 되돌리기") { confirmReset = true }
                }
            }

            if Store.sellsPro { ProSection().id("pro") }

            if Store.tipURL != nil {
                Section {
                    HStack {
                        Text("톡톡이 마음에 드셨다면")
                        Spacer()
                        Button("☕ 개발자에게 커피 사주기") { license.openTip() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // --scroll-pro: 스크린샷용으로 Pro 영역부터 보이게
            if CommandLine.arguments.contains("--scroll-pro") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo("pro", anchor: .top) }
            } else if CommandLine.arguments.contains("--scroll-top") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo(Gesture.tipTapLeft.id, anchor: .top) }
            }
        }
        }
        .frame(width: 600, height: 680)
        .confirmationDialog("모든 제스처를 기본 설정으로 되돌릴까요?", isPresented: $confirmReset) {
            Button("되돌리기", role: .destructive) { settings.resetToDefaults() }
        }
    }
}

struct GestureRow: View {
    /// Pro 가 풀린 뒤 남은 직접 입력은 기본 동작으로 보여 줌
    private func effectiveTitle(_ s: GestureSetting) -> String {
        if case .preset = s.action { return s.action.title }
        return license.isPro ? s.action.title : gesture.defaultSetting.action.title
    }

    let gesture: Gesture
    @ObservedObject var settings = Settings.shared
    @ObservedObject var license = License.shared
    @State private var recording = false

    var body: some View {
        let s = settings.setting(gesture)
        HStack(alignment: .center, spacing: 12) {
            Toggle(isOn: Binding(get: { s.enabled }, set: { settings.setEnabled(gesture, $0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gesture.title)
                    Text(gesture.hint).font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            // 기본 제공 동작은 무료, 직접 입력(단축키 녹화)은 Pro
            Menu(effectiveTitle(s)) {
                ForEach(PresetAction.allCases) { p in
                    Button(p.title) { settings.setAction(gesture, .preset(p)) }
                }
                Divider()
                if license.isPro {
                    Button("직접 입력 (단축키 녹화)…") { recording = true }
                } else {
                    Button("🔒 직접 입력 (단축키 녹화) — Pro") { license.openCheckout() }
                }
            }
            .frame(width: 230)
            .disabled(!s.enabled)
            .popover(isPresented: $recording) {
                ShortcutRecorder { keys in
                    if let keys, !keys.isEmpty { settings.setAction(gesture, .keys(keys)) }
                    recording = false
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 누른 단축키를 차례로 기록 (최대 5개) — 하나면 그 단축키, 여러 개면 순서대로 실행
struct ShortcutRecorder: View {
    let done: ([Shortcut]?) -> Void
    @State private var keys: [Shortcut] = []
    @State private var monitor: Any?
    private let maxKeys = 5

    var body: some View {
        VStack(spacing: 12) {
            Text("원하는 단축키를 누르세요").font(.headline)
            Text("여러 개를 누르면 순서대로 실행돼요 (최대 \(maxKeys)개)")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if keys.isEmpty {
                    Text("예: ⌘⇧T  또는  ⌘A → ⌘C").foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(keys.enumerated()), id: \.offset) { i, k in
                        if i > 0 { Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary) }
                        Text(k.display).font(.system(.body, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(minHeight: 30)

            HStack {
                Button("지우기") { keys.removeAll() }.disabled(keys.isEmpty)
                Spacer()
                Button("취소") { finish(nil) }
                Button("완료") { finish(keys) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(keys.isEmpty)
            }
            Text("⌘Space, ⌘Tab 처럼 macOS가 먼저 가져가는 단축키는 녹화되지 않아요.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // 수식키 없는 Return 은 완료, esc 는 (비어 있을 때) 취소 — 나머지는 모두 기록
                let plain = event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
                if plain, event.keyCode == 0x24 || event.keyCode == 0x4C { if !keys.isEmpty { finish(keys) }; return nil }
                if plain, event.keyCode == 0x35, keys.isEmpty { finish(nil); return nil }
                if keys.count < maxKeys, let s = Shortcut(event: event) { keys.append(s) }
                return nil
            }
        }
        .onDisappear { removeMonitor() }
    }

    private func removeMonitor() { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    private func finish(_ k: [Shortcut]?) { removeMonitor(); done(k) }
}

struct ProSection: View {
    @ObservedObject var license = License.shared
    @State private var code = ""
    @State private var error: String?
    @State private var busy = false
    /// 등록된 기기 (Pro 사용 중이거나, 한도 초과로 해제가 필요할 때)
    @State private var devices: [License.Device] = []

    var body: some View {
        Section("톡톡 Pro") {
            if license.payload != nil || Demo.on {
                HStack {
                    Label("Pro 사용 중 — \(Demo.on ? "you@example.com" : license.email ?? "")", systemImage: "checkmark.seal.fill")
                    Spacer()
                    Text(Demo.on ? "TOK-A2B3-C4D5-E6F7" : license.code ?? "").font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
                deviceList(code: nil)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("원하는 단축키를 직접 녹화해 제스처에 연결 (여러 키 순서 실행)")
                        Text(Store.priceText).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Pro 구매") { license.openCheckout() }
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    TextField("라이선스 코드 (TOK-XXXX-XXXX-XXXX)", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: code) { new in
                            let f = LicenseCode.format(new)
                            if f != new { code = f }
                        }
                        .onSubmit(register)
                    Button(busy ? "등록 중…" : "등록", action: register)
                        .disabled(code.isEmpty || busy)
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
                if !devices.isEmpty { deviceList(code: code) }
                Button("코드를 잃어버렸어요") { license.openResend() }
                    .buttonStyle(.link).font(.caption)
            }
        }
        .task(id: license.code) {
            if Demo.on { devices = Demo.devices; return }
            if license.payload != nil { devices = (try? await license.devices()) ?? [] }
        }
    }

    /// 등록된 맥 목록과 해제 버튼 (code == nil 이면 이 맥의 라이선스)
    @ViewBuilder private func deviceList(code: String?) -> some View {
        ForEach(devices) { d in
            HStack {
                Image(systemName: "laptopcomputer")
                Text(d.device_name ?? "Mac")
                if d.isThisMac { Text("이 맥").font(.caption).padding(.horizontal, 6).background(.quaternary, in: Capsule()) }
                Spacer()
                Button("해제") { release(d, code: code) }.disabled(busy)
            }
        }
        Text("맥 3대까지 쓸 수 있어요. 포맷 후 같은 맥에 다시 등록할 땐 칸을 차지하지 않아요.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func register() {
        busy = true; error = nil
        Task {
            do {
                try await license.activate(code: code)
                code = ""; devices = (try? await license.devices()) ?? []
            } catch let e as License.ServerError {
                error = e.message; devices = e.devices
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func release(_ d: License.Device, code: String?) {
        let alert = NSAlert()
        alert.messageText = "‘\(d.device_name ?? "Mac")’을(를) 해제할까요?"
        alert.informativeText = d.isThisMac ? "이 맥에서 Pro 기능이 꺼져요. 코드를 다시 입력하면 언제든 다시 등록할 수 있어요."
                                            : "그 맥에서는 다음 확인 때 Pro 기능이 꺼져요."
        alert.addButton(withTitle: "해제"); alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        Task {
            do { devices = try await license.deactivate(deviceID: d.device_id, code: code); error = nil }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

/// 라이선스 코드 입력 도우미: 대문자로, 하이픈 자동 (TOK-XXXX-XXXX-XXXX)
enum LicenseCode {
    static func format(_ raw: String) -> String {
        var chars = raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        if ["", "T", "TO", "TOK"].contains(chars) { return chars }   // TOK 를 직접 치는 중
        if chars.hasPrefix("TOK") { chars.removeFirst(3) }
        chars = String(chars.prefix(12))
        var out = "TOK"
        for (i, c) in chars.enumerated() {
            if i % 4 == 0 { out += "-" }
            out.append(c)
        }
        return out
    }
}

/// --demo: 스크린샷용 예시 데이터 (실제 이메일·코드·맥 이름을 가림)
enum Demo {
    static let on = CommandLine.arguments.contains("--demo")
    static let devices: [License.Device] = [
        .init(device_id: License.deviceID, device_name: "MacBook Pro", activated_at: ""),
        .init(device_id: "demo-mac-mini", device_name: "Mac mini", activated_at: ""),
    ]
}
