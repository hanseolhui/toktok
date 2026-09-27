import SwiftUI

// MARK: - 설정 창

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var license = License.shared
    @ObservedObject var language = AppLanguage.shared
    @ObservedObject var updater = Updater.shared
    @State private var confirmReset = false

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            ForEach(Gesture.Group.allCases, id: \.self) { group in
                Section(group.title) {
                    ForEach(Gesture.allCases.filter { $0.group == group }) { g in
                        GestureRow(gesture: g).id(g.id)
                    }
                }
            }

            Section(t("가장자리 슬라이더", "Edge sliders")) {
                ForEach(EdgeSide.allCases) { SliderRow(side: $0) }
                Text(t("트랙패드 왼쪽·오른쪽 끝에 손가락을 대고 위아래로 쓸어요. 가로 스크롤·확대/축소·단축키는 Pro.",
                       "Rest a finger on the far left/right edge and slide up or down. Horizontal scroll, zoom and shortcuts are Pro."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(t("⭐ 스와이프 앱 전환 (Pro)", "⭐ Swipe to switch apps (Pro)")) {
                ProToggle(title: t("한 손가락 대고 두 손가락을 좌우로 → 앱 전환 (⌘Tab)", "Rest one finger, slide two fingers sideways → switch apps (⌘Tab)"),
                          isOn: Binding(get: { settings.appSwitch }, set: { settings.appSwitch = $0 }))
                Text(t("시스템 설정 → 트랙패드 → 추가 제스처의 '전체 화면 앱 쓸어넘기기'가 세 손가락이면 네 손가락으로 바꿔 주세요.",
                       "If System Settings → Trackpad → More Gestures uses three fingers for swiping between full-screen apps, switch it to four."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            ExcludedAppsSection()

            Section {
                HStack {
                    Text(t("제스처 하는 법, 동작 바꾸기, Pro 등록, 문제 해결", "How to use gestures, change actions, register Pro, troubleshooting"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(t("📖 사용 설명서", "📖 User guide")) { NSWorkspace.shared.open(Store.guideURL) }
                }
                Toggle(isOn: $settings.typingGuard) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("타자 칠 때는 잠깐 쉬기", "Pause while typing"))
                        Text(t("키보드를 누른 뒤 0.5초 동안은 제스처를 무시해요 (손바닥이 닿아 잘못 실행되는 것 방지)",
                               "Ignores gestures for 0.5 s after a key press, so a resting palm won't trigger anything"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(t("제스처가 인식되면 트랙패드 진동", "Haptic feedback when a gesture is recognized"), isOn: $settings.haptic)
                Toggle(t("로그인 시 자동 실행", "Launch at login"), isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.launchAtLogin = $0 }))
                HStack {
                    Text(t("사용 체크와 동작을 처음 상태로 돌려요", "Restore gesture checkboxes and actions"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(t("기본 설정으로 되돌리기", "Reset to defaults")) { confirmReset = true }
                }
            }

            Section {
                Picker(t("언어", "Language"), selection: $language.choice) {
                    ForEach(AppLanguage.Choice.allCases) { Text($0.title).tag($0) }
                }
                UpdateRow()
            }

            TroubleshootSection()
            FeedbackSection()

            if Store.sellsPro { ProSection().id("pro") }

            if Store.tipURL != nil {
                Section {
                    HStack {
                        Text(t("톡톡이 마음에 드셨다면", "Enjoying TokTok?"))
                        Spacer()
                        Button(t("☕ 개발자에게 커피 사주기", "☕ Buy the developer a coffee")) { license.openTip() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        // 언어를 바꾸면 제목까지 새로 그리기
        .id(language.choice)
        .onChange(of: language.choice) { _ in
            DispatchQueue.main.async { NSApp.windows.first { $0.contentViewController is NSHostingController<SettingsView> }?.title = t("톡톡 설정", "TokTok Settings") }
        }
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
        .confirmationDialog(t("모든 제스처를 기본 설정으로 되돌릴까요?", "Reset all gestures to defaults?"), isPresented: $confirmReset) {
            Button(t("되돌리기", "Reset"), role: .destructive) { settings.resetToDefaults() }
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
    @ObservedObject var language = AppLanguage.shared
    @State private var recording = false

    var body: some View {
        let s = settings.setting(gesture)
        HStack(alignment: .center, spacing: 12) {
            let locked = gesture.isPro && !license.isPro
            Toggle(isOn: Binding(get: { s.enabled && !locked }, set: { on in
                if locked { license.openCheckout() } else { settings.setEnabled(gesture, on) }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gesture.title + (locked ? "  🔒" : ""))
                    Text(gesture.hint).font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            // 기본 제공 동작은 무료, 직접 입력(단축키 녹화)은 Pro
            Menu(effectiveTitle(s)) {
                ForEach(PresetAction.Category.allCases, id: \.self) { c in
                    Section(c.title) {
                        ForEach(PresetAction.allCases.filter { $0.category == c }) { p in
                            Button(p.title) { settings.setAction(gesture, .preset(p)) }
                        }
                    }
                }
                Divider()
                if license.isPro {
                    Button(t("직접 입력 (단축키 녹화)…", "Custom (record shortcut)…")) { recording = true }
                } else {
                    Button(t("🔒 직접 입력 (단축키 녹화) — Pro", "🔒 Custom (record shortcut) — Pro")) { license.openCheckout() }
                }
            }
            .frame(width: 230)
            .disabled(!s.enabled || locked)
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
            Text(t("원하는 단축키를 누르세요", "Press the shortcut you want")).font(.headline)
            Text(t("여러 개를 누르면 순서대로 실행돼요 (최대 \(maxKeys)개)", "Press several to run them in order (up to \(maxKeys))"))
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if keys.isEmpty {
                    Text(t("예: ⌘⇧T  또는  ⌘A → ⌘C", "e.g. ⌘⇧T  or  ⌘A → ⌘C")).foregroundStyle(.tertiary)
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
                Button(t("지우기", "Clear")) { keys.removeAll() }.disabled(keys.isEmpty)
                Spacer()
                Button(t("취소", "Cancel")) { finish(nil) }
                Button(t("완료", "Done")) { finish(keys) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(keys.isEmpty)
            }
            Text(t("⌘Space, ⌘Tab 처럼 macOS가 먼저 가져가는 단축키는 녹화되지 않아요.", "Shortcuts macOS grabs first, like ⌘Space or ⌘Tab, can’t be recorded."))
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
    @ObservedObject var language = AppLanguage.shared
    @State private var code = ""
    @State private var error: String?
    @State private var busy = false
    /// 등록된 기기 (Pro 사용 중이거나, 한도 초과로 해제가 필요할 때)
    @State private var devices: [License.Device] = []

    var body: some View {
        Section(t("톡톡 Pro", "TokTok Pro")) {
            if license.payload != nil || Demo.on {
                HStack {
                    Label(t("Pro 사용 중 — ", "Pro active — ") + "\(Demo.on ? "you@example.com" : license.email ?? "")", systemImage: "checkmark.seal.fill")
                    Spacer()
                    Text(Demo.on ? "TOK-A2B3-C4D5-E6F7" : license.code ?? "").font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
                deviceList(code: nil)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("원하는 단축키를 직접 녹화해 제스처에 연결 (여러 키 순서 실행)", "Record your own shortcuts for gestures (including key sequences)"))
                        Text(Store.priceText).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(t("Pro 구매", "Get Pro")) { license.openCheckout() }
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    TextField(t("라이선스 코드 (TOK-XXXX-XXXX-XXXX)", "License code (TOK-XXXX-XXXX-XXXX)"), text: $code)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: code) { new in
                            let f = LicenseCode.format(new)
                            if f != new { code = f }
                        }
                        .onSubmit(register)
                    Button(busy ? t("등록 중…", "Registering…") : t("등록", "Register"), action: register)
                        .disabled(code.isEmpty || busy)
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
                if !devices.isEmpty { deviceList(code: code) }
                Button(t("코드를 잃어버렸어요", "I lost my code")) { license.openResend() }
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
                if d.isThisMac { Text(t("이 맥", "This Mac")).font(.caption).padding(.horizontal, 6).background(.quaternary, in: Capsule()) }
                Spacer()
                Button(t("해제", "Remove")) { release(d, code: code) }.disabled(busy)
            }
        }
        Text(t("맥 3대까지 쓸 수 있어요. 포맷 후 같은 맥에 다시 등록할 땐 칸을 차지하지 않아요.", "Use on up to 3 Macs. Re-registering the same Mac after a reinstall doesn’t use another slot."))
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
        alert.messageText = t("‘\(d.device_name ?? "Mac")’을(를) 해제할까요?", "Remove ‘\(d.device_name ?? "Mac")’?")
        alert.informativeText = d.isThisMac ? t("이 맥에서 Pro 기능이 꺼져요. 코드를 다시 입력하면 언제든 다시 등록할 수 있어요.", "Pro will turn off on this Mac. You can register again anytime with your code.")
                                            : t("그 맥에서는 다음 확인 때 Pro 기능이 꺼져요.", "Pro will turn off on that Mac at its next check.")
        alert.addButton(withTitle: t("해제", "Remove")); alert.addButton(withTitle: t("취소", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        Task {
            do { devices = try await license.deactivate(deviceID: d.device_id, code: code); error = nil }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

/// Pro 기능 켜기 (Pro 가 아니면 구매 페이지로)
struct ProToggle: View {
    let title: String
    let isOn: Binding<Bool>
    @ObservedObject var license = License.shared

    var body: some View {
        Toggle(isOn: Binding(get: { isOn.wrappedValue && license.isPro }, set: { on in
            if license.isPro { isOn.wrappedValue = on } else { license.openCheckout() }
        })) { Text(title + (license.isPro ? "" : "  🔒")) }
    }
}

/// 가장자리 슬라이더 한 줄 (켜기 + 조절할 것)
struct SliderRow: View {
    let side: EdgeSide
    @ObservedObject var settings = Settings.shared
    @ObservedObject var license = License.shared
    @ObservedObject var language = AppLanguage.shared
    @State private var recording = false

    var body: some View {
        let s = settings.slider(side)
        HStack {
            Toggle(side.title, isOn: Binding(get: { s.enabled }, set: { var n = s; n.enabled = $0; settings.setSlider(side, n) }))
                .toggleStyle(.checkbox)
            Spacer()
            Menu(s.mode.isPro && !license.isPro ? SliderSetting.default(side).mode.title : s.mode.title) {
                ForEach(SliderMode.presets, id: \.title) { m in
                    if m.isPro && !license.isPro {
                        Button("🔒 " + m.title + " — Pro") { license.openCheckout() }
                    } else {
                        Button(m.title) { var n = s; n.mode = m; settings.setSlider(side, n) }
                    }
                }
                Divider()
                if license.isPro {
                    Button(t("직접 입력 (위·아래 단축키 녹화)…", "Custom (record up/down shortcuts)…")) { recording = true }
                } else {
                    Button(t("🔒 직접 입력 — Pro", "🔒 Custom — Pro")) { license.openCheckout() }
                }
            }
            .frame(width: 230)
            .disabled(!s.enabled)
            .popover(isPresented: $recording) {
                SliderRecorder { up, down in
                    if let up, let down { var n = s; n.mode = .custom(up: up, down: down); settings.setSlider(side, n) }
                    recording = false
                }
            }
        }
    }
}

/// 슬라이더 직접 입력: 위로 쓸 때 → 아래로 쓸 때 단축키를 차례로 녹화
struct SliderRecorder: View {
    let done: ([Shortcut]?, [Shortcut]?) -> Void
    @State private var up: [Shortcut]?

    var body: some View {
        VStack(spacing: 6) {
            Text(up == nil ? t("① 위로 쓸 때", "① Sliding up") : t("② 아래로 쓸 때", "② Sliding down")).font(.headline).padding(.top, 14)
            if up == nil {
                ShortcutRecorder { keys in if let keys { up = keys } else { done(nil, nil) } }
            } else {
                ShortcutRecorder { keys in done(up, keys) }.id("down")
            }
        }
    }
}

/// 앱별 끄기 (Pro): 게임·원격 데스크톱처럼 톡톡이 방해되는 앱
struct ExcludedAppsSection: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var license = License.shared
    @ObservedObject var language = AppLanguage.shared

    var body: some View {
        Section(t("⭐ 앱별 끄기 (Pro)", "⭐ Turn off in apps (Pro)")) {
            ForEach(settings.excludedApps, id: \.self) { id in
                HStack {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                    }
                    Text(Self.name(id))
                    Spacer()
                    Button(t("빼기", "Remove")) { settings.excludedApps.removeAll { $0 == id } }
                }
            }
            HStack {
                Text(t("이 앱들이 맨 앞에 있을 때는 톡톡이 쉬어요", "TokTok pauses while these apps are in front"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if license.isPro {
                    Menu(t("앱 추가", "Add app")) {
                        ForEach(Self.runningApps(excluding: settings.excludedApps), id: \.self) { id in
                            Button(Self.name(id)) { settings.excludedApps.append(id) }
                        }
                    }
                    .frame(width: 120)
                } else {
                    Button(t("🔒 Pro", "🔒 Pro")) { license.openCheckout() }
                }
            }
        }
    }

    static func name(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func runningApps(excluding: [String]) -> [String] {
        let ids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !excluding.contains($0) && $0 != Bundle.main.bundleIdentifier }
        return Array(Set(ids)).sorted { name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending }
    }
}

/// 의견·아이디어 보내기 (서버를 거쳐 메일로)
struct FeedbackSection: View {
    @ObservedObject var language = AppLanguage.shared
    @State private var text = ""
    @State private var email = ""
    @State private var status: String?
    @State private var busy = false

    var body: some View {
        Section(t("💬 의견 · 아이디어 보내기", "💬 Send feedback or ideas")) {
            TextEditor(text: $text)
                .frame(height: 70)
                .font(.body)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(t("이런 제스처가 있으면 좋겠어요, 이게 잘 안 돼요…", "A gesture I'd love, something that doesn't work…"))
                            .foregroundStyle(.tertiary).padding(.top, 1).padding(.leading, 5).allowsHitTesting(false)
                    }
                }
            HStack {
                TextField(t("답장 받을 이메일 (선택)", "Email for a reply (optional)"), text: $email)
                    .textFieldStyle(.roundedBorder)
                Button(busy ? t("보내는 중…", "Sending…") : t("보내기", "Send"), action: send)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || busy)
            }
            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func send() {
        busy = true; status = nil
        Task {
            var req = URLRequest(url: Store.server.appendingPathComponent("api/feedback"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let os = ProcessInfo.processInfo.operatingSystemVersion
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "message": text, "email": email, "lang": Store.langCode,
                "app": Updater.current, "os": "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                "pro": License.shared.payload != nil ? "yes" : "no",
            ])
            let ok = ((try? await URLSession.shared.data(for: req))?.1 as? HTTPURLResponse)?.statusCode == 200
            status = ok ? t("고마워요! 잘 받았어요 🙏", "Thank you! We got it 🙏")
                        : t("보내지 못했어요. help@seoriarts.com 으로 보내 주세요.", "Couldn't send. Please email help@seoriarts.com.")
            if ok { text = "" }
            busy = false
        }
    }
}

/// 문제 해결: 트랙패드 다시 찾기, 디버그 로그
struct TroubleshootSection: View {
    @ObservedObject var language = AppLanguage.shared
    @State private var debug = Log.enabled
    @State private var count = Multitouch.current?.deviceCount ?? 0

    var body: some View {
        Section(t("문제 해결", "Troubleshooting")) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("트랙패드 \(count)개 연결됨", "\(count) trackpad(s) connected"))
                    Text(t("매직 트랙패드를 연결하면 자동으로 찾아요. 안 되면 다시 찾기를 눌러 주세요.",
                           "Magic Trackpad is detected automatically when connected. If not, click Rescan."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("다시 찾기", "Rescan")) {
                    Multitouch.current?.restart()
                    count = Multitouch.current?.deviceCount ?? 0
                }
            }
            Toggle(isOn: Binding(get: { debug }, set: { on in
                debug = on; Log.enabled = on; UserDefaults.standard.set(on, forKey: "debug")
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("디버그 로그 기록", "Debug logging"))
                    Text(t("제스처가 인식되지 않은 이유를 기록해요. 문의할 때 로그 파일을 함께 보내 주세요.",
                           "Records why a gesture wasn’t recognized. Attach the log file when contacting support."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if debug {
                HStack {
                    Spacer()
                    Button(t("로그 파일 보기", "Show log file")) {
                        if FileManager.default.fileExists(atPath: Log.url.path) {
                            NSWorkspace.shared.activateFileViewerSelecting([Log.url])
                        } else {
                            let a = NSAlert()
                            a.messageText = t("아직 기록된 로그가 없어요", "No log yet")
                            a.informativeText = t("제스처를 몇 번 해 본 뒤 다시 눌러 주세요.", "Try a few gestures, then click again.")
                            a.runModal()
                        }
                    }
                }
            }
        }
        .onAppear { count = Multitouch.current?.deviceCount ?? 0 }
    }
}

/// 업데이트 확인 · 설치 (한 번에)
struct UpdateRow: View {
    @ObservedObject var updater = Updater.shared
    @ObservedObject var language = AppLanguage.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("업데이트", "Updates"))
                Text(status).font(.caption).foregroundStyle(isError ? .red : .secondary)
            }
            Spacer()
            switch updater.state {
            case .available(let v, _):
                Button(t("\(v) 설치하고 다시 시작", "Install \(v) and relaunch")) { Task { await updater.install() } }
                    .buttonStyle(.borderedProminent)
            case .checking, .installing:
                ProgressView().controlSize(.small)
            case .failed:
                Button(t("웹에서 받기", "Download")) { updater.openReleasePage() }
                Button(t("다시 확인", "Check again")) { Task { await updater.check() } }
            default:
                Button(t("업데이트 확인", "Check for updates")) { Task { await updater.check() } }
            }
        }
    }

    private var isError: Bool { if case .failed = updater.state { return true }; return false }

    private var status: String {
        let cur = t("현재 버전 ", "Current version ") + Updater.current
        switch updater.state {
        case .idle:                   return cur
        case .checking:               return t("확인하는 중…", "Checking…")
        case .upToDate:               return cur + t(" · 최신 버전이에요", " · You're up to date")
        case .available(let v, _):    return cur + t(" · 새 버전 \(v) 이 있어요", " · Version \(v) is available")
        case .installing:             return t("받아서 설치하는 중… 곧 다시 시작돼요", "Downloading and installing… TokTok will relaunch")
        case .failed(let m):          return m
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
