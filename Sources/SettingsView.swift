import SwiftUI

// MARK: - 설정 창

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var license = License.shared
    @State private var confirmReset = false

    var body: some View {
        Form {
            ForEach(Gesture.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(Gesture.allCases.filter { $0.group == group }) { g in
                        GestureRow(gesture: g)
                    }
                }
            }

            Section {
                Toggle("로그인 시 자동 실행", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.launchAtLogin = $0 }))
                HStack {
                    Text("사용 체크와 동작을 처음 상태로 돌려요")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("기본 설정으로 되돌리기") { confirmReset = true }
                }
            }

            if Store.sellsPro { ProSection() }

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
        .frame(width: 600, height: 680)
        .confirmationDialog("모든 제스처를 기본 설정으로 되돌릴까요?", isPresented: $confirmReset) {
            Button("되돌리기", role: .destructive) { settings.resetToDefaults() }
        }
    }
}

struct GestureRow: View {
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

            if license.isPro {
                Menu(s.action.title) {
                    ForEach(PresetAction.allCases) { p in
                        Button(p.title) { settings.setAction(gesture, .preset(p)) }
                    }
                    Divider()
                    Button("단축키 직접 지정…") { recording = true }
                }
                .frame(width: 230)
                .disabled(!s.enabled)
                .popover(isPresented: $recording) {
                    ShortcutRecorder { shortcut in
                        if let shortcut { settings.setAction(gesture, .shortcut(shortcut)) }
                        recording = false
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Text(gesture.defaultSetting.action.title).foregroundStyle(.secondary)
                    Button { license.openCheckout() } label: { Image(systemName: "lock.fill") }
                        .buttonStyle(.borderless)
                        .help("동작을 바꾸려면 톡톡 Pro가 필요해요")
                }
                .frame(width: 230, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 누른 키 조합을 단축키로 기록
struct ShortcutRecorder: View {
    let done: (Shortcut?) -> Void
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 8) {
            Text("원하는 단축키를 누르세요").font(.headline)
            Text("예: ⌘⇧T   ·   취소: esc").font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 0x35, event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
                    finish(nil)
                } else {
                    finish(Shortcut(event: event))
                }
                return nil
            }
        }
        .onDisappear { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    }

    private func finish(_ s: Shortcut?) {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        done(s)
    }
}

struct ProSection: View {
    @ObservedObject var license = License.shared
    @State private var key = ""
    @State private var error: String?

    var body: some View {
        Section("톡톡 Pro") {
            if let email = license.email {
                HStack {
                    Label("Pro 사용 중 — \(email)", systemImage: "checkmark.seal.fill")
                    Spacer()
                    Button("해제") { license.deactivate() }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("제스처마다 원하는 동작·단축키로 바꾸기")
                        Text(Store.priceText).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Pro 구매") { license.openCheckout() }
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    TextField("라이선스 키", text: $key)
                    Button("등록") {
                        do { try license.activate(key); error = nil; key = "" }
                        catch { self.error = error.localizedDescription }
                    }
                    .disabled(key.isEmpty)
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
    }
}
